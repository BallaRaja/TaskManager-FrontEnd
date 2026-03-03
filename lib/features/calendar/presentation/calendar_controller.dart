// lib/features/calendar/presentation/calendar_controller.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/session_manager.dart';

class CalendarController extends ChangeNotifier {
  List<Map<String, dynamic>> _tasks = [];
  bool _isLoading = true;
  DateTime selectedDate = DateTime.now();
  String? _userId;
  String? _token;

  // Added for profile avatar in CalendarPage
  String? _avatarUrl;
  bool _isLoadingAvatar = true;

  List<Map<String, dynamic>> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get avatarUrl => _avatarUrl;
  bool get isLoadingAvatar => _isLoadingAvatar;

  /// 1 = navigating forward (next week/month), -1 = backward (previous)
  int navigationDirection = 1;

  Future<void> init() async {
    _token = await SessionManager.getToken();
    _userId = await SessionManager.getUserId();
    if (_token == null || _userId == null) return;

    await Future.wait([
      _fetchTasks(),
      _fetchProfileAvatar(), // Fetch avatar separately
    ]);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _fetchProfileAvatar() async {
    try {
      final response = await http.get(
        Uri.parse("${ApiConstants.backendUrl}/api/profile/$_userId"),
        headers: {"Authorization": "Bearer $_token"},
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final rawUrl = json["data"]?["profile"]?["avatarUrl"];

        // Validate and convert URL
        if (rawUrl == null || rawUrl.isEmpty) {
          debugPrint("🧪🧪👤 Calendar: Avatar URL is null or empty");
          _avatarUrl = null;
        } else if (rawUrl.contains('placeholder')) {
          debugPrint("🧪🧪👤 Calendar: Avatar is placeholder: $rawUrl");
          _avatarUrl = null;
        } else if (rawUrl.startsWith('/')) {
          // Relative URL - convert to absolute
          _avatarUrl = "${ApiConstants.backendUrl}$rawUrl";
          debugPrint("🧪🧪👤 Calendar: Converted relative URL to: $_avatarUrl");
        } else if (rawUrl.startsWith('http')) {
          // Already absolute URL
          _avatarUrl = rawUrl;
          debugPrint("🧪🧪👤 Calendar: Using absolute URL: $_avatarUrl");
        } else {
          debugPrint("🧪🧪👤 Calendar: Unknown URL format: $rawUrl");
          _avatarUrl = null;
        }
      }
    } catch (e) {
      debugPrint("Avatar fetch error: $e");
    } finally {
      _isLoadingAvatar = false;
      notifyListeners();
    }
  }

  Future<void> _fetchTasks() async {
    try {
      final response = await http.get(
        Uri.parse("${ApiConstants.backendUrl}/api/task/$_userId"),
        headers: {"Authorization": "Bearer $_token"},
      );
      if (response.statusCode == 200) {
        final List raw = jsonDecode(response.body)["data"] ?? [];
        _tasks = List<Map<String, dynamic>>.from(raw);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Calendar fetch error: $e");
    }
  }

  void setSelectedDate(DateTime date) {
    final newDate = DateTime(date.year, date.month, date.day);
    navigationDirection = newDate.isAfter(selectedDate) ? 1 : -1;
    selectedDate = newDate;
    notifyListeners();
  }

  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();
    await Future.wait([_fetchTasks(), _fetchProfileAvatar()]);
    _isLoading = false;
    notifyListeners();
  }

  /// Determine whether a specific occurrence of a (possibly repeating) task
  /// is marked completed based on the `completedDates` array that we will
  /// start storing on the backend.
  bool _isInstanceCompleted(Map<String, dynamic> task, DateTime date) {
    // non-repeating tasks rely on the regular status field
    if (task['repeat'] == null) {
      return task['status'] == 'completed';
    }
    final List<dynamic> completed = task['completedDates'] ?? [];
    for (final d in completed) {
      try {
        final dt = DateTime.parse(d.toString()).toLocal();
        if (dt.year == date.year && dt.month == date.month && dt.day == date.day) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  /// Toggle a task's completion status for a given instance or globally.
  /// After updating the server we refresh the list to make sure the local
  /// copy stays accurate (especially because the backend may rewrite the
  /// `completedDates` array).
  Future<bool> toggleTaskComplete(Map<String, dynamic> task) async {
    final token = _token ?? await SessionManager.getToken();
    if (token == null) return false;
    final taskId = task['_id']?.toString();
    if (taskId == null) return false;

    // figure out the target instance date (if available)
    DateTime? instanceDate;
    if (task['dueDate'] != null) {
      instanceDate = DateTime.parse(task['dueDate']).toLocal();
    }

    // compute new status: if instanceDate exists and the task is repeating we
    // look up the instance status, otherwise use the simple status field.
    final bool currentlyCompleted = instanceDate != null && task['repeat'] != null
        ? _isInstanceCompleted(task, instanceDate)
        : task['status'] == 'completed';

    final newStatus = currentlyCompleted ? 'pending' : 'completed';

    final body = <String, dynamic>{'status': newStatus};
    if (instanceDate != null) {
      body['instanceDate'] = instanceDate.toIso8601String();
    }
    if (newStatus == 'completed') {
      body['completedAt'] = DateTime.now().toIso8601String();
    } else {
      body['completedAt'] = null;
    }

    try {
      final response = await http.put(
        Uri.parse('${ApiConstants.backendUrl}/api/task/$taskId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        // server returns updated task; rather than manually patching the list
        // it's simpler to refetch everything so that completedDates etc are
        // in sync.
        await _fetchTasks();
        notifyListeners();
        return true;
      }
    } catch (_) {}
    return false;
  }

  // Public method to refresh avatar only
  Future<void> refreshAvatar() async {
    await _fetchProfileAvatar();
  }

  // Recurrence Logic (unchanged)
  bool hasInstanceOnDate(Map<String, dynamic> task, DateTime date) {
    final dueStr = task["dueDate"];
    if (dueStr == null) return false;
    // Convert UTC → local so day comparisons use device timezone
    final baseDue = DateTime.parse(dueStr).toLocal();
    final repeat = task["repeat"] as Map<String, dynamic>?;

    if (repeat == null) {
      return _isSameDay(baseDue, date);
    }

    final untilStr = repeat["until"];
    final until = untilStr != null ? DateTime.parse(untilStr).toLocal() : null;
    if (until != null && date.isAfter(until)) return false;

    final frequency = repeat["frequency"] as String;
    final interval = repeat["interval"] as int? ?? 1;
    final daysOfWeek = List<String>.from(repeat["daysOfWeek"] ?? []);

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

  List<Map<String, dynamic>> getInstancesForDate(DateTime date) {
    final instances = <Map<String, dynamic>>[];
    final normalizedDate = DateTime(date.year, date.month, date.day);

    for (final task in _tasks) {
      if (task["isArchived"] == true) continue;

      final dueStr = task["dueDate"] as String?;
      if (dueStr == null) continue;

      // Convert UTC → local for correct hour/minute assignment
      final baseDue = DateTime.parse(dueStr).toLocal();
        if (hasInstanceOnDate(task, normalizedDate)) {
        final instance = Map<String, dynamic>.from(task);
        final instanceDue = DateTime(
          normalizedDate.year,
          normalizedDate.month,
          normalizedDate.day,
          baseDue.hour,
          baseDue.minute,
        );
        // Store as UTC for consistent internal representation
        instance["dueDate"] = instanceDue.toUtc().toIso8601String();
        // override status for this particular occurrence
        if (_isInstanceCompleted(task, normalizedDate)) {
          instance['status'] = 'completed';
        } else {
          instance['status'] = 'pending';
        }
        instances.add(instance);
      }
    }

    instances.sort(
      (a, b) =>
          DateTime.parse(a["dueDate"]).compareTo(DateTime.parse(b["dueDate"])),
    );
    return instances;
  }

  List<Map<String, dynamic>> getOverdueInstances() {
    final overdue = <Map<String, dynamic>>[];
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 365));

    for (final task in _tasks) {
      if (task["isArchived"] == true) continue;
      final dueStr = task["dueDate"] as String?;
      if (dueStr == null) continue;

      // Convert UTC → local for correct day/time comparisons
      final baseDue = DateTime.parse(dueStr).toLocal();
      DateTime current = baseDue;
      final repeat = task["repeat"] as Map<String, dynamic>?;

      while (current.isBefore(now) && current.isAfter(cutoff)) {
        if (hasInstanceOnDate(task, current)) {
          if (!_isInstanceCompleted(task, current)) {
            final instance = Map<String, dynamic>.from(task);
            instance["dueDate"] = current.toUtc().toIso8601String();
            overdue.add(instance);
          }
        }
        if (repeat == null) break;

        final freq = repeat["frequency"] as String;
        final interval = repeat["interval"] as int? ?? 1;
        current = current.add(_frequencyToDuration(freq) * interval);
      }
    }

    overdue.sort(
      (a, b) =>
          DateTime.parse(a["dueDate"]).compareTo(DateTime.parse(b["dueDate"])),
    );
    return overdue;
  }

  Duration _frequencyToDuration(String freq) {
    switch (freq) {
      case "daily":
        return const Duration(days: 1);
      case "weekly":
        return const Duration(days: 7);
      case "monthly":
        return const Duration(days: 30); // approximate
      default:
        return const Duration(days: 1);
    }
  }

  String _weekdayToAbbrev(int weekday) {
    const days = ["", "mon", "tue", "wed", "thu", "fri", "sat", "sun"];
    return days[weekday];
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
