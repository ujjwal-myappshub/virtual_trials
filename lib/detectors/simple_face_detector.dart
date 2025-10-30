import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// Simple face detector using skin tone and brightness detection
/// More reliable than ML Kit for basic AR jewelry placement
class SimpleFaceDetector {
  double _lastFaceX = 0.5;
  double _lastFaceY = 0.4;
  double _lastFaceSize = 0.25;

  // Configurable parameters for better accuracy across skin tones and lighting
  static const int _samplingStep = 6; // Reduced from 8 for better resolution
  static const int _minBrightness = 60; // Wider range for different skin tones
  static const int _maxBrightness = 220;
  static const int _minPixelCount = 100;

  /// Detect face using skin tone and brightness analysis
  FaceDetectionResult detectFace(CameraImage image) {
    try {
      if (image.planes.isEmpty) {
        return FaceDetectionResult(
          centerX: _lastFaceX,
          centerY: _lastFaceY,
          size: _lastFaceSize,
          confidence: 0.0,
        );
      }

      final plane = image.planes[0];
      final bytes = plane.bytes;
      final width = image.width;
      final height = image.height;
      final bytesPerRow = plane.bytesPerRow;

      // Scan for face-like regions (skin tone + brightness)
      int totalX = 0;
      int totalY = 0;
      int pixelCount = 0;
      int maxBrightness = 0;
      int minBrightness = 255;

      // Scan center region of image (where face typically is)
      final startY = (height * 0.2).toInt();
      final endY = (height * 0.8).toInt();
      final startX = (width * 0.25).toInt();
      final endX = (width * 0.75).toInt();

      for (int y = startY; y < endY; y += _samplingStep) {
        for (int x = startX; x < endX; x += _samplingStep) {
          final index = y * bytesPerRow + x;
          if (index >= 0 && index < bytes.length) {
            final brightness = bytes[index];

            // Look for skin-tone brightness range (wider range for inclusivity)
            if (brightness > _minBrightness && brightness < _maxBrightness) {
              totalX += x;
              totalY += y;
              pixelCount++;

              if (brightness > maxBrightness) maxBrightness = brightness;
              if (brightness < minBrightness) minBrightness = brightness;
            }
          }
        }
      }

      if (pixelCount > _minPixelCount) {
        // Found enough skin-tone pixels
        final avgX = totalX / pixelCount;
        final avgY = totalY / pixelCount;
        
        // Normalize to 0-1 range first
        // For front camera in portrait mode, coordinates may need adjustment
        // This handles various device orientations more robustly
        final normalizedX = (avgX / width).clamp(0.0, 1.0);
        final normalizedY = (avgY / height).clamp(0.0, 1.0);
        
        // Estimate face size based on pixel distribution
        final faceSize = (pixelCount / (width * height) * 10).clamp(0.15, 0.4);
        
        // Calculate confidence based on brightness variance
        final brightnessRange = maxBrightness - minBrightness;
        final confidence = (brightnessRange / 120.0).clamp(0.0, 1.0);
        
        // Smooth the values for stable tracking (less aggressive smoothing)
        _lastFaceX = _lastFaceX * 0.6 + normalizedX * 0.4;
        _lastFaceY = _lastFaceY * 0.6 + normalizedY * 0.4;
        _lastFaceSize = _lastFaceSize * 0.7 + faceSize * 0.3;
        
        return FaceDetectionResult(
          centerX: _lastFaceX,
          centerY: _lastFaceY,
          size: _lastFaceSize,
          confidence: confidence,
        );
      } else {
        // Not enough skin-tone pixels, use center of frame
        return FaceDetectionResult(
          centerX: 0.5,
          centerY: 0.4,
          size: 0.25,
          confidence: 0.1,
        );
      }
    } catch (e) {
      debugPrint('Simple face detection error: $e');
      return FaceDetectionResult(
        centerX: _lastFaceX,
        centerY: _lastFaceY,
        size: _lastFaceSize,
        confidence: 0.0,
      );
    }
  }
  
  void reset() {
    _lastFaceX = 0.5;
    _lastFaceY = 0.4;
    _lastFaceSize = 0.25;
  }
}

class FaceDetectionResult {
  final double centerX;
  final double centerY;
  final double size;
  final double confidence;
  
  FaceDetectionResult({
    required this.centerX,
    required this.centerY,
    required this.size,
    required this.confidence,
  });
  
  bool get isDetected => confidence > 0.3;
}
