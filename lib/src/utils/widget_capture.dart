import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

class WidgetCaptureUtil {
  /// Captures the widget associated with [boundaryKey] to a PNG file stored
  /// in the application documents directory with name `[fileName].png`.
  /// Returns the absolute file path.
  static Future<String> captureWidgetToLocalFile(
    GlobalKey boundaryKey,
    String fileName,
  ) async {
    final context = boundaryKey.currentContext;
    if (context == null) {
      throw StateError('RepaintBoundary context is not available');
    }

    final renderObject = context.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      throw StateError('Provided key is not attached to a RepaintBoundary');
    }

    final ui.Image image = await renderObject.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Failed to encode widget image as PNG');
    }
    final Uint8List pngBytes = byteData.buffer.asUint8List();

    final directory = await getApplicationDocumentsDirectory();
    final String filePath = '${directory.path}/$fileName.png';
    final file = File(filePath);
    await file.writeAsBytes(pngBytes, flush: true);
    return filePath;
  }
}
