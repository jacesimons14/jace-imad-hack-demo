import 'dart:typed_data';

import 'package:opencv_dart/opencv_dart.dart' as cv;

import 'pose.dart';

/// Service that handles ArUco marker detection using OpenCV.
///
/// This service processes camera frames to detect ArUco markers and estimate
/// their 6-DoF pose relative to the camera.
class ArucoDetectorService {
  cv.ArucoDetector? _detector;
  cv.Mat? _cameraMatrix;
  cv.Mat? _distCoeffs;
  bool _isInitialized = false;

  /// Returns true if the detector has been initialized.
  bool get isInitialized => _isInitialized;

  /// Initializes the ArUco detector with camera calibration parameters.
  ///
  /// [cameraMatrix] should be a 3x3 matrix containing:
  ///   [fx,  0, cx]
  ///   [ 0, fy, cy]
  ///   [ 0,  0,  1]
  /// where (fx, fy) are focal lengths and (cx, cy) is the principal point.
  ///
  /// [distCoeffs] should contain distortion coefficients (typically 5 values).
  ///
  /// If not provided, default calibration values will be used (less accurate).
  Future<void> initialize({
    List<double>? cameraMatrix,
    List<double>? distCoeffs,
  }) async {
    try {
      // Use DICT_4X4_50 dictionary (50 markers of 4x4 bits)
      final dictionary = cv.ArucoDictionary.predefined(
          cv.PredefinedDictionaryType.DICT_4X4_50);

      // Create detector with default parameters
      final detectorParams = cv.ArucoDetectorParameters.empty();
      _detector = cv.ArucoDetector.create(dictionary, detectorParams);

      // Set up camera matrix
      if (cameraMatrix != null && cameraMatrix.length == 9) {
        _cameraMatrix = cv.Mat.fromList(
          3,
          3,
          cv.MatType.CV_64FC1,
          cameraMatrix,
        );
      } else {
        // Default camera matrix for a typical webcam (approximate)
        // These values should be replaced with actual calibration data
        _cameraMatrix = cv.Mat.fromList(
          3,
          3,
          cv.MatType.CV_64FC1,
          [
            800.0, 0.0, 320.0, // fx, 0, cx
            0.0, 800.0, 240.0, // 0, fy, cy
            0.0, 0.0, 1.0, // 0, 0, 1
          ],
        );
      }

      // Set up distortion coefficients
      if (distCoeffs != null && distCoeffs.isNotEmpty) {
        _distCoeffs = cv.Mat.fromList(
          1,
          distCoeffs.length,
          cv.MatType.CV_64FC1,
          distCoeffs,
        );
      } else {
        // Zero distortion (assumes undistorted camera or pre-corrected frames)
        _distCoeffs = cv.Mat.zeros(1, 5, cv.MatType.CV_64FC1);
      }

      _isInitialized = true;
    } catch (e) {
      _isInitialized = false;
      rethrow;
    }
  }

  /// Detects ArUco markers in the provided image data.
  ///
  /// [imageData] should be raw RGBA8888 or RGB888 pixel data.
  /// [width] and [height] specify the image dimensions.
  /// [markerSize] is the physical size of the marker in meters.
  ///
  /// Returns a map of marker IDs to their corresponding poses.
  Future<Map<int, Pose>> detectMarkers({
    required Uint8List imageData,
    required int width,
    required int height,
    double markerSize = 0.1, // 10cm default marker size
  }) async {
    if (!_isInitialized || _detector == null) {
      throw StateError('ArucoDetectorService not initialized');
    }

    try {
      // Convert image data to OpenCV Mat
      // Assuming RGBA8888 format (4 channels)
      // NOTE: The API for Mat creation may differ. Alternative approaches:
      // 1. cv.Mat.create(height, width, cv.MatType.CV_8UC4) + manual data copy
      // 2. Use cv.imdecode() if image data is encoded
      // 3. Check opencv_dart documentation for correct constructor
      final imageMat = cv.Mat.fromList(
        height,
        width,
        cv.MatType.CV_8UC4,
        imageData,
      );

      // Convert RGBA to BGR (OpenCV's default format)
      final bgrMat = cv.cvtColor(imageMat, cv.COLOR_RGBA2BGR);

      // Detect markers
      final (corners, ids, rejected) = _detector!.detectMarkers(bgrMat);

      // If no markers detected, return empty map
      if (ids.isEmpty) {
        // Clean up
        imageMat.dispose();
        bgrMat.dispose();
        corners.dispose();
        ids.dispose();
        rejected.dispose();
        return {};
      }

      // Estimate pose for each detected marker
      // NOTE: Function name and signature may differ in opencv_dart
      // Alternative: cv.aruco.estimatePoseSingleMarkers or cv.estimatePoseSingleMarkers
      // Check opencv_dart API documentation for correct function name
      final (rvecs, tvecs, objPoints) = cv.aruco.estimatePoseSingleMarkers(
        corners,
        markerSize,
        _cameraMatrix!,
        _distCoeffs!,
      );

      // Build result map
      final Map<int, Pose> detectedMarkers = {};
      // NOTE: Vector access may differ - ids might be VecI32 instead of Mat
      // May need to use ids.length and ids[i] instead of ids.rows and ids.at()
      for (int i = 0; i < ids.length; i++) {
        final markerId = ids[i];

        // Extract rotation and translation vectors
        final rvec = cv.Vec3d(
          rvecs.at<double>(i, 0),
          rvecs.at<double>(i, 1),
          rvecs.at<double>(i, 2),
        );
        final tvec = cv.Vec3d(
          tvecs.at<double>(i, 0),
          tvecs.at<double>(i, 1),
          tvecs.at<double>(i, 2),
        );

        detectedMarkers[markerId] = Pose(
          rvec: cv.Vec3d(rvec.val1, rvec.val2, rvec.val3) as dynamic,
          tvec: cv.Vec3d(tvec.val1, tvec.val2, tvec.val3) as dynamic,
        );
      }

      // Clean up
      imageMat.dispose();
      bgrMat.dispose();
      corners.dispose();
      ids.dispose();
      rejected.dispose();
      rvecs.dispose();
      tvecs.dispose();
      objPoints.dispose();

      return detectedMarkers;
    } catch (e) {
      // Log error and return empty map
      print('Error detecting markers: $e');
      return {};
    }
  }

  /// Disposes of resources used by the detector.
  void dispose() {
    _detector?.dispose();
    _cameraMatrix?.dispose();
    _distCoeffs?.dispose();
    _detector = null;
    _cameraMatrix = null;
    _distCoeffs = null;
    _isInitialized = false;
  }
}
