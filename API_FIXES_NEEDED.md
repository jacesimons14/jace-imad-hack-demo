# API Fixes Needed

This file documents the API compatibility issues that need to be resolved before the ArUco detection system can be compiled and run.

## Critical Issues to Fix

### 1. OpenCV Dart API (`opencv_dart: ^1.4.3`)

#### Issue 1.1: Mat.fromBytes / Mat.fromList

**Files:** `lib/src/aruco/aruco_detector.dart`, `lib/src/aruco/aruco_processor.dart`

**Problem:** The correct method to create a Mat from byte data is unclear.

**Potential Solutions:**

```dart
// Option A: Use Mat.fromList (if it accepts Uint8List)
final imageMat = cv.Mat.fromList(height, width, cv.MatType.CV_8UC4, imageData);

// Option B: Create empty Mat and copy data
final imageMat = cv.Mat.create(rows: height, cols: width, type: cv.MatType.CV_8UC4);
// Then copy imageData into imageMat

// Option C: Use imdecode for encoded images
final imageMat = cv.imdecode(imageData, cv.IMREAD_COLOR);
```

**Action Required:**

- Check `opencv_dart` package documentation on pub.dev
- Test different Mat creation methods
- Update both files with working approach

#### Issue 1.2: estimatePoseSingleMarkers Function

**Files:** `lib/src/aruco/aruco_detector.dart`, `lib/src/aruco/aruco_processor.dart`

**Problem:** Function may be in different namespace or have different name.

**Potential Solutions:**

```dart
// Option A: Under aruco namespace
final (rvecs, tvecs, objPoints) = cv.aruco.estimatePoseSingleMarkers(...);

// Option B: Direct function
final (rvecs, tvecs, objPoints) = cv.estimatePoseSingleMarkers(...);

// Option C: Different return format
final result = cv.aruco.estimatePoseSingleMarkers(...);
final rvecs = result.rvecs;
final tvecs = result.tvecs;
```

**Action Required:**

- Check opencv_dart ArUco module documentation
- Find correct function name and namespace
- Update return value handling if needed

#### Issue 1.3: VecI32 Access Methods

**Files:** `lib/src/aruco/aruco_detector.dart`, `lib/src/aruco/aruco_processor.dart`

**Problem:** `ids` might be `VecI32` which doesn't have `.rows` or `.at<T>()` methods.

**Potential Solutions:**

```dart
// Option A: Use length and index
for (int i = 0; i < ids.length; i++) {
  final markerId = ids[i];
}

// Option B: Convert to list
final idList = ids.toList();
for (int i = 0; i < idList.length; i++) {
  final markerId = idList[i];
}

// Option C: Use iterator
for (final markerId in ids) {
  // process markerId
}
```

**Action Required:**

- Check VecI32 API in opencv_dart
- Update accessor code in both files

#### Issue 1.4: Mat Access for rvecs/tvecs

**Files:** `lib/src/aruco/aruco_processor.dart`

**Problem:** Accessing rotation/translation vector values.

**Current Code:**

```dart
final rx = rvecs.at<double>(i, 0);
```

**Potential Solutions:**

```dart
// Option A: Direct accessor
final rx = rvecs.at<double>(i, 0);

// Option B: Convert to list
final rvecList = rvecs.toList();
final rx = rvecList[i * 3 + 0];

// Option C: Get row/col
final rx = rvecs.atVec<double>(i)[0];
```

**Action Required:**

- Test Mat data access methods
- Update vector extraction code

### 2. AR Flutter Plugin API (`ar_flutter_plugin: ^0.7.3`)

#### Issue 2.1: ARPlaneAnchor Class

**File:** `lib/src/ar/ar_controller.dart`

**Problem:** `ARPlaneAnchor` may not be the correct class or may not accept transformation matrix.

**Potential Solutions:**

```dart
// Option A: Use platform-specific anchor creation
if (Platform.isIOS) {
  // Use ARKit anchor
} else if (Platform.isAndroid) {
  // Use ARCore anchor
}

// Option B: Create anchor at world position
final anchor = await _arAnchorManager!.addAnchor(
  position: translation,
  rotation: quaternion,
);

// Option C: Use provided anchor factory methods
final anchor = _arAnchorManager!.createAnchor(
  worldTransform: transformation,
);
```

**Action Required:**

- Check ar_flutter_plugin documentation
- Find correct anchor creation method
- May need platform-specific code

#### Issue 2.2: ARNode.addNode Return Type

**File:** `lib/src/ar/ar_controller.dart`

**Problem:** `addNode()` may return `bool` instead of `ARNode`.

**Current Code:**

```dart
final addedNode = await _arObjectManager!.addNode(node, planeAnchor: anchor);
if (addedNode != null) {
  _nodes[markerId] = addedNode;
}
```

**Fix:**

```dart
final success = await _arObjectManager!.addNode(node, planeAnchor: anchor);
if (success == true) {
  _nodes[markerId] = node; // Store the node we created
}
```

**Action Required:**

- Check ARObjectManager.addNode() signature
- Update code to handle boolean return value

#### Issue 2.3: ARSessionManager pause/resume

**File:** `lib/src/ar/ar_controller.dart`

**Problem:** `pause()` and `resume()` methods may not exist.

**Potential Solutions:**

```dart
// Option A: Comment out if not available
// await _arSessionManager!.pause();

// Option B: Use onPause/onResume
_arSessionManager!.onPause();
_arSessionManager!.onResume();

// Option C: Platform-specific lifecycle
if (Platform.isIOS) {
  // ARKit specific
} else if (Platform.isAndroid) {
  // ARCore specific
}
```

**Action Required:**

- Check ARSessionManager API
- Remove or replace pause/resume calls

#### Issue 2.4: vector_math Quaternion API

**File:** `lib/src/ar/ar_controller.dart`

**Problem:** `copyRotationTo()` method may not exist.

**Current Code:**

```dart
quaternion.copyRotationTo(rotationMatrix);
```

**Fix:**

```dart
// Option A: Use copyInto
quaternion.copyInto(rotationMatrix);

// Option B: Get rotation matrix directly
final rotationMatrix = quaternion.asRotationMatrix();

// Option C: Set from quaternion
final transformation = vm.Matrix4.identity();
transformation.setFromTranslationRotation(translation, quaternion);
```

**Action Required:**

- Check vector_math Quaternion API
- Use correct method to convert quaternion to matrix

#### Issue 2.5: ARHitTestResult Type

**File:** `lib/src/ar/ar_view.dart`

**Problem:** `ARHitTestResult` may not be defined or have different name.

**Current Code:**

```dart
_arSessionManager!.onPlaneOrPointTap = (List<ARHitTestResult> hits) {
  // Not used
};
```

**Fix:**

```dart
// Option A: Use dynamic
_arSessionManager!.onPlaneOrPointTap = (List<dynamic> hits) {
  // Not used
};

// Option B: Comment out if not needed
// We don't use tap detection for marker-based AR
```

**Action Required:**

- Check if tap handling is needed
- Remove or fix type if necessary

## Quick Fix Strategy

### Phase 1: Comment Out Problematic Code

1. Comment out all AR rendering code in `ar_controller.dart` and `ar_view.dart`
2. Focus on getting ArUco detection working first
3. Test with `ArucoCameraView` only

### Phase 2: Fix OpenCV API

1. Create a simple test to find correct Mat creation method
2. Update both detector files with working API
3. Test marker detection with printedmarkers

### Phase 3: Fix AR Integration

1. Review ar_flutter_plugin examples on GitHub
2. Update anchor and node creation code
3. Test on physical device (AR won't work in emulator)

## Testing Commands

```bash
# Check for compilation errors
flutter analyze

# Run on device (AR requires physical device)
flutter run -d <device-id>

# Generate ArUco markers for testing
# Visit: https://chev.me/arucogen/
# Select: DICT_4X4_50, IDs 0-9, Size: 10cm
```

## Alternative: Simpler Implementation

If the API issues are too complex, consider:

1. **Use flutter_aruco_detector package**

   ```yaml
   dependencies:
     flutter_aruco_detector: ^1.0.0
   ```

   This package handles OpenCV integration for you.

2. **Skip AR rendering initially**

   - Get marker detection working first
   - Show detection results as overlay
   - Add AR later when API is clarified

3. **Use native platform channels**
   - Write Kotlin/Java for Android
   - Write Swift/Objective-C for iOS
   - More work but more control

## Recommended Next Steps

1. **Install and test on physical device**

   - iOS: iPhone 6S or later with iOS 11+
   - Android: Device with ARCore support

2. **Start with camera-only mode**

   ```dart
   Navigator.pushNamed(context, CameraView.routeName);
   ```

3. **Test ArUco detection mode (may have errors)**

   ```dart
   Navigator.pushNamed(context, ArucoCameraView.routeName);
   ```

4. **Skip AR mode until APIs are fixed**

   - Comment out AR view from menu
   - Focus on detection accuracy

5. **Consult package documentation**
   - opencv_dart: https://pub.dev/packages/opencv_dart
   - ar_flutter_plugin: https://pub.dev/packages/ar_flutter_plugin
   - Check example projects on GitHub

## Summary

The implementation is structurally sound but needs API compatibility fixes. The core architecture (isolates for performance, separation of concerns, proper state management) is correct. Once the specific API calls are corrected based on the actual package documentation, the system should work as designed.

Priority: Fix OpenCV API issues first, as marker detection is the foundation for everything else.
