import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/controller.dart';
import 'core/brand.dart';
import 'core/models.dart';
import 'core/widgets.dart';
import 'data/demo_repository.dart';
import 'data/supabase_repository.dart';
import 'features/activities/activities_view.dart';
import 'features/agenda/agenda_view.dart';
import 'features/auth/login_view.dart';
import 'features/rewards/rewards_view.dart';
import 'features/school/school_view.dart';
import 'features/wallet/wallet_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const demo = bool.fromEnvironment('DEMO_MODE', defaultValue: true);
  SchoolRepository repository;
  if (demo) {
    repository = DemoSchoolRepository();
  } else {
    const url = String.fromEnvironment('SUPABASE_URL'),
        key = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (url.isEmpty || key.isEmpty) {
      runApp(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text(
                'Configuração incompleta. Defina SUPABASE_URL e SUPABASE_ANON_KEY ou use DEMO_MODE=true.',
              ),
            ),
          ),
        ),
      );
      return;
    }
    try {
      await Supabase.initialize(url: url, publishableKey: key);
      repository = SupabaseSchoolRepository(Supabase.instance.client);
    } catch (_) {
      runApp(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text(
                'Não foi possível iniciar. Confira a configuração e a conexão e reabra o aplicativo.',
              ),
            ),
          ),
        ),
      );
      return;
    }
  }
  final controller = SchoolController(repository);
  runApp(SchoolApp(controller));
  await controller.refresh();
  if (!demo) {
    Supabase.instance.client.auth.onAuthStateChange.listen(
      (_) => controller.refresh(),
    );
  }
}

class SchoolApp extends StatelessWidget {
  const SchoolApp(this.c, {super.key});
  final SchoolController c;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: appName,
    debugShowCheckedModeBanner: false,
    locale: const Locale('pt', 'BR'),
    supportedLocales: const [Locale('pt', 'BR')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: canvas,
      colorScheme: ColorScheme.fromSeed(
        seedColor: brandPrimary,
        primary: brandPrimary,
        secondary: const Color(0xFF00788F),
        tertiary: const Color(0xFF805900),
        surface: Colors.white,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: Color(0xFFDDEBFF),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 11, height: 1.2),
        ),
      ),
      appBarTheme: const AppBarTheme(foregroundColor: ink),
      chipTheme: ChipThemeData(
        selectedColor: const Color(0xFFDDEBFF),
        backgroundColor: Colors.white,
        side: BorderSide(color: brandPrimary.withValues(alpha: .18)),
      ),
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: ink, fontSize: 14, height: 1.45),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    ),
    home: AnimatedBuilder(
      animation: c,
      builder: (context, _) => c.account == null ? LoginView(c) : Shell(c),
    ),
  );
}

class Shell extends StatefulWidget {
  const Shell(this.c, {super.key});
  final SchoolController c;
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;
  @override
  Widget build(BuildContext context) {
    final c = widget.c, role = widget.c.account!.role;
    final student = role == AccessRole.student;
    final labels = student
        ? ['Início', 'Agenda', 'Missões', 'Carteira', 'Recompensas']
        : role == AccessRole.teacher
        ? ['Visão geral', 'Agenda', 'Atividades']
        : role == AccessRole.coordinator
        ? ['Coordenação', 'Atividades', 'Agenda']
        : role == AccessRole.guardian
        ? ['Acompanhamento', 'Agenda']
        : ['Entregas'];
    final icons = student
        ? [
            Icons.grid_view_outlined,
            Icons.calendar_month_outlined,
            Icons.explore_outlined,
            Icons.account_balance_wallet_outlined,
            Icons.redeem_outlined,
          ]
        : role == AccessRole.teacher
        ? [
            Icons.grid_view_outlined,
            Icons.calendar_month_outlined,
            Icons.menu_book_outlined,
          ]
        : role == AccessRole.coordinator
        ? [
            Icons.school_outlined,
            Icons.menu_book_outlined,
            Icons.calendar_month_outlined,
          ]
        : role == AccessRole.guardian
        ? [Icons.family_restroom_outlined, Icons.calendar_month_outlined]
        : [Icons.redeem_outlined];
    final current = index.clamp(0, labels.length - 1);
    Widget content;
    if (student) {
      content = [
        HomeView(c, onNavigate: (i) => setState(() => index = i)),
        AgendaView(c),
        ActivitiesView(c),
        WalletView(c),
        RewardsView(c),
      ][current];
    } else if (role == AccessRole.teacher) {
      content = current == 1 ? AgendaView(c) : ActivitiesView(c);
    } else if (role == AccessRole.coordinator) {
      content = [SchoolView(c), ActivitiesView(c), AgendaView(c)][current];
    } else if (role == AccessRole.guardian) {
      content = current == 0 ? GuardianView(c) : AgendaView(c);
    } else {
      content = DeliveryView(c);
    }
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 76,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandLogo(height: 54, excludeFromSemantics: true),
            const SizedBox(width: 12),
            const Flexible(
              child: Text(
                appName,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Atualizar dados',
            onPressed: c.loading ? null : c.refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Avisos',
            icon: Badge(
              isLabelVisible: c.snapshot.rows('notifications').isNotEmpty,
              child: const Icon(Icons.notifications_none_outlined),
            ),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Seus avisos'),
                content: SizedBox(
                  width: 450,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Avisos sem dados pessoais. No celular, você pode agendar lembretes 24 horas antes dos próximos prazos.',
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.notifications_active_outlined),
                          label: const Text('Ativar lembretes neste aparelho'),
                          onPressed: () async {
                            if (c.account!.role != AccessRole.student) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Lembretes de prazo são configurados no perfil do aluno.',
                                  ),
                                ),
                              );
                              return;
                            }
                            if (!await confirm(
                              ctx,
                              'Lembrar dos próximos prazos?',
                              'Vamos pedir permissão para avisos discretos, sem nomes ou detalhes das atividades. Serão agendados os próximos 40 prazos, 24 horas antes. Reative ao abrir uma nova sessão para atualizar os lembretes.',
                            )) {
                              return;
                            }
                            try {
                              final granted = await c.reminders.enable(
                                c.snapshot,
                                c.account!,
                              );
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      granted
                                          ? 'Lembretes agendados.'
                                          : 'Permissão não concedida. A agenda continua disponível.',
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      e is RuleViolation
                                          ? e.message
                                          : 'Não foi possível ativar os lembretes. Confira as permissões do aparelho.',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                        TextButton(
                          onPressed: () async {
                            await c.reminders.clear();
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Lembretes desativados neste aparelho.',
                                  ),
                                ),
                              );
                            }
                          },
                          child: const Text('Desativar lembretes'),
                        ),
                        for (final a in c.snapshot.rows('notifications'))
                          ListTile(
                            title: Text(a['text']),
                            subtitle: Text(dateLabel(a['at'])),
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
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Perfil e conquistas',
            onPressed: () => profile(context, c),
            icon: CircleAvatar(
              radius: 17,
              backgroundColor: const Color(0xFFDFECFC),
              child: Text(
                c.account!.name[0],
                style: const TextStyle(color: ink, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      bottomNavigationBar: wide || labels.length < 2
          ? null
          : NavigationBar(
              selectedIndex: current,
              onDestinationSelected: (i) => setState(() => index = i),
              destinations: List.generate(
                labels.length,
                (i) => NavigationDestination(
                  icon: Icon(icons[i]),
                  label: labels[i],
                ),
              ),
            ),
      body: SafeArea(
        child: Column(
          children: [
            if (c.repository.isDemo)
              Container(
                width: double.infinity,
                color: const Color(0xFFE1ECFF),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 5,
                ),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  children: [
                    const Text(
                      'DEMONSTRAÇÃO • dados fictícios',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF173D78),
                      ),
                    ),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<AccessRole>(
                        value: role,
                        isDense: true,
                        items: AccessRole.values
                            .map(
                              (r) => DropdownMenuItem(
                                value: r,
                                child: Text(
                                  r.label,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (r) async {
                          setState(() => index = 0);
                          await c.switchRole(r!);
                        },
                      ),
                    ),
                    const Text(
                      'Alterações duram nesta sessão',
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            if (c.loading || c.busy)
              const LinearProgressIndicator(minHeight: 3),
            if (c.error != null)
              MaterialBanner(
                content: Text(c.error!),
                actions: [
                  TextButton(
                    onPressed: c.refresh,
                    child: const Text('Atualizar'),
                  ),
                ],
              ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (wide)
                    Container(
                      width: 218,
                      decoration: const BoxDecoration(
                        border: Border(
                          right: BorderSide(color: Color(0xFFE1E8F2)),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(24, 32, 24, 18),
                            child: Text(
                              'MEU ESPAÇO',
                              style: TextStyle(
                                fontSize: 11,
                                letterSpacing: 1.6,
                                color: Color(0xFF586B85),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          for (var i = 0; i < labels.length; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 4,
                              ),
                              child: ListTile(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                selectedTileColor: const Color(0xFFE6F0FD),
                                selected: current == i,
                                leading: Icon(icons[i], size: 21),
                                title: Text(
                                  labels[i],
                                  style: const TextStyle(fontSize: 14),
                                ),
                                onTap: () => setState(() => index = i),
                              ),
                            ),
                          const Spacer(),
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Aprender é um caminho.\nVamos juntos.',
                              style: TextStyle(
                                color: brandPrimary,
                                height: 1.6,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: c.refresh,
                      child: SingleChildScrollView(
                        key: ValueKey('$role-$current'),
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          wide ? 40 : 20,
                          12,
                          wide ? 40 : 20,
                          40,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1200),
                            child: content,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeView extends StatelessWidget {
  const HomeView(this.c, {required this.onNavigate, super.key});
  final SchoolController c;
  final ValueChanged<int> onNavigate;
  @override
  Widget build(BuildContext context) {
    final activities =
        c.snapshot.activities
            .where(
              (a) => ![
                'completed',
                'cancelled',
              ].contains(c.snapshot.state(a, c.account!.id)),
            )
            .toList()
          ..sort((a, b) => a['due_at'].compareTo(b['due_at']));
    final w = c.snapshot.wallet(c.account!.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(
          'Olá, ${c.account!.name.split(' ').first}',
          subtitle: 'Hoje é um bom dia para descobrir algo novo.',
        ),
        LayoutBuilder(
          builder: (context, box) {
            final hero = BrandHero(onExplore: () => onNavigate(2));
            final wallet = Surface(
              color: const Color(0xFFF6EDD0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Icon(Icons.stars_rounded, color: Color(0xFF997016)),
                      SizedBox(width: 8),
                      Text(
                        'MINHAS STAR COINS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Text(
                    '${w['available']}',
                    style: const TextStyle(
                      fontSize: 55,
                      fontWeight: FontWeight.w700,
                      color: ink,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'estrelas de participação',
                    style: TextStyle(color: Color(0xFF78643C)),
                  ),
                  const SizedBox(height: 22),
                  TextButton(
                    onPressed: () => onNavigate(3),
                    child: const Text('Ver minha carteira'),
                  ),
                ],
              ),
            );
            return box.maxWidth > 720
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: hero),
                      const SizedBox(width: 20),
                      Expanded(child: wallet),
                    ],
                  )
                : Column(
                    children: [
                      hero,
                      const SizedBox(height: 16),
                      SizedBox(width: double.infinity, child: wallet),
                    ],
                  );
          },
        ),
        SectionHeading(
          'Vem aí na sua agenda',
          subtitle: 'Um pouco de organização, mais espaço para aprender.',
          action: TextButton(
            onPressed: () => onNavigate(1),
            child: const Text('Ver agenda'),
          ),
        ),
        if (activities.isEmpty)
          const EmptyState(
            'Tudo em dia! Novas atividades aparecerão por aqui.',
          ),
        for (final a in activities.take(3))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ActivityTile(c, a),
          ),
        const SectionHeading('Juntos vamos mais longe'),
        for (final g in c.snapshot.rows('goals'))
          Surface(
            color: const Color(0xFFE4F1FC),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Tag('META COLETIVA • SEM RANKING'),
                const SizedBox(height: 16),
                Text(
                  g['name'],
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(g['description']),
                const SizedBox(height: 20),
                LinearProgressIndicator(
                  value:
                      (c.snapshot
                                  .rows('contributions')
                                  .where((r) => r['class_id'] == g['class_id'])
                                  .length /
                              (g['target'] as int))
                          .clamp(0.0, 1.0),
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(8),
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 12),
                Text(
                  '${c.snapshot.rows('contributions').where((r) => r['class_id'] == g['class_id']).length} de ${g['target']} participações • contribuir não gasta suas moedas.',
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class TagLight extends StatelessWidget {
  const TagLight(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: Color(0xFFB8DDFB),
      letterSpacing: 1.8,
      fontSize: 11,
      fontWeight: FontWeight.bold,
    ),
  );
}

Future<void> profile(
  BuildContext context,
  SchoolController c,
) => showDialog<void>(
  context: context,
  builder: (ctx) => AlertDialog(
    title: Text(c.account!.name),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c.account!.role.label),
            if (!c.repository.isDemo)
              TextButton(
                onPressed: () async {
                  final p = await editForm(ctx, 'Definir ou alterar senha', [
                    const FieldSpec(
                      'password',
                      'Nova senha (mínimo 12 caracteres)',
                      obscure: true,
                    ),
                  ]);
                  if (p != null && ctx.mounted) {
                    await runAction(ctx, c, 'password', p, 'Senha atualizada.');
                  }
                },
                child: const Text('Definir ou alterar senha'),
              ),

            const SectionHeading('Conquistas que ficam'),
            const Icon(
              Icons.workspace_premium_outlined,
              color: brandPrimary,
              size: 48,
            ),
            const SizedBox(height: 12),
            const Text(
              'Parceiro da Turma\nComplete cinco missões de colaboração que contribuam para a turma.',
            ),
            const SizedBox(height: 16),
            for (final b
                in c.snapshot
                    .rows('achievements')
                    .where((a) => a['student_id'] == c.account!.id))
              Tag('★ ${b['name']}'),
            const SizedBox(height: 16),
            const Text(
              'Sem ranking público, sem sequências perdidas por faltas. Star Coins não alteram notas.',
            ),
          ],
        ),
      ),
    ),
    actions: [
      if (!c.repository.isDemo)
        TextButton(
          onPressed: () async {
            await c.reminders.clear();
            await c.repository.signOut();
            await c.refresh();
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('Sair'),
        ),
      TextButton(
        onPressed: () => Navigator.pop(ctx),
        child: const Text('Fechar'),
      ),
    ],
  ),
);
