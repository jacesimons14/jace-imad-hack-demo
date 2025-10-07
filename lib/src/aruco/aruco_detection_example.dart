import 'package:flutter/foundation.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'aruco_detector.dart';
import 'aruco_testing_utils.dart';

/// Example implementation showing how to use the ArUco marker detection
/// functionality integrated with the Flutter AR camera application.
/// 
/// This demonstrates the complete workflow from initialization to detection
/// and provides examples for common use cases.
class ArucoDetectionExample {
  static ArucoDetector? _detector;
  
  /// Initializes the ArUco detection system.
  /// 
  /// This should be called once during app initialization or when
  /// the camera starts. Returns true if initialization is successful.
  static Future<bool> initializeArucoDetection() async {
    try {
      debugPrint('ArucoDetectionExample: Initializing ArUco detection system');
      
      // Create detector with mobile-optimized configuration
      _detector = ArucoDetector.defaultMobile();
      
      // Initialize the detector
      if (!_detector!.initialize()) {
        debugPrint('ArucoDetectionExample: Failed to initialize ArUco detector');
        return false;
      }
      
      debugPrint('ArucoDetectionExample: ArUco detection system initialized successfully');
      return true;
      
    } catch (e) {
      debugPrint('ArucoDetectionExample: Initialization failed: $e');
      return false;
    }
  }
  
  /// Processes a camera frame and detects ArUco markers.
  /// 
  /// This function would typically be called from the isolate worker
  /// for each camera frame. Returns detection results.
  static ArucoDetectionResult? processFrameForMarkers(cv.Mat frame) {
    if (_detector == null) {
      debugPrint('ArucoDetectionExample: Detector not initialized');
      return null;
    }
    
    try {
      // Detect markers in the frame
      final result = _detector!.detectMarkers(frame);
      
      if (result.success && result.markerCount > 0) {
        debugPrint('ArucoDetectionExample: Detected ${result.markerCount} markers: ${result.markerIds}');
        
        // Log detailed information about each detected marker
        for (int i = 0; i < result.markerCount; i++) {
          final id = result.markerIds[i];
          final corners = result.markerCorners[i];
          debugPrint('  Marker $id: corners at [${corners.join(', ')}]');
        }
      }
      
      return result;
      
    } catch (e) {
      debugPrint('ArucoDetectionExample: Detection failed: $e');
      return null;
    }
  }
  
  /// Creates a visualization of detected markers on the camera frame.
  /// 
  /// This can be used to overlay detection results on the camera preview
  /// for debugging or user feedback purposes.
  static cv.Mat? createVisualizationFrame(cv.Mat originalFrame, ArucoDetectionResult detectionResult) {
    if (_detector == null || !detectionResult.success) {
      return null;
    }
    
    try {
      // Draw detected markers on the frame
      final visualizedFrame = _detector!.drawDetectedMarkers(originalFrame, detectionResult);
      
      if (visualizedFrame != null) {
        debugPrint('ArucoDetectionExample: Created visualization with ${detectionResult.markerCount} markers');
      }
      
      return visualizedFrame;
      
    } catch (e) {
      debugPrint('ArucoDetectionExample: Visualization creation failed: $e');
      return null;
    }
  }
  
  /// Demonstrates complete ArUco detection workflow with test markers.
  /// 
  /// This is useful for testing and validation during development.
  static Future<void> runDetectionDemo() async {
    debugPrint('ArucoDetectionExample: Starting ArUco detection demo');
    
    // Initialize detection system
    if (!await initializeArucoDetection()) {
      debugPrint('ArucoDetectionExample: Demo failed - initialization error');
      return;
    }
    
    try {
      // Generate test markers
      debugPrint('ArucoDetectionExample: Generating test markers...');
      final testMarkers = ArucoTestingUtils.generateTestMarkerSet(
        markerIds: [0, 1, 2, 5, 10],
        sizePixels: 200,
      );
      
      // Test detection on each marker
      int successCount = 0;
      for (final (id, marker) in testMarkers) {
        if (marker == null) {
          debugPrint('ArucoDetectionExample: Failed to generate marker $id');
          continue;
        }
        
        // Detect markers
        final result = processFrameForMarkers(marker);
        
        if (result != null && result.success && result.markerCount == 1 && result.markerIds.first == id) {
          successCount++;
          debugPrint('ArucoDetectionExample: ✓ Successfully detected marker $id in ${result.processingTime.toStringAsFixed(1)}ms');
          
          // Create visualization
          final visualized = createVisualizationFrame(marker, result);
          if (visualized != null) {
            debugPrint('ArucoDetectionExample: ✓ Created visualization for marker $id');
            visualized.dispose();
          }
        } else {
          debugPrint('ArucoDetectionExample: ✗ Failed to detect marker $id');
        }
        
        marker.dispose();
      }
      
      debugPrint('ArucoDetectionExample: Demo completed - $successCount/${testMarkers.length} markers detected successfully');
      
      // Run comprehensive test
      final testResults = ArucoTestingUtils.runComprehensiveTest(
        detector: _detector!,
        markerIds: [0, 1, 2, 3, 4, 5, 10, 15, 20, 25],
      );
      
      debugPrint('ArucoDetectionExample: Comprehensive test results: $testResults');
      
    } catch (e) {
      debugPrint('ArucoDetectionExample: Demo failed with exception: $e');
    } finally {
      // Clean up
      disposeArucoDetection();
    }
  }
  
  /// Creates a multi-marker test scene for advanced testing.
  /// 
  /// This demonstrates detection of multiple markers in a single frame,
  /// which is common in AR applications.
  static Future<void> runMultiMarkerDemo() async {
    debugPrint('ArucoDetectionExample: Starting multi-marker detection demo');
    
    if (!await initializeArucoDetection()) {
      debugPrint('ArucoDetectionExample: Multi-marker demo failed - initialization error');
      return;
    }
    
    try {
      // Create test scene with multiple markers
      final testIds = [1, 2, 3, 4, 5, 6];
      final multiMarkerImage = ArucoTestingUtils.createMultiMarkerTestImage(
        markerIds: testIds,
        imageWidth: 800,
        imageHeight: 600,
        markerSize: 100,
      );
      
      if (multiMarkerImage == null) {
        debugPrint('ArucoDetectionExample: Failed to create multi-marker test image');
        return;
      }
      
      // Detect markers in the multi-marker scene
      final result = processFrameForMarkers(multiMarkerImage);
      
      if (result != null && result.success) {
        debugPrint('ArucoDetectionExample: Multi-marker detection results:');
        debugPrint('  Detected ${result.markerCount} markers');
        debugPrint('  Processing time: ${result.processingTime.toStringAsFixed(1)}ms');
        debugPrint('  Detected IDs: ${result.markerIds}');
        
        // Validate results
        final validation = ArucoTestingUtils.validateDetectionResult(
          result: result,
          imageWidth: 800,
          imageHeight: 600,
        );
        
        if (validation.isValid) {
          debugPrint('ArucoDetectionExample: ✓ All detections are valid');
        } else {
          debugPrint('ArucoDetectionExample: ✗ Validation errors: ${validation.errors}');
        }
        
        // Create visualization
        final visualized = createVisualizationFrame(multiMarkerImage, result);
        if (visualized != null) {
          debugPrint('ArucoDetectionExample: ✓ Created multi-marker visualization');
          visualized.dispose();
        }
        
      } else {
        debugPrint('ArucoDetectionExample: Multi-marker detection failed');
      }
      
      multiMarkerImage.dispose();
      
    } catch (e) {
      debugPrint('ArucoDetectionExample: Multi-marker demo failed: $e');
    } finally {
      disposeArucoDetection();
    }
  }
  
  /// Demonstrates performance characteristics of the detection system.
  /// 
  /// This provides insights into processing speeds and resource usage
  /// which are important for real-time AR applications.
  static Future<void> runPerformanceBenchmark() async {
    debugPrint('ArucoDetectionExample: Starting performance benchmark');
    
    if (!await initializeArucoDetection()) {
      debugPrint('ArucoDetectionExample: Benchmark failed - initialization error');
      return;
    }
    
    try {
      const numIterations = 100;
      const testMarkerId = 15;
      
      // Generate test marker
      final marker = ArucoTestingUtils.generateTestMarker(
        markerId: testMarkerId,
        sizePixels: 300,
      );
      
      if (marker == null) {
        debugPrint('ArucoDetectionExample: Failed to generate benchmark marker');
        return;
      }
      
      // Warm up
      for (int i = 0; i < 10; i++) {
        processFrameForMarkers(marker);
      }
      
      // Run benchmark
      final processingTimes = <double>[];
      final startTime = DateTime.now();
      
      for (int i = 0; i < numIterations; i++) {
        final result = processFrameForMarkers(marker);
        if (result != null && result.success) {
          processingTimes.add(result.processingTime);
        }
      }
      
      final totalTime = DateTime.now().difference(startTime).inMicroseconds / 1000.0;
      
      // Calculate statistics
      if (processingTimes.isNotEmpty) {
        final averageTime = processingTimes.reduce((a, b) => a + b) / processingTimes.length;
        final minTime = processingTimes.reduce((a, b) => a < b ? a : b);
        final maxTime = processingTimes.reduce((a, b) => a > b ? a : b);
        final successRate = processingTimes.length / numIterations;
        
        debugPrint('ArucoDetectionExample: Performance Benchmark Results:');
        debugPrint('  Total iterations: $numIterations');
        debugPrint('  Successful detections: ${processingTimes.length}');
        debugPrint('  Success rate: ${(successRate * 100).toStringAsFixed(1)}%');
        debugPrint('  Total time: ${totalTime.toStringAsFixed(1)}ms');
        debugPrint('  Average detection time: ${averageTime.toStringAsFixed(2)}ms');
        debugPrint('  Min detection time: ${minTime.toStringAsFixed(2)}ms');
        debugPrint('  Max detection time: ${maxTime.toStringAsFixed(2)}ms');
        debugPrint('  Estimated FPS: ${(1000.0 / averageTime).toStringAsFixed(1)}');
        
        // Performance validation
        if (averageTime < 30.0) {
          debugPrint('ArucoDetectionExample: ✓ Excellent performance (< 30ms avg)');
        } else if (averageTime < 50.0) {
          debugPrint('ArucoDetectionExample: ✓ Good performance (< 50ms avg)');
        } else {
          debugPrint('ArucoDetectionExample: ⚠ Consider optimization (${averageTime.toStringAsFixed(1)}ms avg)');
        }
      }
      
      marker.dispose();
      
    } catch (e) {
      debugPrint('ArucoDetectionExample: Benchmark failed: $e');
    } finally {
      disposeArucoDetection();
    }
  }
  
  /// Gets current detection statistics.
  /// 
  /// This can be used for monitoring and debugging in production.
  static Map<String, dynamic>? getDetectionStatistics() {
    if (_detector == null) {
      return null;
    }
    
    return _detector!.getStatistics();
  }
  
  /// Disposes the ArUco detection system and frees resources.
  /// 
  /// This should be called when the app is closing or when
  /// switching away from AR mode.
  static void disposeArucoDetection() {
    _detector?.dispose();
    _detector = null;
    debugPrint('ArucoDetectionExample: ArUco detection system disposed');
  }
  
  /// Example of integration with camera frame processing pipeline.
  /// 
  /// This shows how the ArUco detection would be integrated into
  /// the existing frame processing service.
  static void demonstrateIntegration() {
    debugPrint('ArucoDetectionExample: Integration Example');
    debugPrint('');
    debugPrint('To integrate ArUco detection into your camera processing pipeline:');
    debugPrint('');
    debugPrint('1. Initialize ArUco detector in the isolate worker:');
    debugPrint('   final arucoDetector = ArucoDetector.defaultMobile();');
    debugPrint('   arucoDetector.initialize();');
    debugPrint('');
    debugPrint('2. Process each camera frame:');
    debugPrint('   final result = arucoDetector.detectMarkers(preprocessedFrame);');
    debugPrint('');
    debugPrint('3. Send results back to main thread:');
    debugPrint('   return ProcessedFrameResult(');
    debugPrint('     // ... other fields');
    debugPrint('     arucoDetectionResult: result,');
    debugPrint('   );');
    debugPrint('');
    debugPrint('4. Handle results in your UI:');
    debugPrint('   frameProcessingService.processedFrameStream.listen((result) {');
    debugPrint('     if (result.arucoDetectionResult?.success == true) {');
    debugPrint('       // Update AR overlays based on detected markers');
    debugPrint('       updateARAnchors(result.arucoDetectionResult!);');
    debugPrint('     }');
    debugPrint('   });');
    debugPrint('');
  }
}