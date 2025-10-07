# Quick Start Guide

## Getting Your ArUco AR App Running

### Step 1: Install Dependencies

```bash
flutter pub get
```

### Step 2: Check for Errors

```bash
flutter analyze
```

You'll see errors - that's expected! They're documented in `API_FIXES_NEEDED.md`.

### Step 3: Test Camera (Should Work)

```bash
flutter run
```

When the app launches:

1. Select "Camera Only" from the menu
2. Grant camera permission
3. You should see camera preview

✅ If this works, your basic setup is good!

### Step 4: Test ArUco Detection (May Have Errors)

Before running:

1. Print ArUco markers from: https://chev.me/arucogen/
   - Select: DICT_4X4_50
   - IDs: 0, 1, 2
   - Size: 10cm

From main menu, select "ArUco Detection"

- If it works: You'll see marker overlays
- If it errors: Check `API_FIXES_NEEDED.md` for fixes

### Step 5: Fix OpenCV APIs (If Needed)

The most likely errors are in:

- `lib/src/aruco/aruco_detector.dart`
- `lib/src/aruco/aruco_processor.dart`

Common fixes:

```dart
// If Mat.fromList doesn't work, try:
final imageMat = cv.Mat.create(rows: height, cols: width, type: cv.MatType.CV_8UC4);

// If estimatePoseSingleMarkers isn't found, try:
final result = cv.aruco.estimatePoseSingleMarkers(...);
```

Check the actual `opencv_dart` docs:
https://pub.dev/packages/opencv_dart

### Step 6: Test AR Mode (Requires Device)

From main menu, select "Full AR Mode"

- **Note:** Won't work in emulator
- Requires ARCore (Android) or ARKit (iOS) device

## Troubleshooting

### "Camera permission denied"

Add to `AndroidManifest.xml` or `Info.plist` (see IMPLEMENTATION_NOTES.md)

### "No cameras found"

Use a physical device (not emulator)

### "OpenCV function not found"

Check `API_FIXES_NEEDED.md` for the specific function

### App crashes on ArUco detection

Most likely OpenCV API mismatch - see fixes above

### AR view shows black screen

1. Check device has ARCore/ARKit
2. Grant AR permissions
3. Use physical device, not emulator

## Directory Structure

```
lib/src/
  ├── camera/       ← Basic camera (should work)
  ├── aruco/        ← Detection (may need API fixes)
  └── ar/           ← AR rendering (needs device)
```

## Testing Strategy

1. ✅ **Camera Only** - Test first (easiest)
2. ⚠️ **ArUco Detection** - Test second (may need fixes)
3. 🎯 **Full AR** - Test last (needs device + fixes)

## Quick Fixes for Common Issues

### Mat.fromBytes Error

```dart
// OLD (may not work):
final mat = cv.Mat.fromBytes(height, width, type, data);

// TRY:
final mat = cv.Mat.fromList(height, width, type, data);
```

### estimatePoseSingleMarkers Error

```dart
// OLD (may not work):
cv.estimatePoseSingleMarkers(...)

// TRY:
cv.aruco.estimatePoseSingleMarkers(...)
```

### VecI32 Access Error

```dart
// OLD (may not work):
for (int i = 0; i < ids.rows; i++) {
  final id = ids.at<int>(i, 0);
}

// TRY:
for (int i = 0; i < ids.length; i++) {
  final id = ids[i];
}
```

## Need More Help?

1. Read `API_FIXES_NEEDED.md` - Detailed solutions
2. Read `IMPLEMENTATION_NOTES.md` - Architecture details
3. Check `SUMMARY.md` - What's been implemented
4. Visit package docs:
   - https://pub.dev/packages/opencv_dart
   - https://pub.dev/packages/ar_flutter_plugin

## Expected Behavior (When Working)

**Camera Only:**

- Smooth camera preview
- FPS display
- Camera switch button

**ArUco Detection:**

- Real-time marker detection
- Green boxes around markers
- Marker ID and distance shown
- 10-30 FPS typical

**Full AR:**

- 3D models appear on markers
- Models track with marker movement
- Model selector to change 3D objects

## Success Indicators

✅ Camera feed displays smoothly
✅ Markers are detected (green overlays)
✅ FPS stays above 15
✅ 3D models appear on markers (AR mode)
✅ Models track marker movement

## Performance Tips

If detection is slow:

1. Use smaller camera resolution
2. Increase frame skip (change `% 3` to `% 5` in `aruco_camera_view.dart`)
3. Use simpler 3D models
4. Ensure good lighting

## Next Steps After It Works

1. Calibrate camera properly (see IMPLEMENTATION_NOTES.md)
2. Add your own 3D models
3. Customize marker dictionary/size
4. Add more AR features
5. Optimize for your specific use case

Good luck! 🚀
