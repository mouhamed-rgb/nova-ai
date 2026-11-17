class ChatMessage {
  const ChatMessage({required this.role, required this.content});

  final String role;
  final String content;

  bool get isUser => role == 'user';

  Map<String, String> toJson() => {'role': role, 'content': content};
}
