import 'package:flutter/material.dart';
import 'package:camera/camera.dart' as camera;

import 'camera_service.dart';

/// A class that manages camera state and provides camera controls to Flutter Widgets.
///
/// The CameraViewController uses the CameraService to initialize and control camera access.
/// It follows the same pattern as SettingsController with ChangeNotifier for reactivity.
class CameraViewController with ChangeNotifier {
  CameraViewController(this._cameraService);

  // Make CameraService a private variable
  final CameraService _cameraService;

  // Private variables for camera state
  camera.CameraController? _cameraController;
  String? _errorMessage;
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _isDisposed = false;

  // Public getters
  camera.CameraController? get cameraController => _cameraController;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized && _cameraController != null && !_isDisposed;
  bool get hasError => _errorMessage != null;

  /// Initializes the camera and updates the UI state.
  Future<void> initializeCamera() async {
    // Don't initialize if already initialized, currently loading, or disposed
    if (_isInitialized || _isLoading || _isDisposed) return;
    
    _setLoading(true);
    _clearError();

    try {
      _cameraController = await _cameraService.initializeCamera();
      _isInitialized = true;
      
      // Listen to camera controller changes
      _cameraController?.addListener(_onCameraControllerUpdate);
      
    } catch (e) {
      _setError('Failed to initialize camera: ${e.toString()}');
      _isInitialized = false;
    }

    _setLoading(false);
  }

  /// Switches to the next available camera.
  Future<void> switchCamera() async {
    if (!_isInitialized || _isLoading || _isDisposed) return;

    _setLoading(true);
    _clearError();

    try {
      // Remove listener from current controller
      _cameraController?.removeListener(_onCameraControllerUpdate);
      
      _cameraController = await _cameraService.switchCamera();
      
      if (_cameraController != null) {
        // Add listener to new controller
        _cameraController!.addListener(_onCameraControllerUpdate);
      } else {
        _setError('Failed to switch camera');
      }
    } catch (e) {
      _setError('Error switching camera: ${e.toString()}');
    }

    _setLoading(false);
  }

  /// Gets the current camera resolution as a string.
  String getCameraResolution() {
    return _cameraService.getCameraResolution();
  }

  /// Gets the number of available cameras.
  int getAvailableCamerasCount() {
    return _cameraService.cameras?.length ?? 0;
  }

  /// Disposes resources and cleans up the controller.
  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    
    _isDisposed = true;
    _cameraController?.removeListener(_onCameraControllerUpdate);
    await _cameraService.dispose();
    _cameraController = null;
    _isInitialized = false;
    super.dispose();
  }

  // Private helper methods
  void _setLoading(bool loading) {
    if (_isDisposed) return;
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    if (_isDisposed) return;
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    if (_isDisposed) return;
    _errorMessage = null;
    notifyListeners();
  }

  void _onCameraControllerUpdate() {
    if (_isDisposed) return;
    // Notify listeners when camera controller state changes
    notifyListeners();
  }
}