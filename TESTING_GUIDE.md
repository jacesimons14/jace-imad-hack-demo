# Quick Test Guide - ArUco Marker Detection

## 🎯 Quick Start (2 minutes)

### Step 1: Generate Test Markers
1. Go to https://chev.me/arucogen/
2. Select **"4x4 (50, 100, 250, 1000)"** dictionary
3. Generate marker ID **0**
4. Download and display on another screen OR print it

### Step 2: Build and Run
```bash
# Build for iOS (camera required - not simulator)
flutter run -d ios

# Or for Android
flutter run -d android
```

### Step 3: Enable Detection
1. App opens to camera view
2. Look for **eye icon** (👁️) in top-right corner
3. Tap icon - it turns **green** when enabled
4. Frame processing is now active

### Step 4: Test Detection
1. Point camera at ArUco marker
2. **Green overlay card appears** at bottom when detected
3. Shows:
   - ✓ Checkmark icon
   - "Marker Detected" or "Markers Detected"
   - Marker ID(s) in white pills
   - Processing time

## 📊 What You Should See

### Console Output (Expected)
```
CameraViewController: Camera and frame processing initialized
FrameProcessingService: Initialized successfully  
OpenCVIsolateWorker: OpenCV and ArUco initialized
ArucoDetector: Initializing with dictionary and parameters
ArucoDetector: Initialization successful

// When marker is detected:
OpenCVIsolateWorker: Mat created successfully: 1920x1080, channels: 4
ArucoDetector: Detected 1 markers: [0]
CameraViewController: ✓ DETECTED 1 ArUco markers!
CameraViewController: Marker IDs: [0]
```

### Visual Feedback (On Screen)
- **Green gradient card** at bottom of screen
- **White checkmark** icon in circle
- **"✓ Marker Detected"** title
- **"1 marker found"** subtitle
- **Marker ID badge**: white pill with "ID: 0"
- **Processing time**: "Processing: 35.2ms"

## 🔧 Troubleshooting

### No Green Overlay Appears

**Check 1: Is frame processing enabled?**
- Eye icon should be **green**
- If white/gray, tap to enable

**Check 2: Is marker correct format?**
- Must be **DICT_4X4_50** markers
- IDs 0-49 supported
- Try marker ID 0 first

**Check 3: Lighting and distance**
- Ensure **good lighting**
- Marker should be **10cm or larger**
- Distance: **30cm - 2m from camera**
- Keep marker **flat** (not tilted)

### Detection is Slow

**Check processing time in overlay:**
- Good: < 50ms
- Acceptable: 50-100ms
- Slow: > 100ms

**If slow, try:**
- Close other apps
- Use smaller camera resolution
- Ensure marker is clear and in focus

### App Crashes or Errors

**Check console for:**
```
Failed to initialize OpenCV/ArUco
Failed to convert to Mat
```

**Solutions:**
1. Clean build: `flutter clean && flutter pub get`
2. Rebuild: `flutter run -d ios`
3. Check iOS camera permissions in Settings

## 📱 Device Requirements

### iOS
- iOS 12.0 or higher
- Physical device (simulator has no camera)
- Camera permission granted

### Android  
- Android API 21+ (Lollipop)
- Physical device or emulator with camera
- Camera permission granted

## 🎨 UI Elements Reference

### Top-Right Controls
1. **Settings icon** (⚙️) - Opens settings
2. **Eye icon** (👁️) - Toggle frame processing
   - White: Disabled
   - Green: Enabled
3. **Performance metrics** - FPS and efficiency
4. **Camera resolution** - Display resolution

### Bottom Controls
- **Camera switch button** - Switch between cameras (if multiple)
- **Marker detection overlay** - Shows when markers detected

## 🧪 Advanced Testing

### Test Multiple Markers
1. Generate IDs 0, 1, 2 from https://chev.me/arucogen/
2. Display all 3 markers together
3. Overlay shows: "3 markers found"
4. All IDs displayed in white pills

### Test Different Distances
- **Close**: 20-30cm - Should detect
- **Medium**: 50cm-1m - Optimal
- **Far**: 1-3m - Still detects
- **Too far**: > 3m - May not detect

### Test Different Lighting
- **Bright daylight**: Best performance
- **Indoor lighting**: Good performance
- **Dim lighting**: Reduced performance
- **Very dark**: No detection

### Performance Benchmarks
- **FPS**: Should be > 20
- **Processing efficiency**: Should be > 90%
- **Processing time**: Should be < 50ms
- **Queue size**: Should be < 2

## 📝 Test Checklist

- [ ] App launches to camera view
- [ ] Camera preview is working
- [ ] Can enable frame processing (eye icon turns green)
- [ ] Green overlay appears when marker detected
- [ ] Marker ID is displayed correctly
- [ ] Processing time is shown
- [ ] Overlay disappears when marker not visible
- [ ] Multiple markers can be detected simultaneously
- [ ] Performance metrics are reasonable
- [ ] No crashes or errors in console

## 🚀 Next Steps After Successful Detection

1. **Pose Estimation** - Calculate marker position in 3D space
2. **AR Overlay** - Place 3D objects on markers
3. **Multi-marker tracking** - Track multiple markers simultaneously
4. **Gesture recognition** - Use markers for AR interactions

## 📚 Additional Resources

- **ArUco Marker Generator**: https://chev.me/arucogen/
- **OpenCV ArUco Docs**: https://docs.opencv.org/4.x/d5/dae/tutorial_aruco_detection.html
- **Project Documentation**: See ARUCO_DETECTION_FIXES.md for detailed technical info
