import 'dart:io';
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
    final workingPath = await _copyToWorkingFile(picked.path) ?? picked.path;
    final shouldDeleteWorking = workingPath != picked.path;
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

      final ocrText = await _runOcr(textCropPath!);
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
      final bucketId = await _pickBucket(context);
      if (bucketId == null) {
        _showSnack(context, 'Capture canceled');
        return;
      }

      final resolvedOcrText =
          ocrText == null || ocrText.trim().isEmpty
              ? 'OCR failed'
              : ocrText.trim();
      store.addItem(
        TimelineItem(
          id: newSessionItemId(),
          bucketId: bucketId,
          label: 'Scanned card',
          ocrText: resolvedOcrText,
          thumbnailPath: thumbnailPath,
        ),
      );

      _showSnack(
        context,
        resolvedOcrText == 'OCR failed'
            ? 'Added card (OCR failed)'
            : 'Added card',
      );
    } catch (_) {
      _showSnack(context, 'Capture failed');
    } finally {
      if (shouldDeleteWorking) {
        await _safeDelete(workingPath);
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

  static Future<String?> _pickBucket(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(title: Text('Add to step')),
              for (final bucket in MtgBuckets.ordered)
                if (bucket.id != MtgBuckets.trash.id)
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

  static Future<String?> _runOcr(String path) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final input = InputImage.fromFilePath(path);
      final result = await recognizer.processImage(input);
      return result.text;
    } catch (_) {
      return null;
    } finally {
      await recognizer.close();
    }
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
}

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
