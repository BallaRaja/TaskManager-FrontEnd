import 'dart:convert';
import 'package:client/features/ai/models/message.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import '../ai_controller.dart';
import 'widgets/message_bubble.dart';
import 'widgets/suggestion_chip.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/session_manager.dart';

class AIChatPage extends StatefulWidget {
  const AIChatPage({super.key});

  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends State<AIChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _taskLists = [];
  bool _isLoadingLists = false;

  final List<String> suggestions = [
    "What's my schedule today?",
    "Add task: Buy milk tomorrow",
    "Show me overdue tasks",
    "Give me a productivity tip",
  ];

  @override
  void initState() {
    super.initState();
    _fetchTaskLists();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// 🔹 Fetch taskLists for user
  Future<void> _fetchTaskLists() async {
    try {
      setState(() => _isLoadingLists = true);

      final userId = await SessionManager.getUserId();
      if (userId == null) return;

      final res = await http.get(
        Uri.parse("${ApiConstants.backendUrl}/api/taskList/$userId"),
      );

      if (res.statusCode == 200) {
        final List raw = jsonDecode(res.body)["data"] ?? [];
        final lists = List<Map<String, dynamic>>.from(raw);

        // Default list first
        lists.sort((a, b) {
          if (a["isDefault"] == true) return -1;
          if (b["isDefault"] == true) return 1;
          return 0;
        });

        setState(() => _taskLists = lists);
      }
    } catch (e) {
      debugPrint("❌ TaskList fetch error: $e");
    } finally {
      setState(() => _isLoadingLists = false);
    }
  }

  /// 🔹 Show taskList picker sheet
  Future<String?> _showTaskListPicker() async {
    if (_taskLists.isEmpty) return null;

    return showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                "Choose Task List",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ..._taskLists.map((list) {
              return ListTile(
                leading: Icon(
                  list["isDefault"] == true ? Icons.star : Icons.folder,
                  color: Colors.purple,
                ),
                title: Text(list["title"]),
                subtitle: list["isDefault"] == true
                    ? const Text("Default")
                    : null,
                onTap: () => Navigator.pop(context, list["_id"]),
              );
            }).toList(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AIController(),
      child: Consumer<AIController>(
        builder: (context, aiController, _) {
          _scrollToBottom();

          return Scaffold(
            appBar: AppBar(
              title: const Text("AI Assistant"),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: aiController.clearChat,
                ),
              ],
            ),
            body: Column(
              children: [
                // Empty state
                if (aiController.messages.isEmpty)
                  Expanded(
                    child: Center(
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: suggestions.map((s) {
                          return SuggestionChip(
                            label: s,
                            onTap: () {
                              _controller.text = s;
                              aiController.sendMessage(s);
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
                      itemCount: aiController.messages.length,
                      itemBuilder: (context, index) {
                        final msg = aiController.messages[index];
                        final isLast =
                            index == aiController.messages.length - 1;

                        return Column(
                          crossAxisAlignment: msg.role == MessageRole.user
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            MessageBubble(message: msg),

                            // 🔥 Task confirmation actions
                            if (isLast &&
                                msg.role == MessageRole.assistant &&
                                aiController.pendingTaskToCreate != null)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 8,
                                  left: 60,
                                ),
                                child: Row(
                                  children: [
                                    ElevatedButton(
                                      onPressed: () async {
                                        final defaultList = _taskLists
                                            .firstWhere(
                                              (l) => l["isDefault"] == true,
                                            );

                                        aiController
                                                .pendingTaskToCreate!["taskListId"] =
                                            defaultList["_id"];

                                        await aiController.confirmTaskCreation(
                                          context,
                                        );
                                      },
                                      child: const Text("Add to Default"),
                                    ),
                                    const SizedBox(width: 12),
                                    TextButton(
                                      onPressed: () async {
                                        final listId =
                                            await _showTaskListPicker();
                                        if (listId != null) {
                                          aiController
                                                  .pendingTaskToCreate!["taskListId"] =
                                              listId;
                                          await aiController
                                              .confirmTaskCreation(context);
                                        }
                                      },
                                      child: const Text("Choose list"),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),

                // Input bar
                _buildInputBar(aiController),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputBar(AIController aiController) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(hintText: "Ask me anything..."),
              onSubmitted: (v) {
                if (v.trim().isNotEmpty) {
                  aiController.sendMessage(v.trim());
                  _controller.clear();
                }
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: aiController.isLoading
                ? null
                : () {
                    final text = _controller.text.trim();
                    if (text.isNotEmpty) {
                      aiController.sendMessage(text);
                      _controller.clear();
                    }
                  },
          ),
        ],
      ),
    );
  }
}
