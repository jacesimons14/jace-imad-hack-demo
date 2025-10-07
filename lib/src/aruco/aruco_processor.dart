import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:opencv_dart/opencv_dart.dart' as cv;

import 'pose.dart';

/// Message to send to the isolate for processing.
class _ProcessingMessage {
  _ProcessingMessage({
    required this.imageData,
    required this.width,
    required this.height,
    required this.markerSize,
    required this.cameraMatrix,
    required this.distCoeffs,
  });

  final Uint8List imageData;
  final int width;
  final int height;
  final double markerSize;
  final List<double> cameraMatrix;
  final List<double> distCoeffs;
}

/// Result from the isolate processing.
class _ProcessingResult {
  _ProcessingResult({
    required this.markers,
    this.error,
  });

  final Map<int, Pose> markers;
  final String? error;
}

/// High-performance ArUco marker processor using isolates.
///
/// This processor offloads heavy OpenCV computations to a background isolate
/// to prevent blocking the main UI thread and maintain smooth frame rates.
class ArucoProcessor {
  Isolate? _isolate;
  SendPort? _sendPort;
  ReceivePort? _receivePort;
  StreamController<Map<int, Pose>>? _resultController;
  bool _isInitialized = false;
  bool _isDisposed = false;

  List<double> _cameraMatrix = [
    800.0, 0.0, 320.0, // fx, 0, cx
    0.0, 800.0, 240.0, // 0, fy, cy
    0.0, 0.0, 1.0, // 0, 0, 1
  ];
  List<double> _distCoeffs = [0.0, 0.0, 0.0, 0.0, 0.0];

  /// Stream of detected markers (map of marker ID to Pose).
  Stream<Map<int, Pose>> get markerStream =>
      _resultController?.stream ?? const Stream.empty();

  /// Returns true if the processor has been initialized.
  bool get isInitialized => _isInitialized;

  /// Initializes the processor and spawns the background isolate.
  ///
  /// [cameraMatrix] should be a 9-element list representing a 3x3 matrix.
  /// [distCoeffs] should contain distortion coefficients (typically 5 values).
  Future<void> initialize({
    List<double>? cameraMatrix,
    List<double>? distCoeffs,
  }) async {
    if (_isInitialized || _isDisposed) return;

    if (cameraMatrix != null && cameraMatrix.length == 9) {
      _cameraMatrix = cameraMatrix;
    }
    if (distCoeffs != null && distCoeffs.length >= 5) {
      _distCoeffs = distCoeffs;
    }

    try {
      _receivePort = ReceivePort();
      _resultController = StreamController<Map<int, Pose>>.broadcast();

      // Spawn the isolate
      _isolate = await Isolate.spawn(
        _isolateEntry,
        _receivePort!.sendPort,
      );

      // Wait for the isolate to send back its SendPort
      final completer = Completer<SendPort>();
      _receivePort!.listen((message) {
        if (message is SendPort) {
          completer.complete(message);
        } else if (message is _ProcessingResult) {
          if (message.error != null) {
            print('Isolate processing error: ${message.error}');
          }
          if (!_isDisposed) {
            _resultController?.add(message.markers);
          }
        }
      });

      _sendPort = await completer.future;
      _isInitialized = true;
    } catch (e) {
      print('Failed to initialize ArucoProcessor: $e');
      _isInitialized = false;
      await dispose();
      rethrow;
    }
  }

  /// Processes a frame to detect ArUco markers.
  ///
  /// This is non-blocking and will emit results through [markerStream].
  void processFrame({
    required Uint8List imageData,
    required int width,
    required int height,
    double markerSize = 0.1,
  }) {
    if (!_isInitialized || _sendPort == null || _isDisposed) {
      return;
    }

    final message = _ProcessingMessage(
      imageData: imageData,
      width: width,
      height: height,
      markerSize: markerSize,
      cameraMatrix: _cameraMatrix,
      distCoeffs: _distCoeffs,
    );

    _sendPort!.send(message);
  }

  /// Disposes the processor and terminates the isolate.
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
    _receivePort?.close();
    _receivePort = null;
    await _resultController?.close();
    _resultController = null;
    _isInitialized = false;
  }

  /// Entry point for the background isolate.
  static void _isolateEntry(SendPort mainSendPort) {
    final receivePort = ReceivePort();
    mainSendPort.send(receivePort.sendPort);

    cv.ArucoDetector? detector;
    cv.Mat? cameraMatrix;
    cv.Mat? distCoeffs;

    receivePort.listen((message) {
      if (message is _ProcessingMessage) {
        try {
          // Initialize detector if needed
          if (detector == null) {
            final dictionary = cv.ArucoDictionary.predefined(
              cv.PredefinedDictionaryType.DICT_4X4_50,
            );
            final detectorParams = cv.ArucoDetectorParameters.empty();
            detector = cv.ArucoDetector.create(dictionary, detectorParams);

            cameraMatrix = cv.Mat.fromList(
              3,
              3,
              cv.MatType.CV_64FC1,
              message.cameraMatrix,
            );
            distCoeffs = cv.Mat.fromList(
              1,
              message.distCoeffs.length,
              cv.MatType.CV_64FC1,
              message.distCoeffs,
            );
          }

          // Process the frame
          final result = _detectMarkersInIsolate(
            detector: detector!,
            cameraMatrix: cameraMatrix!,
            distCoeffs: distCoeffs!,
            imageData: message.imageData,
            width: message.width,
            height: message.height,
            markerSize: message.markerSize,
          );

          mainSendPort.send(result);
        } catch (e) {
          mainSendPort.send(_ProcessingResult(
            markers: {},
            error: e.toString(),
          ));
        }
      }
    });
  }

  /// Performs marker detection in the isolate.
  static _ProcessingResult _detectMarkersInIsolate({
    required cv.ArucoDetector detector,
    required cv.Mat cameraMatrix,
    required cv.Mat distCoeffs,
    required Uint8List imageData,
    required int width,
    required int height,
    required double markerSize,
  }) {
    cv.Mat? imageMat;
    cv.Mat? bgrMat;
    cv.VecMat? corners;
    cv.Mat? ids;
    cv.VecMat? rejected;
    cv.Mat? rvecs;
    cv.Mat? tvecs;
    cv.VecPoint3f? objPoints;

    try {
      // Convert image data to OpenCV Mat (RGBA8888 format)
      // NOTE: API may differ - see aruco_detector.dart for alternatives
      imageMat = cv.Mat.fromList(
        height,
        width,
        cv.MatType.CV_8UC4,
        imageData,
      );

      // Convert RGBA to BGR
      bgrMat = cv.cvtColor(imageMat, cv.COLOR_RGBA2BGR);

      // Detect markers
      final detectionResult = detector.detectMarkers(bgrMat);
      corners = detectionResult.$1;
      ids = detectionResult.$2;
      rejected = detectionResult.$3;

      // If no markers detected, return empty map
      if (ids == null || ids.length == 0) {
        return _ProcessingResult(markers: {});
      }

      // Estimate pose for each detected marker
      // NOTE: API may differ - check opencv_dart documentation
      final poseResult = cv.aruco.estimatePoseSingleMarkers(
        corners!,
        markerSize,
        cameraMatrix,
        distCoeffs,
      );
      rvecs = poseResult.$1;
      tvecs = poseResult.$2;
      objPoints = poseResult.$3;

      // Build result map
      final Map<int, Pose> detectedMarkers = {};
      // NOTE: Vector access - using length and index instead of rows/at
      for (int i = 0; i < ids.length; i++) {
        final markerId = ids[i];

        // Extract rotation and translation vectors
        final rx = rvecs.at<double>(i, 0);
        final ry = rvecs.at<double>(i, 1);
        final rz = rvecs.at<double>(i, 2);
        final tx = tvecs.at<double>(i, 0);
        final ty = tvecs.at<double>(i, 1);
        final tz = tvecs.at<double>(i, 2);

        detectedMarkers[markerId] = Pose.fromVec3d(
          cv.Vec3d(rx, ry, rz),
          cv.Vec3d(tx, ty, tz),
        );
      }

      return _ProcessingResult(markers: detectedMarkers);
    } catch (e) {
      return _ProcessingResult(
        markers: {},
        error: 'Detection error: $e',
      );
    } finally {
      // Clean up OpenCV resources
      imageMat?.dispose();
      bgrMat?.dispose();
      corners?.dispose();
      ids?.dispose();
      rejected?.dispose();
      rvecs?.dispose();
      tvecs?.dispose();
      objPoints?.dispose();
    }
  }
}
