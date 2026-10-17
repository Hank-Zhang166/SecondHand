import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_message.dart';
import '../services/cloud_client.dart';
import '../state/app_state.dart';
import '../utils/format.dart';

/// 私信聊天页
class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.conversationId,
    required this.peerName,
    this.productTitle,
  });

  final int conversationId;
  final String peerName;
  final String? productTitle;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  List<ChatMessage> _messages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final services = context.read<AppServices>();
    final me = services.auth.userId ?? '';
    try {
      final list = await services.chat.messages(widget.conversationId);
      // 打开会话即标记已读
      await services.chat.markRead(widget.conversationId, me);
      if (!mounted) return;
      setState(() {
        _messages = list;
        _loading = false;
      });
      _scrollToBottom();
    } on CloudException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(
          _scrollController.position.maxScrollExtent,
        );
      }
    });
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    final services = context.read<AppServices>();
    final me = services.auth.userId ?? '';
    _inputController.clear();
    try {
      await services.chat.send(
        conversationId: widget.conversationId,
        senderId: me,
        content: text,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
          id: 0,
          conversationId: widget.conversationId,
          senderId: me,
          content: text,
          kind: 'text',
          readAt: null,
          createdAt: DateTime.now(),
        ));
      });
      _scrollToBottom();
    } on CloudException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('发送失败，请重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.read<AppServices>().auth.userId ?? '';
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(widget.peerName,
                style: const TextStyle(fontSize: 16)),
            if (widget.productTitle != null &&
                widget.productTitle!.isNotEmpty)
              Text(
                '商品：${widget.productTitle}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 10, color: Color(0xFF9E9E9E)),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading && _messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Text(
                          '开始你们的第一句对话吧',
                          style: TextStyle(
                              fontSize: 13, color: Color(0xFF9E9E9E)),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) {
                          final m = _messages[i];
                          if (m.isSystem) {
                            return _SystemBubble(m.content);
                          }
                          final mine = m.senderId == me;
                          return _Bubble(
                            text: m.content,
                            mine: mine,
                            time: Format.relative(m.createdAt),
                          );
                        },
                      ),
          ),
          // 输入栏
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: '协商交易时间与地点…',
                        hintStyle: TextStyle(fontSize: 13),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _send,
                    icon: const Icon(Icons.send, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF660874),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 聊天气泡
class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.text,
    required this.mine,
    required this.time,
  });

  final String text;
  final bool mine;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine) ...[
            const CircleAvatar(
              radius: 14,
              backgroundColor: Color(0xFFF3E5F5),
              child: Icon(Icons.person, size: 14, color: Color(0xFF660874)),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: mine ? const Color(0xFF660874) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 2),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: mine ? Colors.white : const Color(0xFF212121),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 9,
                      color: mine
                          ? Colors.white54
                          : const Color(0xFFBDBDBD),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (mine) const SizedBox(width: 0),
        ],
      ),
    );
  }
}

/// 系统提示气泡（居中灰色）
class _SystemBubble extends StatelessWidget {
  const _SystemBubble(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFEEEEEE),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: Color(0xFF757575)),
        ),
      ),
    );
  }
}
