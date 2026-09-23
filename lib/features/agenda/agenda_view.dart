import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/controller.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';
import '../activities/activities_view.dart';

class AgendaView extends StatefulWidget {
  const AgendaView(this.c, {super.key});
  final SchoolController c;
  @override
  State<AgendaView> createState() => _AgendaViewState();
}

class _AgendaViewState extends State<AgendaView> {
  String view = 'week', subject = 'all', status = 'all';
  DateTime focus = DateTime.now();
  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final day = DateTime(focus.year, focus.month, focus.day);
    final start = view == 'week'
        ? day.subtract(Duration(days: day.weekday - 1))
        : day;
    final end = start.add(Duration(days: view == 'week' ? 7 : 1));
    final items =
        [
            for (final a in c.snapshot.activities) {...a, 'personal': false},
            for (final a in c.snapshot.rows('personal'))
              {...a, 'personal': true},
          ].where((a) {
            final date = DateTime.parse(a['due_at']).toLocal();
            final personal = a['personal'] == true;
            return (view == 'list'
                    ? !date.isBefore(day) ||
                          (!personal &&
                              c.snapshot.state(a, c.account!.id) != 'completed')
                    : !date.isBefore(start) && date.isBefore(end)) &&
                (subject == 'all' || a['subject'] == subject) &&
                (status == 'all' ||
                    (!personal &&
                        c.snapshot.state(a, c.account!.id) == status));
          }).toList()
          ..sort((a, b) => a['due_at'].compareTo(b['due_at']));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(
          'Seu tempo, bem cuidado',
          subtitle: 'Compromissos da escola e espaço para os seus planos.',
          action: c.account!.role == AccessRole.student
              ? IconButton.filled(
                  tooltip: 'Novo lembrete pessoal',
                  icon: const Icon(Icons.add),
                  onPressed: () async {
                    final p = await editForm(context, 'Compromisso pessoal', [
                      const FieldSpec('title', 'Título'),
                      FieldSpec(
                        'due_at',
                        'Data e horário',
                        value: DateTime.now()
                            .add(const Duration(days: 1))
                            .toIso8601String(),
                        date: true,
                      ),
                    ]);
                    if (p != null && context.mounted) {
                      await runAction(
                        context,
                        c,
                        'personal',
                        p,
                        'Lembrete privado criado. Não gera moedas.',
                      );
                    }
                  },
                )
              : null,
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'day', label: Text('Dia')),
                ButtonSegment(value: 'week', label: Text('Semana')),
                ButtonSegment(value: 'list', label: Text('Próximos')),
              ],
              selected: {view},
              onSelectionChanged: (s) => setState(() => view = s.first),
            ),
            SizedBox(
              width: 170,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: subject,
                decoration: const InputDecoration(labelText: 'Disciplina'),
                items:
                    {
                          'all': 'Todas',
                          for (final s in c.snapshot.rows('subjects'))
                            s['name'] as String: s['name'] as String,
                        }.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                onChanged: (s) => setState(() => subject = s!),
              ),
            ),
            SizedBox(
              width: 215,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: status,
                decoration: const InputDecoration(labelText: 'Situação'),
                items: {'all': 'Todas', ...stateLabels}.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
                onChanged: (s) => setState(() => status = s!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            IconButton(
              tooltip: 'Período anterior',
              onPressed: () => setState(
                () => focus = focus.subtract(
                  Duration(days: view == 'week' ? 7 : 1),
                ),
              ),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                DateFormat("MMMM 'de' yyyy", 'pt_BR').format(focus),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Próximo período',
              onPressed: () => setState(
                () => focus = focus.add(Duration(days: view == 'week' ? 7 : 1)),
              ),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        if (view == 'week')
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: List.generate(7, (i) {
                final d = start.add(Duration(days: i));
                return Expanded(
                  child: Semantics(
                    label: DateFormat('EEEE, dd MMMM', 'pt_BR').format(d),
                    child: InkWell(
                      onTap: () => setState(() {
                        focus = d;
                        view = 'day';
                      }),
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color:
                              d.day == DateTime.now().day &&
                                  d.month == DateTime.now().month
                              ? brandPrimary
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            Text(
                              DateFormat('EEE', 'pt_BR').format(d),
                              style: TextStyle(
                                fontSize: 11,
                                color:
                                    d.day == DateTime.now().day &&
                                        d.month == DateTime.now().month
                                    ? Colors.white
                                    : ink,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${d.day}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color:
                                    d.day == DateTime.now().day &&
                                        d.month == DateTime.now().month
                                    ? Colors.white
                                    : ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        const SizedBox(height: 16),
        if (items.isEmpty)
          const EmptyState(
            'Agenda livre neste período. Use os filtros para explorar outros compromissos.',
          ),
        for (final a in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: a['personal'] == true
                ? Surface(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.lock_outline,
                        color: brandPrimary,
                      ),
                      title: Text(a['title']),
                      subtitle: Text(
                        '${dateLabel(a['due_at'])}\nPessoal • privado • sem Star Coins',
                      ),
                    ),
                  )
                : ActivityTile(c, a),
          ),
      ],
    );
  }
}
