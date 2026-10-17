/// 私信消息
class ChatMessage {
  final int id;
  final int conversationId;
  final String senderId;
  final String content;
  final String kind; // text / system
  final DateTime? readAt;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.kind,
    required this.readAt,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] is int ? j['id'] as int : int.tryParse('${j['id']}') ?? 0,
        conversationId: j['conversation_id'] is int
            ? j['conversation_id'] as int
            : int.tryParse('${j['conversation_id']}') ?? 0,
        senderId: '${j['sender_id'] ?? ''}',
        content: '${j['content'] ?? ''}',
        kind: '${j['kind'] ?? 'text'}',
        readAt: DateTime.tryParse('${j['read_at']}'),
        createdAt:
            DateTime.tryParse('${j['created_at']}') ?? DateTime.now(),
      );

  bool get isSystem => kind == 'system';
}
