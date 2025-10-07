import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/settings/settings_controller.dart';
import 'src/settings/settings_service.dart';
import 'src/camera/camera_controller.dart';
import 'src/camera/camera_service.dart';
import 'src/aruco/frame_processing_service.dart';

void main() async {
  // Ensure that plugin services are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Set up the SettingsController, which will glue user settings to multiple
  // Flutter Widgets.
  final settingsController = SettingsController(SettingsService());

  // Set up services for AR functionality
  final cameraService = CameraService();
  final frameProcessingService = FrameProcessingService();
  
  // Set up the CameraViewController with both services
  final cameraController = CameraViewController(cameraService, frameProcessingService);

  // Load the user's preferred theme while the splash screen is displayed.
  // This prevents a sudden theme change when the app is first displayed.
  await settingsController.loadSettings();

  // Run the app and pass in the controllers. The app listens to the
  // controllers for changes, then passes them further down to views.
  runApp(MyApp(
    settingsController: settingsController,
    cameraController: cameraController,
  ));
}
