import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:parksmart/services/notification_store_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);

    // Request permission on Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> showLiveSession({
    required String lotName,
    required bool isEv,
    required DateTime startTime,
    required double cost,
  }) async {
    final title = isEv ? 'EV Charging at $lotName' : 'Parking at $lotName';
    final body = 'RM ${cost.toStringAsFixed(2)} so far';

    await _plugin.show(
      1,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'session_live_channel',
          'Live Session',
          channelDescription: 'Live parking session status',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
          ongoing: true,
          autoCancel: false,
          showWhen: true,
          when: startTime.millisecondsSinceEpoch,
          usesChronometer: true,
          visibility: NotificationVisibility.public,
          playSound: false,
          enableVibration: false,
        ),
      ),
    );
  }

  Future<void> showSessionReminder({
    required int seconds,
    required double cost,
    required String lotName,
  }) async {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final duration = h > 0 ? '${h}h ${m}m' : '${m}m';
    final body = '$lotName • $duration elapsed • RM ${cost.toStringAsFixed(2)}';

    NotificationStoreService.save(
      title: 'Parking Session Update',
      body: body,
      type: 'session_reminder',
    );
  }

  Future<void> showPaymentSuccess({
    required String lotName,
    required double amount,
  }) async {
    final body = '$lotName • RM ${amount.toStringAsFixed(2)} paid';

    await _plugin.show(
      2,
      'Payment Successful',
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'payment_channel',
          'Payment Notifications',
          channelDescription: 'Payment success notifications',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          autoCancel: true,
        ),
      ),
    );

    NotificationStoreService.save(
      title: 'Payment Successful',
      body: body,
      type: 'payment',
    );
  }

  Future<void> showSessionStarted({
    required String lotName,
    required bool isEv,
  }) async {
    final title = isEv ? 'EV Charging Started' : 'Parking Session Started';
    final body = 'Your session at $lotName has begun.';

    await _plugin.show(
      3,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'session_channel',
          'Session Reminders',
          channelDescription: 'Parking session reminders',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          autoCancel: true,
        ),
      ),
    );

    NotificationStoreService.save(
      title: title,
      body: body,
      type: isEv ? 'ev_start' : 'session_start',
    );
  }

  Future<void> cancelSessionNotification() async {
    await _plugin.cancel(1);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
