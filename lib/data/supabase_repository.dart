import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/models.dart';

class SupabaseSchoolRepository extends SchoolRepository {
  SupabaseSchoolRepository(this.client);
  final SupabaseClient client;
  Account? _account;
  @override
  Account? get account => _account;
  @override
  bool get isDemo => false;
  @override
  Future<void> signIn(String email, String password) async {
    await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    await load();
  }

  @override
  Future<void> signOut() async {
    await client.auth.signOut();
    _account = null;
  }

  @override
  Future<SchoolSnapshot> load() async {
    if (client.auth.currentUser == null) {
      _account = null;
      return SchoolSnapshot({});
    }
    final result = Map<String, dynamic>.from(
      await client.rpc('school_snapshot') as Map,
    );
    _account = Account.fromJson(Map<String, dynamic>.from(result['account']));
    return SchoolSnapshot(result);
  }

  @override
  Future<void> execute(String operation, JsonMap payload) async {
    if (operation == 'recover') {
      const redirect = String.fromEnvironment('AUTH_REDIRECT_URL');
      await client.auth.resetPasswordForEmail(
        payload['email'],
        redirectTo: redirect.isEmpty ? null : redirect,
      );
      return;
    }
    if (operation == 'password') {
      if ((payload['password'] as String).length < 12) {
        throw RuleViolation('Use pelo menos 12 caracteres.');
      }
      await client.auth.updateUser(
        UserAttributes(password: payload['password']),
      );
      return;
    }
    if (client.auth.currentSession == null) {
      throw RuleViolation('Entre novamente para continuar.');
    }
    try {
      payload = {...payload};
      for (final key in ['start_at', 'due_at', 'end_at']) {
        if (payload[key] is String) {
          payload[key] = DateTime.parse(payload[key]).toUtc().toIso8601String();
        }
      }
      if (operation == 'invite') {
        try {
          await client.functions.invoke('invite-user', body: payload);
        } on FunctionException catch (e) {
          throw RuleViolation(
            e.details is Map
                ? e.details['error'] as String? ?? 'Confira o cadastro.'
                : 'Confira o serviço de convites.',
          );
        }
        return;
      }
      await client.rpc(
        'school_command',
        params: {'operation': operation, 'payload': payload},
      );
    } on PostgrestException catch (e) {
      if (e.code == 'P0001') throw RuleViolation(e.message);
      rethrow;
    }
  }
}
