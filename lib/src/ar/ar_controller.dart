import 'dart:async';

import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import '../aruco/pose.dart';

/// Controller for managing AR session and placing virtual objects.
///
/// This controller integrates with the ar_flutter_plugin to manage
/// AR anchors and 3D objects based on detected ArUco marker poses.
class ARController with ChangeNotifier {
  ARSessionManager? _arSessionManager;
  ARObjectManager? _arObjectManager;
  ARAnchorManager? _arAnchorManager;
  ARLocationManager? _arLocationManager;

  bool _isInitialized = false;
  bool _isDisposed = false;
  String? _errorMessage;

  // Track created anchors and nodes by marker ID
  // NOTE: ARAnchor type may differ in ar_flutter_plugin API
  // May need to use dynamic or specific anchor types
  final Map<int, dynamic> _anchors = {};
  final Map<int, ARNode> _nodes = {};

  /// Returns true if the AR session is initialized.
  bool get isInitialized => _isInitialized;

  /// Returns any error message from AR operations.
  String? get errorMessage => _errorMessage;

  /// Returns true if there's an error.
  bool get hasError => _errorMessage != null;

  /// Initializes the AR managers when the AR view is ready.
  Future<void> onARViewCreated({
    required ARSessionManager arSessionManager,
    required ARObjectManager arObjectManager,
    required ARAnchorManager arAnchorManager,
    ARLocationManager? arLocationManager,
  }) async {
    if (_isDisposed) return;

    _arSessionManager = arSessionManager;
    _arObjectManager = arObjectManager;
    _arAnchorManager = arAnchorManager;
    _arLocationManager = arLocationManager;

    try {
      // Configure AR session
      // NOTE: onInitialize parameters may differ in ar_flutter_plugin versions
      // Remove or adjust parameters that don't exist (like handleScale)
      await _arSessionManager!.onInitialize(
        showFeaturePoints: false,
        showPlanes: false,
        showWorldOrigin: false,
        handlePans: false,
        handleRotation: false,
      );

      _isInitialized = true;
      _clearError();
      notifyListeners();
    } catch (e) {
      _setError('Failed to initialize AR session: $e');
    }
  }

  /// Updates or creates an AR anchor for a detected marker.
  ///
  /// [markerId] is the ArUco marker ID.
  /// [pose] contains the 6-DoF pose from the ArUco detector.
  /// [modelUrl] is optional URL to a 3D model (GLTF/GLB format).
  Future<void> updateMarkerAnchor({
    required int markerId,
    required Pose pose,
    String? modelUrl,
  }) async {
    if (!_isInitialized || _isDisposed) return;

    try {
      // Convert Rodrigues vector to rotation matrix then to quaternion
      final quaternion = pose.toQuaternion();

      // Translation vector (convert to appropriate scale if needed)
      final translation = pose.tvec;

      // Remove existing anchor if it exists
      if (_anchors.containsKey(markerId)) {
        await _removeMarkerAnchor(markerId);
      }

      // Create transformation matrix
      final rotationMatrix = vm.Matrix3.identity();
      quaternion.copyRotationTo(rotationMatrix);

      final transformation = vm.Matrix4.identity();
      transformation.setRotation(rotationMatrix);
      transformation.setTranslation(translation);

      // Create anchor at the marker's pose
      final anchor = ARPlaneAnchor(
        transformation: transformation,
      );

      final addedAnchor = await _arAnchorManager!.addAnchor(anchor);
      if (addedAnchor != null) {
        _anchors[markerId] = addedAnchor;

        // If a model URL is provided, attach a 3D object
        if (modelUrl != null && modelUrl.isNotEmpty) {
          await _attachModelToAnchor(markerId, addedAnchor, modelUrl);
        }
      }
    } catch (e) {
      print('Error updating marker anchor $markerId: $e');
    }
  }

  /// Attaches a 3D model to an existing anchor.
  Future<void> _attachModelToAnchor(
    int markerId,
    ARAnchor anchor,
    String modelUrl,
  ) async {
    if (_arObjectManager == null) return;

    try {
      // Remove existing node if present
      if (_nodes.containsKey(markerId)) {
        await _arObjectManager!.removeNode(_nodes[markerId]!);
        _nodes.remove(markerId);
      }

      // Create AR node with 3D model
      final node = ARNode(
        type: NodeType.webGLB,
        uri: modelUrl,
        scale: vm.Vector3(0.1, 0.1, 0.1), // Adjust scale as needed
        position: vm.Vector3(0, 0, 0), // Relative to anchor
        rotation: vm.Vector4(0, 0, 0, 1), // Identity quaternion
      );

      final addedNode =
          await _arObjectManager!.addNode(node, planeAnchor: anchor);
      if (addedNode != null) {
        _nodes[markerId] = addedNode;
      }
    } catch (e) {
      print('Error attaching model to marker $markerId: $e');
    }
  }

  /// Removes an AR anchor and its associated node.
  Future<void> _removeMarkerAnchor(int markerId) async {
    // Remove node first
    if (_nodes.containsKey(markerId) && _arObjectManager != null) {
      try {
        await _arObjectManager!.removeNode(_nodes[markerId]!);
      } catch (e) {
        print('Error removing node for marker $markerId: $e');
      }
      _nodes.remove(markerId);
    }

    // Remove anchor
    if (_anchors.containsKey(markerId) && _arAnchorManager != null) {
      try {
        await _arAnchorManager!.removeAnchor(_anchors[markerId]!);
      } catch (e) {
        print('Error removing anchor for marker $markerId: $e');
      }
      _anchors.remove(markerId);
    }
  }

  /// Removes all anchors and nodes.
  Future<void> clearAllAnchors() async {
    final markerIds = List<int>.from(_anchors.keys);
    for (final markerId in markerIds) {
      await _removeMarkerAnchor(markerId);
    }
  }

  /// Removes anchors for markers that are no longer detected.
  Future<void> pruneUndetectedMarkers(Set<int> detectedMarkerIds) async {
    final currentMarkerIds = List<int>.from(_anchors.keys);
    for (final markerId in currentMarkerIds) {
      if (!detectedMarkerIds.contains(markerId)) {
        await _removeMarkerAnchor(markerId);
      }
    }
  }

  /// Pauses the AR session.
  Future<void> pause() async {
    if (_arSessionManager != null && _isInitialized) {
      try {
        await _arSessionManager!.pause();
      } catch (e) {
        print('Error pausing AR session: $e');
      }
    }
  }

  /// Resumes the AR session.
  Future<void> resume() async {
    if (_arSessionManager != null && _isInitialized) {
      try {
        await _arSessionManager!.resume();
      } catch (e) {
        print('Error resuming AR session: $e');
      }
    }
  }

  /// Disposes resources and cleans up the controller.
  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    await clearAllAnchors();

    if (_arSessionManager != null) {
      try {
        await _arSessionManager!.dispose();
      } catch (e) {
        print('Error disposing AR session: $e');
      }
    }

    _arSessionManager = null;
    _arObjectManager = null;
    _arAnchorManager = null;
    _arLocationManager = null;
    _isInitialized = false;

    super.dispose();
  }

  // Private helper methods
  void _setError(String error) {
    if (_isDisposed) return;
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    if (_isDisposed) return;
    _errorMessage = null;
    notifyListeners();
  }
}
