// Deterministic build asset renderer: preserves the supplied JPEG without redesign.
// Run: flutter test tool/generate_brand_assets.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Render platform icon sizes from the original ImpactLab logo', () async {
    final codec = await ui.instantiateImageCodec(
      File('assets/branding/impactlab-logo.jpeg').readAsBytesSync(),
    );
    final source = (await codec.getNextFrame()).image;
    Future<void> render(String path, int size, {double inset = .07}) async {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawColor(const ui.Color(0xFF02102D), ui.BlendMode.src);
      final available = size * (1 - 2 * inset);
      final scale = math.min(
        available / source.width,
        available / source.height,
      );
      final w = source.width * scale, h = source.height * scale;
      canvas.drawImageRect(
        source,
        ui.Rect.fromLTWH(
          0,
          0,
          source.width.toDouble(),
          source.height.toDouble(),
        ),
        ui.Rect.fromLTWH((size - w) / 2, (size - h) / 2, w, h),
        ui.Paint()..filterQuality = ui.FilterQuality.high,
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(size, size);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File(path);
      await file.parent.create(recursive: true);
      final temporary = File('$path.tmp');
      await temporary.writeAsBytes(bytes!.buffer.asUint8List());
      await temporary.rename(path);
      image.dispose();
      picture.dispose();
    }

    for (final density in {
      'mdpi': 48,
      'hdpi': 72,
      'xhdpi': 96,
      'xxhdpi': 144,
      'xxxhdpi': 192,
    }.entries) {
      await render(
        'android/app/src/main/res/mipmap-${density.key}/ic_launcher.png',
        density.value,
      );
    }
    final catalog =
        jsonDecode(
              File(
                'ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json',
              ).readAsStringSync(),
            )
            as Map;
    for (final item in catalog['images'] as List) {
      final size =
          (double.parse((item['size'] as String).split('x').first) *
                  double.parse((item['scale'] as String).replaceAll('x', '')))
              .round();
      await render(
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/${item['filename']}',
        size,
      );
    }
    await render('web/favicon.png', 48);
    for (final scale in [1, 2, 3]) {
      final suffix = scale == 1 ? '' : '@${scale}x';
      await render(
        'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage$suffix.png',
        192 * scale,
      );
    }
    for (final size in [192, 512]) {
      await render('web/icons/Icon-$size.png', size);
      await render('web/icons/Icon-maskable-$size.png', size, inset: .20);
    }
    source.dispose();
    codec.dispose();
  });
}
