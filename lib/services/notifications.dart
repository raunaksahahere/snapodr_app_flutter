import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Local notifications raised from the polling loops. There is no push server
/// yet, so these only fire while the app is running.
class Notifications {
  static final _plugin = FlutterLocalNotificationsPlugin();

  // Sound and importance are baked into the channel on Android 8+ and cannot be
  // changed afterwards, so cash alerts get their own channel to stand apart.
  static const _orderChannel = AndroidNotificationDetails(
    'snapodr_orders',
    'Live orders',
    channelDescription: 'New orders and kitchen status changes',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
  );

  static const _cashChannel = AndroidNotificationDetails(
    'snapodr_cash',
    'Cash to collect',
    channelDescription: 'A table has asked to settle their bill in cash',
    importance: Importance.max,
    priority: Priority.max,
    playSound: true,
    category: AndroidNotificationCategory.reminder,
  );

  static Future<void> init() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> order(String title, String body, {required String key}) => _show(title, body, key, _orderChannel);

  static Future<void> cash(String title, String body, {required String key}) => _show(title, body, key, _cashChannel);

  static Future<void> _show(String title, String body, String key, AndroidNotificationDetails android) => _plugin.show(
    // Deriving the id from the order/session keeps repeat alerts for the same
    // thing from stacking up in the tray.
    id: key.hashCode & 0x7fffffff,
    title: title,
    body: body,
    notificationDetails: NotificationDetails(android: android, iOS: const DarwinNotificationDetails()),
  );
}
