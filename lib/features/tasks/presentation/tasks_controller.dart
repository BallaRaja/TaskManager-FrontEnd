// lib/features/tasks/presentation/tasks_controller.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/api_constants.dart';
import '../../../core/utils/session_manager.dart';

class TasksController extends ChangeNotifier {
  String? _avatarUrl;
  bool _isLoadingAvatar = true;
  final List<Map<String, dynamic>> _tasks = [];
  final List<Map<String, dynamic>> _taskLists = [];
  bool _isLoading = true;
  int _selectedListIndex = 0;

  String? _userId;
  String? _token;

  String? get avatarUrl => _avatarUrl;
  bool get isLoadingAvatar => _isLoadingAvatar;
  List<Map<String, dynamic>> get tasks => _tasks;
  List<Map<String, dynamic>> get taskLists => _taskLists;
  bool get isLoading => _isLoading;
  int get selectedListIndex => _selectedListIndex;

  Future<void> init() async {
    _token = await SessionManager.getToken();
    _userId = await SessionManager.getUserId();

    if (_token == null || _userId == null) {
      _isLoading = false;
      _isLoadingAvatar = false;
      notifyListeners();
      return;
    }

    await Future.wait([
      _fetchProfileAvatar(),
      _fetchTaskLists(),
      _fetchTasks(),
    ]);

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

  Future<void> createTask(Map<String, dynamic> taskData) async {
    _token ??= await SessionManager.getToken();
    if (_token == null) return;

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
        await _fetchTasks();
      }
    } catch (_) {}
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

      final DateTime dateA =
          DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final DateTime dateB =
          DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);

      return dateB.compareTo(dateA);
    });
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

    _isLoading = false;
    notifyListeners();
  }
}
