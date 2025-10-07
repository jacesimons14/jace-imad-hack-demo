import 'package:flutter/material.dart';
import 'package:camera/camera.dart' as camera;

import '../settings/settings_view.dart';
import '../aruco/frame_processing_service.dart';
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
              
              // ArUco marker detection overlay
              if (widget.controller.isFrameProcessingEnabled)
                _buildMarkerDetectionOverlay(),
              
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
    
    // Get the actual camera aspect ratio
    final cameraAspectRatio = cameraController.value.aspectRatio;
    
    return Container(
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          aspectRatio: cameraAspectRatio,
          child: camera.CameraPreview(cameraController),
        ),
      ),
    );
  }

  Widget _buildMarkerDetectionOverlay() {
    return StreamBuilder<ProcessedFrameResult>(
      stream: widget.controller.processedFrameStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        
        final result = snapshot.data!;
        
        // Check if ArUco detection result exists and has markers
        if (result.arucoDetectionResult == null || 
            !result.arucoDetectionResult!.success ||
            result.arucoDetectionResult!.markerCount == 0) {
          return const SizedBox.shrink();
        }
        
        final arucoResult = result.arucoDetectionResult!;
        
        return Positioned(
          bottom: 120,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.green.withOpacity(0.9),
                  Colors.green.withOpacity(0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '✓ Marker${arucoResult.markerCount > 1 ? 's' : ''} Detected',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${arucoResult.markerCount} marker${arucoResult.markerCount > 1 ? 's' : ''} found',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Marker IDs:',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: arucoResult.markerIds.map((id) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'ID: $id',
                              style: const TextStyle(
                                color: Colors.green,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Processing: ${arucoResult.processingTime.toStringAsFixed(1)}ms',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
          
          // Frame processing toggle
          if (widget.controller.isInitialized)
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  widget.controller.isFrameProcessingEnabled
                      ? Icons.visibility
                      : Icons.visibility_off,
                  color: widget.controller.isFrameProcessingEnabled
                      ? Colors.green
                      : Colors.white,
                ),
                onPressed: () {
                  widget.controller.setFrameProcessingEnabled(
                    !widget.controller.isFrameProcessingEnabled,
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
          
          // Performance metrics
          if (widget.controller.isInitialized && widget.controller.isFrameProcessingEnabled)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'FPS: ${widget.controller.currentPerformanceMetrics.estimatedFps.toStringAsFixed(1)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    'Efficiency: ${widget.controller.currentPerformanceMetrics.processingEfficiency.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                ],
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