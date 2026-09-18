import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_escolar/main.dart';
import 'package:portal_escolar/core/controller.dart';
import 'package:portal_escolar/core/models.dart';
import 'package:portal_escolar/data/demo_repository.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(1440, 1000)]) {
    testWidgets('Rendered preview $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final font = FontLoader('Roboto')
        ..addFont(
          Future.value(
            ByteData.sublistView(
              File('test/fonts/roboto-regular.ttf').readAsBytesSync(),
            ),
          ),
        );
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(
          Future.value(
            ByteData.sublistView(
              File('test/fonts/materialicons-regular.otf').readAsBytesSync(),
            ),
          ),
        );
      await icons.load();
      final c = SchoolController(DemoSchoolRepository());
      await c.refresh();
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(key: boundary, child: SchoolApp(c)),
      );
      await tester.pumpAndSettle();
      Future<void> capture(String name) async {
        expect(tester.takeException(), isNull);
        if (!const bool.fromEnvironment('CAPTURE_SCREENSHOTS')) return;
        await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await render.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            'docs/screenshots/$name-${size.width.toInt()}.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await capture('inicio');
      for (final label in ['Agenda', 'Missões', 'Carteira', 'Recompensas']) {
        await tester.tap(find.text(label).first);
        await tester.pumpAndSettle();
        await capture(label.toLowerCase().replaceAll('õ', 'o'));
      }
      await c.switchRole(AccessRole.teacher);
      await tester.pumpAndSettle();
      await capture('professor');
    });
  }
}
