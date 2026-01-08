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
        _avatarUrl = json["data"]?["profile"]?["avatarUrl"];
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
    selectedDate = DateTime(date.year, date.month, date.day);
    notifyListeners();
  }

  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();
    await Future.wait([_fetchTasks(), _fetchProfileAvatar()]);
    _isLoading = false;
    notifyListeners();
  }

  // Recurrence Logic (unchanged)
  bool hasInstanceOnDate(Map<String, dynamic> task, DateTime date) {
    final dueStr = task["dueDate"];
    if (dueStr == null) return false;
    final baseDue = DateTime.parse(dueStr);
    final repeat = task["repeat"] as Map<String, dynamic>?;

    if (repeat == null) {
      return _isSameDay(baseDue, date);
    }

    final untilStr = repeat["until"];
    final until = untilStr != null ? DateTime.parse(untilStr) : null;
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

      final baseDue = DateTime.parse(dueStr);
      if (hasInstanceOnDate(task, normalizedDate)) {
        final instance = Map<String, dynamic>.from(task);
        final instanceDue = DateTime(
          normalizedDate.year,
          normalizedDate.month,
          normalizedDate.day,
          baseDue.hour,
          baseDue.minute,
        );
        instance["dueDate"] = instanceDue.toIso8601String();
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
      if (task["isArchived"] == true || task["status"] == "completed") continue;
      final dueStr = task["dueDate"] as String?;
      if (dueStr == null) continue;

      final baseDue = DateTime.parse(dueStr);
      DateTime current = baseDue;
      final repeat = task["repeat"] as Map<String, dynamic>?;

      while (current.isBefore(now) && current.isAfter(cutoff)) {
        if (hasInstanceOnDate(task, current)) {
          final instance = Map<String, dynamic>.from(task);
          instance["dueDate"] = current.toIso8601String();
          overdue.add(instance);
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
