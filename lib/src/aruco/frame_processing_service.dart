import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';

import 'opencv_isolate_worker.dart';

/// Commands that can be sent to the isolate.
enum IsolateCommand {
  shutdown,
}

/// Represents a frame processing request sent to the isolate.
class FrameProcessingRequest {
  final Uint8List frameData;
  final int width;
  final int height;
  final ImageFormatGroup format;
  final int timestamp;
  
  FrameProcessingRequest({
    required this.frameData,
    required this.width,
    required this.height,
    required this.format,
    required this.timestamp,
  });
}

/// Represents the result of frame processing from the isolate.
class ProcessedFrameResult {
  final int originalTimestamp;
  final double processingTime;
  final bool success;
  final Uint8List? processedData;
  final String? errorMessage;
  
  ProcessedFrameResult({
    required this.originalTimestamp,
    required this.processingTime,
    required this.success,
    this.processedData,
    this.errorMessage,
  });
}

/// Performance metrics for the frame processing service.
class PerformanceMetrics {
  final int processedFrameCount;
  final double averageProcessingTime;
  final int currentQueueSize;
  final int skippedFrameCount;
  final List<int> recentProcessingTimes;
  
  PerformanceMetrics({
    required this.processedFrameCount,
    required this.averageProcessingTime,
    required this.currentQueueSize,
    this.skippedFrameCount = 0,
    this.recentProcessingTimes = const <int>[],
  });
  
  /// Gets the current frames per second estimate.
  double get estimatedFps {
    if (recentProcessingTimes.isEmpty) return 0.0;
    final avgTime = recentProcessingTimes.fold<int>(0, (sum, time) => sum + time) / recentProcessingTimes.length;
    return avgTime > 0 ? 1000.0 / avgTime : 0.0; // Convert ms to FPS
  }
  
  /// Gets the processing efficiency percentage (100% = no skipped frames).
  double get processingEfficiency {
    final totalFrames = processedFrameCount + skippedFrameCount;
    return totalFrames > 0 ? (processedFrameCount / totalFrames) * 100.0 : 100.0;
  }
  
  @override
  String toString() {
    return 'PerformanceMetrics(frames: $processedFrameCount, skipped: $skippedFrameCount, '
           'avgTime: ${averageProcessingTime.toStringAsFixed(2)}ms, '
           'queue: $currentQueueSize, fps: ${estimatedFps.toStringAsFixed(1)}, '
           'efficiency: ${processingEfficiency.toStringAsFixed(1)}%)';
  }
}

/// A service that handles camera frame processing using OpenCV in a background isolate.
///
/// This service manages the complete pipeline for camera frame processing:
/// - Receives raw camera frames from CameraService
/// - Converts frames to OpenCV-compatible format
/// - Processes frames in background isolate to prevent UI blocking
/// - Returns processed frame data and detection results
/// - Implements frame throttling and memory management for optimal performance
class FrameProcessingService {
  static const int _maxFrameQueueSize = 3; // Prevent memory buildup
  static const int _frameSkipThreshold = 2; // Skip frames if queue is this full
  static const Duration _performanceLogInterval = Duration(seconds: 5);
  
  // Isolate communication
  Isolate? _isolate;
  SendPort? _isolateSendPort;
  ReceivePort? _mainReceivePort;
  final Completer<SendPort> _isolateReady = Completer<SendPort>();
  
  // Frame processing state
  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _isDisposed = false;
  int _frameQueueCount = 0;
  int _skippedFrameCount = 0;
  
  // Performance monitoring and throttling
  int _processedFrameCount = 0;
  double _averageProcessingTime = 0.0;
  DateTime? _lastPerformanceLog;
  
  // Memory management
  final List<int> _recentProcessingTimes = <int>[];
  static const int _maxProcessingTimeHistory = 50;
  
  // Stream controllers for processed data
  final StreamController<ProcessedFrameResult> _processedFrameController = 
      StreamController<ProcessedFrameResult>.broadcast();
  final StreamController<PerformanceMetrics> _performanceController = 
      StreamController<PerformanceMetrics>.broadcast();
  
  /// Stream of processed frame results
  Stream<ProcessedFrameResult> get processedFrameStream => _processedFrameController.stream;
  
  /// Stream of performance metrics
  Stream<PerformanceMetrics> get performanceStream => _performanceController.stream;
  
  /// Returns true if the service is initialized and ready to process frames
  bool get isInitialized => _isInitialized && !_isDisposed;
  
  /// Returns true if currently processing frames
  bool get isProcessing => _isProcessing;
  
  /// Returns current performance metrics
  PerformanceMetrics get currentMetrics => PerformanceMetrics(
    processedFrameCount: _processedFrameCount,
    averageProcessingTime: _averageProcessingTime,
    currentQueueSize: _frameQueueCount,
    skippedFrameCount: _skippedFrameCount,
    recentProcessingTimes: List<int>.from(_recentProcessingTimes),
  );
  
  /// Initializes the frame processing service and spawns the background isolate.
  Future<void> initialize() async {
    if (_isInitialized || _isDisposed) return;
    
    try {
      // Set up main thread receive port
      _mainReceivePort = ReceivePort();
      
      // Spawn the isolate for OpenCV processing
      _isolate = await Isolate.spawn(
        OpenCVIsolateWorker.entryPoint,
        _mainReceivePort!.sendPort,
        debugName: 'OpenCVProcessingIsolate',
      );
      
      // Listen for messages from isolate
      _mainReceivePort!.listen(_handleIsolateMessage);
      
      // Wait for isolate to be ready
      _isolateSendPort = await _isolateReady.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Isolate initialization timeout'),
      );
      
      _isInitialized = true;
      debugPrint('FrameProcessingService: Initialized successfully');
      
    } catch (e) {
      debugPrint('FrameProcessingService: Initialization failed: $e');
      await dispose();
      rethrow;
    }
  }
  
  /// Processes a camera frame in the background isolate.
  Future<void> processFrame(CameraImage frame) async {
    if (!isInitialized || _isDisposed) return;
    
    // Implement intelligent frame skipping for performance
    if (_frameQueueCount >= _frameSkipThreshold) {
      _skippedFrameCount++;
      debugPrint('FrameProcessingService: Skipping frame - queue threshold reached');
      return;
    }
    
    // Skip frame if queue is full (prevent memory buildup)
    if (_frameQueueCount >= _maxFrameQueueSize) {
      _skippedFrameCount++;
      debugPrint('FrameProcessingService: Dropping frame - queue full');
      return;
    }
    
    try {
      // Extract frame data
      final frameData = await _extractFrameData(frame);
      if (frameData == null) return;
      
      _frameQueueCount++;
      final processingStartTime = DateTime.now();
      
      // Send frame to isolate for processing
      _isolateSendPort?.send(FrameProcessingRequest(
        frameData: frameData,
        width: frame.width,
        height: frame.height,
        format: frame.format.group,
        timestamp: processingStartTime.millisecondsSinceEpoch,
      ));
      
    } catch (e) {
      debugPrint('FrameProcessingService: Error processing frame: $e');
      _frameQueueCount = (_frameQueueCount - 1).clamp(0, _maxFrameQueueSize);
    }
  }
  
  /// Starts continuous frame processing.
  void startProcessing() {
    if (!isInitialized || _isProcessing) return;
    _isProcessing = true;
    debugPrint('FrameProcessingService: Started processing');
  }
  
  /// Stops frame processing.
  void stopProcessing() {
    if (!_isProcessing) return;
    _isProcessing = false;
    debugPrint('FrameProcessingService: Stopped processing');
  }
  
  /// Disposes the service and cleans up resources.
  Future<void> dispose() async {
    if (_isDisposed) return;
    
    _isDisposed = true;
    _isProcessing = false;
    
    // Send shutdown signal to isolate
    _isolateSendPort?.send(IsolateCommand.shutdown);
    
    // Clean up isolate
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _isolateSendPort = null;
    
    // Close receive port
    _mainReceivePort?.close();
    _mainReceivePort = null;
    
    // Close stream controllers
    await _processedFrameController.close();
    await _performanceController.close();
    
    debugPrint('FrameProcessingService: Disposed');
  }
  
  /// Gets the current processing load as a percentage (0-100).
  double getProcessingLoad() {
    if (_recentProcessingTimes.isEmpty) return 0.0;
    
    // Calculate load based on recent processing times
    const targetFrameTime = 33.0; // 30 FPS target (33ms per frame)
    final avgTime = _recentProcessingTimes.fold<int>(0, (sum, time) => sum + time) / _recentProcessingTimes.length;
    
    return (avgTime / targetFrameTime * 100.0).clamp(0.0, 100.0);
  }
  
  /// Determines if frame processing should be throttled based on current load.
  bool shouldThrottleFrameProcessing() {
    final load = getProcessingLoad();
    final queueFullness = _frameQueueCount / _maxFrameQueueSize;
    
    // Throttle if processing load is high or queue is getting full
    return load > 80.0 || queueFullness > 0.6;
  }
  
  // Private methods
  
  /// Handles messages received from the isolate.
  void _handleIsolateMessage(dynamic message) {
    if (_isDisposed) return;
    
    if (message is SendPort) {
      // Isolate is ready
      if (!_isolateReady.isCompleted) {
        _isolateReady.complete(message);
      }
    } else if (message is ProcessedFrameResult) {
      // Processed frame result
      _frameQueueCount = (_frameQueueCount - 1).clamp(0, _maxFrameQueueSize);
      _updatePerformanceMetrics(message);
      _processedFrameController.add(message);
    } else if (message is String) {
      // Debug message from isolate
      debugPrint('FrameProcessingService: Isolate: $message');
    }
  }
  
  /// Updates performance metrics based on processed frame result.
  void _updatePerformanceMetrics(ProcessedFrameResult result) {
    _processedFrameCount++;
    
    final processingTime = result.processingTime;
    
    // Update average processing time (exponential moving average)
    _averageProcessingTime = _averageProcessingTime == 0.0
        ? processingTime
        : (_averageProcessingTime * 0.9) + (processingTime * 0.1);
    
    // Track recent processing times for FPS calculation
    _recentProcessingTimes.add(processingTime.round());
    if (_recentProcessingTimes.length > _maxProcessingTimeHistory) {
      _recentProcessingTimes.removeAt(0);
    }
    
    // Emit performance metrics periodically or when significant changes occur
    final now = DateTime.now();
    if (_lastPerformanceLog == null || 
        now.difference(_lastPerformanceLog!).compareTo(_performanceLogInterval) >= 0 ||
        _processedFrameCount % 30 == 0) {
      
      _lastPerformanceLog = now;
      _performanceController.add(currentMetrics);
      
      // Log performance summary
      final metrics = currentMetrics;
      debugPrint('FrameProcessingService: ${metrics.toString()}');
    }
  }
  
  /// Extracts frame data from CameraImage and converts to Uint8List.
  Future<Uint8List?> _extractFrameData(CameraImage frame) async {
    try {
      // Handle different image formats
      switch (frame.format.group) {
        case ImageFormatGroup.yuv420:
          return _convertYuv420ToRgba(frame);
        case ImageFormatGroup.bgra8888:
          return frame.planes[0].bytes;
        case ImageFormatGroup.nv21:
          return _convertNv21ToRgba(frame);
        default:
          debugPrint('FrameProcessingService: Unsupported format: ${frame.format.group}');
          return null;
      }
    } catch (e) {
      debugPrint('FrameProcessingService: Error extracting frame data: $e');
      return null;
    }
  }
  
  /// Converts YUV420 format to RGBA.
  Uint8List _convertYuv420ToRgba(CameraImage frame) {
    final yPlane = frame.planes[0];
    final uPlane = frame.planes[1];
    final vPlane = frame.planes[2];
    
    final width = frame.width;
    final height = frame.height;
    final rgba = Uint8List(width * height * 4);
    
    // Basic YUV to RGBA conversion
    // This is a simplified implementation - in production, use optimized native code
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final yIndex = y * yPlane.bytesPerRow + x;
        final uvIndex = (y ~/ 2) * yPlane.bytesPerRow + (x ~/ 2);
        
        final yValue = yPlane.bytes[yIndex];
        final uValue = uPlane.bytes[uvIndex];
        final vValue = vPlane.bytes[uvIndex];
        
        // YUV to RGB conversion
        final r = (yValue + 1.402 * (vValue - 128)).clamp(0, 255).toInt();
        final g = (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128)).clamp(0, 255).toInt();
        final b = (yValue + 1.772 * (uValue - 128)).clamp(0, 255).toInt();
        
        final rgbaIndex = (y * width + x) * 4;
        rgba[rgbaIndex] = r;
        rgba[rgbaIndex + 1] = g;
        rgba[rgbaIndex + 2] = b;
        rgba[rgbaIndex + 3] = 255; // Alpha
      }
    }
    
    return rgba;
  }
  
  /// Converts NV21 format to RGBA.
  Uint8List _convertNv21ToRgba(CameraImage frame) {
    // Similar to YUV420 but with different plane layout
    // Simplified implementation - use native code for production
    return _convertYuv420ToRgba(frame);
  }
}