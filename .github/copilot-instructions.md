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