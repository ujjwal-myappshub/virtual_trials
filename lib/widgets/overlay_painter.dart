import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../models/product.dart';

class OverlayPainter extends CustomPainter {
  // Positioning constants for jewelry placement
  static const double _earringScaleFactor = 0.2;
  static const double _earringMinSize = 30.0;
  static const double _earringMaxSize = 80.0;
  static const double _earringHeightMultiplier = 1.2;
  static const double _earringYOffset = 0.15;
  static const double _earSpacingFactor = 0.4;

  static const double _necklaceWidthMultiplier = 1.4;
  static const double _necklaceHeightRatio = 0.3;
  static const double _necklaceYOffset = 2.0;

  // Head rotation adjustment factors
  static const double _headYawNormalizationFactor = 45.0;
  static const double _headRollNormalizationFactor = 45.0;
  static const double _earringRotationFactor = 0.3;
  static const double _necklaceRotationFactor = 0.2;

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
  final double estimatedFaceCenterX;
  final double estimatedFaceCenterY;
  final double estimatedFaceSize;
  final double faceYaw; // -1 to 1 for head rotation
  final double faceRoll; // -1 to 1 for head tilt
  final bool isCapturedMode; // Whether we're in captured image mode

  // Manual adjustment parameters
  final double manualOffsetX;
  final double manualOffsetY;
  final double manualScale;
  final double manualRotation;
  
  // Whether we're in adjustment mode
  bool get _isAdjustmentMode => manualScale != 1.0 || 
      manualOffsetX != 0.0 || 
      manualOffsetY != 0.0 || 
      manualRotation != 0.0;

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
    this.estimatedFaceCenterX = 0.5,
    this.estimatedFaceCenterY = 0.4,
    this.estimatedFaceSize = 0.3,
    this.faceYaw = 0.0,
    this.faceRoll = 0.0,
    this.isCapturedMode = false,
    this.manualOffsetX = 0.0,
    this.manualOffsetY = 0.0,
    this.manualScale = 1.0,
    this.manualRotation = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize == null) return;

    // Map camera image coordinates -> screen coordinates
    double baseW = imageSize!.width;
    double baseH = imageSize!.height;

    // If sensor rotation is 90/270, swap width/height for scaling
    // But only if we're not in captured mode (since the image is already rotated)
    final bool isRotated = !isCapturedMode && (rotation == 90 || rotation == 270);
    if (isRotated) {
      final t = baseW;
      baseW = baseH;
      baseH = t;
    }

    // Calculate scale factors
    // In captured mode, the image is already scaled to fit the screen
    final double scaleX = isCapturedMode ? 1.0 : size.width / baseW;
    final double scaleY = isCapturedMode ? 1.0 : size.height / baseH;

    // Get face position and size with null safety and improved fallback
    // Note: estimatedFaceCenterX/Y are already normalized (0-1) and rotated for screen display
    final double scaledFaceCenterX;
    final double scaledFaceCenterY;
    final double scaledFaceWidth;
    
    if (face != null) {
      // Face detected by ML Kit - use actual pixel coordinates from camera image
      final faceCenterX = face!.boundingBox.center.dx;
      final faceCenterY = face!.boundingBox.center.dy;
      final faceWidth = face!.boundingBox.width;
      
      // Apply scaling to convert from image coordinates to screen coordinates
      scaledFaceCenterX = faceCenterX * scaleX;
      scaledFaceCenterY = faceCenterY * scaleY;
      scaledFaceWidth = faceWidth * scaleX;
    } else {
      if (isCapturedMode && imageSize != null) {
        // In captured mode, account for image aspect ratio fitting
        final double imageAspectRatio = imageSize!.width / imageSize!.height;
        final double screenAspectRatio = size.width / size.height;

        double displayWidth, displayHeight, offsetX, offsetY;

        if (screenAspectRatio > imageAspectRatio) {
          // Screen is wider - image has vertical bars (pillarboxing)
          displayHeight = size.height;
          displayWidth = size.height * imageAspectRatio;
          offsetX = (size.width - displayWidth) / 2;
          offsetY = 0;
        } else {
          // Screen is taller - image has horizontal bars (letterboxing)
          displayWidth = size.width;
          displayHeight = size.width / imageAspectRatio;
          offsetX = 0;
          offsetY = (size.height - displayHeight) / 2;
        }

        // Map normalized face coordinates to displayed image area
        scaledFaceCenterX = offsetX + (estimatedFaceCenterX * displayWidth);
        scaledFaceCenterY = offsetY + (estimatedFaceCenterY * displayHeight);
        scaledFaceWidth = estimatedFaceSize * displayWidth;
      } else {
        // Using estimated position - already normalized (0-1) and rotated
        scaledFaceCenterX = estimatedFaceCenterX * size.width;
        scaledFaceCenterY = estimatedFaceCenterY * size.height;
        scaledFaceWidth = estimatedFaceSize * size.width;
      }
    }
    
    // Apply manual position and scale adjustments
    final double adjustedFaceCenterX = scaledFaceCenterX + manualOffsetX;
    final double adjustedFaceCenterY = scaledFaceCenterY + manualOffsetY;
    final double adjustedFaceWidth = scaledFaceWidth * manualScale;
    
    debugPrint('Manual adjustments - X: $manualOffsetX, Y: $manualOffsetY, Scale: $manualScale, Rotation: $manualRotation');

    // Calculate head rotation and tilt with null safety and smoothing
    // When in adjustment mode, we want to ignore the automatic head rotation
    final double headYaw = _isAdjustmentMode ? 0.0 : ((face?.headEulerAngleY ?? 0.0) / _headYawNormalizationFactor);
    final double headRoll = _isAdjustmentMode ? 0.0 : ((face?.headEulerAngleZ ?? 0.0) / _headRollNormalizationFactor);
    
    // Apply manual rotation fully; reduce head roll influence
    final double rollComponentEarring = headRoll * _earringRotationFactor;
    // We're not using rollComponentNecklace anymore since we're using manualRotation directly

    // Combine rotations
    final double totalEarringRotation = manualRotation + rollComponentEarring;
    // We're using manualRotation directly for necklace to simplify the rotation
    debugPrint('Painting with manualOffset: ($manualOffsetX, $manualOffsetY), scale: $manualScale, rotation: $manualRotation');

    // Position jewelry based on face position and rotation
    if (product.type == JewelryType.earring) {
      // Calculate earring size based on face width with limits (using adjusted values)
      final double eSize = (adjustedFaceWidth * _earringScaleFactor).clamp(_earringMinSize, _earringMaxSize);

      // Calculate ear positions with head rotation and tilt (using adjusted values)
      double earY = adjustedFaceCenterY - (adjustedFaceWidth * _earringYOffset);

      // Calculate ear positions with head rotation (yaw)
      double earSpacing = adjustedFaceWidth * _earSpacingFactor;
      double leftEarX = adjustedFaceCenterX - earSpacing * (1.0 - headYaw * 0.5);
      double rightEarX = adjustedFaceCenterX + earSpacing * (1.0 + headYaw * 0.5);

      // Apply head roll (tilt) adjustment - more subtle effect
      // When in adjustment mode, we want to ignore the automatic roll adjustment
      final rollAdjustment = _isAdjustmentMode ? 0 : (totalEarringRotation * adjustedFaceWidth * 0.1);
      
      if (earringLeft != null && showLeft) {
        // Apply manual position adjustments to ear position
        // Add manual offsets to the ear position
        final leftX = leftEarX - (headYaw * adjustedFaceWidth * 0.15);
        final leftY = earY + rollAdjustment;
        
        final dst = Rect.fromCenter(
          center: Offset(mirrorX ? size.width - leftX : leftX, leftY),
          width: eSize,
          height: eSize * _earringHeightMultiplier
        );
        
        final src = Rect.fromLTWH(0, 0, 
          earringLeft!.width.toDouble(),
          earringLeft!.height.toDouble()
        );
        
        // Save canvas state
        canvas.save();
        
        // Apply mirroring if needed
        if (mirrorX) {
          canvas.scale(-1.0, 1.0);
          canvas.translate(-size.width, 0);
        }
        
        // Apply rotation based on head tilt and manual rotation
        final rotationCenter = Offset(dst.center.dx, dst.center.dy);
        canvas.translate(rotationCenter.dx, rotationCenter.dy);
        canvas.rotate(totalEarringRotation);
        canvas.translate(-rotationCenter.dx, -rotationCenter.dy);
        
        // Draw the earring
        canvas.drawImageRect(earringLeft!, src, dst, Paint());
        
        // Restore canvas state
        canvas.restore();
      }
      
      if (earringRight != null && showRight) {
        // Right ear position with head rotation and tilt
        // Add manual offsets to the ear position
        final rightX = rightEarX - (headYaw * adjustedFaceWidth * 0.15);
        final rightY = earY - rollAdjustment;
        
        final dst = Rect.fromCenter(
          center: Offset(mirrorX ? size.width - rightX : rightX, rightY),
          width: eSize,
          height: eSize * _earringHeightMultiplier
        );
        
        final src = Rect.fromLTWH(0, 0, 
          earringRight!.width.toDouble(),
          earringRight!.height.toDouble()
        );
        
        // Apply mirroring if needed
        if (mirrorX) {
          canvas.save();
          canvas.scale(-1.0, 1.0);
          canvas.translate(-size.width, 0);
        }
        
        // Apply rotation based on head tilt and manual rotation
        // Apply manual rotation and position
        canvas.save();
        canvas.translate(dst.center.dx, dst.center.dy);
        canvas.rotate(totalEarringRotation);
        canvas.translate(-dst.center.dx, -dst.center.dy);
        
        canvas.drawImageRect(earringRight!, src, dst, Paint());
        canvas.restore();
        
        if (mirrorX) canvas.restore();
      }
    } else if (product.type == JewelryType.necklace && showNecklace && necklace != null) {
      debugPrint('Painting necklace at: ($adjustedFaceCenterX, $adjustedFaceCenterY) with manual offset: ($manualOffsetX, $manualOffsetY)');
      
      // Calculate base necklace dimensions
      final double baseNecklaceWidth = adjustedFaceWidth * _necklaceWidthMultiplier;
      final double baseNecklaceHeight = baseNecklaceWidth * _necklaceHeightRatio;

      // Apply manual scale
      final double scaledNecklaceWidth = baseNecklaceWidth * manualScale;
      final double scaledNecklaceHeight = baseNecklaceHeight * manualScale;

      // Base position below the face at neck/chest level
      double neckX = adjustedFaceCenterX;
      double neckY = adjustedFaceCenterY + (adjustedFaceWidth * _necklaceYOffset);

      // Apply manual position offsets
      neckX += manualOffsetX;
      neckY += manualOffsetY;

      final rect = Rect.fromCenter(
        center: Offset(neckX, neckY),
        width: scaledNecklaceWidth,
        height: scaledNecklaceHeight
      );
      
      final src = Rect.fromLTWH(0, 0, 
        necklace!.width.toDouble(), 
        necklace!.height.toDouble()
      );
      
      // Save canvas state for transformations
      canvas.save();
      
      // Apply rotation around the center of the necklace
      final rotationCenter = rect.center;
      canvas.translate(rotationCenter.dx, rotationCenter.dy);
      canvas.rotate(manualRotation); // Use manual rotation directly
      canvas.translate(-rotationCenter.dx, -rotationCenter.dy);
      
      // Draw the necklace
      canvas.drawImageRect(necklace!, src, rect, Paint());
      
      // Restore canvas
      canvas.restore();
    }
    
    // Face landmarks are available but not currently used for positioning
    // Commented out to avoid unused variable warnings
    /*
    if (face != null && face!.landmarks.isNotEmpty) {
      final landmarks = face!.landmarks;
      // These positions could be used for more accurate earring placement
      final rightEar = landmarks[FaceLandmarkType.rightEar]?.position;
      final leftEar = landmarks[FaceLandmarkType.leftEar]?.position;
    }
    */
  }

  @override
  bool shouldRepaint(covariant OverlayPainter oldDelegate) {
    return oldDelegate.face != face ||
           oldDelegate.estimatedFaceCenterX != estimatedFaceCenterX ||
           oldDelegate.estimatedFaceCenterY != estimatedFaceCenterY ||
           oldDelegate.estimatedFaceSize != estimatedFaceSize ||
           oldDelegate.faceYaw != faceYaw ||
           oldDelegate.faceRoll != faceRoll ||
           oldDelegate.showLeft != showLeft ||
           oldDelegate.showRight != showRight ||
           oldDelegate.showNecklace != showNecklace ||
           oldDelegate.mirrorX != mirrorX ||
           oldDelegate.rotation != rotation ||
           oldDelegate.imageSize != imageSize ||
           oldDelegate.necklace != necklace ||
           oldDelegate.earringLeft != earringLeft ||
           oldDelegate.earringRight != earringRight ||
           oldDelegate.manualOffsetX != manualOffsetX ||
           oldDelegate.manualOffsetY != manualOffsetY ||
           oldDelegate.manualScale != manualScale ||
           oldDelegate.manualRotation != manualRotation ||
           oldDelegate.isCapturedMode != isCapturedMode;
  }
}