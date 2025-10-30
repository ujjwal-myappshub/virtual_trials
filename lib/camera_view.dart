import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import '../models/product.dart';
import 'widgets/overlay_painter.dart';

class CameraView extends StatefulWidget {
  final Product product;
  const CameraView({super.key, required this.product});

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CapturedImagePainter extends CustomPainter {
  final ui.Image image;
  final double jewelryOffsetX;
  final double jewelryOffsetY;
  final double jewelryScale;
  final double jewelryRotation;
  final bool showLeft;
  final bool showRight;
  final bool showNecklace;
  final Product product;
  final ui.Image? earringLeft;
  final ui.Image? earringRight;
  final ui.Image? necklace;

  const _CapturedImagePainter(
    this.image, {
    this.jewelryOffsetX = 0.0,
    this.jewelryOffsetY = 0.0,
    this.jewelryScale = 1.0,
    this.jewelryRotation = 0.0,
    required this.showLeft,
    required this.showRight,
    required this.showNecklace,
    required this.product,
    this.earringLeft,
    this.earringRight,
    this.necklace,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (image.width <= 0 || image.height <= 0) return;

    final double imageAspectRatio = image.width / image.height;
    final double screenAspectRatio = size.width / size.height;

    Rect dstRect;
    if (screenAspectRatio > imageAspectRatio) {
      final double imageHeight = size.width / imageAspectRatio;
      final double dy = (size.height - imageHeight) / 2;
      dstRect = Rect.fromLTWH(0, dy, size.width, imageHeight);
    } else {
      final double imageWidth = size.height * imageAspectRatio;
      final double dx = (size.width - imageWidth) / 2;
      dstRect = Rect.fromLTWH(dx, 0, imageWidth, size.height);
    }

    try {
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        dstRect,
        Paint()..filterQuality = FilterQuality.high,
      );

      _drawJewelry(canvas, dstRect);
    } catch (e) {
      debugPrint('Error in paint: $e');
    }
  }

  void _drawJewelry(Canvas canvas, Rect imageRect) {
    final double centerX = imageRect.center.dx + jewelryOffsetX;
    final double centerY = imageRect.center.dy + jewelryOffsetY;
    final double scale = jewelryScale.clamp(0.3, 3.0);

    // Draw necklace
    if (product.type == JewelryType.necklace && showNecklace && necklace != null) {
      final double baseWidth = imageRect.width * 0.6 * scale;
      final double baseHeight = baseWidth * 0.4;

      final Rect dstRect = Rect.fromCenter(
        center: Offset(centerX, centerY),
        width: baseWidth,
        height: baseHeight,
      );

      // Draw shadow
      final shadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
      
      canvas.save();
      canvas.translate(dstRect.center.dx, dstRect.center.dy + 5);
      canvas.scale(1.0, 0.5);
      canvas.drawCircle(
        Offset.zero,
        baseWidth * 0.4,
        shadowPaint,
      );
      canvas.restore();

      // Draw necklace
      canvas.save();
      canvas.translate(dstRect.center.dx, dstRect.center.dy);
      canvas.rotate(jewelryRotation);
      
      // Add a subtle border
      final borderPaint = Paint()
        ..color = Colors.white.withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      
      // Draw the necklace image
      paintImage(
        canvas: canvas,
        rect: Rect.fromCenter(
          center: Offset.zero,
          width: baseWidth,
          height: baseHeight,
        ),
        image: necklace!,
        fit: BoxFit.contain,
      );
      
      // Draw border
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: baseWidth * 0.9,
            height: baseHeight * 0.9,
          ),
          const Radius.circular(8.0),
        ),
        borderPaint,
      );
      
      canvas.restore();
    }
    // Draw earrings (captured mode painter didn't previously handle this)
    else if (product.type == JewelryType.earring) {
      final double eSize = (imageRect.width * 0.14 * scale).clamp(24.0, 160.0);
      // Place around face area heuristically when no face landmarks are available in captured painter
      final double earSpacing = imageRect.width * 0.22 * scale; // horizontal distance from center
      final double earY = centerY - imageRect.height * 0.08; // slightly above center

      final Paint paint = Paint();

      if (earringLeft != null && showLeft) {
        final Rect dstLeft = Rect.fromCenter(
          center: Offset(centerX - earSpacing, earY),
          width: eSize,
          height: eSize * 1.2,
        );
        final Rect srcLeft = Rect.fromLTWH(0, 0, earringLeft!.width.toDouble(), earringLeft!.height.toDouble());

        canvas.save();
        canvas.translate(dstLeft.center.dx, dstLeft.center.dy);
        canvas.rotate(jewelryRotation);
        canvas.translate(-dstLeft.center.dx, -dstLeft.center.dy);
        canvas.drawImageRect(earringLeft!, srcLeft, dstLeft, paint);
        canvas.restore();
      }

      if (earringRight != null && showRight) {
        final Rect dstRight = Rect.fromCenter(
          center: Offset(centerX + earSpacing, earY),
          width: eSize,
          height: eSize * 1.2,
        );
        final Rect srcRight = Rect.fromLTWH(0, 0, earringRight!.width.toDouble(), earringRight!.height.toDouble());

        canvas.save();
        canvas.translate(dstRight.center.dx, dstRight.center.dy);
        canvas.rotate(jewelryRotation);
        canvas.translate(-dstRight.center.dx, -dstRight.center.dy);
        canvas.drawImageRect(earringRight!, srcRight, dstRight, paint);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CapturedImagePainter oldDelegate) {
    return image != oldDelegate.image ||
        jewelryOffsetX != oldDelegate.jewelryOffsetX ||
        jewelryOffsetY != oldDelegate.jewelryOffsetY ||
        (jewelryScale - oldDelegate.jewelryScale).abs() > 0.01 ||
        (jewelryRotation - oldDelegate.jewelryRotation).abs() > 0.01 ||
        showLeft != oldDelegate.showLeft ||
        showRight != oldDelegate.showRight ||
        showNecklace != oldDelegate.showNecklace ||
        product != oldDelegate.product;
  }
}

class _CameraViewState extends State<CameraView> with WidgetsBindingObserver {
  // Camera & controller
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _isCaptured = false;
  bool _torchOn = false;
  ui.Image? _capturedImage;
  DateTime? _lastProcessTime;
  static const int _minProcessingIntervalMs = 66; // ~15 FPS

  // Face tracking
  Face? _face;
  double _estimatedFaceCenterX = 0.5;
  double _estimatedFaceCenterY = 0.4;
  double _estimatedFaceSize = 0.2;
  int _rotation = 0;

  // UI toggles
  bool _showLeft = true;
  bool _showRight = true;
  bool _showNecklace = true;
  bool _adjustmentMode = false;

  // Manual adjustment
  double _jewelryOffsetX = 0.0;
  double _jewelryOffsetY = 0.0;
  double _jewelryScale = 1.0;
  double _jewelryRotation = 0.0;
  double _lastScale = 1.0;
  double _lastRotation = 0.0;
  Offset _lastOffset = Offset.zero;
  Offset _initialFocalPoint = Offset.zero;
  double _initialRotation = 0.0;

  // Face detector
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableTracking: true,
      performanceMode: FaceDetectorMode.accurate,
      minFaceSize: 0.15,
    ),
  );

  // Assets
  ui.Image? _earringLeftImg;
  ui.Image? _earringRightImg;
  ui.Image? _necklaceImg;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _preloadAssets();
  }

  @override
  void dispose() {
    _stopImageStream();
    _controller?.dispose();
    _faceDetector.close();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    } else if (state == AppLifecycleState.paused) {
      _stopImageStream();
    }
  }

  Future<void> _initializeCamera() async {
    if (!mounted) return;

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('No cameras available');
      }

      // Prefer front camera
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.yuv420
            : ImageFormatGroup.bgra8888,
      );

      await _controller?.initialize();
      if (!mounted) return;

      setState(() => _isInitialized = true);
      _startImageStream();
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error initializing camera')),
        );
      }
    }
  }

  void _startImageStream() {
    if (_controller == null || !_isInitialized) return;

    _controller?.startImageStream((CameraImage image) {
      if (!_isProcessing) {
        _isProcessing = true;
        _processCameraImage(image).whenComplete(() {
          _isProcessing = false;
        });
      }
    });
  }

  Future<void> _stopImageStream() async {
    await _controller?.stopImageStream();
    if (mounted) {
      setState(() => _isProcessing = false);
    }
  }

  Future<InputImage?> _inputImageFromCameraImage(
      CameraImage image, int rotation) async {
    try {
      // Get the image bytes
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      // Get image size
      final Size imageSize = Size(
        image.width.toDouble(),
        image.height.toDouble(),
      );

      // Get image rotation
      final imageRotation = InputImageRotationValue.fromRawValue(rotation);
      if (imageRotation == null) return null;

      // Get image format
      final inputImageFormat =
          InputImageFormatValue.fromRawValue(image.format.raw);
      if (inputImageFormat == null) return null;

      // Create input image metadata
      final metadata = InputImageMetadata(
        size: imageSize,
        rotation: imageRotation,
        format: inputImageFormat,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      // Return the input image
      return InputImage.fromBytes(
        bytes: bytes,
        metadata: metadata,
      );
    } catch (e) {
      debugPrint('Error creating InputImage: $e');
      return null;
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (!mounted || _isCaptured) return;

    final now = DateTime.now();
    if (_lastProcessTime != null &&
        now.difference(_lastProcessTime!).inMilliseconds <
            _minProcessingIntervalMs) {
      return;
    }
    _lastProcessTime = now;

    try {
      final inputImage = await _inputImageFromCameraImage(image, _rotation);
      if (inputImage == null) return;

      final faces = await _faceDetector.processImage(inputImage);

      if (!mounted) return;

      if (faces.isNotEmpty) {
        setState(() {
          _face = faces.first;
          _updateFacePosition();
        });
      } else {
        setState(() => _face = null);
      }
    } catch (e) {
      debugPrint('Error processing image: $e');
    }
  }

  void _updateFacePosition() {
    if (_face == null || _controller?.value.previewSize == null) return;

    final previewSize = _controller!.value.previewSize!;
    final face = _face!;

    // Update face position
    final faceRect = face.boundingBox;
    _estimatedFaceCenterX =
        (faceRect.left + faceRect.right) / 2 / previewSize.width;
    _estimatedFaceCenterY =
        (faceRect.top + faceRect.bottom) / 2 / previewSize.height;
    _estimatedFaceSize = faceRect.width / previewSize.width;

    // Update rotation based on face angle
    if (face.headEulerAngleY != null) {
      _jewelryRotation = face.headEulerAngleY! * (3.14159 / 180.0);
    }
  }

  Future<void> _preloadAssets() async {
    try {
      if (widget.product.type == JewelryType.earring) {
        // Load left and right earring assets; fall back to mirroring left if right missing
        await _loadUiImage('assets/jewelry/earring_left.png');
        await _loadUiImage('assets/jewelry/earring_right.png');

        if (_earringRightImg == null && _earringLeftImg != null) {
          setState(() {
            _earringRightImg = _earringLeftImg;
          });
        }
      } else if (widget.product.type == JewelryType.necklace) {
        // Load the selected necklace image explicitly
        await _loadNecklace(widget.product.image);
        // Fallback to default path if loading by product image failed
        if (_necklaceImg == null) {
          await _loadNecklace('assets/jewelry/necklace.png');
        }
      }
    } catch (e) {
      debugPrint('Error preloading assets: $e');
    }
  }

  Future<void> _loadUiImage(String assetPath) async {
    try {
      final ByteData data = await rootBundle.load(assetPath);
      final Uint8List bytes = data.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();

      if (mounted) {
        setState(() {
          if (assetPath.contains('left')) {
            _earringLeftImg = frame.image;
          } else if (assetPath.contains('right')) {
            _earringRightImg = frame.image;
          } else if (assetPath.contains('necklace')) {
            _necklaceImg = frame.image;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading image $assetPath: $e');
    }
  }

  Future<void> _loadNecklace(String assetPath) async {
    try {
      final ByteData data = await rootBundle.load(assetPath);
      final Uint8List bytes = data.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _necklaceImg = frame.image;
        });
      }
    } catch (e) {
      debugPrint('Error loading necklace image $assetPath: $e');
    }
  }

  Future<ui.Image> _loadImage(Uint8List img) async {
    final Completer<ui.Image> completer = Completer();
    ui.decodeImageFromList(img, (ui.Image img) {
      return completer.complete(img);
    });
    return completer.future;
  }

  Future<void> _captureFrame() async {
    if (_controller == null || !_isInitialized) return;

    try {
      final XFile file = await _controller!.takePicture();
      final Uint8List bytes = await file.readAsBytes();
      final ui.Image capturedImage = await _loadImage(bytes);

      if (mounted) {
        setState(() {
          _isCaptured = true;
          _capturedImage = capturedImage;
          _adjustmentMode = true; // Enable adjustment mode after capture
          
          // Reset adjustments to default values
          _jewelryOffsetX = 0.0;
          _jewelryOffsetY = 0.0;
          _jewelryScale = 1.0;
          _jewelryRotation = 0.0;
          _lastScale = 1.0;
          _lastRotation = 0.0;
          _lastOffset = Offset.zero;
          _initialFocalPoint = Offset.zero;
          
          if (_face != null) {
            _updateFacePosition();
          }
        });
      }
    } catch (e) {
      debugPrint('Error capturing frame: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error capturing image')),
        );
      }
    }
  }

  void _resetCapture() {
    setState(() {
      _isCaptured = false;
      _capturedImage = null;
      _adjustmentMode = false; // Disable adjustment mode when retaking
      
      // Reset all adjustments
      _jewelryOffsetX = 0.0;
      _jewelryOffsetY = 0.0;
      _jewelryScale = 1.0;
      _jewelryRotation = 0.0;
      _lastRotation = 0.0;
      
      // Reset face tracking
      _face = null;
      _estimatedFaceCenterX = 0.5;
      _estimatedFaceCenterY = 0.4;
      _estimatedFaceSize = 0.2;
      
      // Restart the camera preview
      _startImageStream();
    });
  }

  Future<void> _toggleTorch() async {
    if (_controller == null || !_isInitialized) return;

    try {
      await _controller!.setFlashMode(
        _torchOn ? FlashMode.off : FlashMode.torch,
      );
      setState(() => _torchOn = !_torchOn);
    } catch (e) {
      debugPrint('Error toggling torch: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Torch not available')),
        );
      }
    }
  }

  Future<void> _closeCameraAndPop() async {
    await _stopImageStream();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return
     PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          await _closeCameraAndPop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Camera preview or captured image
              if (_controller != null && _isInitialized)
                _isCaptured && _capturedImage != null
                  ? Stack(
                      children: [
                        // Captured image
                        CustomPaint(
                          size: Size.infinite,
                          painter: _CapturedImagePainter(
                            _capturedImage!,
                            jewelryOffsetX: _jewelryOffsetX,
                            jewelryOffsetY: _jewelryOffsetY,
                            jewelryScale: _jewelryScale,
                            jewelryRotation: _jewelryRotation,
                            showLeft: _showLeft,
                            showRight: _showRight,
                            showNecklace: _showNecklace,
                            product: widget.product,
                            earringLeft: _earringLeftImg,
                            earringRight: _earringRightImg,
                            necklace: _necklaceImg,
                          ),
                        ),
                        // Gesture detector overlay
                        if (_adjustmentMode)
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onScaleStart: (details) {
                                _initialFocalPoint = details.focalPoint;
                                _lastScale = _jewelryScale;
                                _lastRotation = _jewelryRotation;
                                _lastOffset = Offset(
                                    _jewelryOffsetX, _jewelryOffsetY);
                              },
                              onScaleUpdate: (details) {
                                if (details.scale != 1.0) {
                                  // Scaling
                                  setState(() {
                                    _jewelryScale = _lastScale * details.scale;
                                  });
                                } else if (details.rotation != 0.0) {
                                  // Rotation
                                  setState(() {
                                    _jewelryRotation =
                                        _lastRotation + details.rotation;
                                  });
                                } else if (details.focalPointDelta !=
                                    Offset.zero) {
                                  // Panning
                                  setState(() {
                                    _jewelryOffsetX = _lastOffset.dx +
                                        details.focalPointDelta.dx;
                                    _jewelryOffsetY = _lastOffset.dy +
                                        details.focalPointDelta.dy;
                                  });
                                }
                              },
                            ),
                          ),
                      ],
                    )
                  : CameraPreview(_controller!),

            // Loading indicator
            if (!_isInitialized ||
                _controller == null ||
                !_controller!.value.isInitialized)
              const Center(
                  child: CircularProgressIndicator(color: Colors.white)),

            // Gesture controls for captured image
            if (_isInitialized && _isCaptured && _adjustmentMode)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onScaleStart: (details) {
                    _initialFocalPoint = details.focalPoint;
                    _lastScale = _jewelryScale;
                    _lastRotation = _jewelryRotation;
                    _lastOffset = Offset(_jewelryOffsetX, _jewelryOffsetY);
                  },
                  onScaleUpdate: (details) {
                    setState(() {
                      // Pan with one finger
                      if (details.pointerCount == 1) {
                        _jewelryOffsetX = _lastOffset.dx + (details.focalPoint.dx - _initialFocalPoint.dx);
                        _jewelryOffsetY = _lastOffset.dy + (details.focalPoint.dy - _initialFocalPoint.dy);
                      }
                      
                      // Scale with pinch
                      if (details.scale != 1.0) {
                        _jewelryScale = (_lastScale * details.scale).clamp(0.3, 3.0);
                      }
                      
                      // Rotate with two fingers
                      if (details.rotation != 0.0) {
                        _jewelryRotation = (_lastRotation + details.rotation) % (2 * 3.14159);
                      }
                    });
                  },
                  child: Container(color: Colors.transparent),
                ),
              ),

            // Face overlay (only in camera mode)
            if (_isInitialized && !_isCaptured && _face != null)
              CustomPaint(
                painter: OverlayPainter(
                  face: _face!,
                  imageSize: _controller?.value.previewSize,
                  product: widget.product,
                  earringLeft: _earringLeftImg,
                  earringRight: _earringRightImg,
                  necklace: _necklaceImg,
                  showLeft: _showLeft,
                  showRight: _showRight,
                  showNecklace: _showNecklace,
                  mirrorX: true,
                  rotation: _rotation,
                  estimatedFaceCenterX: _estimatedFaceCenterX,
                  estimatedFaceCenterY: _estimatedFaceCenterY,
                  estimatedFaceSize: _estimatedFaceSize,
                  faceYaw: _face?.headEulerAngleY ?? 0.0,
                  faceRoll: _face?.headEulerAngleZ ?? 0.0,
                  isCapturedMode: false,
                  manualOffsetX: _jewelryOffsetX,
                  manualOffsetY: _jewelryOffsetY,
                  manualScale: _jewelryScale,
                  manualRotation: _jewelryRotation,
                ),
              ),

            // Debug overlay
            if (kDebugMode)
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Face: ${_face != null ? 'Detected' : 'Not Detected'}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                      Text(
                        'Pos: ${_estimatedFaceCenterX.toStringAsFixed(2)}, ${_estimatedFaceCenterY.toStringAsFixed(2)}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                      Text(
                        'Size: ${_estimatedFaceSize.toStringAsFixed(2)}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                      if (_controller?.value.previewSize != null)
                        Text(
                          'Preview: ${_controller!.value.previewSize!.width.toInt()}x${_controller!.value.previewSize!.height.toInt()}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11),
                        ),
                    ],
                  ),
                ),
              ),

            // Top back button
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: _closeCameraAndPop,
                ),
              ),
            ),

            // Bottom controls
            if (_isInitialized && !_isCaptured)
              Positioned(
                bottom: 32,
                left: 0,
                right: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Flash toggle
                    IconButton(
                      icon: Icon(
                        _torchOn ? Icons.flash_on : Icons.flash_off,
                        color: Colors.white,
                        size: 30,
                      ),
                      onPressed: _toggleTorch,
                    ),
                    const SizedBox(height: 20),
                    // Capture button
                    GestureDetector(
                      onTap: _captureFrame,
                      child: Container(
                        width: 70,
                        height: 70,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 4),
                          borderRadius: BorderRadius.circular(35),
                        ),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Captured image controls
            if (_isInitialized && _isCaptured)
              Positioned(
                bottom: 32,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Retake button
                    TextButton(
                      onPressed: _resetCapture,
                      child: const Text(
                        'Retake',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    
                    // Save button
                    ElevatedButton(
                      onPressed: () {
                        // TODO: Implement save functionality
                        _closeCameraAndPop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
                   ],
        ), // Stack
      ), // SafeArea
    ), // Scaffold
  ); // PopScope

  }
}
