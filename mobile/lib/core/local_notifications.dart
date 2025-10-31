import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotifications {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static const AndroidNotificationChannel _defaultChannel = AndroidNotificationChannel(
    'default_channel',
    'Geral',
    description: 'Notificações gerais',
    importance: Importance.high,
  );

  static Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOSInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidInit, iOS: iOSInit);
    await _plugin.initialize(initSettings);
    await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_defaultChannel);
  }

  static Future<void> showSimple({required String title, required String body}) async {
    const android = AndroidNotificationDetails(
      'default_channel',
      'Geral',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iOS = DarwinNotificationDetails();
    const details = NotificationDetails(android: android, iOS: iOS);
    await _plugin.show(DateTime.now().millisecondsSinceEpoch ~/ 1000, title, body, details);
  }
}
