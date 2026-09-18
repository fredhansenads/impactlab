import '../core/models.dart';
import '../domain/school_engine.dart';
import 'demo_seed.dart';

/// Session-only storage adapter; domain rules live in SchoolEngine.
class DemoSchoolRepository extends SchoolRepository {
  DemoSchoolRepository({DateTime Function()? clock})
    : engine = SchoolEngine(demoSeed((clock ?? DateTime.now)()), clock: clock);
  final SchoolEngine engine;
  @override
  bool get isDemo => true;
  @override
  Account get account => engine.account;
  @override
  void switchDemoRole(AccessRole role) => engine.switchDemoRole(role);
  @override
  Future<void> signIn(String email, String password) =>
      engine.signIn(email, password);
  @override
  Future<void> signOut() => engine.signOut();
  @override
  Future<SchoolSnapshot> load() => engine.load();
  @override
  Future<void> execute(String operation, JsonMap payload) =>
      engine.execute(operation, payload);
  // Inspectable fixtures for domain tests, never exposed by the real repository.
  List<JsonMap> rows(String key) => engine.rows(key);
  JsonMap find(String table, String id) => engine.find(table, id);
  JsonMap wallet(String student) => engine.wallet(student);
  set online(bool value) => engine.online = value;
}
