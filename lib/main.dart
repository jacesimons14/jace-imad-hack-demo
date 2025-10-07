import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/settings/settings_controller.dart';
import 'src/settings/settings_service.dart';
import 'src/camera/camera_controller.dart';
import 'src/camera/camera_service.dart';
import 'src/ar/ar_controller.dart';
import 'src/aruco/aruco_processor.dart';

void main() async {
  // Ensure that plugin services are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Set up the SettingsController, which will glue user settings to multiple
  // Flutter Widgets.
  final settingsController = SettingsController(SettingsService());

  // Set up the CameraViewController for camera access
  final cameraController = CameraViewController(CameraService());

  // Set up the ARController for AR functionality
  final arController = ARController();

  // Set up the ArucoProcessor for marker detection
  final arucoProcessor = ArucoProcessor();

  // Load the user's preferred theme while the splash screen is displayed.
  // This prevents a sudden theme change when the app is first displayed.
  await settingsController.loadSettings();

  // Run the app and pass in the controllers. The app listens to the
  // controllers for changes, then passes them further down to views.
  runApp(MyApp(
    settingsController: settingsController,
    cameraController: cameraController,
    arController: arController,
    arucoProcessor: arucoProcessor,
  ));
}
