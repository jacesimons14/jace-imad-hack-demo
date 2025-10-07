import 'dart:typed_data';

/// Platform-agnostic interface for OpenCV operations.
/// Provides a common interface that can be implemented differently
/// for web and mobile platforms.
abstract class PlatformOpenCV {
  /// Creates a Mat from bytes.
  PlatformMat createMatFromBytes(int height, int width, MatType type, Uint8List data);
  
  /// Creates an empty Mat.
  PlatformMat createEmptyMat();
  
  /// Creates a zero-filled Mat.
  PlatformMat createZeroMat(int height, int width, MatType type);
  
  /// Converts color space.
  PlatformMat cvtColor(PlatformMat src, ColorConversion code);
  
  /// Applies blur.
  PlatformMat blur(PlatformMat src, Size kernelSize);
  
  /// Applies histogram equalization.
  PlatformMat equalizeHist(PlatformMat src);
  
  /// Clones a Mat.
  PlatformMat cloneMat(PlatformMat src);
}

/// Platform-agnostic Mat representation.
abstract class PlatformMat {
  int get rows;
  int get cols;
  int get channels;
  MatType get type;
  
  /// Disposes the Mat and frees memory.
  void dispose();
  
  /// Gets the raw data as bytes.
  Uint8List get data;
}

/// Mat types supported across platforms.
enum MatType {
  CV_8UC1,
  CV_8UC3,
  CV_8UC4,
  CV_16UC1,
  CV_16UC3,
  CV_16UC4,
  CV_32FC1,
  CV_32FC3,
  CV_32FC4,
}

/// Color conversion codes.
enum ColorConversion {
  COLOR_RGBA2BGR,
  COLOR_BGR2GRAY,
  COLOR_GRAY2RGBA,
  COLOR_BGR2RGBA,
}

/// Size representation.
class Size {
  final int width;
  final int height;
  
  const Size(this.width, this.height);
  
  @override
  String toString() => 'Size($width, $height)';
}