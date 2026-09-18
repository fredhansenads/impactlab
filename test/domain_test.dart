import 'package:flutter_test/flutter_test.dart';
import 'package:portal_escolar/core/controller.dart';
import 'package:portal_escolar/core/models.dart';
import 'package:portal_escolar/data/demo_repository.dart';

void main() {
  late DemoSchoolRepository r;
  setUp(() => r = DemoSchoolRepository());
  Future<void> submit([String activity = 'a1']) async {
    r.switchDemoRole(AccessRole.student);
    await r.execute('submit', {
      'activity_id': activity,
      'text': 'Realizei os critérios propostos.',
    });
  }

  Future<void> approve([String activity = 'a1']) async {
    r.switchDemoRole(AccessRole.teacher);
    final id = r
        .rows('submissions')
        .firstWhere((s) => s['activity_id'] == activity)['id'];
    await r.execute('validate', {
      'ids': [id],
      'approve': true,
    });
  }

  Future<void> reserve([String request = 'request-1']) async {
    r.switchDemoRole(AccessRole.student);
    await r.execute('reserve', {'reward_id': 'r1', 'request_id': request});
  }

  test(
    'Integrated publication, delivery, approval, reservation and pickup',
    () async {
      r.switchDemoRole(AccessRole.teacher);
      await r.execute('publish', {
        'title': 'Leitura científica',
        'description': 'Leia um texto e registre duas ideias.',
        'kind': 'academic',
        'subject': 'Ciências',
        'class_id': 'c1',
        'category': 'Leitura',
        'criteria': 'Duas ideias registradas; alternativa: leitura assistida.',
        'coins': 10,
        'validator': 'teacher',
        'collective': false,
        'frequency': 'once',
        'limit': 1,
        'start_at': DateTime.now()
            .subtract(const Duration(days: 1))
            .toIso8601String(),
        'due_at': DateTime.now().add(const Duration(days: 2)).toIso8601String(),
      });
      final id = r.rows('activities').last['id'] as String;
      await submit(id);
      expect(r.wallet('student')['available'], 40);
      await approve(id);
      expect(r.wallet('student')['available'], 50);
      await reserve();
      expect(r.wallet('student')['available'], 20);
      expect(r.wallet('student')['reserved'], 30);
      r.switchDemoRole(AccessRole.delivery);
      await r.execute('deliver', {
        'code': r.rows('redemptions').single['code'],
      });
      expect(r.wallet('student')['reserved'], 0);
      expect(r.wallet('student')['available'], 20);
      r.switchDemoRole(AccessRole.guardian);
      final s = await r.load();
      expect(s.submissions.single['status'], 'completed');
      expect(s.redemptions.single['status'], 'delivered');
      expect(s.rows('wallets'), hasLength(1));
    },
  );
  test('Repeated approval is idempotent', () async {
    await submit();
    await approve();
    await approve();
    expect(r.wallet('student')['available'], 50);
    expect(
      r.rows('ledger').where((l) => l['reference'].toString().endsWith(':1')),
      hasLength(1),
    );
  });
  test('Student cannot validate, publish, set rules or correct', () async {
    await submit();
    for (final op in ['validate', 'publish', 'rules', 'correct']) {
      await expectLater(
        r.execute(op, {
          'ids': [r.rows('submissions').single['id']],
          'approve': true,
          'id': 'opening-student',
          'coins': 999,
        }),
        throwsA(isA<RuleViolation>()),
      );
    }
    expect(r.wallet('student')['available'], 40);
  });
  test('Teacher is limited to assigned subject', () async {
    r.switchDemoRole(AccessRole.teacher);
    await expectLater(
      r.execute('publish', {
        'kind': 'academic',
        'class_id': 'c1',
        'subject': 'Português',
      }),
      throwsA(isA<RuleViolation>()),
    );
  });
  test('Guardian validates only explicitly assigned family mission', () async {
    await submit();
    r.switchDemoRole(AccessRole.guardian);
    await expectLater(
      r.execute('validate', {
        'ids': [r.rows('submissions').single['id']],
        'approve': true,
      }),
      throwsA(isA<RuleViolation>()),
    );
    await submit('a4');
    r.switchDemoRole(AccessRole.guardian);
    await r.execute('validate', {
      'ids': [r.rows('submissions').last['id']],
      'approve': true,
    });
    expect(r.wallet('student')['available'], 55);
  });
  test('Insufficient balance leaves stock unchanged', () async {
    await expectLater(
      r.execute('reserve', {'reward_id': 'r2', 'request_id': 'expensive'}),
      throwsA(isA<RuleViolation>()),
    );
    expect(r.find('rewards', 'r2')['stock'], 8);
    expect(r.wallet('student')['available'], 40);
  });
  test('Concurrent attempts cannot double spend', () async {
    final results = await Future.wait(
      List.generate(
        10,
        (i) => r
            .execute('reserve', {'reward_id': 'r1', 'request_id': 'q$i'})
            .then((_) => true)
            .catchError((_) => false),
      ),
    );
    expect(results.where((v) => v), hasLength(1));
    expect(r.wallet('student')['available'], 10);
    expect(r.find('rewards', 'r1')['stock'], 11);
  });
  test('Retry with same request is idempotent', () async {
    await reserve();
    await reserve();
    expect(r.rows('redemptions'), hasLength(1));
  });
  test('Cancellation restores stock and available balance once', () async {
    await reserve();
    final id = r.rows('redemptions').single['id'];
    await r.execute('cancel_redemption', {'id': id});
    expect(r.wallet('student')['available'], 40);
    expect(r.wallet('student')['reserved'], 0);
    expect(r.find('rewards', 'r1')['stock'], 12);
    await expectLater(
      r.execute('cancel_redemption', {'id': id}),
      throwsA(isA<RuleViolation>()),
    );
  });
  test('Pickup code cannot be reused or used after cancellation', () async {
    await reserve();
    final code = r.rows('redemptions').single['code'];
    r.switchDemoRole(AccessRole.delivery);
    await r.execute('deliver', {'code': code});
    await expectLater(
      r.execute('deliver', {'code': code}),
      throwsA(isA<RuleViolation>()),
    );
  });
  test('Delivery sees no academic or wallet data', () async {
    await submit();
    r.switchDemoRole(AccessRole.delivery);
    final s = await r.load();
    expect(s.activities, isEmpty);
    expect(s.submissions, isEmpty);
    expect(s.rows('wallets'), isEmpty);
    expect(s.data.keys, containsAll(['redemptions']));
  });
  test(
    'Personal reminders private even from guardian and coordination',
    () async {
      await r.execute('personal', {
        'title': 'Meu lembrete',
        'due_at': DateTime.now().toIso8601String(),
      });
      for (final role in [
        AccessRole.guardian,
        AccessRole.coordinator,
        AccessRole.teacher,
      ]) {
        r.switchDemoRole(role);
        expect((await r.load()).rows('personal'), isEmpty);
      }
    },
  );
  test('Corrections preserve original ledger and cannot repeat', () async {
    r.switchDemoRole(AccessRole.coordinator);
    await r.execute('correct', {
      'id': 'opening-student',
      'reason': 'Importação demonstrativa indevida',
    });
    expect(r.wallet('student')['available'], 0);
    expect(r.wallet('student')['earned'], 40);
    expect(r.find('ledger', 'opening-student')['amount'], 40);
    await expectLater(
      r.execute('correct', {
        'id': 'opening-student',
        'reason': 'Tentativa duplicada de correção',
      }),
      throwsA(isA<RuleViolation>()),
    );
  });
  test('Single participation limit survives review request', () async {
    await submit();
    await approve();
    r.switchDemoRole(AccessRole.student);
    await r.execute('review', {
      'id': r.rows('submissions').single['id'],
      'reason': 'Quero revisar o retorno',
    });
    await expectLater(
      r.execute('submit', {'activity_id': 'a1', 'text': 'Repetição'}),
      throwsA(isA<RuleViolation>()),
    );
  });
  test('Batch validation rolls back on forbidden delivery', () async {
    await submit();
    await submit('a4');
    r.switchDemoRole(AccessRole.teacher);
    await expectLater(
      r.execute('validate', {
        'ids': r.rows('submissions').map((s) => s['id']).toList(),
        'approve': true,
      }),
      throwsA(isA<RuleViolation>()),
    );
    expect(r.wallet('student')['available'], 40);
    expect(
      r.rows('submissions').every((s) => s['status'] == 'submitted'),
      isTrue,
    );
  });
  test('Offline mutations rejected without state change', () async {
    r.online = false;
    await expectLater(
      r.execute('reserve', {'reward_id': 'r1', 'request_id': 'offline'}),
      throwsA(isA<RuleViolation>()),
    );
    expect(r.wallet('student')['available'], 40);
  });
  test('Late status is independent of completion and uses submission time', () {
    final a = {'due_at': '2026-09-18T12:00:00', 'cancelled': false};
    expect(
      isLate(a, {'submitted_at': '2026-09-18T11:00:00'}, DateTime(2026, 9, 20)),
      isFalse,
    );
    expect(
      isLate(a, {'submitted_at': '2026-09-18T13:00:00'}, DateTime(2026, 9, 20)),
      isTrue,
    );
  });
  test(
    'Daily participation, achievement and collective progress remain after spending',
    () async {
      var date = DateTime(2026, 9, 18, 12);
      final demo = DemoSchoolRepository(clock: () => date);
      final activity = demo.find('activities', 'a2');
      activity['frequency'] = 'daily';
      activity['limit'] = 5;
      for (var i = 0; i < 5; i++) {
        demo.switchDemoRole(AccessRole.student);
        await demo.execute('submit', {
          'activity_id': 'a2',
          'text': 'Organizei cinco materiais.',
        });
        demo.switchDemoRole(AccessRole.teacher);
        await demo.execute('validate', {
          'ids': [demo.rows('submissions').single['id']],
          'approve': true,
        });
        if (i == 0) {
          demo.switchDemoRole(AccessRole.student);
          await expectLater(
            demo.execute('submit', {
              'activity_id': 'a2',
              'text': 'Ainda no mesmo período.',
            }),
            throwsA(isA<RuleViolation>()),
          );
        }
        date = date.add(const Duration(days: 1));
      }
      expect(demo.rows('achievements'), hasLength(1));
      expect(demo.rows('contributions'), hasLength(5));
      demo.switchDemoRole(AccessRole.student);
      await demo.execute('reserve', {
        'reward_id': 'r1',
        'request_id': 'after-badge',
      });
      expect(demo.wallet('student')['earned'], 115);
      expect(demo.rows('achievements'), hasLength(1));
      expect(
        (await demo.load())
            .rows('contributions')
            .every((c) => !c.containsKey('student_id')),
        isTrue,
      );
    },
  );
  test(
    'Retry after a lost response does not create a second reservation',
    () async {
      final repository = LostResponseRepository();
      final controller = SchoolController(repository);
      await controller.refresh();
      expect(await controller.act('reserve', {'reward_id': 'r1'}), isFalse);
      expect(repository.wallet('student')['available'], 10);
      expect(await controller.act('reserve', {'reward_id': 'r1'}), isTrue);
      expect(repository.rows('redemptions'), hasLength(1));
      expect(repository.wallet('student')['reserved'], 30);
      controller.dispose();
    },
  );
}

class LostResponseRepository extends DemoSchoolRepository {
  bool loseResponse = true;
  @override
  Future<void> execute(String operation, Map<String, dynamic> payload) async {
    await super.execute(operation, payload);
    if (loseResponse) {
      loseResponse = false;
      throw StateError('Simulated response lost after server commit');
    }
  }
}
