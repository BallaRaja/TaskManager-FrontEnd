import 'package:client/core/utils/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants/api_constants.dart';

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

    final DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: <DarwinNotificationCategory>[
        DarwinNotificationCategory(
          'task_reminders',
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.plain('mark_done', 'Mark as done'),
            DarwinNotificationAction.plain('snooze', 'Snooze/Extend 1h'),
          ],
        ),
      ],
    );

    final InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    // Initialize plugin with callback for actions
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

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
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction('mark_done', 'Mark as done',
              showsUserInterface: true, cancelNotification: true),
          AndroidNotificationAction('snooze', 'Snooze/Extend 1h',
              showsUserInterface: true, cancelNotification: true),
        ],
      ),
      iOS: DarwinNotificationDetails(
        sound: 'reminder.caf',
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        categoryIdentifier: 'task_reminders',
      ),
    );
  }

  // Schedule reminder 3 minutes before a task
  Future<void> scheduleTaskReminder(Map<String, dynamic> task) async {
    final String? dueIso = task['dueDate'];
    if (dueIso == null) return;

    final DateTime dueDate = DateTime.parse(dueIso);
    final DateTime reminderTime = dueDate.subtract(const Duration(minutes: 3));

    if (reminderTime.isBefore(DateTime.now())) return; // Past, no reminder

    final tz.TZDateTime scheduled = tz.TZDateTime.from(reminderTime, tz.local);

    await _notifications.zonedSchedule(
      task['_id'].hashCode, // Unique ID
      'Upcoming Task',
      '${task['title']} is due in 3 minutes!',
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

      // collect all upcoming due dates within a reasonable window
      final dates = _upcomingInstances(task, daysAhead: 30);
      for (final due in dates) {
        final copy = Map<String, dynamic>.from(task);
        copy['dueDate'] = due.toUtc().toIso8601String();
        await scheduleTaskReminder(copy);
      }
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

  // Handle taps and actions from notifications
  void _handleNotificationResponse(NotificationResponse response) async {
    if (response.payload == null) return;
    try {
      final Map<String, dynamic> task = jsonDecode(response.payload!);
      final String? actionId = response.actionId;

      if (actionId == 'mark_done') {
        await _updateTaskStatus(task, 'completed');
      } else if (actionId == 'snooze') {
        await _snoozeTask(task);
      }
    } catch (e) {
      debugPrint('Notification response error: $e');
    }
  }

  Future<void> _updateTaskStatus(Map<String, dynamic> task, String status) async {
    final String? token = await SessionManager.getToken();
    if (token == null) return;
    final id = task['_id']?.toString();
    if (id == null) return;

    final body = <String, dynamic>{'status': status};
    // if this notification refers to a specific instance (dueDate may differ)
    if (task['dueDate'] != null) {
      body['instanceDate'] = task['dueDate'];
    }

    try {
      final resp = await http.put(
        Uri.parse('${ApiConstants.backendUrl}/api/task/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );
      if (resp.statusCode == 200) {
        // reschedule notifications to reflect change
        await scheduleAllNotifications();
      }
    } catch (e) {
      debugPrint('Error updating task status from notification: $e');
    }
  }

  Future<void> _snoozeTask(Map<String, dynamic> task) async {
    final String? token = await SessionManager.getToken();
    if (token == null) return;
    final id = task['_id']?.toString();
    if (id == null) return;

    final dueIso = task['dueDate'];
    if (dueIso == null) return;

    final DateTime due = DateTime.parse(dueIso);
    final DateTime newDue = due.add(const Duration(hours: 1));

    final body = <String, dynamic>{'dueDate': newDue.toIso8601String()};
    // also send instanceDate for repeatable tasks so only this occurrence shifts
    if (task['repeat'] != null) {
      body['instanceDate'] = dueIso;
    }

    try {
      final resp = await http.put(
        Uri.parse('${ApiConstants.backendUrl}/api/task/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );
      if (resp.statusCode == 200) {
        await scheduleAllNotifications();
      }
    } catch (e) {
      debugPrint('Error snoozing task from notification: $e');
    }
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

  // Basic recurrence helpers copied from calendar controller so we can
  // determine upcoming instances without pulling in that class.
  String _weekdayToAbbrev(int weekday) {
    const days = ["", "mon", "tue", "wed", "thu", "fri", "sat", "sun"];
    return days[weekday];
  }
  bool _hasInstance(Map<String, dynamic> task, DateTime date) {
    final dueStr = task['dueDate'];
    if (dueStr == null) return false;
    final baseDue = DateTime.parse(dueStr).toLocal();
    final repeat = task['repeat'] as Map<String, dynamic>?;

    if (repeat == null) {
      return _isSameDay(baseDue, date);
    }

    final untilStr = repeat['until'];
    final until = untilStr != null ? DateTime.parse(untilStr).toLocal() : null;
    if (until != null && date.isAfter(until)) return false;

    final frequency = repeat['frequency'] as String;
    final interval = repeat['interval'] as int? ?? 1;
    final daysOfWeek = List<String>.from(repeat['daysOfWeek'] ?? []);

    final daysDiff = date.difference(baseDue).inDays;

    if (frequency == "daily") {
      return daysDiff >= 0 && daysDiff % interval == 0;
    } else if (frequency == "weekly") {
      final weekDiff = daysDiff ~/ 7;
      final dayAbbrev = _weekdayToAbbrev(date.weekday);
      final requiredDays = daysOfWeek.isEmpty
          ? [_weekdayToAbbrev(baseDue.weekday)]
          : daysOfWeek;
      return weekDiff >= 0 &&
          weekDiff % interval == 0 &&
          requiredDays.contains(dayAbbrev);
    } else if (frequency == "monthly") {
      final monthsDiff =
          (date.year - baseDue.year) * 12 + (date.month - baseDue.month);
      if (monthsDiff >= 0 && monthsDiff % interval == 0) {
        final targetDay = baseDue.day;
        final daysInMonth = DateTime(date.year, date.month + 1, 0).day;
        return targetDay <= daysInMonth && date.day == targetDay;
      }
    }
    return false;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime? _nextDueForTask(Map<String, dynamic> task) {
    final dueStr = task['dueDate'];
    if (dueStr == null) return null;
    DateTime candidate = DateTime.parse(dueStr).toLocal();
    final now = DateTime.now();

    // if non repeating and still in future, return candidate
    if (task['repeat'] == null) {
      return candidate.isAfter(now) ? candidate : null;
    }

    // for repeating tasks, search forward day-by-day up to a year
    for (int i = 0; i < 365; i++) {
      if (candidate.isAfter(now) && _hasInstance(task, candidate)) {
        return candidate;
      }
      candidate = candidate.add(const Duration(days: 1));
    }
    return null;
  }

  /// Return all instance due dates for the given task starting from now up to
  /// [daysAhead] days.  This ensures multiple reminders can be scheduled for
  /// repeating tasks.  Non-repeating tasks will yield a single date if it's
  /// still in the future.
  List<DateTime> _upcomingInstances(Map<String, dynamic> task, {int daysAhead = 30}) {
    final dueStr = task['dueDate'];
    if (dueStr == null) return [];
    final now = DateTime.now();
    final pathDates = <DateTime>[];

    DateTime candidate = DateTime.parse(dueStr).toLocal();

    if (task['repeat'] == null) {
      if (candidate.isAfter(now)) pathDates.add(candidate);
      return pathDates;
    }

    final cutoff = now.add(Duration(days: daysAhead));
    // start from the later of base due or today
    if (candidate.isBefore(now)) candidate = now;

    // walk forward until cutoff
    while (candidate.isBefore(cutoff)) {
      if (_hasInstance(task, candidate) && candidate.isAfter(now)) {
        pathDates.add(candidate);
      }
      candidate = candidate.add(const Duration(days: 1));
    }

    return pathDates;
  }
}
