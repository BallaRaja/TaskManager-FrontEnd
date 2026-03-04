// lib/features/focus/logic/focus_controller.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/focus_repository.dart';
import '../models/focus_session.dart';

enum FocusPhase { idle, work, breakTime, completed }

class FocusController extends ChangeNotifier {
  static const int defaultWorkMinutes = 25;
  static const int defaultBreakMinutes = 5;
  static const int dailyGoalMinutes = 120;

  final FocusRepository _repo = FocusRepository();

  // ── Configurable durations ─────────────────────────────────
  int _workMinutes = defaultWorkMinutes;
  int _breakMinutes = defaultBreakMinutes;
  int get workMinutes => _workMinutes;
  int get breakMinutes => _breakMinutes;

  // ── Timer state ────────────────────────────────────────────
  Timer? _timer;
  int _secondsLeft = 0;
  bool _isRunning = false;
  FocusPhase _phase = FocusPhase.idle;

  // ── Task ──────────────────────────────────────────────────
  String? _selectedTaskId;
  String? _selectedTaskTitle;
  DateTime? _selectedTaskDue;
  bool _isDeadlineMode = false;

  // ── Stats ─────────────────────────────────────────────────
  int _sessionsToday = 0;
  int _totalMinutesToday = 0;
  int _streak = 0;

  // ── Animation / sound trigger flags ───────────────────────
  bool _triggerCompletionEffect = false;
  bool _triggerBreakEffect = false;
  bool _triggerResumeEffect = false;

  // ── Getters ────────────────────────────────────────────────
  int get secondsLeft => _secondsLeft;
  bool get isRunning => _isRunning;
  FocusPhase get phase => _phase;
  int get sessionsToday => _sessionsToday;
  int get totalMinutesToday => _totalMinutesToday;
  int get streak => _streak;
  String? get selectedTaskId => _selectedTaskId;
  String? get selectedTaskTitle => _selectedTaskTitle;
  DateTime? get selectedTaskDue => _selectedTaskDue;
  bool get isDeadlineMode => _isDeadlineMode;
  bool get triggerCompletionEffect => _triggerCompletionEffect;
  bool get triggerBreakEffect => _triggerBreakEffect;
  bool get triggerResumeEffect => _triggerResumeEffect;
  bool get hasTaskSelected => _selectedTaskId != null;

  double get goalProgress =>
      (_totalMinutesToday / dailyGoalMinutes).clamp(0.0, 1.0);

  // Total seconds for current phase arc progress
  int get totalSecondsForPhase {
    if (_phase == FocusPhase.breakTime) return _breakMinutes * 60;
    if (_isDeadlineMode && _selectedTaskDue != null) {
      final secs = _selectedTaskDue!.difference(DateTime.now()).inSeconds;
      return secs > 0 ? secs : _workMinutes * 60;
    }
    return _workMinutes * 60;
  }

  String get formattedTime {
    final s = _secondsLeft.abs();
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  // ── Init ──────────────────────────────────────────────────
  Future<void> init() async {
    _phase = FocusPhase.idle;
    _secondsLeft = _workMinutes * 60; // ✅ show proper time on load, not 00:00
    await _loadTodayStats();
  }

  Future<void> _loadTodayStats() async {
    try {
      final data = await _repo.getDailySummary();
      // ✅ Only update from backend if values are >= local counts
      // so a failed reload after _saveSession doesn't wipe local increments
      final backendSessions = data['totalSessions'] as int? ?? 0;
      final backendMinutes = data['totalMinutes'] as int? ?? 0;
      final backendStreak = data['streak'] as int? ?? 0;

      _sessionsToday = backendSessions > _sessionsToday
          ? backendSessions
          : _sessionsToday;
      _totalMinutesToday = backendMinutes > _totalMinutesToday
          ? backendMinutes
          : _totalMinutesToday;
      _streak = backendStreak;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load daily stats: $e');
      // ✅ Still notify so UI shows whatever local counts we have
      notifyListeners();
    }
  }

  // ── Duration setters (only when not running) ───────────────
  void setWorkMinutes(int minutes) {
    if (_isRunning) return;
    _workMinutes = minutes;
    _isDeadlineMode = false;
    if (_phase == FocusPhase.work || _phase == FocusPhase.idle) {
      _secondsLeft = _workMinutes * 60;
    }
    notifyListeners();
  }

  void setBreakMinutes(int minutes) {
    if (_isRunning) return;
    _breakMinutes = minutes;
    if (_phase == FocusPhase.breakTime) {
      _secondsLeft = _breakMinutes * 60;
    }
    notifyListeners();
  }

  // ── Task selection ─────────────────────────────────────────
  void selectTask(String taskId, String taskTitle, {String? dueDateStr}) {
    // Stop any running timer
    _timer?.cancel();
    _isRunning = false;
    _phase = FocusPhase.idle;
    _triggerCompletionEffect = false;
    _triggerBreakEffect = false;
    _triggerResumeEffect = false;

    _selectedTaskId = taskId;
    _selectedTaskTitle = taskTitle;
    _selectedTaskDue = null;
    _isDeadlineMode = false;

    // Try parse deadline
    if (dueDateStr != null && dueDateStr.isNotEmpty) {
      final due = DateTime.tryParse(dueDateStr)?.toLocal();
      if (due != null && due.isAfter(DateTime.now())) {
        _selectedTaskDue = due;
        _isDeadlineMode = true;
        _secondsLeft = due.difference(DateTime.now()).inSeconds;
      }
    }

    if (!_isDeadlineMode) {
      _secondsLeft = _workMinutes * 60;
    }

    notifyListeners();

    // ✅ Auto-start timer immediately after task is selected
    Future.microtask(() => start());
  }

  void clearTask() {
    _timer?.cancel();
    _isRunning = false;
    _phase = FocusPhase.idle;
    _selectedTaskId = null;
    _selectedTaskTitle = null;
    _selectedTaskDue = null;
    _isDeadlineMode = false;
    _secondsLeft = _workMinutes * 60;
    _triggerCompletionEffect = false;
    _triggerBreakEffect = false;
    _triggerResumeEffect = false;
    notifyListeners();
  }

  // ── Timer controls ─────────────────────────────────────────
  void start() {
    if (_isRunning) return;
    if (!hasTaskSelected) return;
    if (_phase == FocusPhase.completed) return;

    if (_phase == FocusPhase.idle) {
      _phase = FocusPhase.work;
    }

    _isRunning = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    notifyListeners();
  }

  void pause() {
    _timer?.cancel();
    _isRunning = false;
    notifyListeners();
  }

  void reset() {
    _timer?.cancel();
    _isRunning = false;
    _phase = FocusPhase.idle;
    _triggerCompletionEffect = false;
    _triggerBreakEffect = false;
    _triggerResumeEffect = false;

    if (_isDeadlineMode && _selectedTaskDue != null) {
      final remaining = _selectedTaskDue!.difference(DateTime.now()).inSeconds;
      _secondsLeft = remaining > 0 ? remaining : _workMinutes * 60;
    } else {
      _secondsLeft = _workMinutes * 60;
    }
    notifyListeners();
  }

  void consumeEffectFlags() {
    _triggerCompletionEffect = false;
    _triggerBreakEffect = false;
    _triggerResumeEffect = false;
    // don't call notifyListeners here — called from build
  }

  void _tick() {
    if (_secondsLeft > 0) {
      _secondsLeft--;
      notifyListeners();
    } else {
      _onPhaseComplete();
    }
  }

  Future<void> _onPhaseComplete() async {
    _timer?.cancel();
    _isRunning = false;

    if (_phase == FocusPhase.work) {
      // ── Work done ──
      _triggerCompletionEffect = true;
      notifyListeners();

      await _saveSession();

      // Short delay so UI can show completion animation
      await Future.delayed(const Duration(milliseconds: 1200));

      // Switch to break
      _phase = FocusPhase.breakTime;
      _secondsLeft = _breakMinutes * 60;
      _triggerCompletionEffect = false;
      _triggerBreakEffect = true;
      notifyListeners();

      // Auto-start break
      _isRunning = true;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
      notifyListeners();
    } else if (_phase == FocusPhase.breakTime) {
      // ── Break done ──
      _triggerBreakEffect = false;
      _triggerResumeEffect = true;
      notifyListeners();

      await Future.delayed(const Duration(milliseconds: 1000));

      _phase = FocusPhase.idle;
      _triggerResumeEffect = false;

      if (_isDeadlineMode && _selectedTaskDue != null) {
        final remaining = _selectedTaskDue!
            .difference(DateTime.now())
            .inSeconds;
        _secondsLeft = remaining > 0 ? remaining : _workMinutes * 60;
      } else {
        _secondsLeft = _workMinutes * 60;
      }

      notifyListeners();

      // ✅ Auto-start next work session after break ends
      Future.microtask(() => start());
    }
  }

  Future<void> _saveSession() async {
    try {
      final now = DateTime.now();
      final date =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final session = FocusSession(
        id: now.millisecondsSinceEpoch.toString(),
        taskId: _selectedTaskId ?? 'no_task',
        duration: _workMinutes,
        date: date,
      );

      await _repo.saveSession(session);

      // ✅ Increment local counts immediately so UI updates even if reload fails
      _sessionsToday++;
      _totalMinutesToday += _workMinutes;
      notifyListeners();

      // Try to sync streak from backend (non-critical)
      await _loadTodayStats();
    } catch (e) {
      debugPrint('Failed to save focus session: $e');
      // ✅ Still increment locally so stats card shows progress
      _sessionsToday++;
      _totalMinutesToday += _workMinutes;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
