import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../services/cloud_client.dart';
import '../services/history_store.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/empty_state.dart';
import '../widgets/product_image.dart';
import 'product_detail_page.dart';

/// 浏览历史（本地记录，最多 100 条）
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final Map<int, Product> _productMap = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final services = context.read<AppServices>();
    final history = services.history;
    final ids = history.items.map((e) => e.productId).toList();
    setState(() => _loading = true);
    if (ids.isEmpty) {
      setState(() {
        _productMap.clear();
        _loading = false;
      });
      return;
    }
    try {
      final products = await services.products.byIds(ids);
      if (products.isNotEmpty) {
        await services.imageUrls.warm(products
            .map((p) => p.coverPath)
            .where((p) => p.isNotEmpty)
            .toSet()
            .toList());
      }
      if (!mounted) return;
      setState(() {
        _productMap
          ..clear()
          ..addEntries(products.map((p) => MapEntry(p.id, p)));
        _loading = false;
      });
    } on CloudException catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _clearAll() async {
    final history = context.read<HistoryStore>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('清空浏览历史'),
        content: const Text('确定清空全部浏览历史吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空',
                style: TextStyle(color: Color(0xFFB71C1C))),
          ),
        ],
      ),
    );
    if (ok != true) return;
    history.clear();
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<HistoryStore>();
    final items = history.items;
    return Scaffold(
      appBar: AppBar(
        title: const Text('浏览历史'),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: _clearAll,
              child: const Text('清空',
                  style: TextStyle(color: Color(0xFF757575))),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(items),
      ),
    );
  }

  Widget _buildBody(List<HistoryEntry> items) {
    if (_loading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          EmptyState(icon: Icons.history, text: '暂无浏览记录'),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final entry = items[i];
        final p = _productMap[entry.productId];
        if (p == null) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: Color(0xFFBDBDBD)),
              title: const Text('商品已下架或删除',
                  style: TextStyle(fontSize: 13, color: Color(0xFF9E9E9E))),
              subtitle: Text('浏览于 ${Format.relative(entry.viewedAt)}',
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFFBDBDBD))),
            ),
          );
        }
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
                children: [
                  ProductImage(p.coverPath, width: 64, height: 64),
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
                              fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          Format.price(p.price),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE8641C),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    Format.relative(entry.viewedAt),
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFF9E9E9E)),
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
