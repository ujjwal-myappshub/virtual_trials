import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceDetectorService {
  final FaceDetector _faceDetector;
  bool _isDisposed = false;

  FaceDetectorService()
      : _faceDetector = FaceDetector(
          options: FaceDetectorOptions(
            performanceMode: FaceDetectorMode.accurate,
            enableLandmarks: true,
            enableClassification: false,
            enableTracking: true,
            minFaceSize: 0.15,
          ),
        );

  Future<List<Face>> processImage(InputImage inputImage) async {
    if (_isDisposed) return [];
    try {
      return await _faceDetector.processImage(inputImage);
    } catch (e) {
      debugPrint('Face detection error: $e');
      return [];
    }
  }

  void dispose() {
    if (!_isDisposed) {
      _faceDetector.close();
      _isDisposed = true;
    }
  }
}
