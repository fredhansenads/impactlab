import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:portal_escolar/core/brand.dart';
import 'package:portal_escolar/features/auth/login_view.dart';
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
      await tester.runAsync(
        () => precacheImage(
          const AssetImage(brandLogoAsset),
          tester.element(find.byType(Shell)),
        ),
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
          final path = 'docs/screenshots/$name-${size.width.toInt()}.png';
          // Replace atomically so Windows previewers can keep the old file open.
          File('$path.tmp')
            ..writeAsBytesSync(bytes!.buffer.asUint8List())
            ..renameSync(path);
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
      final theme = Theme.of(tester.element(find.byType(Scaffold).first));
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            theme: theme,
            debugShowCheckedModeBanner: false,
            locale: const Locale('pt', 'BR'),
            supportedLocales: const [Locale('pt', 'BR')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: LoginView(c),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await capture('acesso');
    });
  }
}
