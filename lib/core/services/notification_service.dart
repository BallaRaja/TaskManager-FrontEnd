import 'package:client/core/utils/session_manager.dart';
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

  Future<void> init() async {
    // Initialize timezone data
    tz.initializeTimeZones();

    String timeZoneName;
    try {
      timeZoneName = await FlutterTimezone.getLocalTimezone();
    } catch (e) {
      // Fallback for desktop platforms (Linux/macOS/Windows) or any error
      debugPrint(
        "⚠️ Could not get local timezone, using UTC (common on desktop)",
      );
      timeZoneName = 'UTC';
    }

    // Set local location (safe even if timezone not found)
    try {
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint("⚠️ Timezone '$timeZoneName' not found, falling back to UTC");
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    // Rest of initialization (unchanged)
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _notifications.initialize(initSettings);

    // Create Android channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'task_reminders',
      'Task Reminders',
      description: 'Notifications for upcoming and overdue tasks',
      importance: Importance.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('reminder'),
    );

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(channel);
  }

  NotificationDetails _notificationDetails() {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'task_reminders',
        'Task Reminders',
        channelDescription: 'Task reminders and overdue alerts',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('reminder'),
      ),
      iOS: DarwinNotificationDetails(
        sound: 'reminder.caf',
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  // Schedule 10-min reminder for a task
  Future<void> scheduleTaskReminder(Map<String, dynamic> task) async {
    final String? dueIso = task['dueDate'];
    if (dueIso == null) return;

    final DateTime dueDate = DateTime.parse(dueIso);
    final DateTime reminderTime = dueDate.subtract(const Duration(minutes: 10));

    if (reminderTime.isBefore(DateTime.now())) return; // Past, no reminder

    final tz.TZDateTime scheduled = tz.TZDateTime.from(reminderTime, tz.local);

    await _notifications.zonedSchedule(
      task['_id'].hashCode, // Unique ID
      'Upcoming Task',
      '${task['title']} is due in 10 minutes!',
      scheduled,
      _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode(task),
    );
  }

  // Cancel reminder for a task
  Future<void> cancelTaskReminder(String taskId) async {
    await _notifications.cancel(taskId.hashCode);
  }

  // Fetch tasks and schedule all reminders + daily overdue check
  Future<void> scheduleAllNotifications() async {
    final String? token = await SessionManager.getToken();
    final String? userId = await SessionManager.getUserId();
    if (token == null || userId == null) return;

    final response = await http.get(
      Uri.parse("${ApiConstants.backendUrl}/api/task/$userId"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode != 200) return;

    final List tasks = jsonDecode(response.body)['data'] ?? [];
    final now = DateTime.now();

    // Cancel all previous reminders first (to avoid duplicates)
    await _notifications.cancelAll();

    // Schedule individual reminders
    for (final task in tasks) {
      if (task['status'] == 'completed' || task['isArchived'] == true) continue;
      await scheduleTaskReminder(task);
    }

    // Schedule daily overdue summary at 9 AM
    final tz.TZDateTime next9AM = _nextInstanceOfTime(9, 0);
    int overdueCount = tasks
        .where(
          (t) =>
              t['status'] != 'completed' &&
              t['dueDate'] != null &&
              DateTime.parse(t['dueDate']).isBefore(now),
        )
        .length;

    String body = overdueCount == 0
        ? "Great job! No overdue tasks today 🎉"
        : "You have $overdueCount overdue task${overdueCount > 1 ? 's' : ''}!";

    await _notifications.zonedSchedule(
      999999, // Fixed ID for daily overdue
      'Daily Task Check',
      body,
      next9AM,
      _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // Repeats daily at 9 AM
    );
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
