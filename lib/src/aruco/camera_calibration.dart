/// Camera calibration parameters for ArUco pose estimation.
///
/// These parameters are essential for accurate 6-DoF pose estimation.
/// Values should be obtained through a proper camera calibration process
/// using a chessboard pattern and OpenCV's calibration tools.
class CameraCalibration {
  const CameraCalibration({
    required this.fx,
    required this.fy,
    required this.cx,
    required this.cy,
    this.k1 = 0.0,
    this.k2 = 0.0,
    this.p1 = 0.0,
    this.p2 = 0.0,
    this.k3 = 0.0,
  });

  /// Focal length in x-direction (pixels)
  final double fx;

  /// Focal length in y-direction (pixels)
  final double fy;

  /// Principal point x-coordinate (pixels)
  final double cx;

  /// Principal point y-coordinate (pixels)
  final double cy;

  /// Radial distortion coefficient k1
  final double k1;

  /// Radial distortion coefficient k2
  final double k2;

  /// Tangential distortion coefficient p1
  final double p1;

  /// Tangential distortion coefficient p2
  final double p2;

  /// Radial distortion coefficient k3
  final double k3;

  /// Returns the camera intrinsic matrix as a flat list (row-major).
  ///
  /// Format:
  /// [fx,  0, cx]
  /// [ 0, fy, cy]
  /// [ 0,  0,  1]
  List<double> get cameraMatrix => [
        fx,
        0.0,
        cx,
        0.0,
        fy,
        cy,
        0.0,
        0.0,
        1.0,
      ];

  /// Returns the distortion coefficients as a list.
  ///
  /// Format: [k1, k2, p1, p2, k3]
  List<double> get distortionCoefficients => [k1, k2, p1, p2, k3];

  /// Creates a default calibration for a typical 640x480 webcam.
  ///
  /// These are approximate values and should be replaced with actual
  /// calibration data for production use.
  factory CameraCalibration.defaultWebcam640x480() {
    return const CameraCalibration(
      fx: 800.0, // Approximate focal length
      fy: 800.0, // Assume square pixels
      cx: 320.0, // Center of 640x480 image
      cy: 240.0,
      k1: 0.0, // Assume zero distortion (or pre-corrected)
      k2: 0.0,
      p1: 0.0,
      p2: 0.0,
      k3: 0.0,
    );
  }

  /// Creates a default calibration for a typical 1920x1080 camera.
  factory CameraCalibration.defaultFullHD() {
    return const CameraCalibration(
      fx: 1500.0, // Scaled focal length for higher resolution
      fy: 1500.0,
      cx: 960.0, // Center of 1920x1080 image
      cy: 540.0,
      k1: 0.0,
      k2: 0.0,
      p1: 0.0,
      p2: 0.0,
      k3: 0.0,
    );
  }

  /// Creates a calibration from measured camera parameters.
  factory CameraCalibration.fromMeasurements({
    required double focalLengthMM,
    required double sensorWidthMM,
    required double sensorHeightMM,
    required int imageWidth,
    required int imageHeight,
    double k1 = 0.0,
    double k2 = 0.0,
    double p1 = 0.0,
    double p2 = 0.0,
    double k3 = 0.0,
  }) {
    // Convert focal length from mm to pixels
    final fx = (focalLengthMM * imageWidth) / sensorWidthMM;
    final fy = (focalLengthMM * imageHeight) / sensorHeightMM;

    return CameraCalibration(
      fx: fx,
      fy: fy,
      cx: imageWidth / 2.0,
      cy: imageHeight / 2.0,
      k1: k1,
      k2: k2,
      p1: p1,
      p2: p2,
      k3: k3,
    );
  }

  /// Creates a scaled version of this calibration for a different resolution.
  CameraCalibration scaleForResolution({
    required int originalWidth,
    required int originalHeight,
    required int newWidth,
    required int newHeight,
  }) {
    final scaleX = newWidth / originalWidth;
    final scaleY = newHeight / originalHeight;

    return CameraCalibration(
      fx: fx * scaleX,
      fy: fy * scaleY,
      cx: cx * scaleX,
      cy: cy * scaleY,
      k1: k1,
      k2: k2,
      p1: p1,
      p2: p2,
      k3: k3,
    );
  }

  @override
  String toString() {
    return 'CameraCalibration(fx: $fx, fy: $fy, cx: $cx, cy: $cy, '
        'k1: $k1, k2: $k2, p1: $p1, p2: $p2, k3: $k3)';
  }
}
