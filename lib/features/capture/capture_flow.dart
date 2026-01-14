import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/timeline_item.dart';
import '../../mtg/buckets.dart';
import '../../mtg/ocr_bucket_classifier.dart';
import '../../session/session_item_id.dart';
import '../../session/session_scope.dart';
import '../../session/session_store.dart';

class CaptureFlow {
  const CaptureFlow._();

  static const int _thumbnailSize = 288;
  static const int _thumbnailQuality = 80;

  static Future<void> start(BuildContext context) async {
    final source = await _pickSource(context);
    if (source == null) return;

    final picked = await _pickImage(source);
    if (picked == null) return;

    final store = SessionScope.of(context);
    final originalPath = picked.path;
    final workingPath = await _copyToWorkingFile(originalPath) ?? originalPath;
    final shouldDeleteWorking = workingPath != originalPath;
    final shouldDeleteOriginal = source == ImageSource.camera;
    String? textCropPath;
    String? artCropPath;

    try {
      final textCrop = await _cropImage(
        sourcePath: workingPath,
        title: 'Crop rules text',
        compressFormat: ImageCompressFormat.png,
        compressQuality: 100,
      );
      if (textCrop == null) {
        _showSnack(context, 'Capture canceled');
        return;
      }
      textCropPath = textCrop.path;

      final ocrText = await _runOcrWithFallbacks(textCropPath!);
      await _safeDelete(textCropPath);
      textCropPath = null;

      final artCrop = await _cropImage(
        sourcePath: workingPath,
        title: 'Crop artwork',
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 90,
      );
      if (artCrop == null) {
        _showSnack(context, 'Capture canceled');
        return;
      }
      artCropPath = artCrop.path;

      final thumbnailBytes = await _generateThumbnailBytes(artCropPath);
      final thumbnailPath = await store.cacheThumbnailBytes(thumbnailBytes);
      final editedOcrText = await _editOcrText(context, ocrText);
      if (editedOcrText == null) {
        _showSnack(context, 'Capture canceled');
        return;
      }
      final suggestionText = _buildSuggestionText(
        originalText: ocrText,
        editedText: editedOcrText,
      );
      final suggestedBucketId = suggestionText == null
          ? null
          : OcrBucketClassifier.suggestBucketId(suggestionText);
      final bucketId = await _pickBucket(
        context,
        suggestedBucketId: suggestedBucketId,
      );
      if (bucketId == null) {
        _showSnack(context, 'Capture canceled');
        return;
      }

      final resolvedOcrText = _resolveOcrText(
        originalText: ocrText,
        editedText: editedOcrText,
      );
      store.addItem(
        TimelineItem(
          id: newSessionItemId(),
          bucketId: bucketId,
          label: 'Scanned card',
          ocrText: resolvedOcrText,
          thumbnailPath: thumbnailPath,
        ),
      );

      _showSnack(context, _buildOcrSnackMessage(resolvedOcrText));
    } catch (_) {
      _showSnack(context, 'Capture failed');
    } finally {
      if (shouldDeleteWorking) {
        await _safeDelete(workingPath);
      }
      if (shouldDeleteOriginal) {
        await _safeDelete(originalPath);
      }
      await _safeDelete(textCropPath);
      await _safeDelete(artCropPath);
    }
  }

  static Future<ImageSource?> _pickSource(BuildContext context) async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take photo'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from library'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
  }

  static Future<String?> _pickBucket(
    BuildContext context, {
    String? suggestedBucketId,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final buckets = [
          for (final bucket in MtgBuckets.ordered)
            if (bucket.id != MtgBuckets.trash.id) bucket,
        ];
        MtgBucketDefinition? suggestedBucket;
        if (suggestedBucketId != null) {
          for (final bucket in buckets) {
            if (bucket.id == suggestedBucketId) {
              suggestedBucket = bucket;
              break;
            }
          }
        }
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(title: Text('Add to step')),
              if (suggestedBucket != null) ...[
                ListTile(
                  leading: const Icon(Icons.auto_awesome_outlined),
                  title: Text('Suggested: ${suggestedBucket.label}'),
                  onTap: () => Navigator.of(context).pop(suggestedBucket.id),
                ),
                const Divider(height: 1),
              ],
              for (final bucket in buckets)
                ListTile(
                  title: Text(bucket.label),
                  onTap: () => Navigator.of(context).pop(bucket.id),
                ),
            ],
          ),
        );
      },
    );
  }

  static Future<String?> _runOcrWithFallbacks(String sourcePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final tempPaths = <String>[];
    try {
      final originalText = await _runOcrOnPath(recognizer, sourcePath);
      if (_isGoodOcrText(originalText)) return originalText;

      final processedPath = await _prepareOcrInput(
        sourcePath,
        highContrast: false,
      );
      if (processedPath != sourcePath) tempPaths.add(processedPath);
      final processedText = await _runOcrOnPath(recognizer, processedPath);
      var bestText = _pickBestText(originalText, processedText);
      if (_isGoodOcrText(bestText)) return bestText;

      final highContrastPath = await _prepareOcrInput(
        sourcePath,
        highContrast: true,
      );
      if (highContrastPath != sourcePath) tempPaths.add(highContrastPath);
      final highContrastText = await _runOcrOnPath(
        recognizer,
        highContrastPath,
      );
      bestText = _pickBestText(bestText, highContrastText);
      return bestText;
    } catch (_) {
      return null;
    } finally {
      await recognizer.close();
      for (final path in tempPaths) {
        await _safeDelete(path);
      }
    }
  }

  static Future<String?> _runOcrOnPath(
    TextRecognizer recognizer,
    String path,
  ) async {
    try {
      final input = InputImage.fromFilePath(path);
      final result = await recognizer.processImage(input);
      return result.text;
    } catch (_) {
      return null;
    }
  }

  static Future<String> _prepareOcrInput(
    String sourcePath, {
    required bool highContrast,
  }) async {
    try {
      final bytes = await File(sourcePath).readAsBytes();
      final processed = await compute(
        highContrast ? _preprocessOcrImageHighContrast : _preprocessOcrImage,
        bytes,
      );
      if (processed == null) return sourcePath;
      final tempDir = await getTemporaryDirectory();
      final filename = 'ocr_${DateTime.now().microsecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$filename');
      await file.writeAsBytes(processed, flush: true);
      return file.path;
    } catch (_) {
      return sourcePath;
    }
  }

  static Future<String?> _editOcrText(
    BuildContext context,
    String? ocrText,
  ) async {
    final controller = TextEditingController(text: ocrText ?? '');
    try {
      return await showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Review rules text'),
            content: TextField(
              controller: controller,
              minLines: 4,
              maxLines: 10,
              decoration: const InputDecoration(
                labelText: 'Rules text',
                hintText: 'Edit before saving to a step',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(controller.text),
                child: const Text('Save text'),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  static String? _pickBestText(String? first, String? second) {
    if (first == null) return second;
    if (second == null) return first;
    return _scoreOcrText(second) > _scoreOcrText(first) ? second : first;
  }

  static int _scoreOcrText(String? text) {
    if (text == null) return 0;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    final alnumMatches = RegExp(r'[A-Za-z0-9]').allMatches(trimmed).length;
    final lineBreaks = '\n'.allMatches(trimmed).length;
    return alnumMatches + (lineBreaks * 6);
  }

  static bool _isGoodOcrText(String? text) {
    if (text == null) return false;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    final compact = trimmed.replaceAll(RegExp(r'\s+'), '');
    if (compact.length >= 120) return true;
    if (compact.length >= 40 && trimmed.contains('\n')) return true;
    return false;
  }

  static String _resolveOcrText({
    required String? originalText,
    required String editedText,
  }) {
    final trimmed = editedText.trim();
    if (trimmed.isNotEmpty) return trimmed;
    if (originalText == null || originalText.trim().isEmpty) {
      return 'OCR failed';
    }
    return 'No rules text';
  }

  static String _buildOcrSnackMessage(String text) {
    if (text == 'OCR failed') return 'Added card (OCR failed)';
    if (text == 'No rules text') return 'Added card (no rules text)';
    return 'Added card';
  }

  static Future<CroppedFile?> _cropImage({
    required String sourcePath,
    required String title,
    required ImageCompressFormat compressFormat,
    required int compressQuality,
  }) {
    return ImageCropper().cropImage(
      sourcePath: sourcePath,
      compressFormat: compressFormat,
      compressQuality: compressQuality,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: title,
          toolbarColor: Colors.black,
          toolbarWidgetColor: Colors.white,
          hideBottomControls: false,
        ),
        IOSUiSettings(title: title),
      ],
    );
  }

  static Future<Uint8List?> _generateThumbnailBytes(String sourcePath) async {
    final bytes = await File(sourcePath).readAsBytes();
    return compute(_encodeThumbnail, bytes);
  }

  static Future<XFile?> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    try {
      final picked = await picker.pickImage(source: source);
      if (picked != null) return picked;

      final lost = await picker.retrieveLostData();
      if (lost.isEmpty) return null;
      return lost.file;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _copyToWorkingFile(String path) async {
    final source = File(path);
    if (!await source.exists()) return null;
    try {
      final tempDir = await getTemporaryDirectory();
      final extension = path.contains('.') ? path.split('.').last : 'jpg';
      final filename =
          'capture_${DateTime.now().microsecondsSinceEpoch}.$extension';
      final dest = File('${tempDir.path}/$filename');
      await source.copy(dest.path);
      return dest.path;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _safeDelete(String? path) async {
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (!await file.exists()) return;
    try {
      await file.delete();
    } catch (_) {}
  }

  static void _showSnack(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static String? _buildSuggestionText({
    required String? originalText,
    required String editedText,
  }) {
    final trimmedEdited = editedText.trim();
    if (trimmedEdited.isNotEmpty) return trimmedEdited;
    final trimmedOriginal = originalText?.trim() ?? '';
    if (trimmedOriginal.isEmpty) return null;
    return trimmedOriginal;
  }
}

const int _ocrMinSide = 900;
const int _ocrMaxSide = 2000;

Uint8List? _encodeThumbnail(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;

  final square = img.copyResizeCropSquare(
    decoded,
    size: CaptureFlow._thumbnailSize,
  );
  final jpg = img.encodeJpg(square, quality: CaptureFlow._thumbnailQuality);
  return Uint8List.fromList(jpg);
}

Uint8List? _preprocessOcrImage(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;

  var processed = _resizeForOcr(decoded);
  processed = img.grayscale(processed);
  processed = img.contrast(processed, contrast: 125);
  processed = img.normalize(processed, min: 0, max: 255);
  final png = img.encodePng(processed, level: 6);
  return Uint8List.fromList(png);
}

Uint8List? _preprocessOcrImageHighContrast(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;

  var processed = _resizeForOcr(decoded);
  processed = img.grayscale(processed);
  processed = img.contrast(processed, contrast: 160);
  processed = img.normalize(processed, min: 0, max: 255);
  processed = img.luminanceThreshold(processed, threshold: 0.6);
  final png = img.encodePng(processed, level: 6);
  return Uint8List.fromList(png);
}

img.Image _resizeForOcr(img.Image source) {
  final minSide = math.min(source.width, source.height);
  final maxSide = math.max(source.width, source.height);
  if (minSide >= _ocrMinSide && maxSide <= _ocrMaxSide) {
    return source;
  }

  final scale = minSide < _ocrMinSide
      ? _ocrMinSide / minSide
      : _ocrMaxSide / maxSide;
  final targetWidth = (source.width * scale).round();
  final targetHeight = (source.height * scale).round();
  return img.copyResize(
    source,
    width: targetWidth,
    height: targetHeight,
    interpolation: img.Interpolation.cubic,
  );
}
