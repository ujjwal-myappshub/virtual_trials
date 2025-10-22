import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show rootBundle, DeviceOrientation;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'detectors/face_detector_service.dart';
import 'widgets/overlay_painter.dart';
import 'models/product.dart';

class CameraView extends StatefulWidget {
  final Product product;
  const CameraView({super.key, required this.product});

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isProcessing = false;
  DateTime? _lastProcessed;
  Face? _face;

  final FaceDetectorService _faceService = FaceDetectorService();

  ui.Image? _earringLeftImg;
  ui.Image? _earringRightImg;
  ui.Image? _necklaceImg;

  int? _imgWidth;
  int? _imgHeight;
  int _rotation = 0;

  bool _torchOn = false;
  double _exposureOffset = 0;
  double _minExposure = 0;
  double _maxExposure = 0;
  bool _fill = false;

  bool _showLeft = true;
  bool _showRight = true;
  bool _showNecklace = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _controller!.initialize();
      await _controller!.setFocusMode(FocusMode.auto);
      // Ensure no unintended zoom; keeps full field of view
      try {
        await _controller!.setZoomLevel(1.0);
      } catch (_) {}

      _minExposure = await _controller!.getMinExposureOffset();
      _maxExposure = await _controller!.getMaxExposureOffset();
      _exposureOffset = (_minExposure + _maxExposure) / 2;
      await _controller!.setExposureOffset(_exposureOffset);

      setState(() => _isInitialized = true);
      unawaited(_preloadAssets());

      _controller!.startImageStream((image) async {
        if (_isProcessing) return;
        final now = DateTime.now();
        if (_lastProcessed != null &&
            now.difference(_lastProcessed!).inMilliseconds < 90) return;
        _lastProcessed = now;

        _isProcessing = true;
        try {
          await _processImage(image);
        } finally {
          _isProcessing = false;
        }
      });
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  Future<void> _preloadAssets() async {
    Future<ui.Image> load(String asset) async {
      final data = await rootBundle.load(asset);
      final completer = Completer<ui.Image>();
      ui.decodeImageFromList(data.buffer.asUint8List(), completer.complete);
      return completer.future;
    }

    try {
      if (widget.product.type == JewelryType.earring) {
        final img = await load(widget.product.image);
        _earringLeftImg = img;
        _earringRightImg = img;
      } else if (widget.product.type == JewelryType.necklace) {
        _necklaceImg = await load(widget.product.image);
      }
    } catch (e) {
      debugPrint('Asset preload failed: $e');
    }
  }

  Future<void> _processImage(CameraImage image) async {
    try {
      // Compute rotation from device orientation + sensor orientation
      final deviceOrientation = _controller!.value.deviceOrientation;
      int baseRot;
      switch (deviceOrientation) {
        case DeviceOrientation.portraitUp:
          baseRot = 0;
          break;
        case DeviceOrientation.landscapeLeft:
          baseRot = 90;
          break;
        case DeviceOrientation.portraitDown:
          baseRot = 180;
          break;
        case DeviceOrientation.landscapeRight:
          baseRot = 270;
          break;
      }
      final sensor = _controller!.description.sensorOrientation;
      final rotation = (sensor + baseRot) % 360;
      _imgWidth = image.width;
      _imgHeight = image.height;
      _rotation = rotation;

      final faces = await _faceService.processCameraImage(image, rotation);
      if (!mounted) return;

      setState(() => _face = faces.isNotEmpty ? faces.first : null);
    } catch (e) {
      debugPrint('Processing error: $e');
    }
  }

  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
    _faceService.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted || _controller == null) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _controller?.stopImageStream();
      _controller?.dispose();
      setState(() => _isInitialized = false);
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _closeCameraAndPop() async {
    try {
      await _controller?.stopImageStream();
      await _controller?.dispose();
    } catch (_) {}
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        await _closeCameraAndPop();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraPreview(_controller!),
                    if (_imgWidth != null && _imgHeight != null)
                      CustomPaint(
                        painter: OverlayPainter(
                          face: _face,
                          imageSize: Size(
                              _imgWidth!.toDouble(), _imgHeight!.toDouble()),
                          product: widget.product,
                          earringLeft: _earringLeftImg,
                          earringRight: _earringRightImg,
                          necklace: _necklaceImg,
                          showLeft: _showLeft,
                          showRight: _showRight,
                          showNecklace: _showNecklace,
                          mirrorX: _controller!.description.lensDirection ==
                              CameraLensDirection.front,
                          rotation: _rotation,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // --- UI controls ---
            Positioned(
              top: 40,
              left: 12,
              right: 12,
              child: SafeArea(
                child: Row(
                  children: [
                    _circleBtn(
                        icon: Icons.arrow_back, onTap: _closeCameraAndPop),
                    const Spacer(),
                    if (widget.product.type == JewelryType.earring)
                      _earringModeButtons(),
                    if (widget.product.type == JewelryType.necklace)
                      _toggleBtn(
                        active: _showNecklace,
                        label: "Necklace",
                        onTap: () =>
                            setState(() => _showNecklace = !_showNecklace),
                      ),
                    const SizedBox(width: 8),
                    _circleBtn(
                      icon: _torchOn ? Icons.flash_on : Icons.flash_off,
                      onTap: () async {
                        _torchOn = !_torchOn;
                        await _controller!.setFlashMode(
                            _torchOn ? FlashMode.torch : FlashMode.off);
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleBtn({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _toggleBtn(
      {required bool active,
      required String label,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.blueAccent.withOpacity(0.8) : Colors.black54,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 13)),
      ),
    );
  }

  Widget _earringModeButtons() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          _toggleBtn(
            active: _showLeft && !_showRight,
            label: "Left",
            onTap: () => setState(() {
              _showLeft = true;
              _showRight = false;
            }),
          ),
          _toggleBtn(
            active: _showLeft && _showRight,
            label: "Both",
            onTap: () => setState(() {
              _showLeft = true;
              _showRight = true;
            }),
          ),
          _toggleBtn(
            active: !_showLeft && _showRight,
            label: "Right",
            onTap: () => setState(() {
              _showLeft = false;
              _showRight = true;
            }),
          ),
        ],
      ),
    );
  }
}
