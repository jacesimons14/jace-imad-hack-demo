import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import '../aruco/opencv_test.dart';

class CameraViewController extends ChangeNotifier {
  CameraController? _cameraController;
  List<CameraDescription>? cameras;
  int selectedCameraIdx = 0;
  bool _openCVReady = false;

  bool get openCVReady => _openCVReady;

  Future<void> initialize() async {
    // ...existing camera initialization code...

    // Test OpenCV after camera is ready
    await _testOpenCV();
  }

  Future<void> _testOpenCV() async {
    try {
      print('🧪 Testing OpenCV integration...');
      OpenCVTest.printOpenCVInfo();
      _openCVReady = await OpenCVTest.runBasicTests();
      notifyListeners();
    } catch (e) {
      print('❌ OpenCV test failed: $e');
      _openCVReady = false;
      notifyListeners();
    }
  }

  // ...existing code...
}