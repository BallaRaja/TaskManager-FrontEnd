// lib/features/tasks/presentation/tasks_controller.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/utils/session_manager.dart';

enum TaskListSortMode { custom, az, za }

class TasksController extends ChangeNotifier {
  String? _avatarUrl;
  bool _isLoadingAvatar = true;
  final List<Map<String, dynamic>> _tasks = [];
  final List<Map<String, dynamic>> _taskLists = [];
  bool _isLoading = true;
  int _selectedListIndex = 0;

  // ── Ordering state ──
  TaskListSortMode _listSortMode = TaskListSortMode.custom;
  List<String> _customListOrder = []; // IDs of non-default lists
  final Map<String, List<String>> _taskOrders = {}; // listId → ordered taskIds

  String? _userId;
  String? _token;

  String? get avatarUrl => _avatarUrl;
  bool get isLoadingAvatar => _isLoadingAvatar;
  List<Map<String, dynamic>> get tasks => _tasks;
  List<Map<String, dynamic>> get taskLists => _taskLists;
  bool get isLoading => _isLoading;
  int get selectedListIndex => _selectedListIndex;
  TaskListSortMode get listSortMode => _listSortMode;

  Future<void> init() async {
    _token = await SessionManager.getToken();
    _userId = await SessionManager.getUserId();

    if (_token == null || _userId == null) {
      _isLoading = false;
      _isLoadingAvatar = false;
      notifyListeners();
      return;
    }

    // Load persisted sort prefs before fetching (so _sortTaskLists uses them)
    await Future.wait([_loadListSortMode(), _loadCustomListOrder()]);

    await Future.wait([
      _fetchProfileAvatar(),
      _fetchTaskLists(),
      _fetchTasks(),
    ]);

    await _loadAllTaskOrders();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _fetchProfileAvatar() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.backendUrl}/api/profile/$_userId'),
        headers: {'Authorization': 'Bearer $_token'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        final dynamic avatarUrl = json['data']?['profile']?['avatarUrl'];

        print('🧪 [TasksController] Raw avatarUrl from backend: $avatarUrl');

        // Handle different URL formats
        if (avatarUrl == null ||
            avatarUrl.toString().isEmpty ||
            avatarUrl.toString().contains('placeholder')) {
          _avatarUrl = null;
          print(
            '🧪 [TasksController] No valid avatar (null/empty/placeholder)',
          );
        } else if (avatarUrl.toString().startsWith('/')) {
          _avatarUrl = '${ApiConstants.backendUrl}$avatarUrl';
          print('🧪 [TasksController] Converted relative URL to: $_avatarUrl');
        } else if (avatarUrl.toString().startsWith('http')) {
          _avatarUrl = avatarUrl.toString();
          print('🧪 [TasksController] Using absolute URL: $_avatarUrl');
        } else {
          _avatarUrl = null;
          print('🧪 [TasksController] Invalid URL format: $avatarUrl');
        }
      }
    } catch (e) {
      print('🧪 [TasksController] Error fetching avatar: $e');
      _avatarUrl = null;
    } finally {
      _isLoadingAvatar = false;
      notifyListeners();
    }
  }

  Future<void> refreshAvatar() async {
    _isLoadingAvatar = true;
    notifyListeners();
    await _fetchProfileAvatar();
  }

  Future<void> createTaskList(String title) async {
    final String trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) return;

    _token ??= await SessionManager.getToken();
    if (_token == null) return;

    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.backendUrl}/api/taskList'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({'title': trimmedTitle}),
      );

      if (response.statusCode == 201) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        final Map<String, dynamic>? created =
            json['data'] as Map<String, dynamic>?;

        if (created != null) {
          _taskLists.add(created);
          _sortTaskLists();

          _selectedListIndex = _taskLists.indexWhere(
            (list) => list['_id'] == created['_id'],
          );
          if (_selectedListIndex < 0) {
            _selectedListIndex = 0;
          }

          notifyListeners();
        } else {
          await _fetchTaskLists();
        }
      }
    } catch (_) {}
  }

  Future<void> deleteTaskList(String listId) async {
    _token ??= await SessionManager.getToken();
    if (_token == null) return;

    try {
      final response = await http.delete(
        Uri.parse('${ApiConstants.backendUrl}/api/taskList/$listId'),
        headers: {'Authorization': 'Bearer $_token'},
      );

      if (response.statusCode == 200) {
        _taskLists.removeWhere((l) => l['_id']?.toString() == listId);
        _tasks.removeWhere((t) => t['taskListId']?.toString() == listId);
        _selectedListIndex = 0;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> renameTaskList(String listId, String newTitle) async {
    _token ??= await SessionManager.getToken();
    if (_token == null) return;

    final trimmed = newTitle.trim();
    if (trimmed.isEmpty) return;

    try {
      final response = await http.put(
        Uri.parse('${ApiConstants.backendUrl}/api/taskList/$listId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({'title': trimmed}),
      );

      if (response.statusCode == 200) {
        final updated =
            jsonDecode(response.body)['data'] as Map<String, dynamic>?;
        if (updated != null) {
          final idx = _taskLists.indexWhere(
            (l) => l['_id']?.toString() == listId,
          );
          if (idx != -1) {
            _taskLists[idx] = updated;
            notifyListeners();
          }
        }
      }
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> createTask(Map<String, dynamic> taskData) async {
    _token ??= await SessionManager.getToken();
    if (_token == null) return null;

    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.backendUrl}/api/task'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode(taskData),
      );

      if (response.statusCode == 201) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        final created = json['data'] as Map<String, dynamic>?;
        if (created != null) {
          upsertTaskLocal(created);
          return created;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> updateTask(
    String taskId,
    Map<String, dynamic> data,
  ) async {
    _token ??= await SessionManager.getToken();
    if (_token == null) return null;

    try {
      final response = await http.put(
        Uri.parse('${ApiConstants.backendUrl}/api/task/$taskId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        final updated =
            jsonDecode(response.body)['data'] as Map<String, dynamic>?;
        if (updated != null) upsertTaskLocal(updated);
        return updated;
      }
    } catch (_) {}
    return null;
  }

  Future<void> deleteTask(String taskId) async {
    _token ??= await SessionManager.getToken();
    if (_token == null) return;

    try {
      final response = await http.delete(
        Uri.parse('${ApiConstants.backendUrl}/api/task/$taskId'),
        headers: {'Authorization': 'Bearer $_token'},
      );

      if (response.statusCode == 200) {
        _tasks.removeWhere((t) => t['_id']?.toString() == taskId);
        notifyListeners();
      }
    } catch (_) {}
  }

  void upsertTaskLocal(Map<String, dynamic> updatedTask) {
    final String? id = updatedTask['_id']?.toString();
    if (id == null) return;

    final int index = _tasks.indexWhere((t) => t['_id']?.toString() == id);
    if (index == -1) {
      _tasks.insert(0, updatedTask);
    } else {
      _tasks[index] = updatedTask;
    }
    notifyListeners();
  }

  void removeTaskLocal(String taskId) {
    _tasks.removeWhere((t) => t['_id']?.toString() == taskId);
    notifyListeners();
  }

  void _sortTaskLists() {
    _taskLists.sort((a, b) {
      if (a['isDefault'] == true) return -1;
      if (b['isDefault'] == true) return 1;

      switch (_listSortMode) {
        case TaskListSortMode.az:
          return (a['title']?.toString() ?? '').toLowerCase().compareTo(
            (b['title']?.toString() ?? '').toLowerCase(),
          );
        case TaskListSortMode.za:
          return (b['title']?.toString() ?? '').toLowerCase().compareTo(
            (a['title']?.toString() ?? '').toLowerCase(),
          );
        case TaskListSortMode.custom:
          final aId = a['_id']?.toString() ?? '';
          final bId = b['_id']?.toString() ?? '';
          final aIdx = _customListOrder.indexOf(aId);
          final bIdx = _customListOrder.indexOf(bId);
          if (aIdx == -1 && bIdx == -1) {
            // Both not in custom order yet → sort by createdAt desc
            final dateA =
                DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final dateB =
                DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return dateB.compareTo(dateA);
          }
          if (aIdx == -1) return 1;
          if (bIdx == -1) return -1;
          return aIdx.compareTo(bIdx);
      }
    });
  }

  // ── Sort-mode & order persistence ──────────────────────────

  Future<void> _loadListSortMode() async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString('list_sort_mode') ?? 'custom';
    _listSortMode = TaskListSortMode.values.firstWhere(
      (e) => e.name == modeStr,
      orElse: () => TaskListSortMode.custom,
    );
  }

  Future<void> _saveListSortMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('list_sort_mode', _listSortMode.name);
  }

  Future<void> _loadCustomListOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('custom_list_order');
    if (raw != null) {
      _customListOrder = List<String>.from(jsonDecode(raw));
    }
  }

  Future<void> _saveCustomListOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_list_order', jsonEncode(_customListOrder));
  }

  Future<void> _loadAllTaskOrders() async {
    final prefs = await SharedPreferences.getInstance();
    for (final list in _taskLists) {
      final listId = list['_id']?.toString();
      if (listId == null) continue;
      final raw = prefs.getString('task_order_$listId');
      if (raw != null) {
        _taskOrders[listId] = List<String>.from(jsonDecode(raw));
      }
    }
  }

  // ── Public ordering API ─────────────────────────────────────

  /// Change sort mode for the lists panel.
  Future<void> setListSortMode(TaskListSortMode mode) async {
    _listSortMode = mode;
    await _saveListSortMode();
    _sortTaskLists();
    notifyListeners();
  }

  /// Drag-reorder non-default lists (indices into non-default slice).
  Future<void> reorderLists(int oldIndex, int newIndex) async {
    final nonDefault = _taskLists.where((l) => l['isDefault'] != true).toList();
    if (oldIndex < 0 ||
        oldIndex >= nonDefault.length ||
        newIndex < 0 ||
        newIndex >= nonDefault.length) {
      return;
    }

    final ids = nonDefault.map((l) => l['_id'].toString()).toList();
    final moved = ids.removeAt(oldIndex);
    ids.insert(newIndex, moved);
    _customListOrder = ids;

    await _saveCustomListOrder();
    _sortTaskLists();
    notifyListeners();
  }

  /// Returns [pending] tasks sorted by the stored custom order for [listId].
  List<Map<String, dynamic>> getOrderedPendingTasks(
    String listId,
    List<Map<String, dynamic>> pending,
  ) {
    final order = _taskOrders[listId];
    if (order == null || order.isEmpty) return pending;
    final result = <Map<String, dynamic>>[];
    final remaining = List<Map<String, dynamic>>.from(pending);
    for (final id in order) {
      final idx = remaining.indexWhere((t) => t['_id']?.toString() == id);
      if (idx != -1) result.add(remaining.removeAt(idx));
    }
    result.addAll(remaining); // new tasks not yet in the order go last
    return result;
  }

  /// Persist a new task order after a drag.
  Future<void> reorderTasks(
    String listId,
    int oldIndex,
    int newIndex,
    List<Map<String, dynamic>> displayedOrdered,
  ) async {
    final ids = displayedOrdered.map((t) => t['_id'].toString()).toList();
    final moved = ids.removeAt(oldIndex);
    ids.insert(newIndex, moved);
    _taskOrders[listId] = ids;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('task_order_$listId', jsonEncode(ids));
    notifyListeners();
  }

  Future<void> _fetchTaskLists() async {
    _userId ??= await SessionManager.getUserId();
    if (_userId == null) return;

    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.backendUrl}/api/taskList/$_userId'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        final List<dynamic> raw = json['data'] ?? [];

        _taskLists
          ..clear()
          ..addAll(raw.cast<Map<String, dynamic>>());

        _sortTaskLists();

        if (_taskLists.isEmpty) {
          _selectedListIndex = 0;
        } else if (_selectedListIndex >= _taskLists.length) {
          _selectedListIndex = _taskLists.length - 1;
        }

        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _fetchTasks() async {
    _token ??= await SessionManager.getToken();
    if (_token == null) return;

    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.backendUrl}/api/task'),
        headers: {'Authorization': 'Bearer $_token'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        final List<dynamic> raw = json['data'] ?? [];

        _tasks
          ..clear()
          ..addAll(raw.cast<Map<String, dynamic>>());

        notifyListeners();
      }
    } catch (_) {}
  }

  void selectList(int index) {
    if (index < 0 || index >= _taskLists.length) return;
    if (_selectedListIndex == index) return;

    _selectedListIndex = index;
    notifyListeners();
  }

  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();

    _token = await SessionManager.getToken();
    _userId = await SessionManager.getUserId();

    if (_token == null || _userId == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    await Future.wait([_fetchTaskLists(), _fetchTasks()]);
    await _loadAllTaskOrders();

    _isLoading = false;
    notifyListeners();
  }
}
