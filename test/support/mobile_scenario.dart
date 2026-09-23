import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_escolar/core/models.dart';
import 'package:portal_escolar/main.dart' as app;

/// Shared by the desktop widget harness and native integration tests.
Future<void> mobileScenario(WidgetTester tester) async {
  await app.main();
  await tester.pumpAndSettle();
  expect(find.text('ImpactLab'), findsOneWidget);
  for (final label in ['Agenda', 'Missões', 'Carteira', 'Recompensas']) {
    await tester.tap(find.text(label).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: label);
  }
  for (final role in AccessRole.values) {
    await tester.tap(find.byType(DropdownButton<AccessRole>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(role.label).last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: role.label);
  }
  await tester.tap(find.byType(DropdownButton<AccessRole>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Aluno').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Missões').first);
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Um pequeno ecossistema').first);
  await tester.tap(find.text('Um pequeno ecossistema').first);
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Enviar minha participação'));
  await tester.tap(find.text('Enviar minha participação'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byType(TextFormField),
    'Observei árvores e insetos.',
  );
  await tester.ensureVisible(find.text('Salvar'));
  await tester.tap(find.text('Salvar'));
  await tester.pumpAndSettle();
  expect(find.textContaining('Lia'), findsWidgets);
  expect(find.textContaining('Aguardando validação'), findsWidgets);
  expect(tester.takeException(), isNull);
}
