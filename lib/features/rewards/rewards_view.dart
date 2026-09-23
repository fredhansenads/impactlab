import 'package:flutter/material.dart';
import '../../core/controller.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';

class RewardsView extends StatelessWidget {
  const RewardsView(this.c, {super.key});
  final SchoolController c;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionHeading(
        'Seu esforço abre possibilidades',
        subtitle: 'Escolha algo especial e combine a retirada na escola.',
      ),
      const Tag(
        'Alimentação regular e direitos básicos nunca dependem de moedas',
      ),
      const SizedBox(height: 20),
      LayoutBuilder(
        builder: (context, box) {
          final width = box.maxWidth;
          final columns = width > 900
              ? 3
              : width > 560
              ? 2
              : 1;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: c.snapshot.rewards
                .map(
                  (r) => SizedBox(
                    width: (width - 16 * (columns - 1)) / columns,
                    child: Surface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 130,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: r['icon'] == 'snack'
                                  ? const Color(0xFFE0F5FA)
                                  : r['icon'] == 'gift'
                                  ? const Color(0xFFE8EDFF)
                                  : const Color(0xFFE4F1FC),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              r['icon'] == 'snack'
                                  ? Icons.bakery_dining_outlined
                                  : r['icon'] == 'gift'
                                  ? Icons.redeem_outlined
                                  : Icons.auto_awesome_outlined,
                              size: 58,
                              color: ink,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            r['name'],
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            r['description'],
                            style: const TextStyle(height: 1.5),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            children: [
                              Tag(
                                '★ ${r['price']} Star Coins',
                                color: const Color(0xFF805900),
                              ),
                              Tag('${r['stock']} disponíveis'),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${r['location']} • limite ${r['limit']} por aluno',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed:
                                  c.busy ||
                                      r['stock'] == 0 ||
                                      c.account!.role != AccessRole.student
                                  ? null
                                  : () async {
                                      if (await confirm(
                                            context,
                                            'Reservar ${r['name']}?',
                                            'Serão reservadas ${r['price']} Star Coins. ${r['instructions']} Você pode cancelar antes da entrega.',
                                          ) &&
                                          context.mounted) {
                                        await runAction(
                                          context,
                                          c,
                                          'reserve',
                                          {
                                            'reward_id': r['id'],
                                            'request_id':
                                                '${c.account!.id}-${DateTime.now().microsecondsSinceEpoch}',
                                          },
                                          'Recompensa reservada. Seu código está em Meus resgates.',
                                        );
                                      }
                                    },
                              child: const Text('Quero resgatar'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
      if (c.snapshot.rewards.isEmpty)
        const EmptyState('A escola ainda não cadastrou recompensas.'),
      const SectionHeading(
        'Meus resgates',
        subtitle:
            'O código vale uma única vez. Apresente-o no local de retirada.',
      ),
      if (c.snapshot.redemptions.isEmpty)
        const EmptyState(
          'Quando você escolher uma recompensa, ela aparecerá aqui.',
        ),
      for (final r in c.snapshot.redemptions)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${r['location']} • ${{'reserved': 'Aguardando retirada', 'delivered': 'Entregue', 'cancelled': 'Cancelado'}[r['status']]}',
                ),
                if (r['status'] == 'reserved') ...[
                  const SizedBox(height: 12),
                  SelectableText(
                    r['code'],
                    style: const TextStyle(
                      fontSize: 23,
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                      color: brandPrimary,
                    ),
                  ),
                  if (c.account!.role == AccessRole.student)
                    TextButton(
                      onPressed: c.busy
                          ? null
                          : () async {
                              if (await confirm(
                                    context,
                                    'Cancelar reserva?',
                                    'As moedas e o estoque serão devolvidos.',
                                  ) &&
                                  context.mounted) {
                                await runAction(
                                  context,
                                  c,
                                  'cancel_redemption',
                                  {'id': r['id']},
                                );
                              }
                            },
                      child: const Text('Cancelar reserva'),
                    ),
                ],
              ],
            ),
          ),
        ),
    ],
  );
}

class DeliveryView extends StatelessWidget {
  const DeliveryView(this.c, {super.key});
  final SchoolController c;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionHeading(
        'Uma recompensa pronta para entregar',
        subtitle:
            'Confira o código apresentado pelo aluno e confirme a entrega.',
      ),
      FilledButton.icon(
        icon: const Icon(Icons.confirmation_number_outlined),
        label: const Text('Conferir código'),
        onPressed: () async {
          final p = await editForm(context, 'Código de retirada', [
            const FieldSpec('code', 'Código'),
          ]);
          if (p == null || !context.mounted) return;
          final code = (p['code'] as String).toUpperCase().trim();
          final r = c.snapshot.redemptions
              .where((r) => r['code'] == code)
              .firstOrNull;
          if (r == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Código não encontrado. Atualize a lista e confira o código.',
                ),
              ),
            );
            return;
          }
          if (await confirm(
                context,
                'Entregar ${r['name']}?',
                'Local: ${r['location']}. Confirme somente ao entregar o item. O código será encerrado.',
              ) &&
              context.mounted) {
            await runAction(context, c, 'deliver', {
              'code': code,
            }, 'Entrega confirmada.');
          }
        },
      ),
      const SizedBox(height: 24),
      const EmptyState(
        'Esta área acessa apenas códigos, recompensas, situação e locais de retirada. Dados acadêmicos não são disponibilizados.',
      ),
      const SectionHeading('Retiradas'),
      for (final r in c.snapshot.redemptions)
        ListTile(
          leading: const Icon(Icons.redeem_outlined),
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
