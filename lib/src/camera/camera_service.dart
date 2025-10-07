import 'package:camera/camera.dart';

/// A service that handles camera initialization and configuration.
///
/// This service manages the lifecycle of camera access, including
/// initialization, disposal, and error handling for web platform.
class CameraService {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;

  /// Returns true if the camera service has been initialized.
  bool get isInitialized => _isInitialized;

  /// Returns the current camera controller if available.
  CameraController? get controller => _controller;

  /// Returns the list of available cameras.
  List<CameraDescription>? get cameras => _cameras;

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