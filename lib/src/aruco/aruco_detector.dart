import 'package:flutter/foundation.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'package:vector_math/vector_math_64.dart' as vm;

/// ArUco marker detection results containing marker IDs and corner coordinates.
class ArucoDetectionResult {
  /// List of detected marker IDs.
  final List<int> markerIds;
  
  /// List of marker corners. Each marker has 4 corners (x,y coordinates).
  /// Format: [marker1_corners, marker2_corners, ...]
  /// Each marker_corners: [corner1_x, corner1_y, corner2_x, corner2_y, ...]
  final List<List<double>> markerCorners;
  
  /// Number of markers detected.
  final int markerCount;
  
  /// Detection processing time in milliseconds.
  final double processingTime;
  
  /// Whether detection was successful.
  final bool success;
  
  /// Error message if detection failed.
  final String? errorMessage;
  
  ArucoDetectionResult({
    required this.markerIds,
    required this.markerCorners,
    required this.markerCount,
    required this.processingTime,
    required this.success,
    this.errorMessage,
  });
  
  /// Creates a failed detection result.
  factory ArucoDetectionResult.failed(String error, double processingTime) {
    return ArucoDetectionResult(
      markerIds: [],
      markerCorners: [],
      markerCount: 0,
      processingTime: processingTime,
      success: false,
      errorMessage: error,
    );
  }
  
  /// Creates a successful detection result with no markers found.
  factory ArucoDetectionResult.noMarkers(double processingTime) {
    return ArucoDetectionResult(
      markerIds: [],
      markerCorners: [],
      markerCount: 0,
      processingTime: processingTime,
      success: true,
    );
  }
  
  /// Converts detection result to a serializable map for isolate communication.
  Map<String, dynamic> toMap() {
    return {
      'markerIds': markerIds,
      'markerCorners': markerCorners,
      'markerCount': markerCount,
      'processingTime': processingTime,
      'success': success,
      'errorMessage': errorMessage,
    };
  }
  
  /// Creates detection result from a serializable map.
  factory ArucoDetectionResult.fromMap(Map<String, dynamic> map) {
    return ArucoDetectionResult(
      markerIds: List<int>.from(map['markerIds'] ?? []),
      markerCorners: List<List<double>>.from(
        (map['markerCorners'] ?? []).map((corners) => List<double>.from(corners))
      ),
      markerCount: map['markerCount'] ?? 0,
      processingTime: map['processingTime']?.toDouble() ?? 0.0,
      success: map['success'] ?? false,
      errorMessage: map['errorMessage'],
    );
  }
  
  @override
  String toString() {
    if (!success) {
      return 'ArucoDetectionResult(failed: $errorMessage, time: ${processingTime.toStringAsFixed(1)}ms)';
    }
    return 'ArucoDetectionResult(markers: $markerCount, ids: $markerIds, time: ${processingTime.toStringAsFixed(1)}ms)';
  }
}

/// Configuration for ArUco marker detection.
class ArucoDetectorConfig {
  /// The ArUco dictionary to use for detection.
  final cv.ArucoDictionary dictionary;
  
  /// Detector parameters for fine-tuning detection performance.
  final cv.ArucoDetectorParameters params;
  
  /// Whether to enable corner refinement for better accuracy.
  final bool enableCornerRefinement;
  
  /// Minimum marker perimeter rate relative to image size.
  final double minMarkerPerimeterRate;
  
  /// Maximum marker perimeter rate relative to image size.
  final double maxMarkerPerimeterRate;
  
  /// Adaptive threshold window size.
  final int adaptiveThreshWinSizeMin;
  final int adaptiveThreshWinSizeMax;
  
  ArucoDetectorConfig({
    required this.dictionary,
    required this.params,
    this.enableCornerRefinement = true,
    this.minMarkerPerimeterRate = 0.03,
    this.maxMarkerPerimeterRate = 4.0,
    this.adaptiveThreshWinSizeMin = 3,
    this.adaptiveThreshWinSizeMax = 23,
  });
  
  /// Creates a default configuration optimized for mobile AR applications.
  factory ArucoDetectorConfig.defaultMobile() {
    // Use DICT_4X4_50 as it's good for beginners and mobile applications
    final dictionary = cv.ArucoDictionary.predefined(cv.PredefinedDictionaryType.DICT_4X4_50);
    
    // Create detector parameters optimized for mobile
    final params = cv.ArucoDetectorParameters.empty()
      ..minMarkerPerimeterRate = 0.03  // Allow smaller markers
      ..maxMarkerPerimeterRate = 4.0   // Allow larger markers
      ..adaptiveThreshWinSizeMin = 3   // Smaller window for mobile
      ..adaptiveThreshWinSizeMax = 23; // Reasonable max for mobile
    
    return ArucoDetectorConfig(
      dictionary: dictionary,
      params: params,
      enableCornerRefinement: true,
      minMarkerPerimeterRate: 0.03,  // Allow smaller markers
      maxMarkerPerimeterRate: 4.0,   // Allow larger markers
      adaptiveThreshWinSizeMin: 3,   // Smaller window for mobile
      adaptiveThreshWinSizeMax: 23,  // Reasonable max for mobile
    );
  }
  
  /// Creates a high-accuracy configuration for controlled environments.
  factory ArucoDetectorConfig.highAccuracy() {
    final dictionary = cv.ArucoDictionary.predefined(cv.PredefinedDictionaryType.DICT_6X6_250);
    final params = cv.ArucoDetectorParameters.empty()
      ..minMarkerPerimeterRate = 0.01  // Allow very small markers
      ..maxMarkerPerimeterRate = 6.0   // Allow very large markers
      ..adaptiveThreshWinSizeMin = 5   // Larger window for accuracy
      ..adaptiveThreshWinSizeMax = 31; // Larger max window
    
    return ArucoDetectorConfig(
      dictionary: dictionary,
      params: params,
      enableCornerRefinement: true,
      minMarkerPerimeterRate: 0.01,  // Allow very small markers
      maxMarkerPerimeterRate: 6.0,   // Allow very large markers
      adaptiveThreshWinSizeMin: 5,   // Larger window for accuracy
      adaptiveThreshWinSizeMax: 31,  // Larger max window
    );
  }
  
  /// Creates a fast detection configuration for real-time applications.
  factory ArucoDetectorConfig.fastDetection() {
    final dictionary = cv.ArucoDictionary.predefined(cv.PredefinedDictionaryType.DICT_4X4_50);
    final params = cv.ArucoDetectorParameters.empty()
      ..minMarkerPerimeterRate = 0.05  // Slightly larger minimum
      ..maxMarkerPerimeterRate = 3.0   // Slightly smaller maximum
      ..adaptiveThreshWinSizeMin = 3   
      ..adaptiveThreshWinSizeMax = 15; // Smaller max window for speed
    
    return ArucoDetectorConfig(
      dictionary: dictionary,
      params: params,
      enableCornerRefinement: false,  // Skip refinement for speed
      minMarkerPerimeterRate: 0.05,  // Slightly larger minimum
      maxMarkerPerimeterRate: 3.0,   // Slightly smaller maximum
      adaptiveThreshWinSizeMin: 3,   
      adaptiveThreshWinSizeMax: 15,  // Smaller max window for speed
    );
  }
}

/// ArUco marker detector that identifies markers and their corner coordinates.
/// 
/// This class implements the core ArUco detection functionality using OpenCV.
/// It's designed to work within the existing isolate-based processing pipeline.
class ArucoDetector {
  /// Detector configuration.
  final ArucoDetectorConfig config;
  
  /// The actual OpenCV ArUco detector instance.
  cv.ArucoDetector? _detector;
  
  /// Whether the detector has been initialized.
  bool _isInitialized = false;
  
  /// Detection statistics.
  int _totalDetections = 0;
  int _successfulDetections = 0;
  double _averageProcessingTime = 0.0;
  
  ArucoDetector({required this.config});
  
  /// Factory constructor for default mobile configuration.
  factory ArucoDetector.defaultMobile() {
    return ArucoDetector(config: ArucoDetectorConfig.defaultMobile());
  }
  
  /// Factory constructor for high accuracy configuration.
  factory ArucoDetector.highAccuracy() {
    return ArucoDetector(config: ArucoDetectorConfig.highAccuracy());
  }
  
  /// Factory constructor for fast detection configuration.
  factory ArucoDetector.fastDetection() {
    return ArucoDetector(config: ArucoDetectorConfig.fastDetection());
  }
  
  /// Initializes the ArUco detector.
  bool initialize() {
    if (_isInitialized) return true;
    
    try {
      debugPrint('ArucoDetector: Initializing with dictionary and parameters');
      
      // Create the ArUco detector instance
      _detector = cv.ArucoDetector.create(config.dictionary, config.params);
      
      _isInitialized = true;
      debugPrint('ArucoDetector: Initialization successful');
      return true;
      
    } catch (e) {
      debugPrint('ArucoDetector: Initialization failed: $e');
      _isInitialized = false;
      return false;
    }
  }
  
  /// Detects ArUco markers in the provided image.
  /// 
  /// [inputMat] should be a grayscale OpenCV Mat for optimal performance.
  /// Returns an [ArucoDetectionResult] containing detected markers and corners.
  ArucoDetectionResult detectMarkers(cv.Mat inputMat) {
    final startTime = DateTime.now();
    
    // Validate inputs
    if (!_isInitialized || _detector == null) {
      return ArucoDetectionResult.failed(
        'Detector not initialized',
        DateTime.now().difference(startTime).inMicroseconds / 1000.0,
      );
    }
    
    if (inputMat.isEmpty) {
      return ArucoDetectionResult.failed(
        'Input image is empty',
        DateTime.now().difference(startTime).inMicroseconds / 1000.0,
      );
    }
    
    try {
      _totalDetections++;
      
      // Prepare input image
      final grayMat = _prepareInputImage(inputMat);
      
      // Detect markers using opencv_dart API
      final (corners, ids, rejected) = _detector!.detectMarkers(grayMat);
      
      // Clean up temporary mat if we created one
      if (grayMat != inputMat) {
        grayMat.dispose();
      }
      
      final processingTime = DateTime.now().difference(startTime).inMicroseconds / 1000.0;
      
      // Process detection results
      if (ids.isEmpty) {
        // No markers detected
        _updateStatistics(processingTime, false);
        return ArucoDetectionResult.noMarkers(processingTime);
      }
      
      // Validate and format detection results
      final detectionResult = _formatDetectionResults(ids, corners, processingTime);
      
      _updateStatistics(processingTime, detectionResult.success);
      
      if (detectionResult.success) {
        debugPrint('ArucoDetector: Detected ${detectionResult.markerCount} markers: ${detectionResult.markerIds}');
      }
      
      return detectionResult;
      
    } catch (e) {
      final processingTime = DateTime.now().difference(startTime).inMicroseconds / 1000.0;
      _updateStatistics(processingTime, false);
      
      debugPrint('ArucoDetector: Detection failed: $e');
      return ArucoDetectionResult.failed(
        'Detection error: $e',
        processingTime,
      );
    }
  }
  
  /// Draws detected markers on the image for visualization.
  /// Returns a new Mat with markers drawn, or null if drawing fails.
  cv.Mat? drawDetectedMarkers(cv.Mat inputMat, ArucoDetectionResult detection) {
    if (!detection.success || detection.markerCount == 0 || _detector == null) {
      return null;
    }
    
    try {
      // Convert detection result back to OpenCV format
      final ids = cv.VecI32.fromList(detection.markerIds);
      final corners = cv.VecVecPoint2f();
      
      for (final markerCorners in detection.markerCorners) {
        if (markerCorners.length == 8) { // 4 corners × 2 coordinates
          final points = <cv.Point2f>[];
          for (int i = 0; i < 8; i += 2) {
            points.add(cv.Point2f(markerCorners[i], markerCorners[i + 1]));
          }
          corners.add(cv.VecPoint2f.fromList(points));
        }
      }
      
      if (corners.isEmpty) return null;
      
      // Create output image
      cv.Mat outputMat;
      if (inputMat.channels == 1) {
        // Convert grayscale to color for drawing
        outputMat = cv.cvtColor(inputMat, cv.COLOR_GRAY2BGR);
      } else {
        outputMat = inputMat.clone();
      }
      
      // Draw markers using the global function
      cv.arucoDrawDetectedMarkers(outputMat, corners, ids, cv.Scalar(0, 255, 0, 255));
      
      // Clean up temporary structures
      ids.dispose();
      corners.dispose();
      
      return outputMat;
      
    } catch (e) {
      debugPrint('ArucoDetector: Failed to draw markers: $e');
      return null;
    }
  }
  
  /// Gets current detection statistics.
  Map<String, dynamic> getStatistics() {
    final successRate = _totalDetections > 0 ? _successfulDetections / _totalDetections : 0.0;
    
    return {
      'totalDetections': _totalDetections,
      'successfulDetections': _successfulDetections,
      'successRate': successRate,
      'averageProcessingTime': _averageProcessingTime,
      'isInitialized': _isInitialized,
    };
  }
  
  /// Disposes the detector and cleans up resources.
  void dispose() {
    _detector?.dispose();
    _detector = null;
    _isInitialized = false;
    debugPrint('ArucoDetector: Disposed');
  }
  
  // Private methods
  
  /// Prepares the input image for detection (converts to grayscale if needed).
  cv.Mat _prepareInputImage(cv.Mat inputMat) {
    // Check if input is already grayscale
    if (inputMat.channels == 1) {
      return inputMat; // Already grayscale, use as-is
    }
    
    // Convert to grayscale for better detection performance
    try {
      if (inputMat.channels == 3) {
        return cv.cvtColor(inputMat, cv.COLOR_BGR2GRAY);
      } else if (inputMat.channels == 4) {
        return cv.cvtColor(inputMat, cv.COLOR_BGRA2GRAY);
      } else {
        // Unknown format, try to use as-is
        debugPrint('ArucoDetector: Unknown input format with ${inputMat.channels} channels');
        return inputMat;
      }
    } catch (e) {
      debugPrint('ArucoDetector: Failed to convert to grayscale: $e');
      return inputMat; // Fallback to original
    }
  }
  
  /// Formats the raw detection results into a structured result object.
  ArucoDetectionResult _formatDetectionResults(
    cv.VecI32 ids,
    cv.VecVecPoint2f corners,
    double processingTime,
  ) {
    try {
      // Validate detection data
      if (ids.isEmpty || corners.isEmpty) {
        return ArucoDetectionResult.noMarkers(processingTime);
      }
      
      if (ids.length != corners.length) {
        return ArucoDetectionResult.failed(
          'Mismatch between IDs (${ids.length}) and corners (${corners.length})',
          processingTime,
        );
      }
      
      // Extract marker IDs
      final markerIds = <int>[];
      for (int i = 0; i < ids.length; i++) {
        markerIds.add(ids[i]);
      }
      
      // Extract and validate marker corners
      final markerCorners = <List<double>>[];
      for (int i = 0; i < corners.length; i++) {
        final cornerVec = corners[i];
        
        // Each marker should have exactly 4 corners
        if (cornerVec.length != 4) {
          debugPrint('ArucoDetector: Invalid corner count for marker $i: ${cornerVec.length}');
          continue;
        }
        
        // Extract corner coordinates
        final cornerList = <double>[];
        for (int j = 0; j < 4; j++) {
          final point = cornerVec[j];
          cornerList.add(point.x);
          cornerList.add(point.y);
        }
        
        // Validate corner coordinates are within reasonable bounds
        if (_validateCornerCoordinates(cornerList, processingTime)) {
          markerCorners.add(cornerList);
        } else {
          // Remove corresponding marker ID if corners are invalid
          if (markerIds.length > markerCorners.length) {
            markerIds.removeAt(markerCorners.length);
          }
        }
      }
      
      // Final validation
      if (markerIds.length != markerCorners.length) {
        return ArucoDetectionResult.failed(
          'Final mismatch between valid IDs (${markerIds.length}) and corners (${markerCorners.length})',
          processingTime,
        );
      }
      
      return ArucoDetectionResult(
        markerIds: markerIds,
        markerCorners: markerCorners,
        markerCount: markerIds.length,
        processingTime: processingTime,
        success: true,
      );
      
    } catch (e) {
      debugPrint('ArucoDetector: Failed to format detection results: $e');
      return ArucoDetectionResult.failed(
        'Result formatting error: $e',
        processingTime,
      );
    }
  }
  
  /// Validates that corner coordinates form a reasonable quadrilateral.
  bool _validateCornerCoordinates(List<double> corners, double processingTime) {
    if (corners.length != 8) return false; // Must have 4 corners (x,y pairs)
    
    try {
      // Extract corners as points
      final points = <vm.Vector2>[];
      for (int i = 0; i < 8; i += 2) {
        points.add(vm.Vector2(corners[i], corners[i + 1]));
      }
      
      // Check that all coordinates are finite and positive
      for (final point in points) {
        if (!point.x.isFinite || !point.y.isFinite || point.x < 0 || point.y < 0) {
          return false;
        }
      }
      
      // Check that corners form a reasonable quadrilateral
      // Calculate the area using the shoelace formula
      double area = 0.0;
      for (int i = 0; i < 4; i++) {
        final j = (i + 1) % 4;
        area += points[i].x * points[j].y;
        area -= points[j].x * points[i].y;
      }
      area = area.abs() / 2.0;
      
      // Reject if area is too small (likely noise) or too large (likely error)
      if (area < 100 || area > 1000000) {
        return false;
      }
      
      // Check that corners are not too close together (minimum distance)
      for (int i = 0; i < 4; i++) {
        for (int j = i + 1; j < 4; j++) {
          final distance = points[i].distanceTo(points[j]);
          if (distance < 5.0) { // Minimum 5 pixels apart
            return false;
          }
        }
      }
      
      return true;
      
    } catch (e) {
      debugPrint('ArucoDetector: Corner validation failed: $e');
      return false;
    }
  }
  
  /// Updates detection statistics.
  void _updateStatistics(double processingTime, bool successful) {
    if (successful) {
      _successfulDetections++;
    }
    
    // Update average processing time (exponential moving average)
    _averageProcessingTime = _averageProcessingTime == 0.0
        ? processingTime
        : (_averageProcessingTime * 0.9) + (processingTime * 0.1);
  }
}