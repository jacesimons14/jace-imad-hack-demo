import 'package:flutter_test/flutter_test.dart';
import 'package:jace_imad_hack_demo/src/aruco/aruco_detector.dart';
import 'package:jace_imad_hack_demo/src/aruco/aruco_testing_utils.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

void main() {
  group('ArUco Marker Detection Tests', () {
    late ArucoDetector detector;
    
    setUp(() {
      detector = ArucoDetector.defaultMobile();
    });
    
    tearDown(() {
      detector.dispose();
    });
    
    test('ArUco detector initialization', () {
      expect(detector.initialize(), isTrue);
      // Detector is now ready to use
    });
    
    test('ArUco detector configuration factories', () {
      final mobileDetector = ArucoDetector.defaultMobile();
      final highAccuracyDetector = ArucoDetector.highAccuracy();
      final fastDetector = ArucoDetector.fastDetection();
      
      expect(mobileDetector.config.enableCornerRefinement, isTrue);
      expect(highAccuracyDetector.config.enableCornerRefinement, isTrue);
      expect(fastDetector.config.enableCornerRefinement, isFalse);
      
      mobileDetector.dispose();
      highAccuracyDetector.dispose();
      fastDetector.dispose();
    });
    
    test('Single marker generation and detection', () {
      const testMarkerId = 5;
      
      // Generate test marker
      final markerImage = ArucoTestingUtils.generateTestMarker(
        markerId: testMarkerId,
        sizePixels: 200,
      );
      
      expect(markerImage, isNotNull);
      
      // Test detection
      final success = ArucoTestingUtils.testMarkerDetection(
        detector: detector,
        markerImage: markerImage!,
        expectedId: testMarkerId,
      );
      
      expect(success, isTrue);
      
      markerImage.dispose();
    });
    
    test('Multiple marker detection test', () {
      final testIds = [0, 1, 5, 10, 15];
      
      final testResults = ArucoTestingUtils.runComprehensiveTest(
        detector: detector,
        markerIds: testIds,
      );
      
      expect(testResults.totalTests, equals(testIds.length));
      expect(testResults.successRate, greaterThan(0.8)); // At least 80% success rate
      expect(testResults.averageProcessingTime, lessThan(100.0)); // Less than 100ms average
    });
    
    test('Detection result validation', () {
      const testMarkerId = 3;
      const imageSize = 300;
      
      // Generate test marker
      final markerImage = ArucoTestingUtils.generateTestMarker(
        markerId: testMarkerId,
        sizePixels: 150,
      );
      
      expect(markerImage, isNotNull);
      expect(detector.initialize(), isTrue);
      
      // Detect markers
      final result = detector.detectMarkers(markerImage!);
      
      // Validate result
      final validation = ArucoTestingUtils.validateDetectionResult(
        result: result,
        imageWidth: imageSize,
        imageHeight: imageSize,
      );
      
      expect(result.success, isTrue);
      expect(result.markerCount, equals(1));
      expect(result.markerIds.first, equals(testMarkerId));
      expect(validation.isValid, isTrue);
      
      markerImage.dispose();
    });
    
    test('Empty image detection', () {
      // Create empty (black) image
      final emptyImage = cv.Mat.zeros(300, 300, cv.MatType.CV_8UC1);
      
      expect(detector.initialize(), isTrue);
      
      final result = detector.detectMarkers(emptyImage);
      
      expect(result.success, isTrue);
      expect(result.markerCount, equals(0));
      expect(result.markerIds, isEmpty);
      
      emptyImage.dispose();
    });
    
    test('Invalid image detection', () {
      // Create invalid (empty) mat
      final invalidImage = cv.Mat.empty();
      
      expect(detector.initialize(), isTrue);
      
      final result = detector.detectMarkers(invalidImage);
      
      expect(result.success, isFalse);
      expect(result.errorMessage, contains('empty'));
      
      invalidImage.dispose();
    });
    
    test('Detection without initialization', () {
      final markerImage = cv.Mat.zeros(100, 100, cv.MatType.CV_8UC1);
      
      // Don't initialize detector
      final result = detector.detectMarkers(markerImage);
      
      expect(result.success, isFalse);
      expect(result.errorMessage, contains('not initialized'));
      
      markerImage.dispose();
    });
    
    test('Detection performance benchmarking', () {
      const testMarkerId = 7;
      const numIterations = 10;
      
      final markerImage = ArucoTestingUtils.generateTestMarker(
        markerId: testMarkerId,
        sizePixels: 200,
      );
      
      expect(markerImage, isNotNull);
      expect(detector.initialize(), isTrue);
      
      final processingTimes = <double>[];
      
      for (int i = 0; i < numIterations; i++) {
        final result = detector.detectMarkers(markerImage!);
        expect(result.success, isTrue);
        processingTimes.add(result.processingTime);
      }
      
      final averageTime = processingTimes.reduce((a, b) => a + b) / processingTimes.length;
      final maxTime = processingTimes.reduce((a, b) => a > b ? a : b);
      final minTime = processingTimes.reduce((a, b) => a < b ? a : b);
      
      print('Performance results:');
      print('  Average: ${averageTime.toStringAsFixed(2)}ms');
      print('  Min: ${minTime.toStringAsFixed(2)}ms');
      print('  Max: ${maxTime.toStringAsFixed(2)}ms');
      
      // Performance expectations
      expect(averageTime, lessThan(50.0)); // Average less than 50ms
      expect(maxTime, lessThan(100.0)); // Max less than 100ms
      
      markerImage!.dispose();
    });
    
    test('Marker drawing functionality', () {
      const testMarkerId = 12;
      
      // Generate test marker
      final markerImage = ArucoTestingUtils.generateTestMarker(
        markerId: testMarkerId,
        sizePixels: 200,
      );
      
      expect(markerImage, isNotNull);
      expect(detector.initialize(), isTrue);
      
      // Detect markers
      final result = detector.detectMarkers(markerImage!);
      expect(result.success, isTrue);
      expect(result.markerCount, equals(1));
      
      // Draw detected markers
      final drawnImage = detector.drawDetectedMarkers(markerImage, result);
      expect(drawnImage, isNotNull);
      
      // Verify drawn image has proper dimensions
      expect(drawnImage!.rows, equals(markerImage.rows));
      expect(drawnImage.cols, equals(markerImage.cols));
      
      markerImage.dispose();
      drawnImage.dispose();
    });
    
    test('Multi-marker test image creation', () {
      final testIds = [1, 2, 3, 4];
      
      final multiMarkerImage = ArucoTestingUtils.createMultiMarkerTestImage(
        markerIds: testIds,
        imageWidth: 600,
        imageHeight: 400,
        markerSize: 80,
      );
      
      expect(multiMarkerImage, isNotNull);
      expect(multiMarkerImage!.rows, equals(400));
      expect(multiMarkerImage.cols, equals(600));
      
      multiMarkerImage.dispose();
    });
    
    test('ArUco detection result serialization', () {
      final originalResult = ArucoDetectionResult(
        markerIds: [1, 5, 10],
        markerCorners: [
          [10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0],
          [110.0, 120.0, 130.0, 140.0, 150.0, 160.0, 170.0, 180.0],
          [210.0, 220.0, 230.0, 240.0, 250.0, 260.0, 270.0, 280.0],
        ],
        markerCount: 3,
        processingTime: 25.5,
        success: true,
      );
      
      // Serialize to map
      final map = originalResult.toMap();
      
      // Deserialize from map
      final deserializedResult = ArucoDetectionResult.fromMap(map);
      
      // Verify data integrity
      expect(deserializedResult.success, equals(originalResult.success));
      expect(deserializedResult.markerCount, equals(originalResult.markerCount));
      expect(deserializedResult.markerIds, equals(originalResult.markerIds));
      expect(deserializedResult.markerCorners, equals(originalResult.markerCorners));
      expect(deserializedResult.processingTime, equals(originalResult.processingTime));
    });
    
    test('Detection statistics tracking', () {
      const testMarkerId = 8;
      
      final markerImage = ArucoTestingUtils.generateTestMarker(
        markerId: testMarkerId,
        sizePixels: 200,
      );
      
      expect(markerImage, isNotNull);
      expect(detector.initialize(), isTrue);
      
      // Get initial statistics
      final initialStats = detector.getStatistics();
      expect(initialStats['totalDetections'], equals(0));
      expect(initialStats['successfulDetections'], equals(0));
      
      // Perform some detections
      const numDetections = 5;
      for (int i = 0; i < numDetections; i++) {
        final result = detector.detectMarkers(markerImage!);
        expect(result.success, isTrue);
      }
      
      // Check updated statistics
      final finalStats = detector.getStatistics();
      expect(finalStats['totalDetections'], equals(numDetections));
      expect(finalStats['successfulDetections'], equals(numDetections));
      expect(finalStats['successRate'], equals(1.0));
      expect(finalStats['averageProcessingTime'], greaterThan(0.0));
      
      markerImage!.dispose();
    });
  });
}