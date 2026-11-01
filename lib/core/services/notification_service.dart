import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  final Map<String, int> _lastAlertTimestamps = {};

  Future<void> init() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        // App opened from notification
      },
    );

    // Request Android 13+ notification permission
    final androidPlatform = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlatform?.requestNotificationsPermission();

    _isInitialized = true;
  }

  /// 1. Urgent Order Notification: When rider is OFFLINE / shift closed but an order is waiting in the zone
  Future<void> showUrgentOrderAlert({
    required String orderId,
    required String orderRef,
    required String area,
    required double amount,
  }) async {
    if (!_shouldAlert(orderId, cooldownSeconds: 180)) return;

    const androidDetails = AndroidNotificationDetails(
      'fe_sawany_urgent_channel',
      '🚨 طلبات طارئة في منطقتك',
      channelDescription: 'تنبيهات فورية عند وجود طلبات في منطقتك حتى لو الوردية مغلقة',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      ticker: 'طلب طارئ في ثواني',
    );

    await _plugin.show(
      orderId.hashCode,
      '🚨 طلب طارئ متاح في $area!',
      'طلب #$orderRef بقيمة ${amount.toStringAsFixed(0)} ج.م • افتح التطبيق للقبول فوراً',
      const NotificationDetails(android: androidDetails),
    );
  }

  /// 2. New Order Notification: When rider is ON DUTY
  Future<void> showNewOrderAlert({
    required String orderId,
    required String orderRef,
    required String storeName,
    required double earning,
  }) async {
    if (!_shouldAlert(orderId, cooldownSeconds: 120)) return;

    const androidDetails = AndroidNotificationDetails(
      'fe_sawany_duty_channel',
      '🛵 طلبات جديدة متاحة',
      channelDescription: 'إشعارات الطلبات المتاحة على الرادار أثناء الوردية',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      ticker: 'طلب جديد في ثواني',
    );

    await _plugin.show(
      orderId.hashCode,
      '🛵 طلب جديد متاح: $storeName',
      'طلب #$orderRef (+${earning.toStringAsFixed(0)} ج.م أرباحك) • اضغط للمعاينة',
      const NotificationDetails(android: androidDetails),
    );
  }

  /// 3. Delayed Order Alert: When an order is pending for > 20 minutes
  Future<void> showDelayedOrderAlert({
    required String orderId,
    required String orderRef,
    required int elapsedMinutes,
  }) async {
    if (!_shouldAlert("delayed_$orderId", cooldownSeconds: 300)) return;

    const androidDetails = AndroidNotificationDetails(
      'fe_sawany_delayed_channel',
      '⚠️ تنبيهات تأخير الطلبات',
      channelDescription: 'تنبيهات عند بقاء الطلبات معلقة لفترة أطول من المعتاد',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      ticker: 'تنبيه تأخير طلب',
    );

    await _plugin.show(
      ("delayed_$orderId").hashCode,
      '⚠️ طلب معلق يحتاج تحرك سريع!',
      'طلب #$orderRef معلق منذ $elapsedMinutes دقيقة • يرجى سرعة المتابعة والتوصيل',
      const NotificationDetails(android: androidDetails),
    );
  }

  bool _shouldAlert(String key, {int cooldownSeconds = 120}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _lastAlertTimestamps[key] ?? 0;
    if (now - last < cooldownSeconds * 1000) {
      return false;
    }
    _lastAlertTimestamps[key] = now;
    return true;
  }
}
