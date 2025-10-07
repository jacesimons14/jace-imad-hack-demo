import 'package:flutter_test/flutter_test.dart';
import 'package:jace_imad_hack_demo/src/aruco/frame_processing_service.dart';
import 'package:jace_imad_hack_demo/src/camera/camera_service.dart';
import 'package:jace_imad_hack_demo/src/camera/camera_controller.dart';

void main() {
  group('Phase III CV Processing Tests', () {
    late FrameProcessingService frameProcessingService;
    late CameraService cameraService;
    late CameraViewController cameraController;

    setUp(() {
      frameProcessingService = FrameProcessingService();
      cameraService = CameraService();
      cameraController = CameraViewController(cameraService, frameProcessingService);
    });

    tearDown(() async {
      await frameProcessingService.dispose();
      await cameraService.dispose();
      await cameraController.dispose();
    });

    test('FrameProcessingService initializes correctly', () async {
      expect(frameProcessingService.isInitialized, false);
      
      // Initialize the service
      await frameProcessingService.initialize();
      
      expect(frameProcessingService.isInitialized, true);
      expect(frameProcessingService.isProcessing, false);
    });

    test('FrameProcessingService handles start/stop processing', () async {
      await frameProcessingService.initialize();
      
      // Start processing
      frameProcessingService.startProcessing();
      expect(frameProcessingService.isProcessing, true);
      
      // Stop processing
      frameProcessingService.stopProcessing();
      expect(frameProcessingService.isProcessing, false);
    });

    test('Performance metrics are properly initialized', () {
      final metrics = frameProcessingService.currentMetrics;
      
      expect(metrics.processedFrameCount, 0);
      expect(metrics.averageProcessingTime, 0.0);
      expect(metrics.currentQueueSize, 0);
      expect(metrics.skippedFrameCount, 0);
      expect(metrics.recentProcessingTimes, isEmpty);
    });

    test('Performance metrics calculate efficiency correctly', () {
      final metrics = PerformanceMetrics(
        processedFrameCount: 80,
        averageProcessingTime: 25.0,
        currentQueueSize: 1,
        skippedFrameCount: 20,
        recentProcessingTimes: [20, 25, 30, 25],
      );
      
      expect(metrics.processingEfficiency, 80.0); // 80 processed out of 100 total
      expect(metrics.estimatedFps, closeTo(40.0, 5.0)); // 25ms avg = ~40 FPS
    });

    test('CameraViewController integrates frame processing correctly', () {
      expect(cameraController.isFrameProcessingEnabled, false);
      expect(cameraController.isFrameProcessingInitialized, false);
      
      // Should have access to streams
      expect(cameraController.processedFrameStream, isNotNull);
      expect(cameraController.performanceStream, isNotNull);
    });

    test('FrameProcessingService disposes cleanly', () async {
      await frameProcessingService.initialize();
      frameProcessingService.startProcessing();
      
      expect(frameProcessingService.isInitialized, true);
      expect(frameProcessingService.isProcessing, true);
      
      await frameProcessingService.dispose();
      
      expect(frameProcessingService.isInitialized, false);
      expect(frameProcessingService.isProcessing, false);
    });
  });
}