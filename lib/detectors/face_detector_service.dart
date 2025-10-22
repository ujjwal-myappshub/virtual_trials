// lib/detectors/face_detector_service.dart
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart'; // <--- ADDED for debugPrint
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart'; // rotations / formats

class FaceDetectorService {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: false,
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  /// Convert [CameraImage] -> [InputImage] for ML Kit
  InputImage? _inputFromCamera(CameraImage image, int rotation) {
    // 1) Determine format group
    final ImageFormatGroup formatGroup = image.format.group;
    if (formatGroup != ImageFormatGroup.nv21 &&
        formatGroup != ImageFormatGroup.yuv420 &&
        formatGroup != ImageFormatGroup.bgra8888) {
      debugPrint('Unsupported image format for ML Kit: $formatGroup');
      return null;
    }

    // 2) Build bytes in a way ML Kit expects
    Uint8List bytes;
    late final InputImageFormat inputFormat;

    if (formatGroup == ImageFormatGroup.nv21) {
      inputFormat = InputImageFormat.nv21;
      if (image.planes.length >= 2) {
        final y = image.planes[0].bytes;
        final vu = image.planes[1].bytes;
        final builder = BytesBuilder();
        builder.add(y);
        builder.add(vu);
        bytes = builder.toBytes();
      } else {
        final builder = BytesBuilder();
        for (final p in image.planes) builder.add(p.bytes);
        bytes = builder.toBytes();
      }
    } else if (formatGroup == ImageFormatGroup.yuv420) {
      inputFormat = InputImageFormat.nv21;
      final y = image.planes[0].bytes;
      final u = image.planes.length > 1 ? image.planes[1].bytes : Uint8List(0);
      final v = image.planes.length > 2 ? image.planes[2].bytes : Uint8List(0);
      final uvLength = (u.length < v.length) ? u.length : v.length;
      final vuInterleaved = Uint8List(uvLength * 2);
      for (int i = 0, j = 0; i < uvLength; i++, j += 2) {
        vuInterleaved[j] = v[i];
        vuInterleaved[j + 1] = u[i];
      }
      final builder = BytesBuilder();
      builder.add(y);
      builder.add(vuInterleaved);
      bytes = builder.toBytes();
    } else if (formatGroup == ImageFormatGroup.bgra8888) {
      inputFormat = InputImageFormat.bgra8888;
      bytes = image.planes.first.bytes;
    } else {
      return null;
    }

    // 3) Metadata
    final ui.Size imageSize = ui.Size(image.width.toDouble(), image.height.toDouble());
    final InputImageRotation imageRotation =
        InputImageRotationValue.fromRawValue(rotation) ?? InputImageRotation.rotation0deg;

    final metadata = InputImageMetadata(
      size: imageSize,
      rotation: imageRotation,
      format: inputFormat,
      bytesPerRow: image.planes.first.bytesPerRow,
    );

    try {
      return InputImage.fromBytes(bytes: bytes, metadata: metadata);
    } catch (e, st) {
      debugPrint('InputImage.fromBytes error: $e\n$st');
      return null;
    }
  }

  /// Process camera image and return detected faces (empty list if none / on error)
  Future<List<Face>> processCameraImage(CameraImage image, int rotation) async {
    final input = _inputFromCamera(image, rotation);
    if (input == null) return <Face>[];
    try {
      final faces = await _faceDetector.processImage(input);
      return faces;
    } catch (e, st) {
      debugPrint('face detection error: $e\n$st');
      return <Face>[];
    }
  }

  void dispose() => _faceDetector.close();
}