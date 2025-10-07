# ArUco Detection Debugging Guide

## 🔍 Critical Fix Applied

**Problem:** The Mat was being created but actual camera frame data wasn't being copied into it.

**Solution:** Changed from `cv.Mat.create()` (creates empty structure) to `cv.Mat.fromList()` (creates Mat with actual pixel data).

### Key Changes:

#### Before (BROKEN):
```dart
final mat = cv.Mat.create(
  rows: request.height,
  cols: request.width,
  type: cv.MatType.CV_8UC4,
);
// Data never copied! Mat is empty!
```

#### After (FIXED):
```dart
final mat = cv.Mat.fromList(
  request.height,
  request.width,
  cv.MatType.CV_8UC4,
  request.frameData.toList(), // Actually use the frame bytes!
);
```

## 📊 What to Look For in Console

### 1. Successful Initialization
```
OpenCVIsolateWorker: Isolate started
OpenCVIsolateWorker: OpenCV and ArUco initialized
ArucoDetector: Initializing with dictionary and parameters
ArucoDetector: Initialization successful
```

### 2. Frame Processing
```
OpenCVIsolateWorker: Converting frame 1920x1080, 8294400 bytes
OpenCVIsolateWorker: Mat created successfully: 1920x1080, channels: 4
```

### 3. Preprocessing Pipeline
```
OpenCVIsolateWorker: Starting preprocessing pipeline
OpenCVIsolateWorker: Converted to BGR
OpenCVIsolateWorker: Converted to grayscale  
OpenCVIsolateWorker: Applied blur
OpenCVIsolateWorker: Applied histogram equalization
OpenCVIsolateWorker: Preprocessing pipeline completed
```

### 4. ArUco Detection (SUCCESS)
```
ArucoDetector: Detected 1 markers: [0]
CameraViewController: ✓ DETECTED 1 ArUco markers!
CameraViewController: Marker IDs: [0]
```

### 5. ArUco Detection (NO MARKERS)
```
// No detection logs - this is normal when no markers visible
```

## 🚨 Error Scenarios

### ERROR 1: Mat Creation Failed
```
OpenCVIsolateWorker: Failed to convert to Mat with fromList: ...
OpenCVIsolateWorker: Trying alternative Mat creation...
```
**Cause:** Frame data format incompatible with Mat.fromList()  
**Solution:** Check frame format (should be RGBA/BGRA)

### ERROR 2: Detection Not Initializing
```
OpenCVIsolateWorker: Failed to initialize ArUco detector
```
**Cause:** OpenCV ArUco module not properly loaded  
**Solution:** Verify opencv_dart installation

### ERROR 3: Preprocessing Failures
```
OpenCVIsolateWorker: BGR conversion failed: ...
OpenCVIsolateWorker: Grayscale conversion failed: ...
```
**Cause:** Empty or invalid Mat  
**Solution:** Check Mat creation step

### ERROR 4: No Detection Results
```
// Processing happens but no detection logs
```
**Possible Causes:**
1. Marker not in view
2. Marker too small/far
3. Marker type mismatch (using wrong dictionary)
4. Poor lighting
5. Mat has no actual data (our previous bug!)

## 🧪 Testing Steps

### Step 1: Verify Frame Processing is Active
1. Open app
2. Look for **eye icon** (👁️) in top-right
3. Tap to enable - should turn **green**
4. Check console for: `FrameProcessingService: Started processing`

### Step 2: Verify OpenCV Initialization
Look for console logs:
```
OpenCVIsolateWorker: Isolate started
OpenCVIsolateWorker: OpenCV and ArUco initialized
ArucoDetector: Initialization successful
```

### Step 3: Verify Frame Data Flow
Check console for repeating logs:
```
OpenCVIsolateWorker: Converting frame 1920x1080, 8294400 bytes
OpenCVIsolateWorker: Mat created successfully: 1920x1080, channels: 4
```

**KEY CHECK:** The byte count should be non-zero!
- 1920x1080x4 = 8,294,400 bytes (RGBA)
- If you see 0 bytes, frames aren't being captured

### Step 4: Verify Preprocessing
Every frame should show:
```
OpenCVIsolateWorker: Starting preprocessing pipeline
OpenCVIsolateWorker: Converted to grayscale
OpenCVIsolateWorker: Preprocessing pipeline completed
```

### Step 5: Test With Marker
1. Generate marker from https://chev.me/arucogen/
2. Select "4x4 (50, 100, 250, 1000)"
3. Generate ID 0
4. Point camera at marker
5. Look for:
   ```
   ArucoDetector: Detected 1 markers: [0]
   CameraViewController: ✓ DETECTED 1 ArUco markers!
   ```

### Step 6: Check UI Updates
When markers detected:
- **Green card** should appear at bottom of screen
- Shows "✓ Marker Detected"
- Shows "ID: 0" badge
- Shows processing time

## 🐛 Debugging Checklist

- [ ] App launches successfully
- [ ] Camera preview shows live feed
- [ ] Eye icon is present and tappable
- [ ] Eye icon turns green when tapped
- [ ] Console shows "Isolate started"
- [ ] Console shows "OpenCV and ArUco initialized"
- [ ] Console shows frame conversion logs
- [ ] Frame byte count is > 0
- [ ] Preprocessing pipeline completes
- [ ] Generated ArUco marker (DICT_4X4_50, ID 0)
- [ ] Marker is visible in camera view
- [ ] Marker is well-lit and in focus
- [ ] Marker is flat (not tilted)
- [ ] Marker is 10cm+ in size
- [ ] Distance is 30cm - 2m from camera

## 📈 Performance Metrics

### Good Performance:
```
FrameProcessingService: PerformanceMetrics(
  frames: 150,
  skipped: 3,
  avgTime: 45.2ms,
  queue: 1,
  fps: 22.1,
  efficiency: 98.0%
)
```

### Poor Performance (Frame Processing Too Slow):
```
FrameProcessingService: PerformanceMetrics(
  frames: 50,
  skipped: 45,
  avgTime: 120.5ms,
  queue: 3,
  fps: 8.3,
  efficiency: 52.6%
)
```

**If performance is poor:**
1. Device may be underpowered
2. Try reducing camera resolution
3. Disable histogram equalization
4. Reduce blur kernel size

## 🔬 Advanced Debugging

### Enable Verbose Logging

Add this to see every frame:
```dart
// In opencv_isolate_worker.dart
debugPrint('Frame ${request.timestamp}: ${request.width}x${request.height}');
debugPrint('Detection result: $arucoResult');
```

### Check Actual Mat Data

Add after Mat creation:
```dart
final mat = cv.Mat.fromList(...);
debugPrint('Mat isEmpty: ${mat.isEmpty}');
debugPrint('Mat size: ${mat.rows}x${mat.cols}');
debugPrint('Mat channels: ${mat.channels}');
debugPrint('Mat type: ${mat.type}');
```

### Verify ArUco Dict Loading

Add in detector initialization:
```dart
final dictionary = cv.ArucoDictionary.predefined(cv.PredefinedDictionaryType.DICT_4X4_50);
debugPrint('Dictionary loaded: ${dictionary != null}');
debugPrint('Dictionary marker size: ...');
```

## 🎯 Expected Behavior

### With No Marker:
- Frames process continuously
- No detection logs
- No UI overlay
- Processing time: 30-50ms per frame

### With Marker Visible:
- Detection logs appear
- Green UI overlay shows
- Marker ID displayed
- Processing time may increase slightly (35-60ms)

### When Marker Lost:
- Detection stops logging
- Green UI overlay disappears
- Returns to normal processing

## 📱 Device-Specific Notes

### iOS:
- Requires physical device (simulator has no camera)
- Camera permission must be granted
- First frame may take longer (cold start)
- Expect 20-30 FPS processing rate

### Android:
- Some emulators support camera
- Camera permission must be granted
- Frame format may be YUV420 (converted to RGBA)
- Expect 15-25 FPS processing rate

## 🔄 If Still Not Working

### 1. Clean Build
```bash
flutter clean
flutter pub get
flutter run -d ios
```

### 2. Check OpenCV Installation
```bash
flutter pub deps | grep opencv
# Should show: opencv_dart 1.4.3
```

### 3. Verify Frame Processing Service
```bash
# Check logs for:
FrameProcessingService: Initialized successfully
CameraViewController: Frame processing started
```

### 4. Test Without ArUco
Comment out ArUco detection temporarily to verify frame pipeline:
```dart
// final arucoResult = arucoDetector.detectMarkers(processedMat);
final arucoResult = ArucoDetectionResult.noMarkers(0.0);
```

If frames process successfully, issue is in ArUco detection.  
If frames don't process, issue is in frame capture/conversion.

## 📞 Still Having Issues?

Collect this information:
1. Full console output
2. Device model and OS version
3. Flutter version (`flutter --version`)
4. opencv_dart version
5. Screenshot of app UI
6. Marker image you're testing with

Common final checks:
- Is the marker actually DICT_4X4_50? (Check generator settings)
- Is the marker printed clearly? (No blur or distortion)
- Is lighting even? (Avoid shadows or glare)
- Is camera focused? (Tap to focus on marker)
