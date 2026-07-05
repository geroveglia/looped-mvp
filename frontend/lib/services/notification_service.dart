import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// flutter_local_notifications has no web implementation; every entry point
  /// no-ops on web so the app can run in a browser (design/dev preview).
  static bool get _unsupported => kIsWeb;

  Future<void> init() async {
    if (_unsupported || _initialized) return;

    tz_data.initializeTimeZones();
    
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification click if needed
      },
    );
    _initialized = true;
  }

  Future<void> showHydrationReminder() async {
    if (_unsupported) return;
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'hydration_channel',
      'Hydration Reminders',
      channelDescription: 'Reminders to stay hydrated during dance sessions',
      importance: Importance.high,
      priority: Priority.high,
      color: Color(0xFF00D9A5), // Looped Accent
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _notifications.show(
      0,
      'Stay Hydrated! 💧',
      'Take a moment to drink some water and keep the energy up!',
      platformDetails,
    );
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (_unsupported) return;
    if (scheduledDate.isBefore(DateTime.now())) return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'event_reminders',
      'Event Reminders',
      channelDescription: 'Reminders for events you are interested in',
      importance: Importance.high,
      priority: Priority.high,
      color: Color(0xFF00D9A5),
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    // One-shot reminder. Do NOT pass matchDateTimeComponents here:
    // DateTimeComponents.time would turn it into a DAILY repeating alarm.
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelNotification(int id) async {
    if (_unsupported) return;
    await _notifications.cancel(id);
  }

  /// Returns all currently scheduled (pending) notifications.
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (_unsupported) return [];
    return _notifications.pendingNotificationRequests();
  }
}
