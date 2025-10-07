import 'package:flutter/material.dart';
import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';

import '../settings/settings_view.dart';
import 'ar_controller.dart';
import 'model_manager.dart';
import '../aruco/aruco_processor.dart';

/// Displays the AR view with ArUco marker detection and overlay.
///
/// This view integrates the AR session with real-time ArUco marker detection,
/// placing virtual objects on detected markers.
class ARMarkerView extends StatefulWidget {
  const ARMarkerView({
    super.key,
    required this.arController,
    required this.arucoProcessor,
  });

  static const routeName = '/ar';

  final ARController arController;
  final ArucoProcessor arucoProcessor;

  @override
  State<ARMarkerView> createState() => _ARMarkerViewState();
}

class _ARMarkerViewState extends State<ARMarkerView> {
  ARSessionManager? _arSessionManager;
  ARObjectManager? _arObjectManager;
  ARAnchorManager? _arAnchorManager;
  ARLocationManager? _arLocationManager;

  final bool _isProcessing = false;
  int _detectedMarkersCount = 0;
  String? _selectedModelId;

  @override
  void initState() {
    super.initState();

    // Set default model
    _selectedModelId = ModelManager.getDefaultModel().id;

    // Listen to marker detection stream
    widget.arucoProcessor.markerStream.listen((markers) {
      if (mounted && widget.arController.isInitialized) {
        setState(() {
          _detectedMarkersCount = markers.length;
        });

        // Get selected model URL
        final model = ModelManager.getModelById(_selectedModelId ?? '');
        final modelUrl = model?.url;

        // Update AR anchors for each detected marker
        for (final entry in markers.entries) {
          widget.arController.updateMarkerAnchor(
            markerId: entry.key,
            pose: entry.value,
            modelUrl: modelUrl,
          );
        }

        // Prune anchors for markers that are no longer detected
        widget.arController.pruneUndetectedMarkers(markers.keys.toSet());
      }
    });
  }

  @override
  void dispose() {
    // Don't dispose the controllers here since they're shared
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // AR view fills entire screen
          ARView(
            onARViewCreated: _onARViewCreated,
            planeDetectionConfig:
                PlaneDetectionConfig.none, // We use markers, not planes
          ),

          // Overlay controls
          _buildOverlayControls(),

          // Model selector
          _buildModelSelector(),

          // Status indicator
          _buildStatusIndicator(),
        ],
      ),
    );
  }

  void _onARViewCreated(
    ARSessionManager arSessionManager,
    ARObjectManager arObjectManager,
    ARAnchorManager arAnchorManager,
    ARLocationManager arLocationManager,
  ) {
    _arSessionManager = arSessionManager;
    _arObjectManager = arObjectManager;
    _arAnchorManager = arAnchorManager;
    _arLocationManager = arLocationManager;

    // Initialize AR controller
    widget.arController.onARViewCreated(
      arSessionManager: arSessionManager,
      arObjectManager: arObjectManager,
      arAnchorManager: arAnchorManager,
      arLocationManager: arLocationManager,
    );

    // Initialize ArUco processor if not already done
    if (!widget.arucoProcessor.isInitialized) {
      widget.arucoProcessor.initialize();
    }

    // Set up frame callback for marker detection
    _arSessionManager!.onPlaneOrPointTap = (List<ARHitTestResult> hits) {
      // Not used for marker-based AR
    };

    // TODO: Set up frame capture for ArUco processing
    // This requires accessing the camera frames from ARCore/ARKit
    // and passing them to the ArUco processor
  }

  Widget _buildOverlayControls() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      right: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Settings button
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.settings, color: Colors.white),
              onPressed: () {
                Navigator.restorablePushNamed(context, SettingsView.routeName);
              },
            ),
          ),
          const SizedBox(height: 8),
          // Back button
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelSelector() {
    final models = ModelManager.getAvailableModels();

    return Positioned(
      left: 16,
      bottom: 100,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '3D Model',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            DropdownButton<String>(
              value: _selectedModelId,
              dropdownColor: Colors.black87,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              underline: Container(),
              items: models.map((model) {
                return DropdownMenuItem<String>(
                  value: model.id,
                  child: Text(model.name),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedModelId = newValue;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    return Positioned(
      bottom: 32,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_detectedMarkersCount > 0)
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 20,
                )
              else
                const Icon(
                  Icons.search,
                  color: Colors.white70,
                  size: 20,
                ),
              const SizedBox(width: 8),
              Text(
                _detectedMarkersCount > 0
                    ? 'Detected: $_detectedMarkersCount marker${_detectedMarkersCount > 1 ? 's' : ''}'
                    : 'Searching for markers...',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
