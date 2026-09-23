import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../../core/models.dart';

/// Local deadline reminders. Server-side background push is a separate integration.
class LocalReminders {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool enabled = false;
  String? _owner;
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  Future<bool> enable(SchoolSnapshot snapshot, Account account) async {
    if (!supported) {
      throw RuleViolation(
        'Os lembretes do aparelho estão disponíveis no aplicativo Android e iOS. Na Web, consulte os avisos nesta área.',
      );
    }
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    final granted = defaultTargetPlatform == TargetPlatform.android
        ? await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission()
        : await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true);
    enabled = granted == true;
    _owner = account.id;
    if (enabled) await sync(snapshot, account);
    return enabled;
  }

  Future<void> clear() async {
    if (supported) await _plugin.cancelAllPendingNotifications();
    enabled = false;
    _owner = null;
  }

  Future<void> sync(SchoolSnapshot snapshot, Account? account) async {
    if (!enabled) return;
    if (account == null || account.id != _owner) {
      await clear();
      return;
    }
    await _plugin.cancelAllPendingNotifications();
    if (account.role != AccessRole.student) return;
    final entries = [
      ...snapshot.activities.where(
        (a) => ['pending', 'changes'].contains(snapshot.state(a, account.id)),
      ),
      ...snapshot.rows('personal'),
    ]..sort((a, b) => a['due_at'].compareTo(b['due_at']));
    var id = 1;
    for (final entry in entries.take(40)) {
      final when = DateTime.parse(
        entry['due_at'],
      ).toUtc().subtract(const Duration(hours: 24));
      if (!when.isAfter(DateTime.now().toUtc())) continue;
      await _plugin.zonedSchedule(
        id: id++,
        scheduledDate: tz.TZDateTime.from(when, tz.UTC),
        title: 'Um compromisso se aproxima',
        body: 'Confira sua agenda no ImpactLab.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'deadlines',
            'Lembretes de prazo',
            channelDescription: 'Avisos sem dados pessoais',
            importance: Importance.defaultImportance,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }
}
