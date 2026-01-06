enum MessageRole { user, assistant, system }

class ChatMessage {
  final String content;
  final MessageRole role;
  final DateTime timestamp;

  ChatMessage({required this.content, required this.role, DateTime? timestamp})
    : timestamp = timestamp ?? DateTime.now();
}
