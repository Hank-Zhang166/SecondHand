import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/order_intent.dart';
import '../services/cloud_client.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/empty_state.dart';
import 'chat_page.dart';
import 'product_detail_page.dart';

/// 我的订单（买家视角）：我提交的购买意向
class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({super.key});

  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {
  List<OrderIntent> _all = [];
  String _filter = '全部';
  bool _loading = true;

  static const _filters = ['全部', '待处理', '已接受', '已完成', '已拒绝', '已取消'];

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
      final list = await services.orders.myIntents(me);
      if (!mounted) return;
      setState(() {
        _all = list;
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

  List<OrderIntent> get _filtered {
    if (_filter == '全部') return _all;
    return _all.where((e) => e.status.label == _filter).toList();
  }

  Future<void> _cancel(OrderIntent intent) async {
    final services = context.read<AppServices>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('取消购买意向'),
        content: const Text('确定取消对该商品的购买意向吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('再想想'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('取消意向',
                style: TextStyle(color: Color(0xFFB71C1C))),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await services.orders.cancel(intent.id);
      if (!mounted) return;
      _toast('已取消购买意向');
      _load();
    } on CloudException catch (e) {
      if (mounted) _toast(e.message);
    }
  }

  Future<void> _contactSeller(OrderIntent intent) async {
    final services = context.read<AppServices>();
    final me = services.auth.userId;
    if (me == null) return;
    try {
      final conversation = await services.chat.findOrCreateConversation(
        meId: me,
        peerId: intent.sellerId,
        productId: intent.productId,
        productTitle: intent.productTitle,
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatPage(
            conversationId: conversation.id,
            peerName: '卖家',
            productTitle: intent.productTitle,
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
      appBar: AppBar(title: const Text('我的订单')),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: _filters
                  .map((f) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(f),
                          selected: _filter == f,
                          visualDensity: VisualDensity.compact,
                          onSelected: (_) => setState(() => _filter = f),
                        ),
                      ))
                  .toList(),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _all.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final list = _filtered;
    if (list.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          EmptyState(
            icon: Icons.receipt_long_outlined,
            text: _all.isEmpty ? '还没有提交过购买意向' : '该状态下暂无订单',
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final e = list[i];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.productTitle.isEmpty ? '商品 #${e.productId}' : e.productTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                    _intentStatusBadge(e.status),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '提交于 ${Format.dateTime(e.createdAt)}',
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF9E9E9E)),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ProductDetailPage(productId: e.productId),
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                        foregroundColor: const Color(0xFF757575),
                      ),
                      child: const Text('查看商品'),
                    ),
                    const Spacer(),
                    if (e.status == OrderStatus.pending)
                      OutlinedButton(
                        onPressed: () => _cancel(e),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          visualDensity: VisualDensity.compact,
                          side: const BorderSide(color: Color(0xFFE0DCDC)),
                          foregroundColor: const Color(0xFF757575),
                        ),
                        child: const Text('取消意向'),
                      ),
                    if (e.status == OrderStatus.accepted)
                      FilledButton(
                        onPressed: () => _contactSeller(e),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('联系卖家'),
                      ),
                  ],
                ),
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
