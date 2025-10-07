import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// A service that handles camera initialization, configuration, and frame streaming.
///
/// This service manages the lifecycle of camera access, including
/// initialization, disposal, error handling, and frame streaming for OpenCV processing.
class CameraService {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  
  // Frame streaming
  StreamSubscription<CameraImage>? _frameSubscription;
  final StreamController<CameraImage> _frameStreamController = 
      StreamController<CameraImage>.broadcast();
  bool _isStreaming = false;

  /// Returns true if the camera service has been initialized.
  bool get isInitialized => _isInitialized;

  /// Returns the current camera controller if available.
  CameraController? get controller => _controller;

  /// Returns the list of available cameras.
  List<CameraDescription>? get cameras => _cameras;
  
  /// Returns true if frame streaming is active.
  bool get isStreaming => _isStreaming;
  
  /// Stream of camera frames for processing.
  Stream<CameraImage> get frameStream => _frameStreamController.stream;

  /// Initializes the camera service and returns the first available camera.
  ///
  /// Throws [CameraException] if no cameras are available or initialization fails.
  Future<CameraController> initializeCamera() async {
    try {
      // Get available cameras
      _cameras = await availableCameras();
      
      if (_cameras == null || _cameras!.isEmpty) {
        throw CameraException(
          'NoCamerasAvailable',
          'No cameras found on this device',
        );
      }

      // Initialize with the first camera (typically front camera on web)
      final camera = _cameras!.first;
      _controller = CameraController(
        camera,
        ResolutionPreset.high, // Use higher resolution for better natural quality
        enableAudio: false, // Disable audio for AR applications
      );

      await _controller!.initialize();
      _isInitialized = true;

      return _controller!;
    } catch (e) {
      _isInitialized = false;
      rethrow;
    }
  }
  
  /// Starts streaming camera frames for processing.
  ///
  /// This enables the camera to capture frames continuously and emit them
  /// through the frameStream for OpenCV processing.
  Future<void> startFrameStreaming() async {
    if (!_isInitialized || _controller == null || _isStreaming) return;
    
    try {
      await _controller!.startImageStream((CameraImage image) {
        if (!_frameStreamController.isClosed) {
          _frameStreamController.add(image);
        }
      });
      
      _isStreaming = true;
      debugPrint('CameraService: Frame streaming started');
    } catch (e) {
      debugPrint('CameraService: Failed to start frame streaming: $e');
      rethrow;
    }
  }
  
  /// Stops streaming camera frames.
  Future<void> stopFrameStreaming() async {
    if (!_isStreaming || _controller == null) return;
    
    try {
      await _controller!.stopImageStream();
      _isStreaming = false;
      debugPrint('CameraService: Frame streaming stopped');
    } catch (e) {
      debugPrint('CameraService: Failed to stop frame streaming: $e');
      rethrow;
    }
  }

  /// Switches to the next available camera.
  ///
  /// Returns the new camera controller or null if switching fails.
  Future<CameraController?> switchCamera() async {
    if (_cameras == null || _cameras!.length <= 1 || _controller == null) {
      return null;
    }

    try {
      // Find current camera index
      final currentIndex = _cameras!.indexWhere(
        (camera) => camera.name == _controller!.description.name,
      );
      
      // Stop frame streaming if active
      if (_isStreaming) {
        await stopFrameStreaming();
      }
      
      // Switch to next camera (wrap around)
      final nextIndex = (currentIndex + 1) % _cameras!.length;
      final nextCamera = _cameras![nextIndex];

      // Dispose current controller
      await _controller!.dispose();

      // Initialize new controller
      _controller = CameraController(
        nextCamera,
        ResolutionPreset.high, // Use higher resolution for better natural quality
        enableAudio: false,
      );

      await _controller!.initialize();
      return _controller!;
    } catch (e) {
      _isInitialized = false;
      return null;
    }
  }

  /// Disposes the camera controller and cleans up resources.
  Future<void> dispose() async {
    // Stop frame streaming if active
    if (_isStreaming) {
      await stopFrameStreaming();
    }
    
    // Close frame subscription and stream controller
    await _frameSubscription?.cancel();
    _frameSubscription = null;
    
    if (!_frameStreamController.isClosed) {
      await _frameStreamController.close();
    }
    
    // Dispose camera controller
    if (_controller != null) {
      await _controller!.dispose();
      _controller = null;
    }
    
    _isInitialized = false;
  }

  /// Gets the camera resolution as a formatted string.
  String getCameraResolution() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return 'Unknown';
    }
    
    final size = _controller!.value.previewSize;
    if (size != null) {
      return '${size.width.toInt()}x${size.height.toInt()}';
    }
    return 'Unknown';
  }
}