import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'controller.dart';
import 'models.dart';

const ink = Color(0xFF081936);
const brandPrimary = Color(0xFF0756B5);
const canvas = Color(0xFFF4F7FC);
const gold = Color(0xFFF3CA63);
String dateLabel(String value) => DateFormat(
  'dd MMM • HH:mm',
  'pt_BR',
).format(DateTime.parse(value).toLocal());

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {this.subtitle, this.action, super.key});
  final String title;
  final String? subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 5),
                Text(
                  subtitle!,
                  style: const TextStyle(color: Color(0xFF52637D), height: 1.5),
                ),
              ],
            ],
          ),
        ),
        if (action != null) action!,
      ],
    ),
  );
}

class Surface extends StatelessWidget {
  const Surface({
    required this.child,
    this.color = Colors.white,
    this.gradient,
    super.key,
  });
  final Widget child;
  final Color color;
  final Gradient? gradient;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: color,
      gradient: gradient,
      boxShadow: [
        BoxShadow(
          color: ink.withValues(alpha: .035),
          blurRadius: 22,
          offset: const Offset(0, 6),
        ),
      ],
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: ink.withValues(alpha: .07)),
    ),
    child: child,
  );
}

class Tag extends StatelessWidget {
  const Tag(this.text, {this.color = brandPrimary, super.key});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(8),
    ),
    child: StarText(
      text,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Surface(
    child: Row(
      children: [
        const Icon(Icons.spa_outlined, color: brandPrimary),
        const SizedBox(width: 16),
        Expanded(child: Text(text, style: const TextStyle(height: 1.5))),
      ],
    ),
  );
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    ) ??
    false;
Future<void> runAction(
  BuildContext context,
  SchoolController c,
  String action,
  JsonMap p, [
  String message = 'Pronto! Alteração registrada.',
]) async {
  final ok = await c.act(action, p);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? message : c.error ?? 'Tente novamente.')),
    );
  }
}

class FieldSpec {
  const FieldSpec(
    this.keyName,
    this.label, {
    this.value = '',
    this.options,
    this.number = false,
    this.multiline = false,
    this.optional = false,
    this.date = false,
    this.obscure = false,
    this.kindDefaults,
  });
  final String keyName, label, value;
  final Map<String, String>? options, kindDefaults;
  final bool number, multiline, optional, date, obscure;
}

Future<JsonMap?> editForm(
  BuildContext context,
  String title,
  List<FieldSpec> fields,
) => showDialog<JsonMap>(
  context: context,
  builder: (_) => _Editor(title, fields),
);

class _Editor extends StatefulWidget {
  const _Editor(this.title, this.fields);
  final String title;
  final List<FieldSpec> fields;
  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  final form = GlobalKey<FormState>();
  late final controllers = {
    for (final f in widget.fields)
      f.keyName: TextEditingController(text: f.value),
  };
  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 520,
      child: Form(
        key: form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final f in widget.fields)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: f.options != null
                      ? DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue:
                              f.options!.containsKey(
                                controllers[f.keyName]!.text,
                              )
                              ? controllers[f.keyName]!.text
                              : null,
                          decoration: InputDecoration(labelText: f.label),
                          items: f.options!.entries
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Text(e.value),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            controllers[f.keyName]!.text = v ?? '';
                            if (f.keyName == 'kind') {
                              for (final target in widget.fields) {
                                if (target.kindDefaults?.containsKey(v) ==
                                    true) {
                                  controllers[target.keyName]!.text =
                                      target.kindDefaults![v]!;
                                }
                              }
                            }
                          },
                          validator: (v) =>
                              v == null ? 'Selecione uma opção' : null,
                        )
                      : TextFormField(
                          controller: controllers[f.keyName],
                          obscureText: f.obscure,
                          decoration: InputDecoration(
                            labelText: f.label,
                            suffixIcon: f.date
                                ? IconButton(
                                    tooltip: 'Escolher data',
                                    icon: const Icon(
                                      Icons.calendar_month_outlined,
                                    ),
                                    onPressed: () async {
                                      final parsed =
                                          DateTime.tryParse(
                                            controllers[f.keyName]!.text,
                                          )?.toLocal() ??
                                          DateTime.now();
                                      final date = await showDatePicker(
                                        context: context,
                                        initialDate: parsed,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2100),
                                      );
                                      if (date != null && context.mounted) {
                                        final time = await showTimePicker(
                                          context: context,
                                          initialTime: TimeOfDay.fromDateTime(
                                            parsed,
                                          ),
                                        );
                                        if (time != null) {
                                          controllers[f.keyName]!.text =
                                              DateTime(
                                                date.year,
                                                date.month,
                                                date.day,
                                                time.hour,
                                                time.minute,
                                              ).toIso8601String();
                                        }
                                      }
                                    },
                                  )
                                : null,
                          ),
                          keyboardType: f.number
                              ? TextInputType.number
                              : TextInputType.text,
                          maxLines: f.multiline ? 3 : 1,
                          validator: (v) {
                            if (!f.optional && (v ?? '').trim().isEmpty) {
                              return 'Preencha este campo';
                            }
                            if (f.number &&
                                (int.tryParse(v ?? '') == null ||
                                    int.parse(v!) < 0)) {
                              return 'Use um número inteiro positivo ou zero';
                            }
                            if (f.date && DateTime.tryParse(v ?? '') == null) {
                              return 'Selecione uma data válida';
                            }
                            return null;
                          },
                        ),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (!form.currentState!.validate()) return;
          Navigator.pop(context, {
            for (final f in widget.fields)
              f.keyName: f.number
                  ? int.parse(controllers[f.keyName]!.text)
                  : controllers[f.keyName]!.text.trim(),
          });
        },
        child: const Text('Salvar'),
      ),
    ],
  );
}

/// Uses the bundled icon font so the Star Coin symbol is consistent on devices.
class StarText extends StatelessWidget {
  const StarText(this.text, {this.style, super.key});
  final String text;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) {
    final parts = text.split('★');
    return Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < parts.length; i++) ...[
            if (i > 0)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Icon(
                  Icons.star_rounded,
                  size: (style?.fontSize ?? 14) * .95,
                  color: style?.color ?? brandPrimary,
                ),
              ),
            TextSpan(text: parts[i]),
          ],
        ],
      ),
      style: style,
      semanticsLabel: text.replaceAll('★', 'estrela'),
    );
  }
}
