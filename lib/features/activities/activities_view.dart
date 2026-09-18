import 'package:flutter/material.dart';
import '../../core/controller.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';

class ActivitiesView extends StatefulWidget {
  const ActivitiesView(this.c, {super.key});
  final SchoolController c;
  @override
  State<ActivitiesView> createState() => _ActivitiesViewState();
}

class _ActivitiesViewState extends State<ActivitiesView> {
  String filter = 'all';
  final selected = <String>{};
  @override
  Widget build(BuildContext context) {
    final c = widget.c, role = widget.c.account!.role;
    final staff = role == AccessRole.teacher || role == AccessRole.coordinator;
    final pending = c.snapshot.submissions
        .where((s) => s['status'] == 'submitted')
        .toList();
    final activities = c.snapshot.activities
        .where((a) => filter == 'all' || a['kind'] == filter)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(
          staff
              ? 'Aprender, participar, crescer'
              : 'Pequenas ações. Grandes descobertas.',
          subtitle:
              'Cada atividade tem um caminho claro. Participe no seu ritmo.',
          action: staff
              ? IconButton.filled(
                  onPressed: () => publishActivity(context, c),
                  tooltip: 'Publicar atividade',
                  icon: const Icon(Icons.add),
                )
              : null,
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: {'all': 'Todas', ...kindLabels}.entries
              .map(
                (e) => ChoiceChip(
                  label: Text(e.value),
                  selected: filter == e.key,
                  onSelected: (_) => setState(() => filter = e.key),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 20),
        if (staff && pending.isNotEmpty) ...[
          SectionHeading(
            'Entregas para avaliar',
            subtitle:
                '${pending.length} aguardando • selecione para validar em lote',
          ),
          for (final s in pending)
            CheckboxListTile(
              value: selected.contains(s['id']),
              onChanged: (v) => setState(
                () => v == true
                    ? selected.add(s['id'])
                    : selected.remove(s['id']),
              ),
              title: Text(
                c.snapshot.activities.firstWhere(
                  (a) => a['id'] == s['activity_id'],
                )['title'],
              ),
              subtitle: Text(
                '${studentName(c, s['student_id'])} · ${s['text']}',
              ),
            ),
          FilledButton.icon(
            onPressed: selected.isEmpty
                ? null
                : () async {
                    if (await confirm(
                          context,
                          'Validar ${selected.length} entregas?',
                          'As Star Coins serão concedidas uma única vez para cada participação aprovada.',
                        ) &&
                        context.mounted) {
                      await runAction(context, c, 'validate', {
                        'ids': selected.toList(),
                        'approve': true,
                      });
                      setState(() => selected.clear());
                    }
                  },
            icon: const Icon(Icons.done_all),
            label: const Text('Validar selecionadas'),
          ),
          const SizedBox(height: 20),
        ],
        if (activities.isEmpty)
          const EmptyState(
            'Nenhuma atividade por aqui. Novas oportunidades aparecerão nesta área.',
          ),
        for (final a in activities)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: ActivityTile(c, a),
          ),
      ],
    );
  }
}

String studentName(SchoolController c, String id) =>
    c.snapshot
        .rows('profiles')
        .where((p) => p['id'] == id)
        .firstOrNull?['name'] ??
    'Aluno vinculado';

class ActivityTile extends StatelessWidget {
  const ActivityTile(this.c, this.a, {super.key});
  final SchoolController c;
  final JsonMap a;
  @override
  Widget build(BuildContext context) {
    final s = c.snapshot.submission(a['id'], c.account!.id);
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => showActivity(context, c, a),
      child: Surface(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color:
                    (a['kind'] == 'academic' ? teal : const Color(0xFFA05D31))
                        .withValues(alpha: .09),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                a['kind'] == 'academic'
                    ? Icons.menu_book_outlined
                    : a['kind'] == 'collective'
                    ? Icons.eco_outlined
                    : Icons.volunteer_activism_outlined,
                color: teal,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 7,
                    runSpacing: 6,
                    children: [
                      Tag(
                        a['subject'] == ''
                            ? kindLabels[a['kind']]!
                            : a['subject'],
                      ),
                      if (c.account!.role == AccessRole.student)
                        Tag(stateLabels[c.snapshot.state(a, c.account!.id)]!),
                      if (isLate(a, s, DateTime.now()))
                        const Tag('Em atraso', color: Color(0xFF9E4D2B)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    a['title'],
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Até ${dateLabel(a['due_at'])}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF526B65),
                    ),
                  ),
                  const SizedBox(height: 8),
                  StarText(
                    '★ ${a['coins']} Star Coins',
                    style: const TextStyle(
                      color: Color(0xFF805900),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 15, color: teal),
          ],
        ),
      ),
    );
  }
}

Future<void> showActivity(
  BuildContext context,
  SchoolController c,
  JsonMap a,
) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (sheetContext) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        4,
        24,
        24 + MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: AnimatedBuilder(
        animation: c,
        builder: (_, _) {
          final role = c.account!.role;
          final submissions = c.snapshot.submissions
              .where((s) => s['activity_id'] == a['id'])
              .toList();
          final current = c.snapshot.submission(a['id'], c.account!.id);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                a['title'],
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(a['description']),
              const SectionHeading('Como participar'),
              Text(a['criteria']),
              const SizedBox(height: 16),
              StarText(
                'Início: ${dateLabel(a['start_at'])}\nPrazo: ${dateLabel(a['due_at'])}\n★ ${a['coins']} Star Coins após validação\nValidação: ${a['validator'] == 'guardian' ? 'família autorizada' : 'professor'}\nFrequência: ${{'once': 'única', 'daily': 'a cada 24 horas', 'weekly': 'a cada 7 dias'}[a['frequency']]} • limite: ${a['limit']}',
              ),
              if (role == AccessRole.student && a['cancelled'] != true) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: c.busy || current['status'] == 'submitted'
                      ? null
                      : () async {
                          final p =
                              await editForm(sheetContext, 'Minha entrega', [
                                const FieldSpec(
                                  'text',
                                  'Conte o que você realizou',
                                  multiline: true,
                                ),
                              ]);
                          if (p != null && sheetContext.mounted) {
                            await runAction(sheetContext, c, 'submit', {
                              ...p,
                              'activity_id': a['id'],
                            }, 'Entrega enviada. Aguarde a validação.');
                          }
                        },
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Enviar minha participação'),
                ),
              ],
              for (final s in submissions) ...[
                const Divider(height: 32),
                Text(
                  '${studentName(c, s['student_id'])} • ${stateLabels[s['status']]}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(s['text'] ?? ''),
                if (s['feedback'] != null) Text('Orientação: ${s['feedback']}'),
                if (s['review'] != null)
                  Text('Revisão solicitada: ${s['review']}'),
                if ((role == AccessRole.teacher ||
                        role == AccessRole.coordinator ||
                        (role == AccessRole.guardian &&
                            a['validator'] == 'guardian')) &&
                    s['status'] == 'submitted')
                  Wrap(
                    spacing: 10,
                    children: [
                      FilledButton(
                        onPressed: c.busy
                            ? null
                            : () async {
                                if (await confirm(
                                      sheetContext,
                                      'Validar participação?',
                                      'Confirme que os critérios foram atendidos. Serão concedidas ${a['coins']} Star Coins.',
                                    ) &&
                                    sheetContext.mounted) {
                                  await runAction(sheetContext, c, 'validate', {
                                    'ids': [s['id']],
                                    'approve': true,
                                  });
                                }
                              },
                        child: const Text('Validar'),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          final p =
                              await editForm(sheetContext, 'Orientar ajustes', [
                                const FieldSpec(
                                  'feedback',
                                  'O que precisa ser ajustado?',
                                  multiline: true,
                                ),
                              ]);
                          if (p != null && sheetContext.mounted) {
                            await runAction(sheetContext, c, 'validate', {
                              ...p,
                              'ids': [s['id']],
                              'approve': false,
                            });
                          }
                        },
                        child: const Text('Solicitar ajustes'),
                      ),
                    ],
                  ),
                if (role == AccessRole.student &&
                    ['changes', 'completed'].contains(s['status']))
                  TextButton(
                    onPressed: () async {
                      final p = await editForm(sheetContext, 'Pedir revisão', [
                        const FieldSpec(
                          'reason',
                          'Explique sua solicitação',
                          multiline: true,
                        ),
                      ]);
                      if (p != null && sheetContext.mounted) {
                        await runAction(sheetContext, c, 'review', {
                          ...p,
                          'id': s['id'],
                        });
                      }
                    },
                    child: const Text('Pedir revisão'),
                  ),
              ],
              if (role == AccessRole.teacher ||
                  role == AccessRole.coordinator) ...[
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () async {
                    final p =
                        await editForm(sheetContext, 'Prorrogar ou adaptar', [
                          FieldSpec(
                            'due_at',
                            'Novo prazo',
                            value: a['due_at'],
                            date: true,
                          ),
                          FieldSpec(
                            'criteria',
                            'Critérios e alternativa acessível',
                            value: a['criteria'],
                            multiline: true,
                          ),
                          const FieldSpec(
                            'reason',
                            'Justificativa',
                            multiline: true,
                          ),
                        ]);
                    if (p != null && sheetContext.mounted) {
                      await runAction(sheetContext, c, 'adapt', {
                        ...p,
                        'id': a['id'],
                      });
                    }
                  },
                  child: const Text('Prorrogar ou adaptar'),
                ),
                TextButton(
                  onPressed: () async {
                    final p = await editForm(
                      sheetContext,
                      'Cancelar atividade',
                      [const FieldSpec('reason', 'Justificativa')],
                    );
                    if (p != null && sheetContext.mounted) {
                      await runAction(sheetContext, c, 'adapt', {
                        ...p,
                        'id': a['id'],
                        'cancelled': true,
                      });
                      if (sheetContext.mounted) {
                        Navigator.pop(sheetContext);
                      }
                    }
                  },
                  child: const Text('Cancelar atividade'),
                ),
              ],
            ],
          );
        },
      ),
    ),
  ),
);
Future<void> publishActivity(BuildContext context, SchoolController c) async {
  final classes = c.snapshot.rows('classes');
  final assignments = c.snapshot.rows('assignments');
  final allowed = classes
      .where(
        (r) =>
            c.account!.role == AccessRole.coordinator ||
            assignments.any((a) => a['class_id'] == r['id']),
      )
      .toList();
  final p = await editForm(context, 'Nova atividade ou missão', [
    const FieldSpec('title', 'Título'),
    const FieldSpec('description', 'Instruções', multiline: true),
    const FieldSpec('kind', 'Tipo', value: 'academic', options: kindLabels),
    FieldSpec(
      'class_id',
      'Turma',
      options: {for (final r in allowed) r['id']: r['name']},
    ),
    FieldSpec(
      'subject',
      'Disciplina (use Sem disciplina nas missões)',
      value: '',
      options: {
        '': 'Sem disciplina',
        for (final s in c.snapshot.rows('subjects')) s['name']: s['name'],
      },
    ),
    const FieldSpec('category', 'Categoria', value: 'Colaboração'),
    FieldSpec(
      'start_at',
      'Início',
      value: DateTime.now().toIso8601String(),
      date: true,
    ),
    FieldSpec(
      'due_at',
      'Prazo',
      value: DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      date: true,
    ),
    const FieldSpec(
      'criteria',
      'Critérios observáveis e alternativa acessível',
      multiline: true,
    ),
    FieldSpec(
      'coins',
      'Star Coins',
      kindDefaults: {
        for (final r in c.snapshot.rows('rules'))
          r['key'] ?? r['id']: '${r['coins']}',
      },
      value:
          '${c.snapshot.rows('rules').where((r) => (r['key'] ?? r['id']) == 'academic').firstOrNull?['coins'] ?? 10}',
      number: true,
    ),
    const FieldSpec(
      'validator',
      'Quem valida',
      value: 'teacher',
      options: {
        'teacher': 'Professor',
        'guardian': 'Família autorizada (boas práticas)',
      },
    ),
    const FieldSpec(
      'frequency',
      'Frequência',
      value: 'once',
      options: {
        'once': 'Uma vez',
        'daily': 'A cada 24 horas',
        'weekly': 'A cada 7 dias',
      },
    ),
    const FieldSpec(
      'limit',
      'Limite total de participações',
      value: '1',
      number: true,
    ),
    const FieldSpec(
      'collective',
      'Contribui para a meta coletiva?',
      value: 'false',
      options: {'false': 'Não', 'true': 'Sim'},
    ),
  ]);
  if (p != null && context.mounted) {
    await runAction(context, c, 'publish', {
      ...p,
      'collective': p['collective'] == 'true',
    });
  }
}
