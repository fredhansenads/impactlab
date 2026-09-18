import 'package:flutter/material.dart';
import '../../core/controller.dart';
import '../../core/widgets.dart';

class LoginView extends StatefulWidget {
  const LoginView(this.c, {super.key});
  final SchoolController c;
  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final email = TextEditingController(), password = TextEditingController();
  String? error;
  bool busy = false;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Surface(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.auto_awesome, color: teal, size: 42),
                const SectionHeading(
                  'Bem-vindo ao Portal Escolar',
                  subtitle: 'Entre com a conta fornecida pela escola.',
                ),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.username],
                  decoration: const InputDecoration(labelText: 'E-mail'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: password,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(labelText: 'Senha'),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () async {
                          setState(() {
                            busy = true;
                            error = null;
                          });
                          try {
                            await widget.c.repository.signIn(
                              email.text,
                              password.text,
                            );
                            await widget.c.refresh();
                          } catch (_) {
                            if (mounted) {
                              setState(
                                () => error =
                                    'Não foi possível entrar. Confira os dados, a conexão ou fale com a escola.',
                              );
                            }
                          } finally {
                            if (mounted) setState(() => busy = false);
                          }
                        },
                  child: Text(busy ? 'Entrando…' : 'Entrar'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: busy
                      ? null
                      : () async {
                          if (!email.text.contains('@')) {
                            setState(
                              () => error =
                                  'Informe seu e-mail para recuperar o acesso.',
                            );
                            return;
                          }
                          setState(() => busy = true);
                          try {
                            await widget.c.repository.execute('recover', {
                              'email': email.text.trim(),
                            });
                            if (mounted) {
                              setState(
                                () => error =
                                    'Se houver uma conta cadastrada, você receberá as instruções por e-mail.',
                              );
                            }
                          } catch (_) {
                            if (mounted) {
                              setState(
                                () => error =
                                    'Não foi possível enviar as instruções. Confira a conexão e fale com a escola.',
                              );
                            }
                          } finally {
                            if (mounted) setState(() => busy = false);
                          }
                        },
                  child: const Text('Recuperar acesso'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
