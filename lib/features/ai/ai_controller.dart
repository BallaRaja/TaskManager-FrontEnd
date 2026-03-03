import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/message.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/session_manager.dart';

class AIController extends ChangeNotifier {
  final String apiKey = ApiConstants.geminiApiKey;
  final String backendUrl = ApiConstants.backendUrl;

  List<ChatMessage> messages = [];
  bool isLoading = false;

  /// Suggestion chips shown in the empty state
  List<String> suggestions = [];
  bool isLoadingSuggestions = false;

  /// Task waiting for user confirmation
  Map<String, dynamic>? pendingTaskToCreate;

  /// System timezone name for prompt context
  static final String _tzLabel = DateTime.now().timeZoneName;

  static const String _chatKey = 'ai_chat_messages';
  static const String _suggestionsKey = 'ai_suggestions';

  /* ───────────────────────── INIT ───────────────────────── */

  /// Call once after creating the controller to restore persisted state.
  Future<void> init() async {
    await _loadMessages();
    await _loadSuggestions();
    // Refresh suggestions in background (only if we have none yet)
    if (suggestions.isEmpty) {
      fetchSuggestions();
    }
  }

  /* ───────────────────────── PERSISTENCE ───────────────────────── */

  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      messages.map((m) => {
        'content': m.content,
        'role': m.role.name,
        'timestamp': m.timestamp.toIso8601String(),
      }).toList(),
    );
    await prefs.setString(_chatKey, encoded);
  }

  Future<void> _loadMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_chatKey);
      if (raw == null || raw.isEmpty) return;
      final List decoded = jsonDecode(raw);
      messages = decoded.map((e) {
        return ChatMessage(
          content: e['content'] as String,
          role: MessageRole.values.firstWhere(
            (r) => r.name == e['role'],
            orElse: () => MessageRole.user,
          ),
          timestamp: DateTime.tryParse(e['timestamp'] ?? '') ?? DateTime.now(),
        );
      }).toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _saveSuggestions(List<String> chips) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_suggestionsKey, jsonEncode(chips));
  }

  Future<void> _loadSuggestions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_suggestionsKey);
      if (raw == null || raw.isEmpty) return;
      final List decoded = jsonDecode(raw);
      suggestions = List<String>.from(decoded);
      notifyListeners();
    } catch (_) {}
  }

  /* ───────────────────────── DYNAMIC SUGGESTIONS ───────────────────────── */

  Future<void> fetchSuggestions() async {
    if (isLoadingSuggestions) return;
    isLoadingSuggestions = true;
    notifyListeners();

    try {
      final taskContext = await _fetchTaskContext();
      final now = nowLocal();

      final uri = Uri.parse(
        "https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash:generateContent?key=$apiKey",
      );

      final body = {
        "contents": [
          {
            "role": "user",
            "parts": [
              {
                "text":
                    "You are a task management AI assistant. "
                    "Based on the user's current tasks and the time, generate exactly 4 short, "
                    "helpful suggestion chip labels (max 6 words each) that the user might want to ask. "
                    "Return ONLY a JSON array of 4 strings, no explanation, no markdown.\n\n"
                    "Current time ($_tzLabel): ${DateFormat('EEE d MMM, h:mm a').format(now)}\n"
                    "Current tasks:\n$taskContext",
              },
            ],
          },
        ],
        "generationConfig": {"temperature": 0.7, "maxOutputTokens": 150},
      };

      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text =
            data["candidates"][0]["content"]["parts"][0]["text"] as String;

        // Extract the JSON array robustly
        final arrayMatch = RegExp(r'\[.*?\]', dotAll: true).firstMatch(text);
        if (arrayMatch != null) {
          final chips = List<String>.from(jsonDecode(arrayMatch.group(0)!));
          if (chips.length >= 2) {
            suggestions = chips.take(4).toList();
            await _saveSuggestions(suggestions);
            notifyListeners();
            return;
          }
        }
      }
    } catch (_) {}

    // Fallback chips if Gemini fails
    if (suggestions.isEmpty) {
      suggestions = [
        "What's my schedule today?",
        "Show overdue tasks",
        "Add a task for tomorrow",
        "Give me a productivity tip",
      ];
      notifyListeners();
    }

    isLoadingSuggestions = false;
    notifyListeners();
  }

  /* ───────────────────────── HELPERS ───────────────────────── */

  void addMessage(String content, MessageRole role) {
    messages.add(ChatMessage(content: content, role: role));
    _saveMessages();
    notifyListeners();
  }

  void clearChat() {
    messages.clear();
    pendingTaskToCreate = null;
    _saveMessages();
    // Refresh suggestions after clearing
    fetchSuggestions();
    notifyListeners();
  }

  /* ───────────────────────── TIME HELPERS ───────────────────────── */

  /// Current local time (uses system timezone)
  DateTime nowLocal() {
    return DateTime.now();
  }

  // Keep old name as alias so callers still work
  DateTime nowIST() => nowLocal();

  /// Convert local time → UTC ISO for backend
  String toUtcIso(DateTime localTime) {
    return localTime.toUtc().toIso8601String();
  }

  /// Pretty display for confirmation (local time)
  String formatForDisplay(DateTime localTime) {
    return DateFormat("EEE, d MMM yyyy 'at' h:mm a").format(localTime);
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

  /* ───────────────────────── TITLE EXTRACTOR ───────────────────────── */

  /// Extracts the actual task name from freeform user input.
  String _extractTaskTitle(String input) {
    var title = input
        .replaceAll(
          RegExp(
            r'\b(add a task to|remind me to|create a task to|set a reminder to|add a task|create a task|add|task:?)\b',
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(
          RegExp(r'\bat\s+\d{1,2}(:\d{2})?\s*(am|pm)?\b', caseSensitive: false),
          ' ',
        )
        .replaceAll(
          RegExp(
            r'\b(today|tomorrow|tonight|morning|afternoon|evening|night)\b',
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
    if (title.isNotEmpty) {
      title = title[0].toUpperCase() + title.substring(1);
    }
    return title.isEmpty ? input.trim() : title;
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

      final now = nowLocal();
      final nowStr = DateFormat("EEE, d MMM yyyy 'at' h:mm a").format(now);
      final tomorrowStr = DateFormat("EEE, d MMM yyyy").format(
        now.add(const Duration(days: 1)),
      );

      final uri = Uri.parse(
        "https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash:generateContent?key=$apiKey",
      );

      // Build conversation history for multi-turn context
      // The first turn is always the system context as a user message,
      // then alternate user/assistant turns from history.
      final List<Map<String, dynamic>> contents = [
        {
          "role": "user",
          "parts": [
            {
              "text":
                  "You are a helpful task management AI assistant.\n\n"
                  "CURRENT DATE & TIME ($_tzLabel): $nowStr\n"
                  "TOMORROW IS: $tomorrowStr\n\n"
                  "TIME RULES:\n"
                  "- morning = 5:00 AM – 11:59 AM\n"
                  "- afternoon = 12:00 PM – 4:59 PM\n"
                  "- evening = 5:00 PM – 8:59 PM\n"
                  "- night = 9:00 PM – 11:59 PM\n\n"
                  "USER'S TASKS (always answer questions using this data):\n"
                  "$taskContext\n\n"
                  "STRICT RULES — READ CAREFULLY:\n"
                  "1. When asked about tasks on a specific day, filter and list ONLY those tasks.\n"
                  "2. Be concise and friendly.\n"
                  "3. ⚠️ TASK CREATION — MANDATORY FORMAT:\n"
                  "   If the user wants to ADD or CREATE a task, you MUST respond with EXACTLY this "
                  "format and NOTHING else — no explanation, no extra text:\n"
                  "   ADD_TASK:{title}|{dueDateISO}|{priority}|{notes}|{repeat}\n\n"
                  "   Priority must be: low, medium, or high.\n"
                  "   dueDateISO must be in the user's local time in ISO 8601 format.\n"
                  "   Leave notes/repeat empty if not mentioned.\n"
                  "4. For all other queries (listing, counting, advice), reply in plain friendly text.",
            },
          ],
        },
        // ── synthetic model ack ──
        {
          "role": "model",
          "parts": [
            {
              "text":
                  "Understood! I will only use the ADD_TASK: format for task creation, never plain text.",
            },
          ],
        },
      ];

      // Append previous real conversation turns.
      // ⚠️ Skip internal UI-generated messages (the "I can add this task…" /
      //    "Tap below to confirm" ones) because they confuse Gemini into
      //    mimicking that format instead of using ADD_TASK:.
      final history = messages.length > 1
          ? messages.sublist(0, messages.length - 1) // exclude just-added user msg
          : <ChatMessage>[];
      for (final msg in history) {
        final isInternalConfirm = msg.role == MessageRole.assistant &&
            (msg.content.contains("Tap below to confirm") ||
             msg.content.contains("I can add this task") ||
             msg.content.contains("I understood this as a task"));
        if (isInternalConfirm) continue; // don't send UI-only messages to Gemini
        contents.add({
          "role": msg.role == MessageRole.user ? "user" : "model",
          "parts": [{"text": msg.content}],
        });
      }

      // Finally, the current user message
      contents.add({
        "role": "user",
        "parts": [{"text": userInput}],
      });

      final requestBody = {
        "contents": contents,
        "generationConfig": {"temperature": 0.3, "maxOutputTokens": 1024},
      };

      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      // 🔴 Gemini error handling
      if (response.statusCode != 200) {
        if (looksLikeTask(userInput)) {
          final localDue = inferDueDateIST(userInput);

          pendingTaskToCreate = {
            "title": _extractTaskTitle(userInput),
            "dueDateLocal": localDue,
            "dueDateUTC": localDue != null ? toUtcIso(localDue) : null,
            "priority": "medium",
            "notes": "",
            "repeat": null,
          };    

          addMessage(
            "I understood this as a task:\n\n"
            "📌 ${pendingTaskToCreate!["title"]}\n"
            "${localDue != null ? "📅 ${formatForDisplay(localDue)}\n" : ""}"
            "\nTap below to confirm →",
            MessageRole.assistant,
          );
        } else {
          addMessage(
            "❌ AI error (status ${response.statusCode}). Please try again.",
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
    } catch (e) {
      addMessage("❌ Something went wrong. Please try again.", MessageRole.assistant);
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

    // Parse and always convert to local time for display
    final parsed = DateTime.tryParse(parts[1].trim());
    final localDue = parsed?.toLocal();

    pendingTaskToCreate = {
      "title": parts[0].trim(),
      "dueDateLocal": localDue,
      "dueDateUTC": localDue != null ? localDue.toUtc().toIso8601String() : null,
      "priority": parts[2].trim().isEmpty ? "medium" : parts[2].trim(),
      "notes": parts[3].trim(),
      "repeat": parts[4].trim().isEmpty ? null : parts[4].trim(),
    };

    addMessage(
      "I can add this task for you:\n\n"
      "📌 ${pendingTaskToCreate!["title"]}\n"
      "${localDue != null ? "📅 ${formatForDisplay(localDue)}\n" : ""}"
      "\nTap below to confirm →",
      MessageRole.assistant,
    );
  }

  /* ───────────────────────── CONFIRM ───────────────────────── */

  Future<bool> confirmTaskCreation(BuildContext context) async {
    if (pendingTaskToCreate == null) return false;

    final success = await _createTaskOnBackend(pendingTaskToCreate!);

    addMessage(
      success
          ? "✅ Task created successfully!"
          : "❌ Failed to create task. Try again?",
      MessageRole.assistant,
    );

    pendingTaskToCreate = null;
    notifyListeners();
    return success;
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

    final now = nowLocal();

    return tasks.map((t) {
      final title = t["title"] ?? "Untitled";
      final status = t["status"] ?? "pending";
      final priority = t["priority"] ?? "medium";
      final notes = (t["notes"] ?? "").toString().trim();

      // Convert UTC dueDate → local for display
      String dueDateStr = "No due date";
      if (t["dueDate"] != null && t["dueDate"].toString().isNotEmpty) {
        final utcDate = DateTime.tryParse(t["dueDate"].toString());
        if (utcDate != null) {
          final localDate = utcDate.toLocal();
          dueDateStr = DateFormat("EEE, d MMM yyyy 'at' h:mm a").format(localDate);

          // Label relative days for clarity
          final todayLocal = DateTime(now.year, now.month, now.day);
          final taskDay = DateTime(localDate.year, localDate.month, localDate.day);
          final diff = taskDay.difference(todayLocal).inDays;
          if (diff == 0) dueDateStr += " (TODAY)";
          else if (diff == 1) dueDateStr += " (TOMORROW)";
          else if (diff == -1) dueDateStr += " (YESTERDAY)";
          else if (diff < -1) dueDateStr += " (OVERDUE)";
        }
      }

      final notesPart = notes.isNotEmpty ? " | notes: $notes" : "";
      return "- [$status] $title | due: $dueDateStr | priority: $priority$notesPart";
    }).join("\n");
  }
}
