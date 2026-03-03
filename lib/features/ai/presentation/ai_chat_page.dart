import 'dart:convert';
import 'package:client/features/ai/models/message.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import '../ai_controller.dart';
import 'widgets/message_bubble.dart';
import 'widgets/suggestion_chip.dart';
import 'widgets/typing_indicator.dart';
import 'widgets/task_created_overlay.dart';
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
  late final AIController _aiController;

  List<Map<String, dynamic>> _taskLists = [];
  String? _userAvatarUrl;

  @override
  void initState() {
    super.initState();
    _aiController = AIController();
    _aiController.init();
    _fetchTaskLists();
    _fetchUserAvatar();
  }

  @override
  void dispose() {
    _aiController.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserAvatar() async {
    try {
      final token = await SessionManager.getToken();
      final userId = await SessionManager.getUserId();
      if (token == null || userId == null) return;

      final res = await http.get(
        Uri.parse('${ApiConstants.backendUrl}/api/profile/$userId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final raw = data['data']?['profile']?['avatarUrl']?.toString() ?? '';
        if (raw.isNotEmpty && !raw.contains('placeholder')) {
          String fullUrl;
          if (raw.startsWith('http')) {
            fullUrl = raw;
          } else if (raw.startsWith('/')) {
            fullUrl = '${ApiConstants.backendUrl}$raw';
          } else {
            return;
          }
          if (mounted) setState(() => _userAvatarUrl = fullUrl);
        }
      }
    } catch (_) {}
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
    return ChangeNotifierProvider.value(
      value: _aiController,
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
                      child: aiController.isLoadingSuggestions &&
                              aiController.suggestions.isEmpty
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.purple,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  "Preparing suggestions…",
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            )
                          : Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              alignment: WrapAlignment.center,
                              children: aiController.suggestions.map((s) {
                                return SuggestionChip(
                                  label: s,
                                  onTap: () {
                                    _controller.text = s;
                                    aiController.sendMessage(s);
                                    _controller.clear();
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
                      itemCount: aiController.messages.length +
                          (aiController.isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        // Show typing indicator as the last item while loading
                        if (aiController.isLoading &&
                            index == aiController.messages.length) {
                          return const Align(
                            alignment: Alignment.centerLeft,
                            child: TypingIndicator(),
                          );
                        }
                        final msg = aiController.messages[index];
                        final isLast =
                            index == aiController.messages.length - 1;

                        return Column(
                          crossAxisAlignment: msg.role == MessageRole.user
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            MessageBubble(
                              message: msg,
                              userAvatarUrl: _userAvatarUrl,
                            ),

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

                                        final ok = await aiController
                                            .confirmTaskCreation(context);
                                        if (ok && context.mounted) {
                                          TaskCreatedOverlay.show(context);
                                        }
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
                                          final ok = await aiController
                                              .confirmTaskCreation(context);
                                          if (ok && context.mounted) {
                                            TaskCreatedOverlay.show(context);
                                          }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── Text field ──────────────────────────────────────────
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E1A2B)
                    : const Color(0xFFF3EEFF),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? Colors.purple.shade900
                      : Colors.purple.shade100,
                  width: 1.2,
                ),
              ),
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: 'Ask me anything…',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white38 : Colors.grey.shade500,
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) {
                    aiController.sendMessage(v.trim());
                    _controller.clear();
                  }
                },
              ),
            ),
          ),

          const SizedBox(width: 8),

          // ── Send button ─────────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: aiController.isLoading
                  ? (isDark ? Colors.grey.shade700 : Colors.grey.shade300)
                  : Colors.purple,
              shape: BoxShape.circle,
              boxShadow: aiController.isLoading
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.purple.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
            ),
            child: IconButton(
              icon: Icon(
                Icons.send_rounded,
                color: aiController.isLoading ? Colors.grey : Colors.white,
                size: 20,
              ),
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
          ),
        ],
      ),
    );
  }
}
