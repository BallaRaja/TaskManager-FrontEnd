import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants/api_constants.dart';
import '../utils/session_manager.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ─────────────────────────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;

    // 1. Initialize timezone data
    tz.initializeTimeZones();

    String timeZoneName;
    try {
      timeZoneName = await FlutterTimezone.getLocalTimezone();
      debugPrint("🕐 Device timezone: $timeZoneName");
    } catch (e) {
      timeZoneName = 'UTC';
      debugPrint("⚠️ Could not get local timezone, using UTC");
    }

    try {
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      tz.setLocalLocation(tz.getLocation('UTC'));
      debugPrint("⚠️ Timezone '$timeZoneName' not found, using UTC");
    }

    // 2. Android init settings
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // 3. iOS init settings
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint("🔔 Notification tapped: ${response.payload}");
      },
    );

    // 4. Android-specific: request permissions + create channel
    if (Platform.isAndroid) {
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidPlugin != null) {
        // Request POST_NOTIFICATIONS permission (Android 13+)
        final granted = await androidPlugin.requestNotificationsPermission();
        debugPrint("🔔 Notification permission granted: $granted");

        // Request SCHEDULE_EXACT_ALARM permission (Android 12+)
        final exactAlarmGranted = await androidPlugin
            .requestExactAlarmsPermission();
        debugPrint("⏰ Exact alarm permission granted: $exactAlarmGranted");

        // Create channel with MAX importance → shows as heads-up banner
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'task_reminders',
          'Task Reminders',
          description: 'Reminders for your upcoming tasks',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        );
        await androidPlugin.createNotificationChannel(channel);
        debugPrint("✅ Notification channel created (MAX importance)");
      }
    }

    _initialized = true;
    debugPrint("✅ NotificationService initialized");
  }

  // ─────────────────────────────────────────────────────────────
  // NOTIFICATION DETAILS  (heads-up banner, lock screen visible)
  // ─────────────────────────────────────────────────────────────
  NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'task_reminders',
        'Task Reminders',
        channelDescription: 'Reminders for your upcoming tasks',
        importance: Importance.max, // heads-up banner
        priority: Priority.max, // highest priority
        playSound: true,
        enableVibration: true,
        visibility: NotificationVisibility.public, // show on lock screen
        fullScreenIntent: true, // wake screen if idle
        autoCancel: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // STABLE POSITIVE NOTIFICATION ID
  // String hashCode can be negative — mask to keep positive int
  // ─────────────────────────────────────────────────────────────
  int _notifId(String taskId) => taskId.hashCode & 0x7FFFFFFF;

  // ─────────────────────────────────────────────────────────────
  // IMMEDIATE TEST NOTIFICATION
  // ─────────────────────────────────────────────────────────────
  Future<void> showTestNotification() async {
    if (!_initialized) await init();
    await _notifications.show(
      0,
      '✅ Notifications Working!',
      'Task reminders are active on this device.',
      _notificationDetails(),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SCHEDULE 2-MIN REMINDER FOR A SINGLE TASK
  // ─────────────────────────────────────────────────────────────
  Future<void> scheduleTaskReminder(Map<String, dynamic> task) async {
    if (!_initialized) await init();

    final String? dueIso = task['dueDate'];
    if (dueIso == null) {
      debugPrint("⏭️ No dueDate for '${task['title']}' — skipping");
      return;
    }

    final DateTime dueDate = DateTime.parse(dueIso).toLocal();
    final DateTime reminderTime = dueDate.subtract(const Duration(minutes: 2));
    final DateTime now = DateTime.now();

    debugPrint(
      "📅 '${task['title']}' due=$dueDate | reminder=$reminderTime | now=$now",
    );

    if (reminderTime.isBefore(now)) {
      // If the due date is still in the future but < 2 min away → fire NOW
      if (dueDate.isAfter(now)) {
        debugPrint("⚡ Due in < 2 min — showing notification immediately");
        await _showImmediateReminder(task, dueDate);
      } else {
        debugPrint("⏭️ Already past due — skipping");
      }
      return;
    }

    final tz.TZDateTime scheduled = tz.TZDateTime.from(reminderTime, tz.local);
    final String timeStr = _formatTime(dueDate);
    final int id = _notifId(task['_id'].toString());

    debugPrint(
      "⏰ Scheduling reminder id=$id for '${task['title']}' at $scheduled",
    );

    // Try exact alarm first
    try {
      await _notifications.zonedSchedule(
        id,
        '⏰ Task Reminder',
        '"${task['title']}" is due at $timeStr',
        scheduled,
        _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: jsonEncode(task),
      );
      debugPrint("✅ Exact reminder set for '${task['title']}' at $scheduled");
      return;
    } catch (e) {
      debugPrint("⚠️ Exact alarm failed: $e — trying inexact fallback");
    }

    // Fallback: inexact (no special permission required)
    try {
      await _notifications.zonedSchedule(
        id,
        '⏰ Task Reminder',
        '"${task['title']}" is due at $timeStr',
        scheduled,
        _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.inexact,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: jsonEncode(task),
      );
      debugPrint("✅ Inexact reminder set for '${task['title']}' at $scheduled");
    } catch (e2) {
      debugPrint("❌ Both alarm modes failed for '${task['title']}': $e2");
    }
  }

  // Fire an immediate notification (task due in < 2 min)
  Future<void> _showImmediateReminder(
    Map<String, dynamic> task,
    DateTime dueDate,
  ) async {
    await _notifications.show(
      _notifId(task['_id'].toString()),
      '⚠️ Task Due Very Soon!',
      '"${task['title']}" is due at ${_formatTime(dueDate)}',
      _notificationDetails(),
      payload: jsonEncode(task),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CANCEL SINGLE REMINDER
  // ─────────────────────────────────────────────────────────────
  Future<void> cancelTaskReminder(String taskId) async {
    await _notifications.cancel(_notifId(taskId));
    debugPrint("🗑️ Cancelled reminder for task $taskId");
  }

  // ─────────────────────────────────────────────────────────────
  // SCHEDULE ALL NOTIFICATIONS FROM API
  // ─────────────────────────────────────────────────────────────
  Future<void> scheduleAllNotifications() async {
    if (!_initialized) await init();

    final String? token = await SessionManager.getToken();
    final String? userId = await SessionManager.getUserId();
    if (token == null || userId == null) {
      debugPrint("⚠️ No session — skipping scheduleAllNotifications");
      return;
    }

    late List tasks;
    try {
      final response = await http
          .get(
            Uri.parse("${ApiConstants.backendUrl}/api/task/$userId"),
            headers: {"Authorization": "Bearer $token"},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint("⚠️ Task fetch failed: ${response.statusCode}");
        return;
      }
      tasks = jsonDecode(response.body)['data'] ?? [];
    } catch (e) {
      debugPrint("⚠️ scheduleAllNotifications error: $e");
      return;
    }

    debugPrint("📋 Scheduling reminders for ${tasks.length} tasks...");

    // Cancel previous to avoid duplicates, then reschedule fresh
    await _notifications.cancelAll();

    final now = DateTime.now();

    for (final task in tasks) {
      if (task['status'] == 'completed' || task['isArchived'] == true) continue;
      await scheduleTaskReminder(task);
    }

    // ── Daily 9 AM overdue summary ──
    final int overdueCount = tasks
        .where(
          (t) =>
              t['status'] != 'completed' &&
              t['dueDate'] != null &&
              DateTime.parse(t['dueDate']).isBefore(now),
        )
        .length;

    final String summaryBody = overdueCount == 0
        ? "Great job! No overdue tasks today 🎉"
        : "You have $overdueCount overdue task${overdueCount > 1 ? 's' : ''}! Tap to review.";

    try {
      await _notifications.zonedSchedule(
        999999,
        '📋 Daily Task Check',
        summaryBody,
        _nextInstanceOfTime(9, 0),
        _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      debugPrint("✅ Daily overdue summary scheduled for 9 AM");
    } catch (e) {
      debugPrint("⚠️ Could not schedule daily summary: $e");
    }

    debugPrint("✅ scheduleAllNotifications complete");
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────
  String _formatTime(DateTime dt) {
    final hour = dt.hour == 0
        ? 12
        : dt.hour > 12
        ? dt.hour - 12
        : dt.hour;
    final min = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$hour:$min $period';
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
