import 'dart:io';

import 'package:image/image.dart' as img;

/// Crops the upper band of an Egyptian tasreeh/رخصة photo where the plate box row usually sits.
/// Helps Gemini focus on digits + letters without mixing dates or names.
Future<File?> cropTasreehPlateBand(File source) async {
  try {
    final bytes = await source.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final w = decoded.width;
    final h = decoded.height;
    if (w < 80 || h < 80) return null;

    // Wide upper band: plate row position varies (tasreeh vs رخصة, photo angle).
    final x = (w * 0.05).round().clamp(0, w - 1);
    final y = (h * 0.04).round().clamp(0, h - 1);
    final cw = (w * 0.90).round().clamp(1, w - x);
    final ch = (h * 0.42).round().clamp(1, h - y);

    final cropped = img.copyCrop(decoded, x: x, y: y, width: cw, height: ch);
    final encoded = img.encodeJpg(cropped, quality: 92);
    final outPath =
        '${source.parent.path}/plate_crop_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final f = File(outPath);
    await f.writeAsBytes(encoded);
    return f;
  } catch (_) {
    return null;
  }
}
