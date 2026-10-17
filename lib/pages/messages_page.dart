import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/conversation.dart';
import '../models/user_profile.dart';
import '../services/cloud_client.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/empty_state.dart';
import 'chat_page.dart';

/// 消息页：私信会话列表（含未读提醒）
class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  List<Conversation> _conversations = [];
  Map<int, int> _unread = {};
  Map<String, UserProfile> _profiles = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final services = context.read<AppServices>();
    final me = services.auth.userId;
    if (me == null) return;
    setState(() => _loading = true);
    try {
      final convs = await services.chat.myConversations(me);
      final unread = await services.chat.unreadCounts(me);
      // 批量拉取对方资料
      final peerIds = convs.map((c) => c.peerOf(me)).toSet();
      final profiles = await _fetchProfiles(peerIds);
      if (!mounted) return;
      setState(() {
        _conversations = convs;
        _unread = unread;
        _profiles = profiles;
        _loading = false;
      });
    } on CloudException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<Map<String, UserProfile>> _fetchProfiles(Set<String> ids) async {
    if (ids.isEmpty) return {};
    try {
      final rows = await context.read<AppServices>().client.select(
            'profiles',
            filters: {'owner_id': 'in.(${ids.join(',')})'},
          );
      final map = <String, UserProfile>{};
      for (final r in rows) {
        final p = UserProfile.fromJson(r as Map<String, dynamic>);
        map[p.ownerId] = p;
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final me = context.read<AppServices>().auth.userId ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('消息')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(me),
      ),
    );
  }

  Widget _buildBody(String me) {
    if (_loading && _conversations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_conversations.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          EmptyState(
            icon: Icons.chat_bubble_outline,
            text: '暂无私信，去首页看看有没有心仪的物品吧',
          ),
        ],
      );
    }
    return ListView.separated(
      itemCount: _conversations.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, indent: 72, color: Color(0xFFF0F0F0)),
      itemBuilder: (context, i) {
        final c = _conversations[i];
        final peerId = c.peerOf(me);
        final peer = _profiles[peerId];
        final unread = _unread[c.id] ?? 0;
        return ListTile(
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFF3E5F5),
                child: Text(
                  (peer?.displayName ?? '同').substring(0, 1),
                  style: const TextStyle(
                      color: Color(0xFF660874), fontWeight: FontWeight.bold),
                ),
              ),
              if (unread > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    constraints:
                        const BoxConstraints(minWidth: 16, minHeight: 16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8641C),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            peer?.displayName ?? '清华同学',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            c.productTitle != null && c.productTitle!.isNotEmpty
                ? '[${c.productTitle}] ${c.lastMessage}'
                : c.lastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: unread > 0
                  ? const Color(0xFF424242)
                  : const Color(0xFF9E9E9E),
            ),
          ),
          trailing: Text(
            Format.relative(c.lastMessageAt),
            style: const TextStyle(fontSize: 10, color: Color(0xFF9E9E9E)),
          ),
          onTap: () => _openChat(c, peer?.displayName ?? '清华同学'),
        );
      },
    );
  }

  void _openChat(Conversation c, String peerName) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          conversationId: c.id,
          peerName: peerName,
          productTitle: c.productTitle,
        ),
      ),
    );
    if (mounted) _load();
  }
}
