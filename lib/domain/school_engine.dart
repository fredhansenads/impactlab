import 'dart:convert';
import 'dart:math';
import '../core/models.dart';

/// Em memória, síncrono dentro de cada comando. Não substitui transações do servidor.
class SchoolEngine {
  SchoolEngine(JsonMap seed, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now {
    data = Map<String, dynamic>.from(jsonDecode(jsonEncode(seed)) as Map);
  }
  final DateTime Function() clock;
  late JsonMap data;
  AccessRole role = AccessRole.student;
  bool online = true;
  int _sequence = 0;
  final _random = Random.secure();
  List<JsonMap> rows(String key) => (data[key] as List).cast<JsonMap>();
  bool get isDemo => true;
  Account get account => Account.fromJson(
    rows('profiles').firstWhere((p) => p['id'] == role.name),
  );
  void switchDemoRole(AccessRole role) {
    this.role = role;
  }

  Future<void> signIn(String email, String password) async {}
  Future<void> signOut() async {
    role = AccessRole.student;
  }

  String id() => 'demo-${++_sequence}';
  String get now => clock().toIso8601String();
  void require(bool condition, String message) {
    if (!condition) throw RuleViolation(message);
  }

  JsonMap find(String table, String value) => rows(table).firstWhere(
    (r) => r['id'] == value,
    orElse: () => throw RuleViolation('Registro não encontrado.'),
  );
  bool linked(String student) => rows(
    'links',
  ).any((l) => l['guardian_id'] == account.id && l['student_id'] == student);
  bool teaches(JsonMap activity) => rows('assignments').any(
    (t) =>
        t['teacher_id'] == account.id &&
        t['class_id'] == activity['class_id'] &&
        (activity['kind'] != 'academic' || t['subject'] == activity['subject']),
  );
  bool participates(JsonMap a, String s) =>
      rows(
        'enrollments',
      ).any((e) => e['student_id'] == s && e['class_id'] == a['class_id']) &&
      ((a['participants'] as List?)?.isNotEmpty != true ||
          (a['participants'] as List).contains(s));
  bool seesStudent(String s) =>
      role == AccessRole.coordinator ||
      account.id == s ||
      (role == AccessRole.guardian && linked(s)) ||
      (role == AccessRole.teacher &&
          rows('enrollments').any(
            (e) =>
                e['student_id'] == s &&
                rows('assignments').any(
                  (t) =>
                      t['teacher_id'] == account.id &&
                      t['class_id'] == e['class_id'],
                ),
          ));
  bool seesClass(String id) =>
      role == AccessRole.coordinator ||
      (role == AccessRole.student &&
          rows(
            'enrollments',
          ).any((e) => e['class_id'] == id && e['student_id'] == account.id)) ||
      (role == AccessRole.teacher &&
          rows(
            'assignments',
          ).any((e) => e['class_id'] == id && e['teacher_id'] == account.id)) ||
      (role == AccessRole.guardian &&
          rows(
            'enrollments',
          ).any((e) => e['class_id'] == id && linked(e['student_id'])));
  bool seesActivity(JsonMap a) =>
      role == AccessRole.coordinator ||
      (role == AccessRole.teacher && teaches(a)) ||
      (role == AccessRole.student && participates(a, account.id)) ||
      (role == AccessRole.guardian &&
          rows('links').any(
            (l) =>
                l['guardian_id'] == account.id &&
                participates(a, l['student_id']),
          ));
  JsonMap wallet(String s) =>
      rows('wallets').firstWhere((w) => w['student_id'] == s);
  void movement(
    String s,
    String kind,
    int amount,
    String title,
    String reference,
  ) {
    rows('ledger').insert(0, {
      'id': id(),
      'student_id': s,
      'kind': kind,
      'amount': amount,
      'title': title,
      'reference': reference,
      'actor': account.name,
      'at': now,
    });
  }

  void notify(String s, String text) => rows(
    'notifications',
  ).insert(0, {'id': id(), 'student_id': s, 'text': text, 'at': now});
  Future<SchoolSnapshot> load() async {
    final result = <String, dynamic>{};
    if (role == AccessRole.delivery) {
      return SchoolSnapshot({
        'redemptions': rows('redemptions')
            .map(
              (r) => {
                'id': r['id'],
                'code': r['code'],
                'name': r['name'],
                'status': r['status'],
                'location': r['location'],
              },
            )
            .toList(),
      });
    }
    for (final key in data.keys) {
      result[key] = rows(key)
          .where((r) {
            if (key == 'personal') return r['student_id'] == account.id;
            if ([
              'wallets',
              'ledger',
              'redemptions',
              'achievements',
              'notifications',
            ].contains(key)) {
              return seesStudent(r['student_id']);
            }
            if (key == 'submissions') {
              return seesStudent(r['student_id']) &&
                  seesActivity(find('activities', r['activity_id']));
            }
            if (key == 'activities') return seesActivity(r);
            if (key == 'audit') return role == AccessRole.coordinator;
            if (key == 'profiles') {
              return role == AccessRole.coordinator ||
                  r['id'] == account.id ||
                  (r['role'] == 'student' && seesStudent(r['id']));
            }
            if (['links', 'enrollments'].contains(key)) {
              return seesStudent(r['student_id']);
            }
            if (key == 'assignments') {
              return role == AccessRole.coordinator ||
                  r['teacher_id'] == account.id;
            }
            if (key == 'classes') return seesClass(r['id']);
            if (['goals', 'contributions'].contains(key)) {
              return seesClass(r['class_id']);
            }
            return true;
          })
          .map(
            (r) => key == 'contributions'
                ? <String, dynamic>{'class_id': r['class_id']}
                : r,
          )
          .toList();
    }
    return SchoolSnapshot(
      Map<String, dynamic>.from(jsonDecode(jsonEncode(result)) as Map),
    );
  }

  Future<void> execute(String operation, JsonMap p) async {
    require(
      online,
      'Esta ação precisa de conexão. Nenhuma alteração foi realizada.',
    );
    // Rollback inclusive para validações em lote.
    final before = jsonEncode(data);
    try {
      _execute(operation, p);
    } catch (_) {
      data = Map<String, dynamic>.from(jsonDecode(before) as Map);
      for (final key in data.keys) {
        data[key] = (data[key] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
      rethrow;
    }
  }

  void _execute(String operation, JsonMap p) {
    switch (operation) {
      case 'publish':
        require(
          role == AccessRole.teacher || role == AccessRole.coordinator,
          'Você não pode publicar atividades.',
        );
        require(
          role == AccessRole.coordinator || teaches(p),
          'Turma ou disciplina fora da sua atribuição.',
        );
        require(
          (p['title'] as String).trim().isNotEmpty &&
              (p['criteria'] as String).trim().isNotEmpty,
          'Informe título e critérios observáveis.',
        );
        require(
          (p['coins'] as int) >= 0 &&
              (p['limit'] as int) > 0 &&
              ['once', 'daily', 'weekly'].contains(p['frequency']),
          'Pontuação ou frequência inválida.',
        );
        require(
          DateTime.parse(p['due_at']).isAfter(DateTime.parse(p['start_at'])),
          'O prazo deve ser posterior ao início.',
        );
        require(
          p['validator'] != 'guardian' || p['kind'] == 'practice',
          'A família confirma somente boas práticas atribuídas.',
        );
        rows(
          'activities',
        ).add({...p, 'id': id(), 'teacher_id': account.id, 'cancelled': false});
      case 'submit':
        require(
          role == AccessRole.student,
          'Somente o aluno envia a própria entrega.',
        );
        final a = find('activities', p['activity_id']);
        require(
          participates(a, account.id) && a['cancelled'] != true,
          'Atividade indisponível.',
        );
        require(
          !clock().isBefore(DateTime.parse(a['start_at'])),
          'A atividade ainda não começou.',
        );
        require(
          (p['text'] as String).trim().isNotEmpty,
          'Descreva sua entrega.',
        );
        final list = rows('submissions')
            .where(
              (s) =>
                  s['activity_id'] == a['id'] && s['student_id'] == account.id,
            )
            .toList();
        final s = list.firstOrNull;
        require(
          s == null || s['status'] == 'changes' || s['status'] == 'completed',
          'A entrega já está aguardando validação.',
        );
        if (s?['status'] == 'completed') {
          require(
            (s!['count'] as int) < (a['limit'] as int),
            'Limite de participação atingido.',
          );
          final elapsed = clock().difference(DateTime.parse(s['validated_at']));
          require(
            a['frequency'] != 'once' &&
                elapsed >= Duration(days: a['frequency'] == 'daily' ? 1 : 7),
            'Aguarde o próximo período de participação.',
          );
        }
        final entry =
            s ??
            {
              'id': id(),
              'activity_id': a['id'],
              'student_id': account.id,
              'count': 0,
            };
        entry.addAll({
          'text': p['text'],
          'status': 'submitted',
          'submitted_at': now,
          'review': null,
        });
        if (s == null) rows('submissions').add(entry);
      case 'validate':
        final ids = (p['ids'] as List).cast<String>();
        require(ids.isNotEmpty, 'Selecione pelo menos uma entrega.');
        for (final sid in ids.toSet()) {
          final s = find('submissions', sid),
              a = find('activities', find('submissions', sid)['activity_id']);
          require(a['cancelled'] != true, 'Atividade cancelada.');
          require(
            role == AccessRole.coordinator ||
                (role == AccessRole.teacher &&
                    teaches(a) &&
                    a['validator'] == 'teacher') ||
                (role == AccessRole.guardian &&
                    linked(s['student_id']) &&
                    a['validator'] == 'guardian'),
            'Você não pode validar esta entrega.',
          );
          if (s['status'] == 'completed' && p['approve'] == true) continue;
          require(
            s['status'] == 'submitted',
            'A entrega não está aguardando validação.',
          );
          if (p['approve'] != true) {
            require(
              (p['feedback'] as String? ?? '').trim().isNotEmpty,
              'Explique os ajustes necessários.',
            );
            s.addAll({'status': 'changes', 'feedback': p['feedback']});
          } else {
            require(
              (s['count'] as int) < (a['limit'] as int),
              'Limite de participação atingido.',
            );
            s.addAll({
              'status': 'completed',
              'count': s['count'] + 1,
              'validated_at': now,
              'validator_id': account.id,
              'review': null,
            });
            final w = wallet(s['student_id']);
            w['available'] += a['coins'];
            w['earned'] += a['coins'];
            movement(
              s['student_id'],
              'gain',
              a['coins'],
              a['title'],
              '${s['id']}:${s['count']}',
            );
            if (a['collective'] == true) {
              rows('contributions').add({
                'id': id(),
                'class_id': a['class_id'],
                'student_id': s['student_id'],
                'submission_id': s['id'],
                'category': a['category'],
              });
            }
            final count = rows('contributions')
                .where(
                  (c) =>
                      c['student_id'] == s['student_id'] &&
                      c['category'] == 'Colaboração',
                )
                .length;
            if (count >= 5 &&
                !rows('achievements').any(
                  (b) =>
                      b['student_id'] == s['student_id'] &&
                      b['name'] == 'Parceiro da Turma',
                )) {
              rows('achievements').add({
                'id': id(),
                'student_id': s['student_id'],
                'name': 'Parceiro da Turma',
                'at': now,
              });
            }
          }
          notify(
            s['student_id'],
            'Há uma atualização na avaliação de uma atividade.',
          );
        }
      case 'review':
        final s = find('submissions', p['id']);
        require(
          role == AccessRole.student &&
              s['student_id'] == account.id &&
              ['completed', 'changes'].contains(s['status']),
          'Revisão indisponível.',
        );
        require(
          (p['reason'] as String).trim().isNotEmpty,
          'Informe o motivo da revisão.',
        );
        s['review'] = p['reason'];
      case 'adapt':
        final a = find('activities', p['id']);
        require(
          role == AccessRole.coordinator ||
              (role == AccessRole.teacher && teaches(a)),
          'Atividade fora da sua atribuição.',
        );
        require(
          (p['reason'] as String? ?? '').trim().isNotEmpty,
          'Informe a justificativa.',
        );
        if (p['due_at'] != null) {
          require(
            !DateTime.parse(p['due_at']).isBefore(DateTime.parse(a['due_at'])),
            'Use uma data posterior ao prazo atual.',
          );
          a['due_at'] = p['due_at'];
        }
        if (p['criteria'] != null) a['criteria'] = p['criteria'];
        if (p['cancelled'] == true) a['cancelled'] = true;
      case 'personal':
        require(
          role == AccessRole.student,
          'Compromissos pessoais são privados do aluno.',
        );
        require((p['title'] as String).trim().isNotEmpty, 'Informe o título.');
        rows('personal').add({...p, 'id': id(), 'student_id': account.id});
      case 'reserve':
        require(
          role == AccessRole.student,
          'Somente o aluno solicita seu resgate.',
        );
        if (rows('redemptions').any(
          (r) =>
              r['student_id'] == account.id &&
              r['request_id'] == p['request_id'],
        )) {
          return;
        }
        require(
          (p['request_id'] as String? ?? '').isNotEmpty,
          'Identificador de solicitação obrigatório.',
        );
        final r = find('rewards', p['reward_id']), w = wallet(account.id);
        require(
          !clock().isBefore(DateTime.parse(r['start_at'])) &&
              !clock().isAfter(DateTime.parse(r['end_at'])),
          'Recompensa fora do período disponível.',
        );
        require(r['stock'] > 0, 'Esta recompensa está sem estoque.');
        require(
          w['available'] >= r['price'],
          'Você ainda não tem Star Coins suficientes.',
        );
        require(
          rows('redemptions')
                  .where(
                    (x) =>
                        x['student_id'] == account.id &&
                        x['reward_id'] == r['id'] &&
                        x['status'] != 'cancelled',
                  )
                  .length <
              r['limit'],
          'Limite de resgates atingido.',
        );
        final rid = id();
        final code = List.generate(
          12,
          (_) => 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'[_random.nextInt(32)],
        ).join();
        rows('redemptions').insert(0, {
          'id': rid,
          'reward_id': r['id'],
          'student_id': account.id,
          'request_id': p['request_id'],
          'name': r['name'],
          'price': r['price'],
          'location': r['location'],
          'code': code,
          'status': 'reserved',
          'at': now,
        });
        w['available'] -= r['price'];
        w['reserved'] += r['price'];
        r['stock'] -= 1;
        movement(account.id, 'reserve', -r['price'] as int, r['name'], rid);
        notify(account.id, 'Seu resgate está pronto para retirada.');
      case 'deliver':
      case 'cancel_redemption':
        final r = operation == 'deliver'
            ? rows('redemptions').firstWhere(
                (r) => r['code'] == p['code'],
                orElse: () => throw RuleViolation('Código inválido.'),
              )
            : find('redemptions', p['id']);
        require(
          operation == 'deliver'
              ? [AccessRole.delivery, AccessRole.coordinator].contains(role)
              : (role == AccessRole.coordinator ||
                    (role == AccessRole.student &&
                        r['student_id'] == account.id)),
          'Você não pode realizar esta operação.',
        );
        require(
          r['status'] == 'reserved',
          'Este código já foi utilizado ou cancelado.',
        );
        final w = wallet(r['student_id']);
        w['reserved'] -= r['price'];
        if (operation == 'deliver') {
          r['status'] = 'delivered';
          movement(
            r['student_id'],
            'spend',
            -r['price'] as int,
            r['name'],
            r['id'],
          );
        } else {
          r['status'] = 'cancelled';
          w['available'] += r['price'];
          find('rewards', r['reward_id'])['stock'] += 1;
          movement(r['student_id'], 'refund', r['price'], r['name'], r['id']);
        }
        notify(r['student_id'], 'O andamento de um resgate foi atualizado.');
      case 'save_reward':
        require(
          role == AccessRole.coordinator,
          'Somente a coordenação administra recompensas.',
        );
        require(
          p['price'] > 0 &&
              p['stock'] >= 0 &&
              p['limit'] > 0 &&
              (p['name'] as String).trim().isNotEmpty,
          'Preencha preço, estoque, limite e nome corretamente.',
        );
        require(
          DateTime.parse(p['end_at']).isAfter(DateTime.parse(p['start_at'])),
          'Período inválido.',
        );
        if (p['id'] == null) {
          rows('rewards').add({...p, 'id': id()});
        } else {
          find('rewards', p['id']).addAll(p);
        }
      case 'rules':
        require(
          role == AccessRole.coordinator,
          'Somente a coordenação define as regras.',
        );
        require(p['coins'] >= 0, 'A pontuação não pode ser negativa.');
        find('rules', p['id'])['coins'] = p['coins'];
      case 'correct':
        require(
          role == AccessRole.coordinator,
          'Somente a coordenação corrige lançamentos.',
        );
        final entry = find('ledger', p['id']);
        require(
          entry['kind'] == 'gain' &&
              !rows('ledger').any(
                (l) =>
                    l['kind'] == 'correction' && l['reference'] == entry['id'],
              ),
          'Lançamento já corrigido ou não elegível.',
        );
        require(
          (p['reason'] as String).trim().length >= 10,
          'Explique o erro do lançamento (mínimo 10 caracteres).',
        );
        final w = wallet(entry['student_id']);
        require(
          w['available'] >= entry['amount'],
          'Saldo disponível insuficiente para estornar. Cancele reservas antes de corrigir.',
        );
        w['available'] -= entry['amount'];
        movement(
          entry['student_id'],
          'correction',
          -entry['amount'] as int,
          'Correção: ${p['reason']}',
          entry['id'],
        );
      case 'invite':
        require(
          role == AccessRole.coordinator,
          'Somente a coordenação cadastra contas.',
        );
        require(
          ['student', 'teacher', 'guardian', 'delivery'].contains(p['role']) &&
              (p['name'] as String).trim().isNotEmpty,
          'Nome ou perfil inválido.',
        );
        final uid = id();
        rows('profiles').add({
          'id': uid,
          'name': p['name'],
          'role': p['role'],
          'school_id': 'school',
        });
        if (p['role'] == 'student') {
          rows('wallets').add({
            'student_id': uid,
            'available': 0,
            'reserved': 0,
            'earned': 0,
          });
        }
      case 'manage':
        require(
          role == AccessRole.coordinator,
          'Somente a coordenação administra cadastros.',
        );
        final table = p['table'] as String;
        require(
          [
            'classes',
            'subjects',
            'enrollments',
            'assignments',
            'links',
          ].contains(table),
          'Cadastro inválido.',
        );
        final row = Map<String, dynamic>.from(p['row']);
        if (table == 'links') {
          require(
            find('profiles', row['guardian_id'])['role'] == 'guardian' &&
                find('profiles', row['student_id'])['role'] == 'student',
            'Vínculos exigem um responsável e um aluno.',
          );
        }
        if (table == 'enrollments') {
          find('classes', row['class_id']);
          require(
            find('profiles', row['student_id'])['role'] == 'student',
            'Perfil deve ser aluno.',
          );
        }
        if (table == 'assignments') {
          find('classes', row['class_id']);
          require(
            find('profiles', row['teacher_id'])['role'] == 'teacher',
            'Perfil deve ser professor.',
          );
          require(
            rows('subjects').any((s) => s['name'] == row['subject']),
            'Disciplina inválida.',
          );
        }
        if (row['id'] != null) {
          if (table == 'subjects') {
            final oldName = find(table, row['id'])['name'];
            for (final item in [
              ...rows('assignments'),
              ...rows('activities'),
            ]) {
              if (item['subject'] == oldName) item['subject'] = row['name'];
            }
          }
          find(table, row['id']).addAll(row);
        } else {
          rows(table).add({...row, 'id': id()});
        }
      default:
        throw RuleViolation('Operação não reconhecida.');
    }
    rows('audit').insert(0, {
      'id': id(),
      'operation': operation,
      'actor': account.name,
      'at': now,
      'reason': p['reason'] ?? '',
      'reference': p['id'] ?? p['activity_id'] ?? p['reward_id'] ?? '',
    });
  }
}
