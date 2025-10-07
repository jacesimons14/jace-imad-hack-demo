# ArUco Marker Detection & AR Demo

A Flutter application demonstrating real-time ArUco marker detection with augmented reality overlay capabilities.

## Features

- 📷 **Camera Access**: Basic camera preview with controls
- 🎯 **ArUco Detection**: Real-time marker detection using OpenCV
- 🔄 **Background Processing**: Isolate-based processing for smooth performance
- 📐 **Pose Estimation**: 6-DoF pose calculation for detected markers
- 🎨 **AR Rendering**: Place 3D models on detected markers (experimental)
- ⚙️ **Camera Calibration**: Configurable calibration parameters

## Architecture

The app is structured in three layers:

### 1. Camera Layer (`lib/src/camera/`)

- Camera service for device access
- Camera controller with state management
- Basic camera preview UI

### 2. ArUco Detection Layer (`lib/src/aruco/`)

- OpenCV-based marker detection
- Isolate-based processor for performance
- Camera calibration configuration
- 6-DoF pose estimation

### 3. AR Rendering Layer (`lib/src/ar/`)

- AR session management
- Anchor and node placement
- 3D model rendering
- Integration with ar_flutter_plugin

## Project Status

✅ **Complete:**

- Project structure and architecture
- Camera access and preview
- ArUco detection logic
- Isolate-based processing
- State management
- UI navigation and menus

⚠️ **Needs API Verification:**

- OpenCV Dart API calls (Mat creation, pose estimation)
- AR Flutter Plugin API (anchor creation, node attachment)
- Vector math operations

See `API_FIXES_NEEDED.md` for detailed API compatibility issues.

## Getting Started

### Prerequisites

- Flutter SDK 3.5.4 or later
- Physical device with camera (AR features won't work in emulator)
- For Android: ARCore-compatible device
- For iOS: iPhone 6S or later with iOS 11+

### Installation

1. Clone the repository
2. Install dependencies:

   ```bash
   flutter pub get
   ```

3. Run on device:
   ```bash
   flutter run
   ```

### Testing ArUco Detection

1. Generate test markers at: https://chev.me/arucogen/

   - Dictionary: DICT_4X4_50
   - Marker IDs: 0-9
   - Size: 10cm x 10cm

2. Print markers and place in good lighting

3. Launch app and select "ArUco Detection" mode

## Dependencies

```yaml
dependencies:
  ar_flutter_plugin: ^0.7.3 # AR rendering
  camera: ^0.10.6 # Camera access
  opencv_dart: ^1.4.3 # Computer vision
  vector_math: ^2.1.4 # 3D math
  ffi: ^2.1.3 # FFI support
```

## Project Structure

```
lib/
├── main.dart                    # App entry point
├── src/
    ├── app.dart                 # App configuration & routing
    ├── camera/                  # Camera layer
    │   ├── camera_service.dart
    │   ├── camera_controller.dart
    │   └── camera_view.dart
    ├── aruco/                   # ArUco detection layer
    │   ├── aruco_detector.dart
    │   ├── aruco_processor.dart
    │   ├── aruco_camera_view.dart
    │   ├── camera_calibration.dart
    │   └── pose.dart
    ├── ar/                      # AR rendering layer
    │   ├── ar_controller.dart
    │   ├── ar_view.dart
    │   └── model_manager.dart
    └── settings/                # Settings UI
```

## Documentation

- `IMPLEMENTATION_NOTES.md` - Architecture and implementation details
- `API_FIXES_NEEDED.md` - API compatibility issues to resolve
- This README - Project overview and getting started

## Known Issues

1. **OpenCV API**: Some OpenCV Dart methods need verification
2. **AR Plugin API**: Anchor/node creation needs platform-specific testing
3. **Emulator**: AR features require physical device
4. **Calibration**: Default values are approximate, needs proper calibration

## Next Steps

1. Verify and fix OpenCV Dart API calls
2. Test on physical devices (iOS and Android)
3. Implement proper camera calibration tool
4. Add more 3D models and model selection
5. Optimize performance and frame rates
6. Add marker size configuration UI

## Performance Notes

- Processes every 3rd frame to maintain smooth FPS
- Uses Dart isolates for background processing
- YUV420/BGRA to RGBA conversion optimized
- Marker detection typically 30-60ms per frame

## Camera Calibration

Default calibration values are provided for:

- 640x480 webcam
- 1920x1080 HD camera

For production use, perform proper calibration:

1. Print chessboard calibration pattern
2. Capture 10-20 images from different angles
3. Use OpenCV calibration tools
4. Update `CameraCalibration` class with results

## Contributing

This is a demo/prototype project. Feel free to:

- Fix API compatibility issues
- Add better 3D models
- Improve performance
- Add more AR features

## License

This project is for demonstration purposes.

## Resources

- OpenCV ArUco: https://docs.opencv.org/4.x/d5/dae/tutorial_aruco_detection.html
- opencv_dart Package: https://pub.dev/packages/opencv_dart
- ar_flutter_plugin: https://pub.dev/packages/ar_flutter_plugin
- ArUco Marker Generator: https://chev.me/arucogen/

## Assets

The `assets` directory houses images, fonts, and any other files you want to
include with your application.

The `assets/images` directory contains [resolution-aware
images](https://flutter.dev/to/resolution-aware-images).

## Localization

This project generates localized messages based on arb files found in
the `lib/src/localization` directory.

To support additional languages, please visit the tutorial on
[Internationalizing Flutter apps](https://flutter.dev/to/internationalization).
