import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'models/message.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/session_manager.dart';

class AIController extends ChangeNotifier {
  final String apiKey = ApiConstants.geminiApiKey;
  final String backendUrl = ApiConstants.backendUrl;

  List<ChatMessage> messages = [];
  bool isLoading = false;

  /// Task waiting for user confirmation
  Map<String, dynamic>? pendingTaskToCreate;

  /// IST offset (fixed for India)
  static const Duration istOffset = Duration(hours: 5, minutes: 30);

  /* ───────────────────────── HELPERS ───────────────────────── */

  void addMessage(String content, MessageRole role) {
    messages.add(ChatMessage(content: content, role: role));
    notifyListeners();
  }

  void clearChat() {
    messages.clear();
    pendingTaskToCreate = null;
    notifyListeners();
  }

  /* ───────────────────────── TIME HELPERS ───────────────────────── */

  /// Current IST time (authoritative)
  DateTime nowIST() {
    return DateTime.now().toUtc().add(istOffset);
  }

  /// Convert IST → UTC ISO for backend
  String toUtcIso(DateTime istTime) {
    return istTime.subtract(istOffset).toIso8601String();
  }

  /// Pretty display for confirmation (IST)
  String formatForDisplay(DateTime istTime) {
    return DateFormat("EEE, d MMM yyyy 'at' h:mm a").format(istTime);
  }

  bool looksLikeTask(String input) {
    final lower = input.toLowerCase();
    return lower.contains(" at ") ||
        lower.contains(" tomorrow") ||
        lower.contains(" today") ||
        lower.contains(" morning") ||
        lower.contains(" afternoon") ||
        lower.contains(" evening") ||
        lower.contains(" night") ||
        lower.contains(" am") ||
        lower.contains(" pm");
  }

  /* ───────────────────────── IST PARSER ───────────────────────── */

  /// Infer date & time STRICTLY in IST
  DateTime? inferDueDateIST(String input) {
    final lower = input.toLowerCase();
    DateTime base = nowIST();

    // 📅 Date words
    if (lower.contains("tomorrow")) {
      base = base.add(const Duration(days: 1));
    }

    // 🕒 Time of day keywords
    final isMorning = lower.contains("morning");
    final isAfternoon = lower.contains("afternoon");
    final isEvening = lower.contains("evening");
    final isNight = lower.contains("night");

    final timeRegex = RegExp(r'(\d{1,2})(?::(\d{2}))?\s*(am|pm)?');
    final match = timeRegex.firstMatch(lower);

    if (match == null) return null;

    int hour = int.parse(match.group(1)!);
    int minute = match.group(2) != null ? int.parse(match.group(2)!) : 0;
    final meridian = match.group(3);

    // Explicit AM/PM
    if (meridian != null) {
      if (meridian == "pm" && hour != 12) hour += 12;
      if (meridian == "am" && hour == 12) hour = 0;
    }
    // Implicit via keywords
    else if (isMorning) {
      if (hour == 12) hour = 5;
    } else if (isAfternoon || isEvening || isNight) {
      if (hour < 12) hour += 12;
    }

    return DateTime(base.year, base.month, base.day, hour, minute);
  }

  /* ───────────────────────── GEMINI ───────────────────────── */

  Future<void> sendMessage(String userInput) async {
    if (userInput.trim().isEmpty) return;

    if (pendingTaskToCreate != null) {
      addMessage("Please confirm the task above 👆", MessageRole.assistant);
      return;
    }

    addMessage(userInput, MessageRole.user);
    isLoading = true;
    notifyListeners();

    try {
      final taskContext = await _fetchTaskContext();

      final istNow = nowIST();
      final istNowStr = istNow.toIso8601String();

      final uri = Uri.parse(
        "https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash:generateContent?key=$apiKey",
      );

      final requestBody = {
        "contents": [
          {
            "role": "user",
            "parts": [
              {
                "text":
                    "You are a task management AI for Indian users.\n\n"
                    "CURRENT IST DATE & TIME (AUTHORITATIVE):\n"
                    "$istNowStr (UTC+05:30)\n\n"
                    "TIME RULES:\n"
                    "- morning = 5:00 AM – 11:59 AM\n"
                    "- afternoon = 12:00 PM – 4:59 PM\n"
                    "- evening = 5:00 PM – 8:59 PM\n"
                    "- night = 9:00 PM – 11:59 PM\n\n"
                    "CURRENT TASK CONTEXT:\n"
                    "$taskContext\n\n"
                    "FORMAT FOR ADDING TASK:\n"
                    "ADD_TASK:{title}|{dueDateISO}|{priority}|{notes}|{repeat}\n\n"
                    "User message: $userInput",
              },
            ],
          },
        ],
        "generationConfig": {"temperature": 0.3, "maxOutputTokens": 512},
      };

      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      // 🔴 Gemini unavailable → fallback
      if (response.statusCode != 200) {
        if (looksLikeTask(userInput)) {
          final istDue = inferDueDateIST(userInput);

          pendingTaskToCreate = {
            "title": userInput.split(" at ").first.trim(),
            "dueDateIST": istDue,
            "dueDateUTC": istDue != null ? toUtcIso(istDue) : null,
            "priority": "medium",
            "notes": "",
            "repeat": null,
          };

          addMessage(
            "I understood this as a task:\n\n"
            "📌 ${pendingTaskToCreate!["title"]}\n"
            "${istDue != null ? "📅 ${formatForDisplay(istDue)}\n" : ""}"
            "\nTap below to confirm →",
            MessageRole.assistant,
          );
        } else {
          addMessage(
            "Sorry, I'm having trouble right now 😕",
            MessageRole.assistant,
          );
        }
        return;
      }

      final data = jsonDecode(response.body);
      final aiReply =
          data["candidates"][0]["content"]["parts"][0]["text"] as String;

      if (aiReply.startsWith("ADD_TASK:")) {
        _handleAddTask(aiReply);
      } else {
        addMessage(aiReply.trim(), MessageRole.assistant);
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /* ───────────────────────── TASK PARSING ───────────────────────── */

  void _handleAddTask(String aiReply) {
    final parts = aiReply.substring(9).split("|");
    if (parts.length < 5) {
      addMessage(aiReply, MessageRole.assistant);
      return;
    }

    final istDue = DateTime.tryParse(parts[1].trim());

    pendingTaskToCreate = {
      "title": parts[0].trim(),
      "dueDateIST": istDue,
      "dueDateUTC": istDue != null ? toUtcIso(istDue) : null,
      "priority": parts[2].trim().isEmpty ? "medium" : parts[2].trim(),
      "notes": parts[3].trim(),
      "repeat": parts[4].trim().isEmpty ? null : parts[4].trim(),
    };

    addMessage(
      "I can add this task for you:\n\n"
      "📌 ${pendingTaskToCreate!["title"]}\n"
      "${istDue != null ? "📅 ${formatForDisplay(istDue)}\n" : ""}"
      "\nTap below to confirm →",
      MessageRole.assistant,
    );
  }

  /* ───────────────────────── CONFIRM ───────────────────────── */

  Future<void> confirmTaskCreation(BuildContext context) async {
    if (pendingTaskToCreate == null) return;

    final success = await _createTaskOnBackend(pendingTaskToCreate!);

    addMessage(
      success
          ? "✅ Task created successfully!"
          : "❌ Failed to create task. Try again?",
      MessageRole.assistant,
    );

    pendingTaskToCreate = null;
    notifyListeners();
  }

  /* ───────────────────────── BACKEND ───────────────────────── */

  Future<bool> _createTaskOnBackend(Map<String, dynamic> task) async {
    final token = await SessionManager.getToken();
    final userId = await SessionManager.getUserId();
    if (token == null || userId == null) return false;

    final payload = {
      "userId": userId,
      "taskListId": task["taskListId"],
      "title": task["title"],
      "notes": task["notes"],
      "priority": task["priority"],
      "dueDate": task["dueDateUTC"],
      "status": "pending",
      "isArchived": false,
      "reminder": {"enabled": false},
      "repeat": null,
    };

    final response = await http.post(
      Uri.parse("$backendUrl/api/task"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(payload),
    );

    return response.statusCode == 200 || response.statusCode == 201;
  }

  /* ───────────────────────── CONTEXT ───────────────────────── */

  Future<String> _fetchTaskContext() async {
    final token = await SessionManager.getToken();
    final userId = await SessionManager.getUserId();
    if (token == null || userId == null) return "No tasks.";

    final res = await http.get(
      Uri.parse("$backendUrl/api/task/$userId"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode != 200) return "No tasks.";

    final List tasks = jsonDecode(res.body)["data"] ?? [];
    if (tasks.isEmpty) return "No tasks.";

    return tasks.map((t) => "- ${t["title"]} (${t["status"]})").join("\n");
  }
}
