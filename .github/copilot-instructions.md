# AI Coding Agent Instructions

## Project Overview
This is a minimal Flutter AR camera application with ArUco marker detection capabilities. The app opens directly to a full-screen camera feed and is designed for AR experiences across web, iOS, and Android platforms.

## Architecture & Structure

### Core Dependencies
- **camera**: Web/mobile camera access with live preview
- **ar_flutter_plugin**: AR functionality for marker detection
- **opencv_dart**: Computer vision processing for ArUco markers
- **vector_math**: 3D math operations for pose calculations
- **flutter_localizations**: Built-in internationalization

### Source Organization
```
lib/src/
├── app.dart              # Minimal app config, camera-first routing
├── aruco/                # ArUco marker detection & pose calculation
├── localization/         # i18n with generated classes
├── camera/               # Camera service, controller & full-screen view
└── settings/             # Theme & user preferences with controller pattern
```

## Key Patterns & Conventions

### Camera-First Architecture
- **Default Route**: Camera view opens directly on app launch (`/`)
- **Full-Screen Experience**: No app bar, camera fills entire viewport
- **Minimal UI**: Settings accessible via overlay button, camera switching via floating button
- **Cross-Platform**: Configured for web, iOS, and Android camera access

### State Management Pattern
- Uses **Controller + Service** pattern (see `CameraViewController` + `CameraService`)
- Controllers extend `ChangeNotifier` and use `ListenableBuilder` for reactivity
- Services handle hardware access/async operations, controllers manage state
- Camera controller includes disposal protection and lifecycle management

### ArUco Integration Specifics
- **Pose calculations**: `lib/src/aruco/pose.dart` defines 6-DoF pose data structure
- Rodrigues rotation vectors converted to quaternions for AR frameworks
- Platform channel communication uses `Float32List.fromList()` for efficient data transfer
- Always use `vm.Vector3` from vector_math package for 3D coordinates

### Platform Configuration
- **iOS**: Camera permissions in `ios/Runner/Info.plist` with ARKit support
- **Android**: Camera permissions in `android/app/src/main/AndroidManifest.xml`
- **Web**: Direct camera access via browser APIs, no additional config needed

## Development Workflow

### Essential Commands
```bash
# Clean build (use when dependencies change)
flutter clean && flutter pub get

# Web development with specific port
flutter run -d chrome --web-port=8081

# iOS testing (requires Xcode)
flutter run -d ios

# Android testing (requires Android Studio/emulator)
flutter run -d android

# Analysis and formatting
flutter analyze
dart format .
```

### Build Targets
- **Web**: Primary development target, direct browser camera access
- **iOS**: Full ArKit integration, camera permissions pre-configured
- **Android**: Camera and AR permissions configured in manifest

### Code Quality
- Uses `package:flutter_lints/flutter.yaml` for standard Flutter linting
- Camera controller includes disposal protection to prevent lifecycle errors
- Minimal UI reduces complexity and focuses on AR experience

## Integration Points

### Camera Integration
- **Direct Launch**: App opens immediately to camera feed
- **Full-Screen Preview**: Camera preview fills entire screen with minimal overlay
- **Error Handling**: Graceful fallbacks for permission denied or hardware issues
- **Multi-Camera Support**: Automatic camera switching if multiple cameras available

### AR Overlay Foundation
- Camera preview positioned for AR content overlay
- Coordinate system ready for ArUco pose projection
- Minimal UI interference with AR visualization space

### Asset Management
- Minimal assets required - focus on camera and AR functionality
- Flutter logo placeholder can be replaced with AR markers or brand assets
- Asset registration in pubspec.yaml under `flutter.assets`

## Common Gotchas
- Camera permissions must be granted on first launch (automatic prompts)
- iOS requires device testing for camera functionality (simulator has no camera)
- Android emulator camera may not work - use physical device for testing
- Web requires HTTPS in production for camera access
- Camera controller disposal protection prevents hot reload errors


## General Steps and Phases for Project Completion

## 🧠 Real-Time ArUco Marker Detection & AR Overlay in Flutter

Implementing a real-time **ArUco marker detector** and **AR overlay** in Flutter combines Dart-based AR rendering with C++ computer vision logic via **Dart’s Foreign Function Interface (FFI)**.

---

### 🧩 Implementation Overview


| **Phase** | **Component / Tool** | **Description** | **Core Task** |
|------------|----------------------|------------------|----------------|
| **I. Setup** | Flutter SDK, `pubspec.yaml` | Add dependencies for AR rendering (`ar_flutter_plugin` or similar) and computer vision (`opencv_dart`). | Initialize the project and configure native permissions (`CAMERA`, `ARCore`/`ARKit`). |
| **II. Camera Feed** | `ARView` Widget | Embed an AR view that accesses the live camera stream within your Flutter widget tree. | Capture raw camera frames at a high frame rate. |
| **III. CV Processing** | `opencv_dart` + Isolates | Use `opencv_dart` bindings to access C++ OpenCV from Dart. | Convert raw image data to a `cv::Mat` and process frames in a background `Isolate` to avoid UI lag. |
| **IV. Marker Detection** | `cv::aruco::ArucoDetector` | Detect ArUco markers in the processed image. | Identify marker corners and unique IDs (`ids`, `corners`). |
| **V. Pose Estimation** | `cv::aruco::estimatePoseSingleMarkers` | Compute the camera’s transformation matrix (pose) relative to the marker. | Determine 6-DoF pose (`rvec` = rotation, `tvec` = translation) using camera calibration data. |
| **VI. AR Rendering** | `ARSessionManager` | Send calculated pose data (`rvec`, `tvec`) back to the main UI thread. | Place an `ARAnchor` at the marker’s position and attach your 3D model (`.gltf` / `.glb`). |
| **VII. Synchronization** | State Management (e.g., Provider, Riverpod) | Continuously update object position and orientation based on new pose data. | Maintain real-time alignment between virtual and physical objects. |

---

### ⚙️ Key Technical Challenges

1. **Performance & Frame Rate**
   - OpenCV operations are computationally heavy.
   - Run detection and pose estimation **in a background isolate** to prevent UI freezing and maintain frame rate.

2. **Image Data Transfer**
   - Efficiently move raw camera buffers (e.g., `RGBA` or `YUV`) from the AR plugin to OpenCV.
   - Minimize data copying — it’s the main source of latency.

3. **Camera Calibration**
   - Pose estimation requires accurate **intrinsic camera parameters** (focal length, principal point) and **distortion coefficients**.
   - Calibrate your camera using OpenCV (e.g., with a chessboard pattern) and **embed those values** in your Dart code before running `estimatePoseSingleMarkers`.

---

### ✅ Summary

Flutter’s **Dart FFI** and **opencv_dart** package enable high-performance C++ vision algorithms within a modern cross-platform UI.  
With proper optimization and camera calibration, this architecture supports **real-time AR marker tracking** and **precise overlay alignment** in Flutter.