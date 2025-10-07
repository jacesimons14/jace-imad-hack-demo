import 'package:flutter/material.dart';
import 'package:camera/camera.dart' as camera;
import 'dart:async';

import 'camera_service.dart';
import '../aruco/frame_processing_service.dart';

/// A class that manages camera state, frame processing, and provides camera controls to Flutter Widgets.
///
/// The CameraViewController uses the CameraService to initialize and control camera access,
/// and integrates with FrameProcessingService for real-time OpenCV processing.
/// It follows the same pattern as SettingsController with ChangeNotifier for reactivity.
class CameraViewController with ChangeNotifier {
  CameraViewController(this._cameraService, this._frameProcessingService);

  // Make services private variables
  final CameraService _cameraService;
  final FrameProcessingService _frameProcessingService;

  // Private variables for camera state
  camera.CameraController? _cameraController;
  String? _errorMessage;
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _isDisposed = false;
  
  // Frame processing state
  bool _isFrameProcessingEnabled = false;
  StreamSubscription<camera.CameraImage>? _frameSubscription;
  StreamSubscription<ProcessedFrameResult>? _processedFrameSubscription;
  StreamSubscription<PerformanceMetrics>? _performanceSubscription;

  // Public getters
  camera.CameraController? get cameraController => _cameraController;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized && _cameraController != null && !_isDisposed;
  bool get hasError => _errorMessage != null;
  
  // Frame processing getters
  bool get isFrameProcessingEnabled => _isFrameProcessingEnabled;
  bool get isFrameProcessingInitialized => _frameProcessingService.isInitialized;
  Stream<ProcessedFrameResult> get processedFrameStream => _frameProcessingService.processedFrameStream;
  Stream<PerformanceMetrics> get performanceStream => _frameProcessingService.performanceStream;
  PerformanceMetrics get currentPerformanceMetrics => _frameProcessingService.currentMetrics;

  /// Initializes the camera and frame processing services.
  Future<void> initializeCamera() async {
    // Don't initialize if already initialized, currently loading, or disposed
    if (_isInitialized || _isLoading || _isDisposed) return;
    
    _setLoading(true);
    _clearError();

    try {
      // Initialize camera service
      _cameraController = await _cameraService.initializeCamera();
      _isInitialized = true;
      
      // Listen to camera controller changes
      _cameraController?.addListener(_onCameraControllerUpdate);
      
      // Initialize frame processing service
      await _frameProcessingService.initialize();
      
      // Set up performance monitoring
      _performanceSubscription = _frameProcessingService.performanceStream.listen(
        _onPerformanceUpdate,
        onError: (error) => debugPrint('CameraViewController: Performance stream error: $error'),
      );
      
      debugPrint('CameraViewController: Camera and frame processing initialized');
      
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
  
  /// Enables or disables frame processing.
  Future<void> setFrameProcessingEnabled(bool enabled) async {
    if (!_isInitialized || _isDisposed) return;
    
    if (enabled && !_isFrameProcessingEnabled) {
      await _startFrameProcessing();
    } else if (!enabled && _isFrameProcessingEnabled) {
      await _stopFrameProcessing();
    }
  }
  
  /// Starts frame processing and connects camera stream to processing service.
  Future<void> _startFrameProcessing() async {
    if (_isFrameProcessingEnabled || !_isInitialized) return;
    
    try {
      // Start camera frame streaming
      await _cameraService.startFrameStreaming();
      
      // Subscribe to camera frames
      _frameSubscription = _cameraService.frameStream.listen(
        _frameProcessingService.processFrame,
        onError: (error) => debugPrint('CameraViewController: Frame stream error: $error'),
      );
      
      // Subscribe to processed frames
      _processedFrameSubscription = _frameProcessingService.processedFrameStream.listen(
        _onProcessedFrameReceived,
        onError: (error) => debugPrint('CameraViewController: Processed frame stream error: $error'),
      );
      
      // Start processing
      _frameProcessingService.startProcessing();
      
      _isFrameProcessingEnabled = true;
      notifyListeners();
      
      debugPrint('CameraViewController: Frame processing started');
    } catch (e) {
      debugPrint('CameraViewController: Failed to start frame processing: $e');
      _setError('Failed to start frame processing: ${e.toString()}');
    }
  }
  
  /// Stops frame processing and disconnects streams.
  Future<void> _stopFrameProcessing() async {
    if (!_isFrameProcessingEnabled) return;
    
    try {
      // Stop processing
      _frameProcessingService.stopProcessing();
      
      // Cancel subscriptions
      await _frameSubscription?.cancel();
      await _processedFrameSubscription?.cancel();
      _frameSubscription = null;
      _processedFrameSubscription = null;
      
      // Stop camera streaming
      await _cameraService.stopFrameStreaming();
      
      _isFrameProcessingEnabled = false;
      notifyListeners();
      
      debugPrint('CameraViewController: Frame processing stopped');
    } catch (e) {
      debugPrint('CameraViewController: Failed to stop frame processing: $e');
    }
  }

  /// Disposes resources and cleans up the controller.
  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    
    _isDisposed = true;
    
    // Stop frame processing first
    if (_isFrameProcessingEnabled) {
      await _stopFrameProcessing();
    }
    
    // Cancel all subscriptions
    await _frameSubscription?.cancel();
    await _processedFrameSubscription?.cancel();
    await _performanceSubscription?.cancel();
    
    // Remove camera listener
    _cameraController?.removeListener(_onCameraControllerUpdate);
    
    // Dispose services
    await _cameraService.dispose();
    await _frameProcessingService.dispose();
    
    _cameraController = null;
    _isInitialized = false;
    super.dispose();
  }

  // Private helper methods
  
  /// Handles camera controller state changes.
  void _onCameraControllerUpdate() {
    if (_isDisposed) return;
    notifyListeners();
  }
  
  /// Handles performance metric updates.
  void _onPerformanceUpdate(PerformanceMetrics metrics) {
    if (_isDisposed) return;
    
    // Log performance issues
    if (metrics.processingEfficiency < 80.0) {
      debugPrint('CameraViewController: Low processing efficiency: ${metrics.processingEfficiency.toStringAsFixed(1)}%');
    }
    
    if (metrics.estimatedFps < 20.0) {
      debugPrint('CameraViewController: Low FPS detected: ${metrics.estimatedFps.toStringAsFixed(1)} FPS');
    }
    
    // Notify listeners for UI updates
    notifyListeners();
  }
  
  /// Handles processed frame results.
  void _onProcessedFrameReceived(ProcessedFrameResult result) {
    if (_isDisposed) return;
    
    if (!result.success) {
      debugPrint('CameraViewController: Frame processing failed: ${result.errorMessage}');
      return;
    }
    
    // Handle ArUco detection results
    if (result.arucoDetectionResult != null) {
      final arucoResult = result.arucoDetectionResult!;
      
      if (arucoResult.success && arucoResult.markerCount > 0) {
        debugPrint('CameraViewController: ✓ DETECTED ${arucoResult.markerCount} ArUco markers!');
        debugPrint('CameraViewController: Marker IDs: ${arucoResult.markerIds}');
        
        // Notify listeners to update UI with detection results
        notifyListeners();
      }
    }
    
    // Log slow processing
    if (result.processingTime > 50.0) {
      debugPrint('CameraViewController: Slow frame processing: ${result.processingTime.toStringAsFixed(2)}ms');
    }
  }
  
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
}