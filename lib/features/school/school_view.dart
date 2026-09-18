import 'package:flutter/material.dart';
import '../../core/controller.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';
import '../activities/activities_view.dart';
import '../wallet/wallet_view.dart';

class SchoolView extends StatelessWidget {
  const SchoolView(this.c, {super.key});
  final SchoolController c;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionHeading(
        'A escola cuida das regras',
        subtitle: 'Acompanhe a participação e administre as oportunidades.',
      ),
      Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          Tag('${c.snapshot.activities.length} atividades'),
          Tag(
            '${c.snapshot.submissions.where((s) => s['status'] == 'completed').length} participações concluídas',
          ),
          Tag(
            '${c.snapshot.rows('wallets').fold<int>(0, (sum, w) => sum + (w['earned'] as int))} Star Coins concedidas',
          ),
        ],
      ),
      const SectionHeading(
        'Pontuação sugerida',
        subtitle:
            'Os valores preenchem novas publicações. Atividades já publicadas preservam sua recompensa.',
      ),
      for (final r in c.snapshot.rows('rules'))
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(r['name']),
          subtitle: Text('${r['coins']} Star Coins'),
          trailing: IconButton(
            tooltip: 'Editar pontuação',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final p = await editForm(context, 'Pontuação: ${r['name']}', [
                FieldSpec(
                  'coins',
                  'Star Coins',
                  value: '${r['coins']}',
                  number: true,
                ),
              ]);
              if (p != null && context.mounted) {
                await runAction(context, c, 'rules', {...p, 'id': r['id']});
              }
            },
          ),
        ),
      SectionHeading(
        'Recompensas e estoque',
        action: IconButton.filled(
          tooltip: 'Nova recompensa',
          onPressed: () => rewardEditor(context, c),
          icon: const Icon(Icons.add),
        ),
      ),
      for (final r in c.snapshot.rewards)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(r['name']),
          subtitle: StarText(
            '${r['price']} ★ • ${r['stock']} unidades • ${r['location']}',
          ),
          trailing: IconButton(
            tooltip: 'Editar recompensa',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => rewardEditor(context, c, r),
          ),
        ),
      SectionHeading(
        'Cadastros e vínculos',
        action: IconButton.filled(
          tooltip: 'Cadastrar conta',
          icon: const Icon(Icons.person_add_alt),
          onPressed: () async {
            final p = await editForm(context, 'Cadastrar conta', [
              const FieldSpec('name', 'Nome de exibição'),
              const FieldSpec('email', 'E-mail de acesso'),
              const FieldSpec(
                'role',
                'Perfil',
                value: 'student',
                options: {
                  'student': 'Aluno',
                  'teacher': 'Professor',
                  'guardian': 'Responsável',
                  'delivery': 'Equipe de entrega',
                },
              ),
            ]);
            if (p != null &&
                context.mounted &&
                await confirm(
                  context,
                  'Cadastrar ${p['name']}?',
                  c.repository.isDemo
                      ? 'Será criada uma conta fictícia nesta sessão. Nenhum e-mail será enviado.'
                      : 'Um convite de acesso será enviado para ${p['email']}.',
                ) &&
                context.mounted) {
              await runAction(
                context,
                c,
                'invite',
                p,
                c.repository.isDemo
                    ? 'Conta fictícia criada.'
                    : 'Convite enviado. Vincule a conta à turma ou ao aluno.',
              );
            }
          },
        ),
      ),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final e in {
            'classes': 'Turmas',
            'subjects': 'Disciplinas',
            'enrollments': 'Matrículas',
            'assignments': 'Atribuições de professores',
            'links': 'Responsáveis vinculados',
          }.entries)
            OutlinedButton(
              onPressed: () => manage(context, c, e.key, e.value),
              child: Text(e.value),
            ),
        ],
      ),
      const SizedBox(height: 12),
      const Text(
        'Contas reais de professores, alunos e responsáveis são provisionadas pelo administrador com convite autenticado; nenhuma senha é definida no aplicativo.',
      ),
      for (final p in c.snapshot.rows('profiles'))
        ListTile(
          dense: true,
          title: Text(p['name']),
          subtitle: Text(AccessRole.values.byName(p['role']).label),
        ),
      const SectionHeading(
        'Correções com histórico',
        subtitle:
            'Somente estorno de lançamento indevido. Nunca use moedas como punição.',
      ),
      for (final l
          in c.snapshot.rows('ledger').where((l) => l['kind'] == 'gain'))
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: StarText('${l['title']} • ${l['amount']} ★'),
          subtitle: Text(studentName(c, l['student_id'])),
          trailing: TextButton(
            child: const Text('Corrigir'),
            onPressed: () async {
              final p =
                  await editForm(context, 'Estornar lançamento indevido', [
                    const FieldSpec(
                      'reason',
                      'Justificativa do erro (mínimo 10 caracteres)',
                      multiline: true,
                    ),
                  ]);
              if (p != null &&
                  context.mounted &&
                  await confirm(
                    context,
                    'Registrar correção?',
                    'O histórico será preservado com um lançamento compensatório.',
                  ) &&
                  context.mounted) {
                await runAction(context, c, 'correct', {...p, 'id': l['id']});
              }
            },
          ),
        ),
      const SectionHeading('Registro de auditoria'),
      if (c.snapshot.rows('audit').isEmpty)
        const EmptyState(
          'As operações administrativas e financeiras aparecerão aqui.',
        ),
      for (final a in c.snapshot.rows('audit').take(30))
        ListTile(
          dense: true,
          title: Text('${a['operation']} • ${a['actor']}'),
          subtitle: Text('${dateLabel(a['at'])} ${a['reason'] ?? ''}'),
        ),
    ],
  );
}

Future<void> rewardEditor(
  BuildContext context,
  SchoolController c, [
  JsonMap? reward,
]) async {
  final r = reward ?? {};
  final p = await editForm(
    context,
    r.isEmpty ? 'Nova recompensa' : 'Editar recompensa',
    [
      FieldSpec('name', 'Nome', value: r['name'] ?? ''),
      FieldSpec(
        'description',
        'Descrição',
        value: r['description'] ?? '',
        multiline: true,
      ),
      FieldSpec(
        'price',
        'Preço em Star Coins',
        value: '${r['price'] ?? 30}',
        number: true,
      ),
      FieldSpec(
        'stock',
        'Estoque disponível (além das reservas)',
        value: '${r['stock'] ?? 10}',
        number: true,
      ),
      FieldSpec(
        'limit',
        'Limite por aluno',
        value: '${r['limit'] ?? 1}',
        number: true,
      ),
      FieldSpec('location', 'Local de retirada', value: r['location'] ?? ''),
      FieldSpec(
        'instructions',
        'Instruções de retirada',
        value: r['instructions'] ?? '',
        multiline: true,
      ),
      FieldSpec(
        'start_at',
        'Disponível a partir de',
        value: r['start_at'] ?? DateTime.now().toIso8601String(),
        date: true,
      ),
      FieldSpec(
        'end_at',
        'Disponível até',
        value:
            r['end_at'] ??
            DateTime.now().add(const Duration(days: 90)).toIso8601String(),
        date: true,
      ),
      FieldSpec(
        'icon',
        'Ilustração',
        value: r['icon'] ?? 'gift',
        options: const {
          'gift': 'Brinde',
          'snack': 'Lanche extra',
          'sticker': 'Adesivo ou avatar',
        },
      ),
    ],
  );
  if (p != null && context.mounted) {
    await runAction(context, c, 'save_reward', {
      ...p,
      if (r['id'] != null) 'id': r['id'],
    });
  }
}

Future<void> manage(
  BuildContext context,
  SchoolController c,
  String table,
  String title,
) async {
  final profiles = c.snapshot.rows('profiles');
  Map<String, String> people(String role) => {
    for (final p in profiles.where((p) => p['role'] == role))
      p['id']: p['name'],
  };
  final classes = {
    for (final r in c.snapshot.rows('classes'))
      r['id'] as String: r['name'] as String,
  };
  final fields = <FieldSpec>[
    if (['classes', 'subjects'].contains(table))
      const FieldSpec('name', 'Nome'),
    if (['enrollments', 'links'].contains(table))
      FieldSpec('student_id', 'Aluno', options: people('student')),
    if (table == 'links')
      FieldSpec('guardian_id', 'Responsável', options: people('guardian')),
    if (['enrollments', 'assignments'].contains(table))
      FieldSpec('class_id', 'Turma', options: classes),
    if (table == 'assignments') ...[
      FieldSpec('teacher_id', 'Professor', options: people('teacher')),
      FieldSpec(
        'subject',
        'Disciplina',
        options: {
          for (final s in c.snapshot.rows('subjects')) s['name']: s['name'],
        },
      ),
    ],
  ];
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final r in c.snapshot.rows(table))
                ListTile(
                  title: Text(
                    r['name'] ??
                        '${r['student_id'] != null ? studentName(c, r['student_id']) : r['teacher_id']}',
                  ),
                  subtitle: Text(
                    r['subject'] ?? r['class_id'] ?? r['guardian_id'] ?? '',
                  ),
                  trailing: IconButton(
                    tooltip: 'Editar cadastro',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () async {
                      final editFields = fields
                          .map(
                            (f) => FieldSpec(
                              f.keyName,
                              f.label,
                              value: '${r[f.keyName] ?? f.value}',
                              options: f.options,
                              number: f.number,
                            ),
                          )
                          .toList();
                      final p = await editForm(
                        ctx,
                        'Editar: $title',
                        editFields,
                      );
                      if (p != null && ctx.mounted) {
                        await runAction(ctx, c, 'manage', {
                          'table': table,
                          'row': {...p, 'id': r['id']},
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Fechar'),
        ),
        FilledButton(
          onPressed: () async {
            final p = await editForm(ctx, 'Adicionar: $title', fields);
            if (p != null && ctx.mounted) {
              await runAction(ctx, c, 'manage', {'table': table, 'row': p});
              if (ctx.mounted) Navigator.pop(ctx);
            }
          },
          child: const Text('Adicionar'),
        ),
      ],
    ),
  );
}

class GuardianView extends StatefulWidget {
  const GuardianView(this.c, {super.key});
  final SchoolController c;
  @override
  State<GuardianView> createState() => _GuardianViewState();
}

class _GuardianViewState extends State<GuardianView> {
  String? selected;
  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final students = c.snapshot
        .rows('profiles')
        .where((p) => p['role'] == 'student')
        .toList();
    final id = selected ?? students.firstOrNull?['id'];
    if (id == null) {
      return const EmptyState(
        'Nenhum aluno vinculado. Solicite o vínculo à coordenação.',
      );
    }
    final classIds = c.snapshot
        .rows('enrollments')
        .where((e) => e['student_id'] == id)
        .map((e) => e['class_id'])
        .toSet();
    final activities = c.snapshot.activities
        .where((a) => classIds.contains(a['class_id']))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(
          'Perto de cada descoberta',
          subtitle: 'Acompanhe os alunos vinculados à sua conta.',
        ),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: id,
          items: students
              .map(
                (s) => DropdownMenuItem<String>(
                  value: s['id'],
                  child: Text(s['name']),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => selected = v),
        ),
        const SizedBox(height: 16),
        const EmptyState(
          'A família confirma somente as missões explicitamente atribuídas a ela. Lembretes pessoais do aluno permanecem privados.',
        ),
        const SectionHeading('Rotina escolar'),
        for (final a in activities)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ActivityTile(c, a),
                Padding(
                  padding: const EdgeInsets.only(top: 5, left: 20),
                  child: Text(stateLabels[c.snapshot.state(a, id)]!),
                ),
              ],
            ),
          ),
        WalletView(c, studentId: id),
        const SectionHeading('Recompensas do aluno'),
        for (final r in c.snapshot.redemptions.where(
          (r) => r['student_id'] == id,
        ))
          ListTile(
            title: Text(r['name']),
            subtitle: Text(
              '${r['location']} • ${r['status'] == 'reserved'
                  ? 'Aguardando retirada'
                  : r['status'] == 'delivered'
                  ? 'Entregue'
                  : 'Cancelado'}',
            ),
          ),
      ],
    );
  }
}
