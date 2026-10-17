import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/order_intent.dart';
import '../services/cloud_client.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/empty_state.dart';
import 'chat_page.dart';

/// 商品意向管理页（卖家视角）：处理买家的购买意向
class ProductIntentsPage extends StatefulWidget {
  const ProductIntentsPage({
    super.key,
    required this.productId,
    required this.productTitle,
  });

  final int productId;
  final String productTitle;

  @override
  State<ProductIntentsPage> createState() => _ProductIntentsPageState();
}

class _ProductIntentsPageState extends State<ProductIntentsPage> {
  List<OrderIntent> _intents = [];
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
      final list = await services.orders.receivedIntents(
        me,
        productId: widget.productId,
      );
      if (!mounted) return;
      setState(() {
        _intents = list;
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

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  /// 接受意向：订单 accepted + 商品标记已预订 + 系统消息通知买家
  Future<void> _accept(OrderIntent intent) async {
    final services = context.read<AppServices>();
    final me = services.auth.userId;
    if (me == null) return;
    try {
      await services.orders.updateStatus(intent.id, OrderStatus.accepted);
      await services.products.updateStatus(
          widget.productId, ProductStatus.reserved);
      final conversation = await services.chat.findOrCreateConversation(
        meId: me,
        peerId: intent.buyerId,
        productId: widget.productId,
        productTitle: widget.productTitle,
      );
      await services.chat.sendSystem(
        conversationId: conversation.id,
        content: '卖家已接受你的购买意向，请私信协商交易时间与地点',
      );
      if (!mounted) return;
      _toast('已接受，商品标记为「已预订」');
      _load();
    } on CloudException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _reject(OrderIntent intent) async {
    try {
      await context.read<AppServices>().orders.updateStatus(
            intent.id,
            OrderStatus.rejected,
          );
      if (!mounted) return;
      _toast('已拒绝该意向');
      _load();
    } on CloudException catch (e) {
      _toast(e.message);
    }
  }

  /// 完成交易：订单 completed + 商品 completed
  Future<void> _complete(OrderIntent intent) async {
    final services = context.read<AppServices>();
    try {
      await services.orders.updateStatus(intent.id, OrderStatus.completed);
      await services.products.updateStatus(
          widget.productId, ProductStatus.completed);
      if (!mounted) return;
      _toast('交易已完成');
      _load();
    } on CloudException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _chatWith(OrderIntent intent) async {
    final services = context.read<AppServices>();
    final me = services.auth.userId;
    if (me == null) return;
    try {
      final conversation = await services.chat.findOrCreateConversation(
        meId: me,
        peerId: intent.buyerId,
        productId: widget.productId,
        productTitle: widget.productTitle,
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatPage(
            conversationId: conversation.id,
            peerName: intent.buyerName,
            productTitle: widget.productTitle,
          ),
        ),
      );
    } on CloudException catch (e) {
      _toast(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text('购买意向'),
            Text(
              widget.productTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: Color(0xFF9E9E9E)),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _intents.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_intents.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          EmptyState(
            icon: Icons.people_outline,
            text: '暂无购买意向，请耐心等待',
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _intents.length,
      itemBuilder: (context, i) {
        final intent = _intents[i];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFFF3E5F5),
                      child: Text(
                        intent.buyerName.substring(0, 1),
                        style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF660874),
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        intent.buyerName,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                    _intentStatusBadge(intent.status),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  Format.dateTime(intent.createdAt),
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF9E9E9E)),
                ),
                if (intent.note.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    intent.note,
                    style: const TextStyle(
                        fontSize: 13, height: 1.5, color: Color(0xFF424242)),
                  ),
                ],
                if (intent.status == OrderStatus.pending) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _reject(intent),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            side: const BorderSide(color: Color(0xFFE0DCDC)),
                            foregroundColor: const Color(0xFF757575),
                          ),
                          child: const Text('拒绝'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _accept(intent),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          child: const Text('接受'),
                        ),
                      ),
                    ],
                  ),
                ],
                if (intent.status == OrderStatus.accepted) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _chatWith(intent),
                          icon: const Icon(Icons.chat_bubble_outline, size: 16),
                          label: const Text('私信买家'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _complete(intent),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            side: const BorderSide(color: Color(0xFFE0DCDC)),
                            foregroundColor: const Color(0xFF2E7D32),
                          ),
                          child: const Text('完成交易'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _intentStatusBadge(OrderStatus status) {
    late final Color bg;
    late final Color fg;
    switch (status) {
      case OrderStatus.pending:
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFE65100);
        break;
      case OrderStatus.accepted:
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        break;
      case OrderStatus.rejected:
        bg = const Color(0xFFFFEBEE);
        fg = const Color(0xFFB71C1C);
        break;
      case OrderStatus.completed:
        bg = const Color(0xFFE3F2FD);
        fg = const Color(0xFF1565C0);
        break;
      case OrderStatus.cancelled:
        bg = const Color(0xFFEEEEEE);
        fg = const Color(0xFF616161);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(status.label,
          style: TextStyle(
              fontSize: 11, color: fg, fontWeight: FontWeight.w500)),
    );
  }
}
