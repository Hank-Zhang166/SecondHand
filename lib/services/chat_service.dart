import '../models/chat_message.dart';
import '../models/conversation.dart';
import 'cloud_client.dart';

/// 私信服务：会话、消息、已读、未读统计
class ChatService {
  final CloudClient client;

  ChatService(this.client);

  /// 查找或创建与对方的会话（同一商品上下文）
  Future<Conversation> findOrCreateConversation({
    required String meId,
    required String peerId,
    int? productId,
    String? productTitle,
  }) async {
    // 先查我参与的会话，再在本地匹配对方
    final rows = await client.select(
      'conversations',
      filters: {
        'or': '(user_a.eq.$meId,user_b.eq.$meId)',
      },
      order: 'last_message_at.desc',
      limit: 100,
    );
    for (final r in rows) {
      final c = Conversation.fromJson(r as Map<String, dynamic>);
      if (c.peerOf(meId) == peerId) return c;
    }
    // 不存在则创建（user_a 固定为自己，保证 RLS 插入通过）
    final created = await client.insert('conversations', {
      'product_id': productId,
      'product_title': productTitle,
      'user_a': meId,
      'user_b': peerId,
      'last_message': '',
    });
    if (created.isEmpty) throw Exception('创建会话失败，请重试');
    return Conversation.fromJson(created.first);
  }

  /// 我的会话列表
  Future<List<Conversation>> myConversations(String meId) async {
    final rows = await client.select(
      'conversations',
      filters: {'or': '(user_a.eq.$meId,user_b.eq.$meId)'},
      order: 'last_message_at.desc',
      limit: 100,
    );
    return rows
        .map((r) => Conversation.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// 会话消息（按时间正序）
  Future<List<ChatMessage>> messages(int conversationId) async {
    final rows = await client.select(
      'messages',
      filters: {'conversation_id': 'eq.$conversationId'},
      order: 'created_at.asc',
      limit: 500,
    );
    return rows
        .map((r) => ChatMessage.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// 发送消息
  Future<void> send({
    required int conversationId,
    required String senderId,
    required String content,
    String kind = 'text',
  }) async {
    await client.insert('messages', {
      'conversation_id': conversationId,
      'content': content,
      'kind': kind,
    });
    await client.update(
      'conversations',
      {
        'last_message': kind == 'system' ? content : content,
        'last_message_at': DateTime.now().toUtc().toIso8601String(),
      },
      filter: {'id': 'eq.$conversationId'},
    );
  }

  /// 把对方发来的消息标记为已读
  Future<void> markRead(int conversationId, String meId) async {
    await client.update(
      'messages',
      {'read_at': DateTime.now().toUtc().toIso8601String()},
      filter: {
        'conversation_id': 'eq.$conversationId',
        'sender_id': 'neq.$meId',
        'read_at': 'is.null',
      },
    );
  }

  /// 未读消息统计：返回 {会话id: 未读数}
  Future<Map<int, int>> unreadCounts(String meId) async {
    final convs = await myConversations(meId);
    if (convs.isEmpty) return {};
    final ids = convs.map((c) => c.id).join(',');
    final rows = await client.select(
      'messages',
      columns: 'conversation_id',
      filters: {
        'conversation_id': 'in.($ids)',
        'sender_id': 'neq.$meId',
        'read_at': 'is.null',
      },
      limit: 500,
    );
    final result = <int, int>{};
    for (final r in rows) {
      final cid = r['conversation_id'];
      final id = cid is int ? cid : int.tryParse('$cid') ?? 0;
      result[id] = (result[id] ?? 0) + 1;
    }
    return result;
  }

  /// 发送系统消息（如"买家提交了购买意向"）
  Future<void> sendSystem({
    required int conversationId,
    required String content,
  }) async {
    await client.insert('messages', {
      'conversation_id': conversationId,
      'content': content,
      'kind': 'system',
      // sender_id 由 DEFAULT auth.uid() 填充为当前用户
    });
    await client.update(
      'conversations',
      {
        'last_message': content,
        'last_message_at': DateTime.now().toUtc().toIso8601String(),
      },
      filter: {'id': 'eq.$conversationId'},
    );
  }
}
