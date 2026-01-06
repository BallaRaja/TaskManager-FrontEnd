import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'models/message.dart';
import '../../core/constants/api_constants.dart';

class AIController extends ChangeNotifier {
  List<ChatMessage> messages = [];
  bool isLoading = false;

  final String apiKey = ApiConstants.geminiApiKey;

  /// 🔹 Add message to chat list
  void addMessage(String content, MessageRole role) {
    print("🟢 addMessage()");
    print("   ↳ Role: ${role.name}");
    print("   ↳ Content: $content");

    messages.add(ChatMessage(content: content, role: role));
    notifyListeners();

    print("   ↳ Total messages: ${messages.length}");
  }

  /// 🔹 Send user message to Gemini API
  Future<void> sendMessage(String userInput) async {
    print("\n🚀 sendMessage() called");
    print("   ↳ Raw input: '$userInput'");

    if (userInput.trim().isEmpty) {
      print("⚠️ Empty input → request aborted");
      return;
    }

    addMessage(userInput, MessageRole.user);

    isLoading = true;
    notifyListeners();
    print("⏳ isLoading = true");

    try {
      final uri = Uri.parse(
        "https://generativelanguage.googleapis.com/v1/models/"
        "gemini-1.5-flash:generateContent?key=$apiKey",
      );

      print("🌐 Sending POST request to:");
      print("   ↳ $uri");

      final requestBody = {
        "contents": [
          {
            "role": "user",
            "parts": [
              {
                "text":
                    "You are a super helpful, friendly task management AI assistant in a Flutter app. "
                    "You help users create tasks, view their schedule, get summaries, and improve productivity. "
                    "Be concise, natural, and proactive. "
                    "If the user asks to add a task, confirm it clearly. "
                    "If they ask for summaries or insights, give useful tips. "
                    "Always respond in a warm, encouraging tone.\n\n"
                    "User message: $userInput",
              },
            ],
          },
        ],
        "generationConfig": {
          "temperature": 0.7,
          "topK": 40,
          "topP": 0.95,
          "maxOutputTokens": 512,
        },
        "safetySettings": [
          {
            "category": "HARM_CATEGORY_HARASSMENT",
            "threshold": "BLOCK_MEDIUM_AND_ABOVE",
          },
          {
            "category": "HARM_CATEGORY_HATE_SPEECH",
            "threshold": "BLOCK_MEDIUM_AND_ABOVE",
          },
          {
            "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
            "threshold": "BLOCK_MEDIUM_AND_ABOVE",
          },
          {
            "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
            "threshold": "BLOCK_MEDIUM_AND_ABOVE",
          },
        ],
      };

      print("📦 Request body:");
      print(jsonEncode(requestBody));

      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      print("📥 Response received");
      print("   ↳ Status code: ${response.statusCode}");
      print("   ↳ Raw body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("✅ JSON parsed successfully");

        final aiReply =
            data["candidates"][0]["content"]["parts"][0]["text"] as String;

        print("🤖 Gemini reply:");
        print(aiReply);

        addMessage(aiReply.trim(), MessageRole.assistant);
      } else {
        print("❌ Gemini API error");

        addMessage(
          "Sorry, I'm having a little trouble right now. Please try again in a moment! 😊",
          MessageRole.assistant,
        );
      }
    } catch (e, stack) {
      print("🔥 Exception occurred");
      print("   ↳ Error: $e");
      print("   ↳ StackTrace: $stack");

      addMessage(
        "Network error — check your connection and try again.",
        MessageRole.assistant,
      );
    }

    isLoading = false;
    notifyListeners();
    print("✅ isLoading = false");
    print("🔚 sendMessage() completed\n");
  }

  /// 🔹 Clear entire chat
  void clearChat() {
    print("🧹 clearChat() called");
    messages.clear();
    notifyListeners();
    print("   ↳ Messages cleared");
  }
}
