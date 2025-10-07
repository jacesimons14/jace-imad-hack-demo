import 'package:flutter/material.dart';
import 'package:camera/camera.dart' as camera;

import '../settings/settings_view.dart';
import 'camera_controller.dart';

/// Displays the camera feed with AR overlay capabilities.
///
/// This view provides a live camera feed suitable for AR applications,
/// with controls for camera switching and resolution display.
class CameraView extends StatefulWidget {
  const CameraView({
    super.key,
    required this.controller,
  });

  static const routeName = '/';

  final CameraViewController controller;

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  @override
  void initState() {
    super.initState();
    // Initialize camera when view loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.initializeCamera();
    });
  }

  @override
  void dispose() {
    // Don't dispose the controller here since it's shared across the app
    // The controller will be disposed when the app shuts down
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (BuildContext context, Widget? child) {
          return Stack(
            children: [
              // Camera preview fills entire screen
              _buildCameraPreview(),
              
              // Minimal overlay controls
              _buildOverlayControls(),
              
              // Camera switch button
              if (_buildFloatingActionButton() != null) _buildFloatingActionButton()!,
              
              // Loading indicator
              if (widget.controller.isLoading)
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
    if (widget.controller.hasError) {
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
                  widget.controller.errorMessage ?? 'Unable to access camera',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => widget.controller.initializeCamera(),
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

    if (!widget.controller.isInitialized) {
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

    final cameraController = widget.controller.cameraController!;
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        width: 640, // Fixed width for camera preview
        height: 480, // Fixed height for camera preview
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: camera.CameraPreview(cameraController),
        ),
      ),
    );
  }

  Widget _buildOverlayControls() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      right: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
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
          const SizedBox(height: 8),
          // Camera info
          if (widget.controller.isInitialized)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${widget.controller.getCameraResolution()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget? _buildFloatingActionButton() {
    if (!widget.controller.isInitialized || widget.controller.getAvailableCamerasCount() <= 1) {
      return null;
    }

    return Positioned(
      bottom: 32,
      right: 16,
      child: FloatingActionButton(
        onPressed: widget.controller.isLoading ? null : () => widget.controller.switchCamera(),
        backgroundColor: Colors.black.withOpacity(0.6),
        foregroundColor: Colors.white,
        child: const Icon(Icons.flip_camera_ios),
      ),
    );
  }
}