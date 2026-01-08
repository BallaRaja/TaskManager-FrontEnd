import 'package:flutter/material.dart';
import '../../models/message.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  // NEW: task-related UI flags
  final bool isLast;
  final bool showCreateTaskButton;
  final VoidCallback? onCreateTaskPressed;

  const MessageBubble({
    super.key,
    required this.message,
    this.isLast = false,
    this.showCreateTaskButton = false,
    this.onCreateTaskPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;

    return Column(
      crossAxisAlignment: isUser
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            padding: const EdgeInsets.all(14),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              color: isUser ? Colors.purple : Colors.grey[200],
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              message.content,
              style: TextStyle(
                color: isUser ? Colors.white : Colors.black87,
                fontSize: 15,
              ),
            ),
          ),
        ),

        // ✅ CREATE TASK BUTTON (Assistant + Last Message + Pending Task)
        if (!isUser && isLast && showCreateTaskButton)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 60, right: 12),
            child: ElevatedButton.icon(
              onPressed: onCreateTaskPressed,
              icon: const Icon(Icons.check, size: 18),
              label: const Text("Create Task"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
