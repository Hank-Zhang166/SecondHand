import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/product.dart';
import '../services/cloud_client.dart';
import '../state/app_state.dart';
import '../widgets/empty_state.dart';
import '../widgets/product_card.dart';
import 'product_detail_page.dart';

/// 首页：搜索 + 分类筛选 + 商品信息流（下拉刷新 / 滚动分页）
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  String _category = Categories.all;
  String _keyword = '';
  final List<Product> _items = [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _error = false;

  static const _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load(more: false);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _load(more: true);
    }
  }

  /// 供外部（发布成功后）调用
  void reload() => _load(more: false);

  Future<void> _load({required bool more}) async {
    if (_loading || _loadingMore) return;
    if (more && !_hasMore) return;
    setState(() {
      if (more) {
        _loadingMore = true;
      } else {
        _loading = true;
        _error = false;
      }
    });
    try {
      final services = context.read<AppServices>();
      final list = await services.products.feed(
        category: _category,
        keyword: _keyword,
        limit: _pageSize,
        offset: more ? _items.length : 0,
      );
      // 预热封面图签名 URL
      final paths = list.map((p) => p.coverPath).where((p) => p.isNotEmpty);
      if (paths.isNotEmpty) await services.imageUrls.warm(paths.toSet().toList());
      if (!mounted) return;
      setState(() {
        if (more) {
          _items.addAll(list);
        } else {
          _items
            ..clear()
            ..addAll(list);
        }
        _hasMore = list.length >= _pageSize;
      });
    } on CloudException catch (e) {
      if (!mounted) return;
      setState(() => _error = true);
      _toast(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = true);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  void _onSearchSubmit(String kw) {
    final k = kw.trim();
    if (k == _keyword) return;
    setState(() => _keyword = k);
    _load(more: false);
  }

  void _onCategorySelected(String c) {
    if (c == _category) return;
    setState(() => _category = c);
    _load(more: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFF660874),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.school,
                  size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
            const Text('清华二手',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: Column(
        children: [
          // 搜索框
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: _onSearchSubmit,
              decoration: InputDecoration(
                hintText: '搜索：教材 / 自行车 / 显示器…',
                hintStyle: const TextStyle(fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _keyword.isEmpty && _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchSubmit('');
                        },
                      ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          // 分类筛选
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text(Categories.all),
                    selected: _category == Categories.all,
                    onSelected: (_) => _onCategorySelected(Categories.all),
                  ),
                ),
                ...Categories.list.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: Icon(
                        Categories.iconOf(c),
                        size: 15,
                        color: _category == c
                            ? const Color(0xFF660874)
                            : const Color(0xFF9E9E9E),
                      ),
                      label: Text(c),
                      selected: _category == c,
                      onSelected: (_) => _onCategorySelected(c),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // 商品流
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _load(more: false),
              child: _buildFeed(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeed() {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          EmptyState(
            icon: _error ? Icons.cloud_off_outlined : Icons.shopping_bag_outlined,
            text: _error ? '加载失败，下拉重试' : '暂无相关商品，换个条件试试',
            actionText: _error ? '重新加载' : null,
            onAction: _error ? () => _load(more: false) : null,
          ),
        ],
      );
    }
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.70,
      ),
      itemCount: _items.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= _items.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final p = _items[i];
        return ProductCard(
          p,
          onTap: () => _openDetail(p),
        );
      },
    );
  }

  Future<void> _openDetail(Product p) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProductDetailPage(productId: p.id)),
    );
    // 返回后刷新（商品状态可能变化）
    if (mounted) _load(more: false);
  }
}
