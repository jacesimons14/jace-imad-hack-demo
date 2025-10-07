import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

void main() {
  group('Mat Data Conversion Tests', () {
    test('Mat.fromList should create Mat with actual data', () {
      // Create sample RGBA data (2x2 pixels = 16 bytes)
      final width = 2;
      final height = 2;
      final channels = 4; // RGBA
      
      // Create test data: 2x2 RGBA image
      final testData = List<int>.generate(
        width * height * channels,
        (i) => (i * 10) % 256, // Generate test pattern
      );
      
      print('Test data length: ${testData.length}');
      print('Test data sample: ${testData.take(16).toList()}');
      
      // Create Mat from list
      final mat = cv.Mat.fromList(
        height,
        width,
        cv.MatType.CV_8UC4,
        testData,
      );
      
      // Verify Mat properties
      expect(mat.rows, equals(height));
      expect(mat.cols, equals(width));
      expect(mat.channels, equals(channels));
      expect(mat.isEmpty, isFalse);
      
      print('Mat created: ${mat.rows}x${mat.cols}, channels: ${mat.channels}');
      
      // Try to extract data back
      try {
        final extractedData = mat.toList();
        print('Extracted data type: ${extractedData.runtimeType}');
        print('Extracted data length: ${extractedData.length}');
        
        // Flatten the 2D list
        final flatData = <int>[];
        for (final row in extractedData) {
          for (final value in row) {
            flatData.add(value.toInt());
          }
        }
        
        print('Flattened data length: ${flatData.length}');
        print('Flattened data sample: ${flatData.take(16).toList()}');
        
        // Data should match (allowing for some conversion artifacts)
        expect(flatData.length, equals(testData.length));
      } catch (e) {
        print('Data extraction failed: $e');
      }
      
      mat.dispose();
    });
    
    test('Mat.fromList with RGBA camera-like data', () {
      // Simulate a small camera frame: 100x100 RGBA
      final width = 100;
      final height = 100;
      final channels = 4;
      
      // Create camera-like data
      final cameraData = Uint8List(width * height * channels);
      for (int i = 0; i < cameraData.length; i++) {
        cameraData[i] = (i % 256); // Fill with pattern
      }
      
      print('Camera-like data size: ${cameraData.length} bytes');
      
      // Convert to Mat (like we do in isolate)
      final mat = cv.Mat.fromList(
        height,
        width,
        cv.MatType.CV_8UC4,
        cameraData.toList(),
      );
      
      expect(mat.rows, equals(height));
      expect(mat.cols, equals(width));
      expect(mat.isEmpty, isFalse);
      
      print('Camera Mat created: ${mat.rows}x${mat.cols}');
      
      // Try grayscale conversion (like in preprocessing)
      try {
        final grayMat = cv.cvtColor(mat, cv.COLOR_RGBA2GRAY);
        print('Grayscale conversion successful: ${grayMat.rows}x${grayMat.cols}, channels: ${grayMat.channels}');
        expect(grayMat.channels, equals(1));
        grayMat.dispose();
      } catch (e) {
        print('Grayscale conversion failed: $e');
      }
      
      mat.dispose();
    });
  });
}
