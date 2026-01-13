import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

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

    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null) return;

    final store = SessionScope.of(context);
    final originalPath = picked.path;
    String? textCropPath;
    String? artCropPath;

    try {
      final textCrop = await _cropImage(
        sourcePath: originalPath,
        title: 'Crop rules text',
      );
      if (textCrop == null) {
        _showSnack(context, 'Capture canceled');
        return;
      }
      textCropPath = textCrop.path;

      final artCrop = await _cropImage(
        sourcePath: originalPath,
        title: 'Crop artwork',
      );
      if (artCrop == null) {
        _showSnack(context, 'Capture canceled');
        return;
      }
      artCropPath = artCrop.path;

      final thumbnailBytes = await _generateThumbnailBytes(artCropPath);
      final thumbnailPath = await store.cacheThumbnailBytes(thumbnailBytes);

      store.addItem(
        TimelineItem(
          id: newSessionItemId(),
          bucketId: MtgBuckets.staticEffects.id,
          label: 'Scanned card',
          ocrText: 'OCR pending',
          thumbnailPath: thumbnailPath,
        ),
      );

      _showSnack(context, 'Added card (OCR pending)');
    } catch (_) {
      _showSnack(context, 'Capture failed');
    } finally {
      await _safeDelete(originalPath);
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

  static Future<CroppedFile?> _cropImage({
    required String sourcePath,
    required String title,
  }) {
    return ImageCropper().cropImage(
      sourcePath: sourcePath,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 90,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: title,
          toolbarColor: Colors.black,
          toolbarWidgetColor: Colors.white,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: title,
        ),
      ],
    );
  }

  static Future<Uint8List?> _generateThumbnailBytes(
    String sourcePath,
  ) async {
    final bytes = await File(sourcePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    final square = img.copyResizeCropSquare(
      decoded,
      size: _thumbnailSize,
    );
    final jpg = img.encodeJpg(square, quality: _thumbnailQuality);
    return Uint8List.fromList(jpg);
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

