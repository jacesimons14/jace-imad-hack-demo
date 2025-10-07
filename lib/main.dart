import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/settings/settings_controller.dart';
import 'src/settings/settings_service.dart';
import 'src/camera/camera_controller.dart';
import 'src/camera/camera_service.dart';

void main() async {
  // Ensure that plugin services are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Set up the SettingsController, which will glue user settings to multiple
  // Flutter Widgets.
  final settingsController = SettingsController(SettingsService());

  // Set up the CameraViewController for AR functionality
  final cameraController = CameraViewController(CameraService());

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
