/// 私信会话
class Conversation {
  final int id;
  final int? productId;
  final String? productTitle;
  final String userA;
  final String userB;
  final String lastMessage;
  final DateTime lastMessageAt;
  final DateTime createdAt;

  Conversation({
    required this.id,
    required this.productId,
    required this.productTitle,
    required this.userA,
    required this.userB,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.createdAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
        id: j['id'] is int ? j['id'] as int : int.tryParse('${j['id']}') ?? 0,
        productId: j['product_id'] is int
            ? j['product_id'] as int
            : int.tryParse('${j['product_id']}'),
        productTitle: j['product_title'] as String?,
        userA: '${j['user_a'] ?? ''}',
        userB: '${j['user_b'] ?? ''}',
        lastMessage: '${j['last_message'] ?? ''}',
        lastMessageAt:
            DateTime.tryParse('${j['last_message_at']}') ?? DateTime.now(),
        createdAt:
            DateTime.tryParse('${j['created_at']}') ?? DateTime.now(),
      );

  /// 对方用户 id
  String peerOf(String me) => userA == me ? userB : userA;
}
