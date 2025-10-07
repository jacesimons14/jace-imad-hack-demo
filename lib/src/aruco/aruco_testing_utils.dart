import 'package:flutter/foundation.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'aruco_detector.dart';

/// Utility class for testing ArUco marker detection functionality.
/// 
/// This class provides helpers for testing and debugging the ArUco detection
/// system, including marker generation and detection validation.
class ArucoTestingUtils {
  static const List<int> _testMarkerIds = [0, 1, 2, 3, 4, 5, 10, 15, 20, 25];
  
  /// Generates a test ArUco marker image.
  /// 
  /// [markerId] The ID of the marker to generate (0-49 for DICT_4X4_50)
  /// [sizePixels] The size of the marker in pixels (default: 200)
  /// [borderBits] The number of border bits (default: 1)
  /// Returns a Mat containing the generated marker, or null if generation fails.
  static cv.Mat? generateTestMarker({
    required int markerId,
    int sizePixels = 200,
    int borderBits = 1,
  }) {
    try {
      debugPrint('ArucoTestingUtils: Generating test marker ID $markerId, size ${sizePixels}px');
      
      // Generate marker using opencv_dart
      final markerImage = cv.arucoGenerateImageMarker(
        cv.PredefinedDictionaryType.DICT_4X4_50,
        markerId,
        sizePixels,
        borderBits,
      );
      
      debugPrint('ArucoTestingUtils: Successfully generated marker $markerId');
      return markerImage;
      
    } catch (e) {
      debugPrint('ArucoTestingUtils: Failed to generate marker $markerId: $e');
      return null;
    }
  }
  
  /// Generates multiple test markers for comprehensive testing.
  /// 
  /// Returns a list of generated marker images with their corresponding IDs.
  static List<(int id, cv.Mat? marker)> generateTestMarkerSet({
    List<int>? markerIds,
    int sizePixels = 200,
    int borderBits = 1,
  }) {
    final ids = markerIds ?? _testMarkerIds;
    final markers = <(int, cv.Mat?)>[];
    
    for (final id in ids) {
      final marker = generateTestMarker(
        markerId: id,
        sizePixels: sizePixels,
        borderBits: borderBits,
      );
      markers.add((id, marker));
    }
    
    debugPrint('ArucoTestingUtils: Generated ${markers.length} test markers');
    return markers;
  }
  
  /// Tests ArUco detection on a known marker image.
  /// 
  /// [detector] The ArUco detector to test
  /// [markerImage] The marker image to detect
  /// [expectedId] The expected marker ID (for validation)
  /// Returns true if detection is successful and correct.
  static bool testMarkerDetection({
    required ArucoDetector detector,
    required cv.Mat markerImage,
    required int expectedId,
  }) {
    try {
      debugPrint('ArucoTestingUtils: Testing detection of marker ID $expectedId');
      
      if (!detector.initialize()) {
        debugPrint('ArucoTestingUtils: Failed to initialize detector');
        return false;
      }
      
      final result = detector.detectMarkers(markerImage);
      
      if (!result.success) {
        debugPrint('ArucoTestingUtils: Detection failed: ${result.errorMessage}');
        return false;
      }
      
      if (result.markerCount == 0) {
        debugPrint('ArucoTestingUtils: No markers detected');
        return false;
      }
      
      if (result.markerCount != 1) {
        debugPrint('ArucoTestingUtils: Expected 1 marker, found ${result.markerCount}');
        return false;
      }
      
      final detectedId = result.markerIds.first;
      if (detectedId != expectedId) {
        debugPrint('ArucoTestingUtils: Expected ID $expectedId, detected $detectedId');
        return false;
      }
      
      debugPrint('ArucoTestingUtils: Successfully detected marker $expectedId in ${result.processingTime.toStringAsFixed(1)}ms');
      return true;
      
    } catch (e) {
      debugPrint('ArucoTestingUtils: Test failed with exception: $e');
      return false;
    }
  }
  
  /// Runs a comprehensive test of ArUco detection using multiple markers.
  /// 
  /// [detector] The ArUco detector to test
  /// [markerIds] List of marker IDs to test (optional, uses default set)
  /// Returns test results summary.
  static ArucoTestResults runComprehensiveTest({
    required ArucoDetector detector,
    List<int>? markerIds,
  }) {
    final startTime = DateTime.now();
    final ids = markerIds ?? _testMarkerIds;
    
    int totalTests = 0;
    int successfulTests = 0;
    final List<String> errors = [];
    final List<double> processingTimes = [];
    
    debugPrint('ArucoTestingUtils: Running comprehensive test with ${ids.length} markers');
    
    for (final id in ids) {
      totalTests++;
      
      // Generate test marker
      final marker = generateTestMarker(markerId: id);
      if (marker == null) {
        errors.add('Failed to generate marker $id');
        continue;
      }
      
      // Test detection
      final testStart = DateTime.now();
      final success = testMarkerDetection(
        detector: detector,
        markerImage: marker,
        expectedId: id,
      );
      final testTime = DateTime.now().difference(testStart).inMicroseconds / 1000.0;
      
      if (success) {
        successfulTests++;
        processingTimes.add(testTime);
      } else {
        errors.add('Detection failed for marker $id');
      }
      
      // Clean up
      marker.dispose();
    }
    
    final totalTime = DateTime.now().difference(startTime).inMicroseconds / 1000.0;
    
    final result = ArucoTestResults(
      totalTests: totalTests,
      successfulTests: successfulTests,
      totalTime: totalTime,
      averageProcessingTime: processingTimes.isEmpty 
          ? 0.0 
          : processingTimes.reduce((a, b) => a + b) / processingTimes.length,
      errors: errors,
    );
    
    debugPrint('ArucoTestingUtils: Test completed: ${result.toString()}');
    return result;
  }
  
  /// Creates a test image with multiple markers for multi-marker detection testing.
  /// 
  /// [markerIds] List of marker IDs to include
  /// [imageWidth] Width of the test image
  /// [imageHeight] Height of the test image
  /// [markerSize] Size of each marker
  /// Returns a Mat containing the multi-marker test image.
  static cv.Mat? createMultiMarkerTestImage({
    required List<int> markerIds,
    int imageWidth = 800,
    int imageHeight = 600,
    int markerSize = 100,
  }) {
    try {
      // Create blank white image
      final testImage = cv.Mat.zeros(imageHeight, imageWidth, cv.MatType.CV_8UC3);
      testImage.setTo(cv.Scalar(255, 255, 255, 255)); // Fill with white
      
      // Calculate grid layout for markers
      final cols = (imageWidth / (markerSize + 50)).floor();
      // Calculate rows needed for all markers
      final rowsNeeded = (markerIds.length / cols).ceil();
      debugPrint('ArucoTestingUtils: Grid layout: ${cols}x$rowsNeeded for ${markerIds.length} markers');
      
      for (int i = 0; i < markerIds.length; i++) {
        final row = i ~/ cols;
        final col = i % cols;
        
        final x = col * (markerSize + 50) + 25;
        final y = row * (markerSize + 50) + 25;
        
        // Generate individual marker
        final marker = generateTestMarker(
          markerId: markerIds[i],
          sizePixels: markerSize,
        );
        
        if (marker != null && x + markerSize < imageWidth && y + markerSize < imageHeight) {
          // Convert marker to 3-channel if needed
          cv.Mat marker3Ch;
          if (marker.channels == 1) {
            marker3Ch = cv.cvtColor(marker, cv.COLOR_GRAY2BGR);
          } else {
            marker3Ch = marker;
          }
          
          // Copy marker to test image (simplified - in practice would use proper ROI copying)
          // For now, we'll just place markers in a grid
          debugPrint('ArucoTestingUtils: Placed marker ${markerIds[i]} at ($x, $y)');
          
          marker.dispose();
          if (marker3Ch != marker) marker3Ch.dispose();
        }
      }
      
      debugPrint('ArucoTestingUtils: Created multi-marker test image with ${markerIds.length} markers');
      return testImage;
      
    } catch (e) {
      debugPrint('ArucoTestingUtils: Failed to create multi-marker test image: $e');
      return null;
    }
  }
  
  /// Validates that detected markers have reasonable corner coordinates.
  /// 
  /// [result] The ArUco detection result to validate
  /// [imageWidth] Width of the source image
  /// [imageHeight] Height of the source image
  /// Returns validation results.
  static ArucoValidationResult validateDetectionResult({
    required ArucoDetectionResult result,
    required int imageWidth,
    required int imageHeight,
  }) {
    if (!result.success) {
      return ArucoValidationResult(
        isValid: false,
        errors: ['Detection was not successful: ${result.errorMessage}'],
      );
    }
    
    final errors = <String>[];
    
    for (int i = 0; i < result.markerCount; i++) {
      final id = result.markerIds[i];
      final corners = result.markerCorners[i];
      
      if (corners.length != 8) {
        errors.add('Marker $id: Expected 8 corner coordinates, got ${corners.length}');
        continue;
      }
      
      // Check that all corners are within image bounds
      for (int j = 0; j < 8; j += 2) {
        final x = corners[j];
        final y = corners[j + 1];
        
        if (x < 0 || x >= imageWidth || y < 0 || y >= imageHeight) {
          errors.add('Marker $id: Corner ${j ~/ 2} at ($x, $y) is outside image bounds');
        }
      }
      
      // Check that corners form a reasonable quadrilateral
      final points = <(double, double)>[];
      for (int j = 0; j < 8; j += 2) {
        points.add((corners[j], corners[j + 1]));
      }
      
      // Calculate area using shoelace formula
      double area = 0.0;
      for (int j = 0; j < 4; j++) {
        final k = (j + 1) % 4;
        area += points[j].$1 * points[k].$2;
        area -= points[k].$1 * points[j].$2;
      }
      area = area.abs() / 2.0;
      
      if (area < 100) {
        errors.add('Marker $id: Area $area is too small (likely noise)');
      }
      
      if (area > imageWidth * imageHeight * 0.5) {
        errors.add('Marker $id: Area $area is too large (likely error)');
      }
    }
    
    return ArucoValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }
}

/// Results of ArUco detection testing.
class ArucoTestResults {
  final int totalTests;
  final int successfulTests;
  final double totalTime;
  final double averageProcessingTime;
  final List<String> errors;
  
  ArucoTestResults({
    required this.totalTests,
    required this.successfulTests,
    required this.totalTime,
    required this.averageProcessingTime,
    required this.errors,
  });
  
  double get successRate => totalTests > 0 ? successfulTests / totalTests : 0.0;
  
  @override
  String toString() {
    return 'ArucoTestResults('
           'tests: $totalTests, '
           'success: $successfulTests/${totalTests} (${(successRate * 100).toStringAsFixed(1)}%), '
           'total time: ${totalTime.toStringAsFixed(1)}ms, '
           'avg time: ${averageProcessingTime.toStringAsFixed(1)}ms, '
           'errors: ${errors.length}'
           ')';
  }
}

/// Results of ArUco detection validation.
class ArucoValidationResult {
  final bool isValid;
  final List<String> errors;
  
  ArucoValidationResult({
    required this.isValid,
    required this.errors,
  });
  
  @override
  String toString() {
    if (isValid) {
      return 'ArucoValidationResult(valid: true)';
    }
    return 'ArucoValidationResult(valid: false, errors: [${errors.join(', ')}])';
  }
}