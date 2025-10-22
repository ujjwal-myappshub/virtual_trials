import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../models/product.dart';

class OverlayPainter extends CustomPainter {
  final Face? face;
  final Size? imageSize;
  final Product product;
  final ui.Image? necklace;
  final ui.Image? earringLeft;
  final ui.Image? earringRight;
  final bool showLeft;
  final bool showRight;
  final bool showNecklace;
  final bool mirrorX;
  final int rotation;

  OverlayPainter({
    required this.product,
    this.face,
    this.imageSize,
    this.necklace,
    this.earringLeft,
    this.earringRight,
    this.showLeft = true,
    this.showRight = true,
    this.showNecklace = true,
    this.mirrorX = false,
    this.rotation = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize == null) return;
    // Map camera image coordinates -> screen coordinates
    double baseW = imageSize!.width;
    double baseH = imageSize!.height;
    // If sensor rotation is 90/270, swap width/height for scaling
    if (rotation == 90 || rotation == 270) {
      final t = baseW;
      baseW = baseH;
      baseH = t;
    }
    final double scaleX = size.width / baseW;
    final double scaleY = size.height / baseH;

    if (face == null) {
      // Draw centered placeholders so the user sees the product even before detection
      if (product.type == JewelryType.earring) {
        final double eSize = (size.width * 0.18).clamp(20.0, 120.0);
        final double y = size.height * 0.42;
        if (earringLeft != null && showLeft) {
          final leftX = size.width * 0.32;
          final dst = Rect.fromCenter(
              center: Offset(leftX, y),
              width: earringLeft!.width > 0 ? eSize : eSize,
              height: earringLeft!.height > 0 ? eSize : eSize);
          final src = Rect.fromLTWH(0, 0, earringLeft!.width.toDouble(),
              earringLeft!.height.toDouble());
          canvas.drawImageRect(earringLeft!, src, dst, Paint());
        }
        if (earringRight != null && showRight) {
          final rightX = size.width * 0.68;
          final dst = Rect.fromCenter(
              center: Offset(rightX, y),
              width: earringRight!.width > 0 ? eSize : eSize,
              height: earringRight!.height > 0 ? eSize : eSize);
          final src = Rect.fromLTWH(0, 0, earringRight!.width.toDouble(),
              earringRight!.height.toDouble());
          canvas.drawImageRect(earringRight!, src, dst, Paint());
        }
      } else if (product.type == JewelryType.necklace && showNecklace) {
        final double w = size.width * 0.55;
        final double h = w * 0.55;
        final rect = Rect.fromCenter(
            center: Offset(size.width / 2, size.height * 0.72),
            width: w,
            height: h);
        if (necklace != null) {
          final src = Rect.fromLTWH(
              0, 0, necklace!.width.toDouble(), necklace!.height.toDouble());
          canvas.drawImageRect(necklace!, src, rect, Paint());
        } else {
          final necklacePaint = Paint()..color = Colors.yellow.withOpacity(0.3);
          canvas.drawRect(rect, necklacePaint);
        }
      }
      return;
    }

    final landmarks = face!.landmarks;
    // Primary landmarks
    final lEar = landmarks[FaceLandmarkType.leftEar]?.position;
    final rEar = landmarks[FaceLandmarkType.rightEar]?.position;
    final lCheek = landmarks[FaceLandmarkType.leftCheek]?.position;
    final rCheek = landmarks[FaceLandmarkType.rightCheek]?.position;
    final lEye = landmarks[FaceLandmarkType.leftEye]?.position;
    final rEye = landmarks[FaceLandmarkType.rightEye]?.position;
    final nose = landmarks[FaceLandmarkType.noseBase]?.position;

    // Resolve fallback positions as doubles
    double? lx =
        lEar?.x.toDouble() ?? lCheek?.x.toDouble() ?? lEye?.x.toDouble();
    double? ly =
        lEar?.y.toDouble() ?? lCheek?.y.toDouble() ?? lEye?.y.toDouble();
    double? rx =
        rEar?.x.toDouble() ?? rCheek?.x.toDouble() ?? rEye?.x.toDouble();
    double? ry =
        rEar?.y.toDouble() ?? rCheek?.y.toDouble() ?? rEye?.y.toDouble();
    if (lx == null || ly == null || rx == null || ry == null) {
      final r = face!.boundingBox;
      lx ??= r.left.toDouble();
      ly ??= r.center.dy;
      rx ??= r.right.toDouble();
      ry ??= r.center.dy;
    }

    if (lx != null && ly != null && rx != null && ry != null) {
      // Debug: draw ear points
      final p = Paint()..color = Colors.greenAccent.withOpacity(0.7);
      double dlx = lx * scaleX;
      if (mirrorX) dlx = size.width - dlx;
      double dly = ly * scaleY;
      double drx = rx * scaleX;
      if (mirrorX) drx = size.width - drx;
      double dry = ry * scaleY;
      canvas.drawCircle(Offset(dlx, dly), 4, p);
      canvas.drawCircle(Offset(drx, dry), 4, p);
      // Draw earrings
      if (product.type == JewelryType.earring) {
        final double earDistanceScreen = (rx - lx).abs() * scaleX;
        // Slightly smaller factor to avoid oversized earrings on narrow FOV
        final double eSize = earDistanceScreen * 0.25;
        final double clampedESize = eSize.clamp(18.0, 100.0);
        if (earringLeft != null && showLeft) {
          double x = lx * scaleX;
          if (mirrorX) x = size.width - x;
          final dst = Rect.fromCenter(
            center: Offset(x, dly),
            width: earringLeft!.width > 0 ? clampedESize : clampedESize,
            height: earringLeft!.height > 0 ? clampedESize : clampedESize,
          );
          final src = Rect.fromLTWH(0, 0, earringLeft!.width.toDouble(),
              earringLeft!.height.toDouble());
          canvas.drawImageRect(earringLeft!, src, dst, Paint());
        }
        if (earringRight != null && showRight) {
          double x = rx * scaleX;
          if (mirrorX) x = size.width - x;
          final dst = Rect.fromCenter(
            center: Offset(x, dry),
            width: clampedESize,
            height: clampedESize,
          );
          final src = Rect.fromLTWH(0, 0, earringRight!.width.toDouble(),
              earringRight!.height.toDouble());
          canvas.drawImageRect(earringRight!, src, dst, Paint());
        }
      }

      // Draw necklace
      if (product.type == JewelryType.necklace && showNecklace) {
        final double faceSpanY = (ry - ly).abs();
        final double neckYImg =
            nose != null ? nose.y.toDouble() + faceSpanY * 2.4 : ly + 60;
        final double neckY = neckYImg * scaleY;
        final double widthPx = (rx - lx).abs() * scaleX * 2.0;
        final double heightPx = widthPx * 0.5;
        final dst = Rect.fromCenter(
          center: Offset(size.width / 2, neckY),
          width: widthPx,
          height: heightPx,
        );
        if (necklace != null) {
          final src = Rect.fromLTWH(
              0, 0, necklace!.width.toDouble(), necklace!.height.toDouble());
          canvas.drawImageRect(necklace!, src, dst, Paint());
        } else {
          // fallback debug rect
          final necklacePaint = Paint()..color = Colors.yellow.withOpacity(0.3);
          canvas.drawRect(dst, necklacePaint);
        }
      }
    }

    // If landmarks missing, draw face box to signal detection
    if (lx == null || ly == null || rx == null || ry == null) {
      final r = face!.boundingBox;
      final rect = Rect.fromLTWH(
          r.left * scaleX, r.top * scaleY, r.width * scaleX, r.height * scaleY);
      final pb = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.redAccent;
      canvas.drawRect(rect, pb);
    }
  }

  @override
  bool shouldRepaint(covariant OverlayPainter oldDelegate) =>
      oldDelegate.face != face ||
      oldDelegate.imageSize != imageSize ||
      oldDelegate.necklace != necklace ||
      oldDelegate.earringLeft != earringLeft ||
      oldDelegate.earringRight != earringRight ||
      oldDelegate.product != product ||
      oldDelegate.showLeft != showLeft ||
      oldDelegate.showRight != showRight ||
      oldDelegate.showNecklace != showNecklace ||
      oldDelegate.mirrorX != mirrorX ||
      oldDelegate.rotation != rotation;
}
