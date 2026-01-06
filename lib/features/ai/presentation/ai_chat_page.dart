import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../ai_controller.dart';
import 'widgets/message_bubble.dart';
import 'widgets/suggestion_chip.dart';

class AIChatPage extends StatefulWidget {
  const AIChatPage({super.key});

  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends State<AIChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<String> suggestions = [
    "What's my schedule today?",
    "Add task: Call mom tomorrow at 8 PM",
    "Show me overdue tasks",
    "Give me a productivity tip",
    "How was my week?",
    "Help me plan my morning",
  ];

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

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AIController(),
      child: Consumer<AIController>(
        builder: (context, aiController, _) {
          _scrollToBottom();

          return Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: const Text(
                "AI Assistant",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    aiController.clearChat();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Chat cleared!")),
                    );
                  },
                ),
              ],
            ),
            body: Column(
              children: [
                // Greeting + Suggestions when empty
                if (aiController.messages.isEmpty)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.smart_toy,
                              size: 80,
                              color: Colors.purple.withOpacity(0.6),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              "Hi! I'm your AI assistant",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              "I can help you manage tasks, plan your day, and stay productive.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 32),
                            Wrap(
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
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  // Chat messages
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                      itemCount: aiController.messages.length,
                      itemBuilder: (context, index) {
                        return MessageBubble(
                          message: aiController.messages[index],
                        );
                      },
                    ),
                  ),

                // Input Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    border: Border(top: BorderSide(color: Colors.grey[300]!)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          maxLines: null,
                          decoration: InputDecoration(
                            hintText: "Ask me anything...",
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                          ),
                          onSubmitted: (value) {
                            if (value.trim().isNotEmpty) {
                              aiController.sendMessage(value.trim());
                              _controller.clear();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      FloatingActionButton(
                        mini: true,
                        backgroundColor: Colors.purple,
                        elevation: 4,
                        onPressed: aiController.isLoading
                            ? null
                            : () {
                                final text = _controller.text.trim();
                                if (text.isNotEmpty) {
                                  aiController.sendMessage(text);
                                  _controller.clear();
                                }
                              },
                        child: aiController.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
