// =============================================================
//  Chat Message Model
// =============================================================

enum MessageRole { user, ai }

class ChatMessage {
  final String id;
  final String content;
  final MessageRole role;
  final DateTime timestamp;
  final bool isLoading; // True while AI is generating response

  const ChatMessage({
    required this.id,
    required this.content,
    required this.role,
    required this.timestamp,
    this.isLoading = false,
  });

  /// Is this a user message?
  bool get isUser => role == MessageRole.user;

  /// Is this an AI message?
  bool get isAI => role == MessageRole.ai;

  /// Convert to format needed by backend API
  Map<String, String> toApiFormat() {
    return {
      'role': role == MessageRole.user ? 'user' : 'assistant',
      'content': content,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'role': role.name,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      content: json['content'],
      role: MessageRole.values.firstWhere((e) => e.name == json['role']),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  /// Create a copy with modified fields
  ChatMessage copyWith({
    String? content,
    bool? isLoading,
  }) {
    return ChatMessage(
      id: id,
      content: content ?? this.content,
      role: role,
      timestamp: timestamp,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  String toString() => 'ChatMessage(role: $role, content: $content)';
}