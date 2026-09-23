import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../test/support/mobile_scenario.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Native demo: navigation, roles, keyboard and submission',
    mobileScenario,
  );
  testWidgets(
    'Native notification plugin registers without requesting permission',
    (tester) async {
      final notifications = FlutterLocalNotificationsPlugin();
      final initialized = await notifications.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_notification'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      expect(initialized, isTrue);
      expect(await notifications.pendingNotificationRequests(), isEmpty);
    },
  );
}
