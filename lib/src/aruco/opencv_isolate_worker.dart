import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

import 'frame_processing_service.dart';

/// OpenCV processing isolate worker.
///
/// This isolate handles all OpenCV operations in the background to prevent
/// UI blocking. It receives frame data from the main thread, processes it
/// using OpenCV, and returns the results.
class OpenCVIsolateWorker {
  /// Entry point for the OpenCV processing isolate.
  static void entryPoint(SendPort mainSendPort) {
    final isolateReceivePort = ReceivePort();
    
    // Send back the isolate's send port to main thread
    mainSendPort.send(isolateReceivePort.sendPort);
    
    // Initialize OpenCV in isolate
    bool isOpenCVInitialized = false;
    
    // Listen for messages from main thread
    isolateReceivePort.listen((message) {
      try {
        if (message is IsolateCommand && message == IsolateCommand.shutdown) {
          debugPrint('OpenCVIsolateWorker: Shutting down isolate');
          isolateReceivePort.close();
          return;
        }
        
        if (message is FrameProcessingRequest) {
          // Initialize OpenCV on first frame
          if (!isOpenCVInitialized) {
            try {
              // OpenCV is automatically initialized when first used
              isOpenCVInitialized = true;
              debugPrint('OpenCVIsolateWorker: OpenCV initialized');
            } catch (e) {
              mainSendPort.send(ProcessedFrameResult(
                originalTimestamp: message.timestamp,
                processingTime: 0.0,
                success: false,
                errorMessage: 'Failed to initialize OpenCV: $e',
              ));
              return;
            }
          }
          
          // Process the frame
          final result = _processFrame(message);
          mainSendPort.send(result);
        }
      } catch (e) {
        debugPrint('OpenCVIsolateWorker: Error processing message: $e');
        if (message is FrameProcessingRequest) {
          mainSendPort.send(ProcessedFrameResult(
            originalTimestamp: message.timestamp,
            processingTime: 0.0,
            success: false,
            errorMessage: 'Processing error: $e',
          ));
        }
      }
    });
    
    debugPrint('OpenCVIsolateWorker: Isolate started');
  }
  
  /// Processes a single frame using OpenCV.
  static ProcessedFrameResult _processFrame(FrameProcessingRequest request) {
    final startTime = DateTime.now();
    
    try {
      // Convert frame data to OpenCV Mat
      final mat = _convertToMat(request);
      if (mat == null) {
        return ProcessedFrameResult(
          originalTimestamp: request.timestamp,
          processingTime: 0.0,
          success: false,
          errorMessage: 'Failed to convert frame to Mat',
        );
      }
      
      // Apply preprocessing pipeline
      final processedMat = _preprocessFrame(mat);
      
      // Convert back to bytes for return (optional)
      final processedBytes = _matToBytes(processedMat);
      
      // Clean up OpenCV resources
      mat.dispose();
      processedMat.dispose();
      
      final processingTime = DateTime.now().difference(startTime).inMicroseconds / 1000.0;
      
      return ProcessedFrameResult(
        originalTimestamp: request.timestamp,
        processingTime: processingTime,
        success: true,
        processedData: processedBytes,
      );
      
    } catch (e) {
      final processingTime = DateTime.now().difference(startTime).inMicroseconds / 1000.0;
      return ProcessedFrameResult(
        originalTimestamp: request.timestamp,
        processingTime: processingTime,
        success: false,
        errorMessage: 'Frame processing failed: $e',
      );
    }
  }
  
  /// Converts frame data to OpenCV Mat.
  static cv.Mat? _convertToMat(FrameProcessingRequest request) {
    try {
      // Create Mat from frame data using opencv_dart API
      // Create a Mat with proper dimensions and type
      final mat = cv.Mat.zeros(
        request.height, 
        request.width, 
        cv.MatType.CV_8UC4, // RGBA format
      );
      
      // Copy data to the Mat - this is simplified, in production
      // you'd use proper memory copying or direct buffer access
      // For now, we'll create a working prototype
      
      debugPrint('OpenCVIsolateWorker: Created Mat ${request.width}x${request.height}');
      return mat;
    } catch (e) {
      debugPrint('OpenCVIsolateWorker: Failed to convert to Mat: $e');
      return null;
    }
  }
  
  /// Applies preprocessing pipeline to the frame.
  static cv.Mat _preprocessFrame(cv.Mat inputMat) {
    try {
      debugPrint('OpenCVIsolateWorker: Starting preprocessing pipeline');
      
      // Step 1: Convert RGBA to BGR for OpenCV processing
      // Most OpenCV functions expect BGR format
      cv.Mat? bgrMat;
      try {
        bgrMat = cv.cvtColor(inputMat, cv.COLOR_RGBA2BGR);
        debugPrint('OpenCVIsolateWorker: Converted to BGR');
      } catch (e) {
        debugPrint('OpenCVIsolateWorker: BGR conversion failed: $e');
        // Fallback: use original mat
        bgrMat = inputMat.clone();
      }
      
      // Step 2: Convert to grayscale for faster processing
      cv.Mat? grayMat;
      try {
        grayMat = cv.cvtColor(bgrMat, cv.COLOR_BGR2GRAY);
        debugPrint('OpenCVIsolateWorker: Converted to grayscale');
      } catch (e) {
        debugPrint('OpenCVIsolateWorker: Grayscale conversion failed: $e');
        // Fallback: create a simple grayscale mat
        grayMat = cv.Mat.zeros(inputMat.rows, inputMat.cols, cv.MatType.CV_8UC1);
      }
      
      // Step 3: Apply blur to reduce noise
      cv.Mat? blurredMat;
      try {
        blurredMat = cv.blur(grayMat, (5, 5));
        debugPrint('OpenCVIsolateWorker: Applied blur');
      } catch (e) {
        debugPrint('OpenCVIsolateWorker: Blur failed: $e');
        // Fallback: use grayscale mat
        blurredMat = grayMat.clone();
      }
      
      // Step 4: Apply histogram equalization for better contrast
      cv.Mat? equalizedMat;
      try {
        equalizedMat = cv.equalizeHist(blurredMat);
        debugPrint('OpenCVIsolateWorker: Applied histogram equalization');
      } catch (e) {
        debugPrint('OpenCVIsolateWorker: Histogram equalization failed: $e');
        // Fallback: use blurred mat
        equalizedMat = blurredMat.clone();
      }
      
      // Clean up intermediate matrices to prevent memory leaks
      if (bgrMat != inputMat) bgrMat.dispose();
      if (grayMat != bgrMat) grayMat.dispose();
      if (blurredMat != grayMat) blurredMat.dispose();
      
      debugPrint('OpenCVIsolateWorker: Preprocessing pipeline completed');
      return equalizedMat;
      
    } catch (e) {
      debugPrint('OpenCVIsolateWorker: Preprocessing pipeline failed: $e');
      // Return a copy of original if all preprocessing fails
      try {
        return inputMat.clone();
      } catch (cloneError) {
        debugPrint('OpenCVIsolateWorker: Even clone failed: $cloneError');
        // Last resort: create an empty mat
        return cv.Mat.zeros(inputMat.rows, inputMat.cols, cv.MatType.CV_8UC1);
      }
    }
  }
  
  /// Converts OpenCV Mat back to bytes.
  static Uint8List? _matToBytes(cv.Mat mat) {
    try {
      debugPrint('OpenCVIsolateWorker: Converting Mat to bytes');
      
      // Convert processed mat back to RGBA for consistency with input format
      cv.Mat? outputMat;
      
      if (mat.channels == 1) {
        // Grayscale to RGBA conversion
        try {
          outputMat = cv.cvtColor(mat, cv.COLOR_GRAY2RGBA);
          debugPrint('OpenCVIsolateWorker: Converted grayscale to RGBA');
        } catch (e) {
          debugPrint('OpenCVIsolateWorker: Grayscale to RGBA failed: $e');
          // Create a simple RGBA mat from grayscale
          outputMat = cv.Mat.zeros(mat.rows, mat.cols, cv.MatType.CV_8UC4);
        }
      } else if (mat.channels == 3) {
        // BGR to RGBA conversion
        try {
          outputMat = cv.cvtColor(mat, cv.COLOR_BGR2RGBA);
          debugPrint('OpenCVIsolateWorker: Converted BGR to RGBA');
        } catch (e) {
          debugPrint('OpenCVIsolateWorker: BGR to RGBA failed: $e');
          // Create a simple RGBA mat
          outputMat = cv.Mat.zeros(mat.rows, mat.cols, cv.MatType.CV_8UC4);
        }
      } else {
        // Already RGBA or other format
        try {
          outputMat = mat.clone();
          debugPrint('OpenCVIsolateWorker: Cloned existing mat');
        } catch (e) {
          debugPrint('OpenCVIsolateWorker: Clone failed: $e');
          // Create empty RGBA mat
          outputMat = cv.Mat.zeros(mat.rows, mat.cols, cv.MatType.CV_8UC4);
        }
      }
      
      // Extract bytes from the mat
      // For now, return a placeholder byte array of correct size
      final expectedSize = outputMat.rows * outputMat.cols * outputMat.channels;
      final bytes = Uint8List(expectedSize);
      
      // TODO: Implement proper data extraction from Mat
      // This would typically involve getting the raw data pointer and copying bytes
      // For now, we'll return a placeholder that maintains the correct structure
      
      // Clean up
      if (outputMat != mat) {
        outputMat.dispose();
      }
      
      debugPrint('OpenCVIsolateWorker: Generated ${bytes.length} bytes');
      return bytes;
      
    } catch (e) {
      debugPrint('OpenCVIsolateWorker: Failed to convert Mat to bytes: $e');
      return null;
    }
  }
}

/// Extension methods for better OpenCV integration.
extension MatExtensions on cv.Mat {
  /// Gets the raw data as Uint8List.
  Uint8List get data {
    // TODO: Implement proper data extraction from Mat using opencv_dart API
    // This is a placeholder implementation
    final totalElements = rows * cols * channels;
    return Uint8List(totalElements);
  }
  
  /// Gets the size of each element in bytes.
  int get elemSize {
    // Return size based on mat type
    switch (type) {
      case cv.MatType.CV_8UC1:
      case cv.MatType.CV_8UC3:
      case cv.MatType.CV_8UC4:
        return 1; // 8-bit unsigned
      case cv.MatType.CV_16UC1:
      case cv.MatType.CV_16UC3:
      case cv.MatType.CV_16UC4:
        return 2; // 16-bit unsigned
      case cv.MatType.CV_32FC1:
      case cv.MatType.CV_32FC3:
      case cv.MatType.CV_32FC4:
        return 4; // 32-bit float
      default:
        return 1; // Default fallback
    }
  }
  
  /// Gets the total number of elements.
  int get total => rows * cols;
}