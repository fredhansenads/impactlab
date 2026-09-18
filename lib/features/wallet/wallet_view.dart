import 'package:flutter/material.dart';
import '../../core/controller.dart';
import '../../core/widgets.dart';

class WalletView extends StatelessWidget {
  const WalletView(this.c, {this.studentId, super.key});
  final SchoolController c;
  final String? studentId;
  @override
  Widget build(BuildContext context) {
    final id = studentId ?? c.account!.id, w = c.snapshot.wallet(id);
    final ledger = c.snapshot
        .rows('ledger')
        .where((r) => r['student_id'] == id)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(
          'Cada estrela conta uma história',
          subtitle: 'Sua participação, reconhecida pela escola.',
        ),
        Surface(
          color: ink,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'STAR COIN  /  SUA CARTEIRA',
                style: TextStyle(
                  color: Color(0xFFCCE2D8),
                  letterSpacing: 1.8,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 20),
              StarText(
                '★ ${w['available']}',
                style: const TextStyle(
                  fontSize: 50,
                  color: gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Text(
                'Star Coins disponíveis',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 32,
                runSpacing: 16,
                children: [
                  Text(
                    '${w['reserved']} reservadas em resgates',
                    style: const TextStyle(color: Colors.white),
                  ),
                  Text(
                    '${w['earned']} conquistadas ao longo do tempo',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Moeda interna da escola, sem valor em dinheiro. Não pode ser comprada ou transferida e não expira nesta versão. Gastar moedas preserva suas conquistas.',
          style: TextStyle(height: 1.6, color: Color(0xFF526B65)),
        ),
        const SectionHeading(
          'Seu caminho até aqui',
          subtitle:
              'Reservas separam moedas; a entrega finaliza o gasto, sem descontar duas vezes.',
        ),
        if (ledger.isEmpty)
          const EmptyState(
            'Suas primeiras Star Coins chegam após uma participação validada.',
          ),
        for (final l in ledger)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Surface(
              child: Row(
                children: [
                  Icon(
                    l['kind'] == 'gain'
                        ? Icons.stars_outlined
                        : Icons.receipt_long_outlined,
                    color: teal,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l['title'],
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${dateLabel(l['at'])} • ${l['actor']}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          '${{'gain': 'Ganho', 'reserve': 'Reserva', 'spend': 'Gasto finalizado', 'refund': 'Devolução', 'correction': 'Correção'}[l['kind']]} • ref. ${l['reference']}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StarText(
                    '${l['amount'] > 0 ? '+' : ''}${l['amount']} ★',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: teal,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
