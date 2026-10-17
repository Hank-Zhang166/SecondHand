import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/product.dart';
import '../services/cloud_client.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/empty_state.dart';
import '../widgets/product_image.dart';
import '../widgets/product_card.dart';
import 'product_detail_page.dart';
import 'product_intents_page.dart';
import 'publish_page.dart';

/// 我的发布：商品状态管理（在售/已预订/已完成/已下架）
class MyPostsPage extends StatefulWidget {
  const MyPostsPage({super.key});

  @override
  State<MyPostsPage> createState() => _MyPostsPageState();
}

class _MyPostsPageState extends State<MyPostsPage> {
  List<Product> _all = [];
  String _filter = '全部';
  bool _loading = true;

  static const _filters = ['全部', '在售', '已预订', '已完成', '已下架'];

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
      final list = await services.products.myProducts(me);
      if (list.isNotEmpty) {
        await services.imageUrls.warm(
            list.map((p) => p.coverPath).where((p) => p.isNotEmpty).toSet().toList());
      }
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

  List<Product> get _filtered {
    if (_filter == '全部') return _all;
    return _all.where((p) => p.status.label == _filter).toList();
  }

  Future<void> _updateStatus(Product p, ProductStatus status) async {
    try {
      await context.read<AppServices>().products.updateStatus(p.id, status);
      if (!mounted) return;
      _toast('已更新为「${status.label}」');
      _load();
    } on CloudException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _remove(Product p) async {
    final services = context.read<AppServices>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除商品'),
        content: const Text('删除后不可恢复，确定删除该商品吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除',
                style: TextStyle(color: Color(0xFFB71C1C))),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await services.products.remove(p.id);
      if (!mounted) return;
      _toast('已删除');
      _load();
    } on CloudException catch (e) {
      if (mounted) _toast(e.message);
    }
  }

  void _showActions(Product p) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text('查看购买意向'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProductIntentsPage(
                      productId: p.id,
                      productTitle: p.title,
                    ),
                  ),
                );
              },
            ),
            if (p.status == ProductStatus.onSale)
              ListTile(
                leading: const Icon(Icons.bookmark_border),
                title: const Text('标记为「已预订」'),
                onTap: () {
                  Navigator.pop(context);
                  _updateStatus(p, ProductStatus.reserved);
                },
              ),
            if (p.status != ProductStatus.completed)
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: const Text('标记为「已完成」'),
                onTap: () {
                  Navigator.pop(context);
                  _updateStatus(p, ProductStatus.completed);
                },
              ),
            if (p.status != ProductStatus.onSale)
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('重新上架'),
                onTap: () {
                  Navigator.pop(context);
                  _updateStatus(p, ProductStatus.onSale);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: Color(0xFFB71C1C)),
              title: const Text('删除商品',
                  style: TextStyle(color: Color(0xFFB71C1C))),
              onTap: () {
                Navigator.pop(context);
                _remove(p);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的发布')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PublishPage()),
          );
          if (mounted) _load();
        },
        backgroundColor: const Color(0xFF660874),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // 状态筛选
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
            icon: Icons.inventory_2_outlined,
            text: _all.isEmpty ? '还没有发布过商品，点右下角 + 发布' : '该状态下暂无商品',
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final p = list[i];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProductDetailPage(productId: p.id),
                ),
              );
              if (mounted) _load();
            },
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProductImage(p.coverPath, width: 84, height: 84),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          Format.price(p.price),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE8641C),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            StatusBadge(p.status),
                            const Spacer(),
                            Text(
                              '${p.location.isEmpty ? '校内' : p.location} · ${p.deadlineText}',
                              style: const TextStyle(
                                  fontSize: 10, color: Color(0xFF9E9E9E)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onPressed: () => _showActions(p),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
