import 'dart:isolate';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

class ArucoProcessorResult {
  final bool success;
  final int markersDetected;
  final String? error;
  final double processingTimeMs;

  ArucoProcessorResult({
    required this.success,
    this.markersDetected = 0,
    this.error,
    required this.processingTimeMs,
  });
}

class ArucoProcessor {
  bool _isInitialized = false;
  Isolate? _processingIsolate;
  ReceivePort? _receivePort;
  SendPort? _sendPort;

  bool get isInitialized => _isInitialized;

  ArucoProcessor() {
    _initializeOpenCV();
  }

  Future<void> _initializeOpenCV() async {
    try {
      // Test basic OpenCV functionality
      final testMat = cv.Mat.zeros(100, 100, cv.MatType.CV_8UC3);
      final success = testMat.rows == 100 && testMat.cols == 100;
      
      if (success) {
        print('✅ OpenCV initialization successful');
        print('✅ Test matrix created: ${testMat.rows}x${testMat.cols}');
        
        // Test ArUco dictionary creation
        final dictionary = cv.getPredefinedDictionary(cv.PredefinedDictionaryType.DICT_6X6_250);
        print('✅ ArUco dictionary loaded with ${dictionary.bytesList.length} markers');
        
        _isInitialized = true;
      } else {
        print('❌ OpenCV initialization failed');
      }
      
      testMat.dispose();
    } catch (e) {
      print('❌ OpenCV error during initialization: $e');
    }
  }

  Future<ArucoProcessorResult> processFrame(CameraImage image) async {
    if (!_isInitialized) {
      return ArucoProcessorResult(
        success: false,
        error: 'OpenCV not initialized',
        processingTimeMs: 0,
      );
    }

    final startTime = DateTime.now();

    try {
      // Convert CameraImage to OpenCV Mat
      final mat = await _convertCameraImageToMat(image);
      
      // Detect ArUco markers
      final result = await _detectMarkers(mat);
      
      final endTime = DateTime.now();
      final processingTime = endTime.difference(startTime).inMilliseconds.toDouble();
      
      mat.dispose();
      
      return ArucoProcessorResult(
        success: true,
        markersDetected: result,
        processingTimeMs: processingTime,
      );
      
    } catch (e) {
      final endTime = DateTime.now();
      final processingTime = endTime.difference(startTime).inMilliseconds.toDouble();
      
      return ArucoProcessorResult(
        success: false,
        error: e.toString(),
        processingTimeMs: processingTime,
      );
    }
  }

  Future<cv.Mat> _convertCameraImageToMat(CameraImage image) async {
    try {
      // Handle different image formats
      if (image.format.group == ImageFormatGroup.yuv420) {
        // Convert YUV420 to RGB
        final yPlane = image.planes[0];
        final uPlane = image.planes[1];
        final vPlane = image.planes[2];
        
        // Create a simple grayscale mat from Y plane for now
        final yData = yPlane.bytes;
        final mat = cv.Mat.fromBytes(
          rows: image.height,
          cols: image.width,
          type: cv.MatType.CV_8UC1,
          bytes: yData,
        );
        
        print('✅ Converted YUV420 image: ${image.width}x${image.height}');
        return mat;
        
      } else if (image.format.group == ImageFormatGroup.bgra8888) {
        // Convert BGRA to grayscale
        final bytes = image.planes[0].bytes;
        final bgraMat = cv.Mat.fromBytes(
          rows: image.height,
          cols: image.width,
          type: cv.MatType.CV_8UC4,
          bytes: bytes,
        );
        
        final grayMat = cv.Mat.empty();
        cv.cvtColor(bgraMat, grayMat, cv.ColorConversionCodes.COLOR_BGRA2GRAY);
        
        bgraMat.dispose();
        print('✅ Converted BGRA image: ${image.width}x${image.height}');
        return grayMat;
        
      } else {
        throw Exception('Unsupported image format: ${image.format.group}');
      }
    } catch (e) {
      print('❌ Image conversion error: $e');
      rethrow;
    }
  }

  Future<int> _detectMarkers(cv.Mat grayMat) async {
    try {
      final dictionary = cv.getPredefinedDictionary(cv.PredefinedDictionaryType.DICT_6X6_250);
      final detector = cv.ArucoDetector.create(dictionary);
      
      final corners = <cv.VecPoint2f>[];
      final ids = <int>[];
      final rejectedCandidates = <cv.VecPoint2f>[];
      
      detector.detectMarkers(grayMat, corners, ids, rejectedCandidates);
      
      final markersFound = ids.length;
      print('🎯 ArUco detection: ${markersFound} markers found');
      
      if (markersFound > 0) {
        print('📍 Marker IDs: $ids');
      }
      
      // Cleanup
      for (final corner in corners) {
        corner.dispose();
      }
      for (final candidate in rejectedCandidates) {
        candidate.dispose();
      }
      detector.dispose();
      dictionary.dispose();
      
      return markersFound;
      
    } catch (e) {
      print('❌ ArUco detection error: $e');
      rethrow;
    }
  }

  void dispose() {
    _processingIsolate?.kill();
    _receivePort?.close();
  }
}
