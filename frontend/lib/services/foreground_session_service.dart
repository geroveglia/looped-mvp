import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Keeps the app process alive with a persistent notification while a dance
/// session is running, so the pedometer stream and timers survive screen lock
/// and backgrounding (Android would otherwise freeze the process in minutes).
///
/// Notification-only mode: no background isolate/callback — all session logic
/// stays in [DanceSessionManager] on the main isolate.
///
/// Android-only; every method is a safe no-op on other platforms.
class ForegroundSessionService {
  ForegroundSessionService._();

  static bool _initialized = false;

  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static void _ensureInit() {
    if (_initialized) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'looped_session',
        channelName: 'Active dance session',
        channelDescription:
            'Keeps step tracking alive while the screen is locked',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions:
          const IOSNotificationOptions(showNotification: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        // No repeating background callback — notification-only mode.
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        autoRunOnBoot: false,
        // Restarting the bare service after a kill is useless without the
        // app's session state; the saved-session restore handles that case.
        allowAutoRestart: false,
      ),
    );
    _initialized = true;
  }

  static Future<void> start(
      {required String title, required String text}) async {
    if (!_supported) return;
    try {
      _ensureInit();
      // Android 13+: notification permission is needed for the FGS banner.
      await FlutterForegroundTask.requestNotificationPermission();

      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(
            notificationTitle: title, notificationText: text);
        return;
      }
      await FlutterForegroundTask.startService(
        // 'health' matches step tracking and is required on Android 14+;
        // it needs ACTIVITY_RECOGNITION granted, which the session manager
        // requests before starting the session.
        serviceTypes: const [ForegroundServiceTypes.health],
        notificationTitle: title,
        notificationText: text,
      );
    } catch (e) {
      // A session without the FGS still works in foreground — never block it.
      debugPrint('ForegroundSessionService.start failed: $e');
    }
  }

  static Future<void> update(
      {required String title, required String text}) async {
    if (!_supported) return;
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(
            notificationTitle: title, notificationText: text);
      }
    } catch (e) {
      debugPrint('ForegroundSessionService.update failed: $e');
    }
  }

  static Future<void> stop() async {
    if (!_supported) return;
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (e) {
      debugPrint('ForegroundSessionService.stop failed: $e');
    }
  }
}
