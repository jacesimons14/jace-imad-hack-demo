import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart' as vm;

/// Holds the 6-DoF pose returned from the native ArUco detector.
class Pose {
  Pose({required this.rvec, required this.tvec});

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
