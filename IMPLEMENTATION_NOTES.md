# ArUco Marker Detection & AR Implementation Notes

This document outlines the implementation of real-time ArUco marker detection and AR overlay in Flutter.

## Architecture Overview

The implementation follows a layered architecture:

1. **Camera Layer** (`lib/src/camera/`)

   - `camera_service.dart`: Low-level camera access
   - `camera_controller.dart`: State management for camera
   - `camera_view.dart`: Basic camera preview UI

2. **ArUco Detection Layer** (`lib/src/aruco/`)

   - `aruco_detector.dart`: OpenCV-based marker detection service
   - `aruco_processor.dart`: Isolate-based processor for performance
   - `aruco_camera_view.dart`: Camera view with marker detection overlay
   - `camera_calibration.dart`: Camera calibration parameters
   - `pose.dart`: 6-DoF pose data structure

3. **AR Rendering Layer** (`lib/src/ar/`)
   - `ar_controller.dart`: AR session and anchor management
   - `ar_view.dart`: Full AR view with 3D object rendering
   - `model_manager.dart`: 3D model asset management

## Key Components

### ArUco Detection Pipeline

```
Camera Frame → Isolate Processing → OpenCV Detection → Pose Estimation → UI Update
```

**Performance Optimizations:**

- Background isolate for CPU-intensive OpenCV operations
- Frame skipping (process every 3rd frame)
- Efficient image format conversion (YUV420/BGRA to RGBA)

### Camera Calibration

Camera calibration is critical for accurate pose estimation. The system provides:

- Default calibration for common resolutions (640x480, 1920x1080)
- Scaling support for different resolutions
- Custom calibration parameter support

**Calibration Matrix Format:**

```
[fx,  0, cx]
[ 0, fy, cy]
[ 0,  0,  1]
```

Where:

- `fx`, `fy`: Focal lengths in pixels
- `cx`, `cy`: Principal point (image center)

**Distortion Coefficients:** `[k1, k2, p1, p2, k3]`

### Pose Estimation

Each detected ArUco marker yields a 6-DoF pose:

- **rvec**: Rodrigues rotation vector (3 values)
- **tvec**: Translation vector in meters (3 values)

The rotation vector is converted to a quaternion for AR rendering:

```dart
angle = ||rvec||
axis = rvec / ||rvec||
quaternion = Quaternion.axisAngle(axis, angle)
```

## Known Issues & Limitations

### OpenCV Dart API Compatibility

The current implementation uses `opencv_dart: ^1.4.3`, which has some API differences from standard OpenCV:

1. **Mat.fromBytes** - May need to use alternative constructors
2. **estimatePoseSingleMarkers** - Function name/signature may differ
3. **Vector access** - `.at<T>()` methods and `.rows` properties may vary

**Solutions:**

- Check the actual `opencv_dart` API documentation on pub.dev
- May need to use `Mat.create()` or `Mat.fromPtr()` instead
- Consider using the `flutter_aruco_detector` package as an alternative
- Test with physical devices as emulators may not support AR

### AR Flutter Plugin Compatibility

The `ar_flutter_plugin: ^0.7.3` has platform-specific limitations:

1. **ARCore (Android):** Requires ARCore-compatible device
2. **ARKit (iOS):** Requires iOS 11+ and A9+ processor
3. **Web/Desktop:** Limited or no support

**API Differences:**

- Some methods like `pause()`/`resume()` may not exist
- Anchor types (`ARPlaneAnchor`, `ARAnchor`) may differ
- Node attachment methods may vary

## Testing Strategy

### Phase 1: Camera Only

Test basic camera access and preview:

```dart
Navigator.pushNamed(context, CameraView.routeName);
```

### Phase 2: ArUco Detection

Test marker detection without AR:

```dart
Navigator.pushNamed(context, ArucoCameraView.routeName);
```

**Test Markers:**

- Use DICT_4X4_50 dictionary
- Print markers at 10cm x 10cm size
- Generate markers at: https://chev.me/arucogen/

### Phase 3: Full AR

Test with 3D model rendering:

```dart
Navigator.pushNamed(context, ARMarkerView.routeName);
```

## Platform-Specific Setup

### Android

Add permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" />
<uses-feature android:name="android.hardware.camera.ar" android:required="true" />
```

### iOS

Add permissions to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required for AR marker detection</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Location access may be required for AR features</string>
```

## Next Steps

1. **Fix OpenCV API Compatibility**

   - Review `opencv_dart` documentation
   - Update Mat creation and ArUco detection calls
   - Test on real devices

2. **Fix AR Plugin Compatibility**

   - Review `ar_flutter_plugin` API
   - Update anchor and node creation
   - Implement proper lifecycle management

3. **Implement Camera Calibration Tool**

   - Add chessboard pattern detection
   - Compute calibration parameters
   - Save/load calibration data

4. **Add 3D Model Assets**

   - Include sample GLB files in assets
   - Test model loading and rendering
   - Add model selection UI

5. **Performance Tuning**

   - Profile frame processing time
   - Optimize image conversion
   - Adjust frame skip rate

6. **Testing on Physical Devices**
   - Test on Android with ARCore
   - Test on iOS with ARKit
   - Verify marker detection accuracy

## Alternative Approaches

If the current implementation has too many compatibility issues:

1. **Use flutter_aruco_detector Package**

   - Pre-built ArUco detection
   - May have better OpenCV integration
   - Less customizable

2. **Native Platform Channels**

   - Write native code for iOS/Android
   - Direct OpenCV integration
   - More complex but more reliable

3. **Web-based Alternative**
   - Use ar.js for web-based AR
   - Flutter web with JS interop
   - Limited to web platform

## References

- OpenCV ArUco Documentation: https://docs.opencv.org/4.x/d5/dae/tutorial_aruco_detection.html
- opencv_dart Package: https://pub.dev/packages/opencv_dart
- ar_flutter_plugin: https://pub.dev/packages/ar_flutter_plugin
- ArUco Marker Generator: https://chev.me/arucogen/
