typedef JsonMap = Map<String, dynamic>;

enum AccessRole {
  student('Aluno'),
  teacher('Professor'),
  coordinator('Coordenação'),
  guardian('Responsável'),
  delivery('Equipe de entrega');

  const AccessRole(this.label);
  final String label;
}

class Account {
  const Account(this.id, this.name, this.role, this.schoolId);
  final String id, name, schoolId;
  final AccessRole role;
  factory Account.fromJson(JsonMap r) => Account(
    r['id'],
    r['name'],
    AccessRole.values.byName(r['role']),
    r['school_id'],
  );
}

class SchoolSnapshot {
  SchoolSnapshot(this.data);
  final JsonMap data;
  List<JsonMap> rows(String key) => (data[key] as List? ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  List<JsonMap> get activities => rows('activities');
  List<JsonMap> get submissions => rows('submissions');
  List<JsonMap> get rewards => rows('rewards');
  List<JsonMap> get redemptions => rows('redemptions');
  JsonMap submission(String activity, String student) =>
      submissions
          .where(
            (s) => s['activity_id'] == activity && s['student_id'] == student,
          )
          .firstOrNull ??
      {};
  JsonMap wallet(String student) =>
      rows('wallets').where((w) => w['student_id'] == student).firstOrNull ??
      {'available': 0, 'reserved': 0, 'earned': 0};
  String state(JsonMap activity, String student) =>
      activity['cancelled'] == true
      ? 'cancelled'
      : submission(activity['id'], student)['status'] ?? 'pending';
}

class RuleViolation implements Exception {
  RuleViolation(this.message);
  final String message;
  @override
  String toString() => message;
}

const stateLabels = {
  'pending': 'Pendente',
  'submitted': 'Aguardando validação',
  'changes': 'Ajustes solicitados',
  'completed': 'Concluída',
  'cancelled': 'Cancelada',
};
const kindLabels = {
  'academic': 'Atividade acadêmica',
  'practice': 'Boa prática',
  'collective': 'Missão coletiva',
};
bool isLate(JsonMap activity, JsonMap submission, DateTime now) {
  if (activity['cancelled'] == true) return false;
  final due = DateTime.parse(activity['due_at']);
  final sent = submission['submitted_at'];
  return (sent == null ? now : DateTime.parse(sent)).isAfter(due);
}

abstract class SchoolRepository {
  bool get isDemo;
  Account? get account;
  Future<void> signIn(String email, String password);
  Future<void> signOut();
  Future<SchoolSnapshot> load();
  Future<void> execute(String operation, JsonMap payload);
  void switchDemoRole(AccessRole role) =>
      throw RuleViolation('Disponível somente na demonstração.');
}
