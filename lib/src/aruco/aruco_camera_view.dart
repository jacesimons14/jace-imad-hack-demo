import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart' as camera;

import '../settings/settings_view.dart';
import '../camera/camera_controller.dart';
import 'aruco_processor.dart';
import 'camera_calibration.dart';
import 'pose.dart';

/// Displays the camera feed with real-time ArUco marker detection overlay.
///
/// This view processes camera frames to detect ArUco markers and displays
/// detection results as an overlay on the camera feed.
class ArucoCameraView extends StatefulWidget {
  const ArucoCameraView({
    super.key,
    required this.cameraController,
    required this.arucoProcessor,
  });

  static const routeName = '/aruco';

  final CameraViewController cameraController;
  final ArucoProcessor arucoProcessor;

  @override
  State<ArucoCameraView> createState() => _ArucoCameraViewState();
}

class _ArucoCameraViewState extends State<ArucoCameraView> {
  StreamSubscription<camera.CameraImage>? _imageStreamSubscription;
  Map<int, Pose> _detectedMarkers = {};
  bool _isProcessingFrame = false;
  int _frameCount = 0;
  int _processedFrameCount = 0;
  DateTime? _lastFrameTime;
  double _fps = 0.0;

  @override
  void initState() {
    super.initState();

    // Initialize camera and ArUco processor
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await widget.cameraController.initializeCamera();

      if (widget.cameraController.isInitialized) {
        await _initializeArucoProcessor();
        _startImageStream();
      }
    });

    // Listen to marker detection results
    widget.arucoProcessor.markerStream.listen((markers) {
      if (mounted) {
        setState(() {
          _detectedMarkers = markers;
          _processedFrameCount++;
        });
      }
    });
  }

  Future<void> _initializeArucoProcessor() async {
    if (!widget.arucoProcessor.isInitialized) {
      // Get camera resolution for calibration
      final resolution = widget.cameraController.getCameraResolution();
      final parts = resolution.split('x');

      CameraCalibration calibration;
      if (parts.length == 2) {
        final width = int.tryParse(parts[0]) ?? 640;
        final height = int.tryParse(parts[1]) ?? 480;

        // Use appropriate default calibration based on resolution
        if (width >= 1920) {
          calibration = CameraCalibration.defaultFullHD();
        } else {
          calibration = CameraCalibration.defaultWebcam640x480();
        }

        // Scale calibration if resolution doesn't match defaults
        if (width != 640 && width != 1920) {
          calibration = calibration.scaleForResolution(
            originalWidth: 640,
            originalHeight: 480,
            newWidth: width,
            newHeight: height,
          );
        }
      } else {
        calibration = CameraCalibration.defaultWebcam640x480();
      }

      await widget.arucoProcessor.initialize(
        cameraMatrix: calibration.cameraMatrix,
        distCoeffs: calibration.distortionCoefficients,
      );
    }
  }

  void _startImageStream() {
    final cameraController = widget.cameraController.cameraController;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    try {
      cameraController.startImageStream((camera.CameraImage image) {
        _onImageReceived(image);
      });
    } catch (e) {
      print('Error starting image stream: $e');
    }
  }

  void _stopImageStream() {
    final cameraController = widget.cameraController.cameraController;
    if (cameraController != null && cameraController.value.isStreamingImages) {
      try {
        cameraController.stopImageStream();
      } catch (e) {
        print('Error stopping image stream: $e');
      }
    }
  }

  void _onImageReceived(camera.CameraImage image) {
    // Skip frame if we're already processing one
    if (_isProcessingFrame) return;

    _isProcessingFrame = true;
    _frameCount++;

    // Calculate FPS
    final now = DateTime.now();
    if (_lastFrameTime != null) {
      final elapsed = now.difference(_lastFrameTime!).inMilliseconds;
      if (elapsed > 0) {
        _fps = 1000.0 / elapsed;
      }
    }
    _lastFrameTime = now;

    // Process every Nth frame to reduce load (process 1 out of every 3 frames)
    if (_frameCount % 3 != 0) {
      _isProcessingFrame = false;
      return;
    }

    try {
      // Convert CameraImage to bytes
      final imageData = _convertCameraImage(image);

      if (imageData != null) {
        // Send to ArUco processor (non-blocking)
        widget.arucoProcessor.processFrame(
          imageData: imageData,
          width: image.width,
          height: image.height,
          markerSize: 0.1, // 10cm marker size - adjust as needed
        );
      }
    } catch (e) {
      print('Error processing frame: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  Uint8List? _convertCameraImage(camera.CameraImage image) {
    try {
      // Handle different image formats
      if (image.format.group == camera.ImageFormatGroup.yuv420) {
        return _convertYUV420ToRGBA(image);
      } else if (image.format.group == camera.ImageFormatGroup.bgra8888) {
        return _convertBGRA8888ToRGBA(image);
      } else {
        print('Unsupported image format: ${image.format.group}');
        return null;
      }
    } catch (e) {
      print('Error converting camera image: $e');
      return null;
    }
  }

  Uint8List _convertYUV420ToRGBA(camera.CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

    final Uint8List rgba = Uint8List(width * height * 4);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int uvIndex = uvPixelStride * (x ~/ 2) + uvRowStride * (y ~/ 2);
        final int index = y * width + x;

        final yp = image.planes[0].bytes[index];
        final up = image.planes[1].bytes[uvIndex];
        final vp = image.planes[2].bytes[uvIndex];

        // Convert YUV to RGB
        int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
        int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91)
            .round()
            .clamp(0, 255);
        int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);

        rgba[index * 4] = r;
        rgba[index * 4 + 1] = g;
        rgba[index * 4 + 2] = b;
        rgba[index * 4 + 3] = 255; // Alpha
      }
    }

    return rgba;
  }

  Uint8List _convertBGRA8888ToRGBA(camera.CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final Uint8List bgra = image.planes[0].bytes;
    final Uint8List rgba = Uint8List(width * height * 4);

    for (int i = 0; i < bgra.length; i += 4) {
      rgba[i] = bgra[i + 2]; // R
      rgba[i + 1] = bgra[i + 1]; // G
      rgba[i + 2] = bgra[i]; // B
      rgba[i + 3] = bgra[i + 3]; // A
    }

    return rgba;
  }

  @override
  void dispose() {
    _stopImageStream();
    _imageStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: widget.cameraController,
        builder: (BuildContext context, Widget? child) {
          return Stack(
            children: [
              // Camera preview
              _buildCameraPreview(),

              // Detection overlay
              if (widget.cameraController.isInitialized)
                _buildDetectionOverlay(),

              // Overlay controls
              _buildOverlayControls(),

              // Loading indicator
              if (widget.cameraController.isLoading)
                const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (widget.cameraController.hasError) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.camera_alt_outlined,
                size: 64,
                color: Colors.white54,
              ),
              const SizedBox(height: 16),
              Text(
                'Camera Error',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                    ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  widget.cameraController.errorMessage ??
                      'Unable to access camera',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => widget.cameraController.initializeCamera(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (!widget.cameraController.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Starting camera...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    final cameraController = widget.cameraController.cameraController!;
    return Center(
      child: camera.CameraPreview(cameraController),
    );
  }

  Widget _buildDetectionOverlay() {
    return CustomPaint(
      painter: _MarkerOverlayPainter(
        markers: _detectedMarkers,
        cameraResolution: widget.cameraController.getCameraResolution(),
      ),
      child: Container(),
    );
  }

  Widget _buildOverlayControls() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Info panel
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Markers: ${_detectedMarkers.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'FPS: ${_fps.toStringAsFixed(1)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                ),
                Text(
                  widget.cameraController.getCameraResolution(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          // Settings button
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.settings, color: Colors.white),
              onPressed: () {
                Navigator.restorablePushNamed(context, SettingsView.routeName);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for drawing marker detection overlays.
class _MarkerOverlayPainter extends CustomPainter {
  _MarkerOverlayPainter({
    required this.markers,
    required this.cameraResolution,
  });

  final Map<int, Pose> markers;
  final String cameraResolution;

  @override
  void paint(Canvas canvas, Size size) {
    if (markers.isEmpty) return;

    final paint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Draw a simple indicator for each detected marker
    // Note: This is a simplified visualization. For accurate corner drawing,
    // you'd need to project the 3D marker corners back to 2D screen coordinates.
    int index = 0;
    for (final entry in markers.entries) {
      final markerId = entry.key;
      final pose = entry.value;

      // Draw a box at the bottom left corner as a placeholder
      final rect = Rect.fromLTWH(
        20.0 + (index * 100.0),
        size.height - 80.0,
        80.0,
        60.0,
      );
      canvas.drawRect(rect, paint);

      // Draw marker ID
      textPainter.text = TextSpan(
        text: 'ID: $markerId',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.black87,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(rect.left + 5, rect.top + 5),
      );

      // Draw distance
      final distance = pose.tvec.length;
      textPainter.text = TextSpan(
        text: '${distance.toStringAsFixed(2)}m',
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 10,
          backgroundColor: Colors.black87,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(rect.left + 5, rect.top + 25),
      );

      index++;
    }
  }

  @override
  bool shouldRepaint(_MarkerOverlayPainter oldDelegate) {
    return markers != oldDelegate.markers;
  }
}
