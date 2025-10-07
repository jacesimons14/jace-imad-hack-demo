import 'dart:typed_data';

import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'package:vector_math/vector_math_64.dart' as vm;

/// Holds the 6-DoF pose returned from the ArUco detector.
class Pose {
  Pose({required this.rvec, required this.tvec});

  /// Factory constructor from OpenCV Vec3d
  factory Pose.fromVec3d(cv.Vec3d rvec, cv.Vec3d tvec) {
    return Pose(
      rvec: vm.Vector3(rvec.val1, rvec.val2, rvec.val3),
      tvec: vm.Vector3(tvec.val1, tvec.val2, tvec.val3),
    );
  }

  /// Rodrigues rotation vector (length 3, radians).
  final vm.Vector3 rvec;

  /// Translation vector (length 3, in metres).
  final vm.Vector3 tvec;

  /// Flat list of 6 floats for platform channels.
  Float32List toFloat32List() => Float32List.fromList([
        rvec.x,
        rvec.y,
        rvec.z,
        tvec.x,
        tvec.y,
        tvec.z,
      ]);

  /// Converts the Rodrigues vector into a quaternion for AR anchors.
  vm.Quaternion toQuaternion() {
    final angle = rvec.length;
    if (angle == 0) return vm.Quaternion.identity();
    final axis = rvec.normalized();
    return vm.Quaternion.axisAngle(axis, angle);
  }
}
