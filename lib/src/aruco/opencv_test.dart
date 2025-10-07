import 'package:opencv_dart/opencv_dart.dart' as cv;

class OpenCVTest {
  static Future<bool> runBasicTests() async {
    print('🧪 Running OpenCV tests...');
    
    try {
      // Test 1: Basic Mat creation
      final testMat = cv.Mat.zeros(100, 100, cv.MatType.CV_8UC3);
      final test1Pass = testMat.rows == 100 && testMat.cols == 100;
      print('Test 1 - Mat creation: ${test1Pass ? "✅ PASS" : "❌ FAIL"}');
      testMat.dispose();
      
      // Test 2: Color conversion
      final colorMat = cv.Mat.ones(50, 50, cv.MatType.CV_8UC3);
      final grayMat = cv.Mat.empty();
      cv.cvtColor(colorMat, grayMat, cv.ColorConversionCodes.COLOR_BGR2GRAY);
      final test2Pass = grayMat.channels == 1;
      print('Test 2 - Color conversion: ${test2Pass ? "✅ PASS" : "❌ FAIL"}');
      colorMat.dispose();
      grayMat.dispose();
      
      // Test 3: ArUco dictionary
      final dictionary = cv.getPredefinedDictionary(cv.PredefinedDictionaryType.DICT_6X6_250);
      final test3Pass = dictionary.bytesList.isNotEmpty;
      print('Test 3 - ArUco dictionary: ${test3Pass ? "✅ PASS" : "❌ FAIL"}');
      print('   Dictionary size: ${dictionary.bytesList.length} markers');
      dictionary.dispose();
      
      // Test 4: ArUco detector creation
      final dict = cv.getPredefinedDictionary(cv.PredefinedDictionaryType.DICT_6X6_250);
      final detector = cv.ArucoDetector.create(dict);
      final test4Pass = true; // If we got here, creation succeeded
      print('Test 4 - ArUco detector: ${test4Pass ? "✅ PASS" : "❌ FAIL"}');
      detector.dispose();
      dict.dispose();
      
      final allTestsPass = test1Pass && test2Pass && test3Pass && test4Pass;
      print('🎯 Overall OpenCV status: ${allTestsPass ? "✅ ALL TESTS PASS" : "❌ SOME TESTS FAILED"}');
      
      return allTestsPass;
      
    } catch (e) {
      print('❌ OpenCV test error: $e');
      return false;
    }
  }
  
  static void printOpenCVInfo() {
    print('📋 OpenCV Information:');
    try {
      // Print available ArUco dictionaries
      final dictTypes = [
        cv.PredefinedDictionaryType.DICT_4X4_50,
        cv.PredefinedDictionaryType.DICT_4X4_100,
        cv.PredefinedDictionaryType.DICT_6X6_250,
        cv.PredefinedDictionaryType.DICT_7X7_1000,
      ];
      
      for (final dictType in dictTypes) {
        try {
          final dict = cv.getPredefinedDictionary(dictType);
          print('   ${dictType.toString().split('.').last}: ${dict.bytesList.length} markers');
          dict.dispose();
        } catch (e) {
          print('   ${dictType.toString().split('.').last}: ❌ Not available');
        }
      }
    } catch (e) {
      print('   Error getting OpenCV info: $e');
    }
  }
}
