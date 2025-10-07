# Architecture Diagram

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                          Flutter App                             │
│                                                                   │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                        Main Menu                           │  │
│  │  [Camera Only] [ArUco Detection] [Full AR Mode]           │  │
│  └───────────────────────────────────────────────────────────┘  │
│                              │                                    │
│        ┌─────────────────────┼─────────────────────┐            │
│        │                     │                     │            │
│        ▼                     ▼                     ▼            │
│  ┌──────────┐         ┌──────────┐         ┌──────────┐        │
│  │  Camera  │         │  ArUco   │         │   Full   │        │
│  │   View   │         │  Camera  │         │  AR View │        │
│  │          │         │   View   │         │          │        │
│  └──────────┘         └──────────┘         └──────────┘        │
│       │                     │                     │             │
│       └─────────┬───────────┴──────────┬──────────┘             │
│                 │                      │                        │
│                 ▼                      ▼                        │
│       ┌─────────────────┐    ┌─────────────────┐              │
│       │     Camera      │    │      AR         │              │
│       │   Controller    │    │   Controller    │              │
│       └─────────────────┘    └─────────────────┘              │
│                 │                      │                        │
│                 ▼                      ▼                        │
│       ┌─────────────────┐    ┌─────────────────┐              │
│       │     Camera      │    │   AR Session    │              │
│       │    Service      │    │    Manager      │              │
│       └─────────────────┘    └─────────────────┘              │
└─────────────────────────────────────────────────────────────────┘
```

## ArUco Detection Pipeline

```
┌─────────────────────────────────────────────────────────────────┐
│                     Main Thread (UI)                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Camera Frame                                                     │
│      │                                                            │
│      ▼                                                            │
│  Format Conversion (YUV420/BGRA → RGBA)                         │
│      │                                                            │
│      ▼                                                            │
│  Frame Skipping (Every 3rd frame)                                │
│      │                                                            │
│      ▼                                                            │
│  Send to Isolate via SendPort                                    │
│      │                                                            │
│      ├──────────────────────────────────────────────────────────┤
│      │         Isolate Boundary (Background Thread)              │
│      ├──────────────────────────────────────────────────────────┤
│      │                                                            │
│      ▼                                                            │
│  ┌────────────────────────────────────────────┐                 │
│  │     Background Isolate Processing          │                 │
│  │                                             │                 │
│  │  1. Receive Image Data                     │                 │
│  │  2. Create OpenCV Mat                      │                 │
│  │  3. Convert RGBA → BGR                     │                 │
│  │  4. Detect ArUco Markers                   │                 │
│  │     ├─ Find corners                        │                 │
│  │     └─ Get marker IDs                      │                 │
│  │  5. Estimate Pose (if markers found)       │                 │
│  │     ├─ Calculate rvec (rotation)           │                 │
│  │     └─ Calculate tvec (translation)        │                 │
│  │  6. Clean up OpenCV resources              │                 │
│  │  7. Send results back via SendPort         │                 │
│  │                                             │                 │
│  └────────────────────────────────────────────┘                 │
│      │                                                            │
│      ▼                                                            │
│  Receive Results via Stream                                      │
│      │                                                            │
│      ▼                                                            │
│  Update UI State (via setState)                                  │
│      │                                                            │
│      ▼                                                            │
│  Draw Marker Overlays / Update AR Anchors                        │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow

```
┌──────────────┐
│   Camera     │
│   Hardware   │
└──────┬───────┘
       │ Raw frames (30-60 FPS)
       ▼
┌──────────────┐
│   Camera     │
│   Plugin     │ (package:camera)
└──────┬───────┘
       │ CameraImage (YUV420/BGRA)
       ▼
┌──────────────┐
│   Format     │
│  Converter   │ (aruco_camera_view.dart)
└──────┬───────┘
       │ RGBA Uint8List
       ▼
┌──────────────┐
│    Frame     │
│   Skipper    │ (Process every 3rd)
└──────┬───────┘
       │ Selected frames
       ▼
┌──────────────┐
│   SendPort   │
│  (Isolate)   │
└──────┬───────┘
       │
       ▼
┌──────────────────────────┐
│   Background Isolate     │
│                          │
│  ┌────────────────────┐  │
│  │  OpenCV Processing │  │
│  │                    │  │
│  │  • Mat creation    │  │
│  │  • Color convert   │  │
│  │  • Detect markers  │  │
│  │  • Estimate pose   │  │
│  │                    │  │
│  └────────────────────┘  │
│                          │
└──────┬───────────────────┘
       │ Map<int, Pose>
       ▼
┌──────────────┐
│  ReceivePort │
│   (Stream)   │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│  Controller  │
│   (State)    │
└──────┬───────┘
       │
       ├───────────┬─────────────┐
       │           │             │
       ▼           ▼             ▼
  ┌────────┐  ┌────────┐   ┌────────┐
  │  UI    │  │   AR   │   │  3D    │
  │Overlay │  │Anchors │   │ Models │
  └────────┘  └────────┘   └────────┘
```

## State Management

```
┌─────────────────────────────────────────────────────────────┐
│                    ChangeNotifier Pattern                    │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────────────────────────────────────────┐  │
│  │            CameraViewController                       │  │
│  │  (extends ChangeNotifier)                            │  │
│  │                                                       │  │
│  │  State:                                              │  │
│  │  • _cameraController: CameraController?             │  │
│  │  • _errorMessage: String?                           │  │
│  │  • _isLoading: bool                                 │  │
│  │  • _isInitialized: bool                             │  │
│  │                                                       │  │
│  │  Methods:                                            │  │
│  │  • initializeCamera()                               │  │
│  │  • switchCamera()                                   │  │
│  │  • dispose()                                        │  │
│  │  • notifyListeners() → Updates UI                  │  │
│  │                                                       │  │
│  └──────────────────────────────────────────────────────┘  │
│                            │                                 │
│                            ▼                                 │
│  ┌──────────────────────────────────────────────────────┐  │
│  │               ListenableBuilder                       │  │
│  │  (Automatically rebuilds on notifyListeners)         │  │
│  │                                                       │  │
│  │  • Wraps UI widgets                                  │  │
│  │  • Listens to controller                            │  │
│  │  • Rebuilds on state changes                        │  │
│  │                                                       │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                               │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              ArucoProcessor                           │  │
│  │  (Stream-based)                                      │  │
│  │                                                       │  │
│  │  State:                                              │  │
│  │  • _isolate: Isolate?                               │  │
│  │  • _resultController: StreamController              │  │
│  │                                                       │  │
│  │  Stream:                                             │  │
│  │  • markerStream: Stream<Map<int, Pose>>            │  │
│  │                                                       │  │
│  │  Methods:                                            │  │
│  │  • initialize()                                     │  │
│  │  • processFrame() → Non-blocking                   │  │
│  │  • dispose()                                        │  │
│  │                                                       │  │
│  └──────────────────────────────────────────────────────┘  │
│                            │                                 │
│                            ▼                                 │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              StreamBuilder / listen()                 │  │
│  │  (Reacts to stream events)                           │  │
│  │                                                       │  │
│  │  • Receives marker detection results                │  │
│  │  • Updates UI or AR anchors                         │  │
│  │                                                       │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

## File Organization

```
lib/
├── main.dart
│   └── Initializes all controllers
│       ├── CameraViewController
│       ├── ARController
│       └── ArucoProcessor
│
├── src/
│   ├── app.dart
│   │   └── App-level routing and MaterialApp configuration
│   │
│   ├── camera/                    [Layer 1: Camera Access]
│   │   ├── camera_service.dart   → Hardware access
│   │   ├── camera_controller.dart → State management
│   │   └── camera_view.dart      → UI (basic preview)
│   │
│   ├── aruco/                     [Layer 2: Computer Vision]
│   │   ├── aruco_detector.dart   → OpenCV detector service
│   │   ├── aruco_processor.dart  → Isolate processor
│   │   ├── aruco_camera_view.dart → UI (with detection)
│   │   ├── camera_calibration.dart → Calibration params
│   │   └── pose.dart             → 6-DoF data structure
│   │
│   ├── ar/                        [Layer 3: AR Rendering]
│   │   ├── ar_controller.dart    → AR session management
│   │   ├── ar_view.dart          → UI (full AR)
│   │   └── model_manager.dart    → 3D models
│   │
│   └── settings/                  [Shared]
│       ├── settings_controller.dart
│       ├── settings_service.dart
│       └── settings_view.dart
```

## Technology Stack

```
┌──────────────────────────────────────────────────────────┐
│                     Flutter Framework                     │
├──────────────────────────────────────────────────────────┤
│                                                            │
│  UI Layer                                                 │
│  ├── Material Design widgets                             │
│  ├── ListenableBuilder (reactive UI)                     │
│  └── CustomPainter (marker overlays)                     │
│                                                            │
│  State Management                                         │
│  ├── ChangeNotifier (controllers)                        │
│  ├── StreamController (isolate results)                  │
│  └── setState (local state)                              │
│                                                            │
│  Concurrency                                              │
│  ├── Dart Isolates (background processing)              │
│  ├── SendPort/ReceivePort (isolate communication)        │
│  └── async/await (async operations)                      │
│                                                            │
├──────────────────────────────────────────────────────────┤
│                   Platform Plugins                        │
├──────────────────────────────────────────────────────────┤
│                                                            │
│  camera: ^0.10.6                                          │
│  └── Platform channels → Native camera APIs              │
│                                                            │
│  opencv_dart: ^1.4.3                                      │
│  └── FFI → OpenCV C++ library                            │
│      ├── ArUco detection                                 │
│      ├── Pose estimation                                 │
│      └── Image processing                                │
│                                                            │
│  ar_flutter_plugin: ^0.7.3                                │
│  └── Platform channels → ARCore/ARKit                    │
│      ├── AR session management                           │
│      ├── Anchor placement                                │
│      └── 3D rendering                                    │
│                                                            │
│  vector_math: ^2.1.4                                      │
│  └── 3D mathematics                                       │
│      ├── Matrix transformations                          │
│      ├── Quaternions                                     │
│      └── Vector operations                               │
│                                                            │
└──────────────────────────────────────────────────────────┘
```

## Performance Considerations

```
┌────────────────────────────────────────────────────────┐
│              Performance Optimizations                  │
├────────────────────────────────────────────────────────┤
│                                                          │
│  1. Background Processing                               │
│     ✓ CPU-intensive OpenCV runs in isolate            │
│     ✓ Main thread stays responsive                     │
│     ✓ UI updates smoothly                              │
│                                                          │
│  2. Frame Skipping                                      │
│     ✓ Process every 3rd frame (20 FPS → 6-7 FPS)      │
│     ✓ Reduces computational load                       │
│     ✓ Still smooth for AR tracking                     │
│                                                          │
│  3. Efficient Memory Management                         │
│     ✓ OpenCV Mats properly disposed                    │
│     ✓ Isolate cleaned up on dispose                    │
│     ✓ Camera controller lifecycle managed              │
│                                                          │
│  4. Smart State Updates                                 │
│     ✓ Only notify when state actually changes          │
│     ✓ Stream-based updates prevent blocking            │
│     ✓ ListenableBuilder for granular rebuilds          │
│                                                          │
│  5. Image Format Optimization                           │
│     ✓ Minimal conversion (YUV → RGBA → BGR)           │
│     ✓ Direct pixel manipulation                        │
│     ✓ No unnecessary copies                            │
│                                                          │
└────────────────────────────────────────────────────────┘
```

## Integration Points

```
Flutter App
    │
    ├─► Camera Plugin
    │   ├─► Android: Camera2 API
    │   └─► iOS: AVFoundation
    │
    ├─► OpenCV Dart (FFI)
    │   ├─► OpenCV C++ library
    │   ├─► ArUco module
    │   └─► Calibration module
    │
    ├─► AR Flutter Plugin
    │   ├─► Android: ARCore SDK
    │   └─► iOS: ARKit Framework
    │
    └─► Vector Math
        └─► Pure Dart (3D math)
```

This architecture provides a clean, maintainable, and performant foundation for ArUco marker detection and AR rendering in Flutter!
