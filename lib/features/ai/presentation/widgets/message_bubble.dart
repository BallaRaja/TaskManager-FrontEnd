import 'package:flutter/material.dart';
import '../../models/message.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  // NEW: task-related UI flags
  final bool isLast;
  final bool showCreateTaskButton;
  final VoidCallback? onCreateTaskPressed;
  // User profile photo URL (shown right of user bubbles)
  final String? userAvatarUrl;

  const MessageBubble({
    super.key,
    required this.message,
    this.isLast = false,
    this.showCreateTaskButton = false,
    this.onCreateTaskPressed,
    this.userAvatarUrl,
  });

  // ── Inline markdown parser ──────────────────────────────────────
  // Handles **bold**, *italic*, lines starting with "- " (bullets),
  // and plain newlines — no external package needed.
  List<InlineSpan> _parseInline(String text) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*');
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      if (match.group(1) != null) {
        spans.add(
          TextSpan(
            text: match.group(1),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      } else if (match.group(2) != null) {
        spans.add(
          TextSpan(
            text: match.group(2),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
      }
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }
    if (spans.isEmpty) spans.add(TextSpan(text: text));
    return spans;
  }

  Widget _buildMarkdown(String content, Color textColor) {
    final lines = content.split('\n');
    final children = <InlineSpan>[];

    for (int i = 0; i < lines.length; i++) {
      if (i > 0) children.add(const TextSpan(text: '\n'));

      final line = lines[i];
      final trimmed = line.trimLeft();

      // Horizontal rule
      if (trimmed == '---' || trimmed == '***') {
        children.add(
          const WidgetSpan(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Divider(height: 1),
            ),
          ),
        );
        continue;
      }

      // Bullet point
      if (trimmed.startsWith('- ') || trimmed.startsWith('• ')) {
        final body = trimmed.startsWith('- ')
            ? trimmed.substring(2)
            : trimmed.substring(2);
        children.add(const TextSpan(text: '• '));
        children.addAll(_parseInline(body));
        continue;
      }

      // Normal line
      children.addAll(_parseInline(line));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(color: textColor, fontSize: 15, height: 1.45),
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final userBubbleColor = isDark
        ? const Color(0xFF9C6BFF)
        : const Color(0xFF7C4DFF);
    final assistantBubbleColor = isDark
        ? const Color(0xFF1E1A2B)
        : const Color(0xFFEDE7FF);
    final assistantTextColor = isDark ? Colors.white : const Color(0xFF1A1A1A);

    return Column(
      crossAxisAlignment: isUser
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        // ── Row: avatar (assistant only) + bubble ──────────────────
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              // Avatar shown only for assistant messages
              if (!isUser) ...[
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.transparent,
                  backgroundImage: const AssetImage('assets/AiProfile.png'),
                ),
                const SizedBox(width: 8),
              ],

              // Message bubble
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  decoration: BoxDecoration(
                    color: isUser ? userBubbleColor : assistantBubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: isUser
                          ? const Radius.circular(18)
                          : const Radius.circular(4),
                      bottomRight: isUser
                          ? const Radius.circular(4)
                          : const Radius.circular(18),
                    ),
                  ),
                  child: isUser
                      ? Text(
                          message.content,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            height: 1.45,
                          ),
                        )
                      : _buildMarkdown(message.content, assistantTextColor),
                ),
              ),

              // User avatar (right side)
              if (isUser) ...[
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.purple.shade200,
                  backgroundImage: (userAvatarUrl != null)
                      ? NetworkImage(userAvatarUrl!) as ImageProvider
                      : null,
                  onBackgroundImageError: userAvatarUrl != null
                      ? (_, __) {
                          imageCache.evict(NetworkImage(userAvatarUrl!));
                        }
                      : null,
                  child: userAvatarUrl == null
                      ? const Icon(Icons.person, size: 20, color: Colors.white)
                      : null,
                ),
              ],
            ],
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
