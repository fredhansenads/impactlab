import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_escolar/main.dart';
import 'package:portal_escolar/core/controller.dart';
import 'package:portal_escolar/core/models.dart';
import 'package:portal_escolar/data/demo_repository.dart';

void main() {
  for (final size in [
    const Size(360, 800),
    const Size(768, 1024),
    const Size(1440, 1000),
  ]) {
    testWidgets('All profiles and navigation fit $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = DemoSchoolRepository(),
          c = SchoolController(DemoSchoolRepository());
      await c.refresh();
      await tester.pumpWidget(SchoolApp(c));
      await tester.pumpAndSettle();
      expect(find.text('ImpactLab'), findsOneWidget);
      expect(tester.takeException(), isNull);
      for (final label in [
        'Agenda',
        'Missões',
        'Carteira',
        'Recompensas',
        'Início',
      ]) {
        await tester.tap(find.text(label).first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: label);
      }
      for (final role in AccessRole.values) {
        repo.switchDemoRole(role);
        await c.switchRole(role);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: role.name);
      }
    });
  }
  testWidgets('Student sends delivery through UI', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = SchoolController(DemoSchoolRepository());
    await c.refresh();
    await tester.pumpWidget(SchoolApp(c));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Um pequeno ecossistema').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enviar minha participação'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField),
      'Observei árvores, pássaros e insetos.',
    );
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(c.snapshot.submissions.single['status'], 'submitted');
    expect(c.snapshot.wallet('student')['available'], 40);
    expect(tester.takeException(), isNull);
  });
}
