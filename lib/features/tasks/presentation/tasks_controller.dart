// lib/features/tasks/presentation/tasks_controller.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../../core/constants/api_constants.dart';
import '../../../core/utils/session_manager.dart';

class TasksController extends ChangeNotifier {
  // State
  String? _avatarUrl;
  bool _isLoadingAvatar = true;
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _taskLists = [];
  bool _isLoading = true;
  int _selectedListIndex = 0;

  String? _userId;
  String? _token;

  // Getters
  String? get avatarUrl => _avatarUrl;
  bool get isLoadingAvatar => _isLoadingAvatar;
  List<Map<String, dynamic>> get tasks => _tasks;
  List<Map<String, dynamic>> get taskLists => _taskLists;
  bool get isLoading => _isLoading;
  int get selectedListIndex => _selectedListIndex;

  Future<void> init() async {
    _token = await SessionManager.getToken();
    _userId = await SessionManager.getUserId();

    print(
      "🔑 [TasksController] Token: ${_token != null ? 'Found' : 'Missing'}",
    );
    print("🆔 [TasksController] UserId: $_userId");

    if (_token == null || _userId == null) {
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
        Uri.parse("${ApiConstants.backendUrl}/api/profile/$_userId"),
        headers: {"Authorization": "Bearer $_token"},
      );
      print("👤 Profile status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        _avatarUrl = json["data"]?["profile"]?["avatarUrl"];
      }
    } catch (e) {
      print("❌ Avatar error: $e");
    } finally {
      _isLoadingAvatar = false;
      notifyListeners();
    }
  }

  // In TasksController class

  Future<void> createTask(Map<String, dynamic> taskData) async {
    try {
      final token = await SessionManager.getToken();
      if (token == null) return;

      final response = await http.post(
        Uri.parse("${ApiConstants.backendUrl}/api/task"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(taskData),
      );

      if (response.statusCode == 201) {
        await _fetchTasks(); // Refresh tasks
        notifyListeners();
      } else {
        print("Failed to create task: ${response.body}");
      }
    } catch (e) {
      print("Error creating task: $e");
    }
  }

  Future<void> _fetchTaskLists() async {
    try {
      final response = await http.get(
        Uri.parse("${ApiConstants.backendUrl}/api/taskList/$_userId"),
      );
      print("📋 TaskLists status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final List raw = jsonDecode(response.body)["data"] ?? [];
        final List<Map<String, dynamic>> lists = List.from(raw);

        lists.sort((a, b) {
          if (a["isDefault"] == true) return -1;
          if (b["isDefault"] == true) return 1;
          return DateTime.parse(
            b["createdAt"],
          ).compareTo(DateTime.parse(a["createdAt"]));
        });

        _taskLists = lists;
        _selectedListIndex = 0;
        notifyListeners();
      }
    } catch (e) {
      print("❌ TaskLists error: $e");
    }
  }

  Future<void> _fetchTasks() async {
    try {
      final response = await http.get(
        Uri.parse("${ApiConstants.backendUrl}/api/task"),
        headers: {"Authorization": "Bearer $_token"},
      );
      print("✅ Tasks status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final List raw = jsonDecode(response.body)["data"] ?? [];
        _tasks = List<Map<String, dynamic>>.from(raw);
        notifyListeners();
      }
    } catch (e) {
      print("❌ Tasks error: $e");
    }
  }

  void selectList(int index) {
    if (index != _selectedListIndex && index < _taskLists.length) {
      _selectedListIndex = index;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();
    await init();
  }
}
