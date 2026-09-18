import 'package:flutter/foundation.dart';
import 'models.dart';
import '../features/agenda/local_reminders.dart';

class SchoolController extends ChangeNotifier {
  SchoolController(this.repository);
  final SchoolRepository repository;
  final reminders = LocalReminders();
  SchoolSnapshot snapshot = SchoolSnapshot({});
  bool loading = false, busy = false;
  String? error;
  final Map<String, String> _pendingReservations = {};
  Account? get account => repository.account;
  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      snapshot = await repository.load();
      try {
        await reminders.sync(snapshot, account);
      } catch (_) {
        /* Notifications never invalidate a committed operation. */
      }
    } catch (e) {
      error = _message(e);
    }
    loading = false;
    notifyListeners();
  }

  Future<bool> act(String operation, JsonMap data) async {
    if (busy) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final requestKey = '${account?.id}:${data['reward_id']}';
      if (operation == 'reserve') {
        data = {
          ...data,
          'request_id': _pendingReservations.putIfAbsent(
            requestKey,
            () => '${account?.id}-${DateTime.now().microsecondsSinceEpoch}',
          ),
        };
      }
      await repository.execute(operation, data);
      snapshot = await repository.load();
      try {
        await reminders.sync(snapshot, account);
      } catch (_) {
        /* Notifications never invalidate a committed operation. */
      }
      if (operation == 'reserve') _pendingReservations.remove(requestKey);
      return true;
    } catch (e) {
      error = _message(e);
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  String _message(Object e) => e is RuleViolation
      ? e.message
      : 'Não foi possível concluir. Verifique a conexão e atualize antes de tentar novamente.';
  Future<void> switchRole(AccessRole role) async {
    repository.switchDemoRole(role);
    await refresh();
  }
}
