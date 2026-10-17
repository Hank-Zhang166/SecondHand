import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../services/cloud_client.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/empty_state.dart';
import '../widgets/product_image.dart';
import 'product_detail_page.dart';

/// 收藏夹：我收藏的商品
class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  List<Product> _products = [];
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
      final ids = await services.favorites.myFavoriteIds(me);
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
        _products = products;
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

  Future<void> _unfavorite(Product p) async {
    final services = context.read<AppServices>();
    final me = services.auth.userId;
    if (me == null) return;
    try {
      await services.favorites.toggle(me, p.id);
      if (!mounted) return;
      _toast('已取消收藏');
      _load();
    } on CloudException catch (e) {
      _toast(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的收藏')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_products.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          EmptyState(
            icon: Icons.star_border,
            text: '还没有收藏商品，去首页逛逛吧',
          ),
        ],
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.70,
      ),
      itemCount: _products.length,
      itemBuilder: (context, i) {
        final p = _products[i];
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ProductImage(p.coverPath, fit: BoxFit.cover, radius: 0),
                      Positioned(
                        right: 4,
                        top: 4,
                        child: GestureDetector(
                          onTap: () => _unfavorite(p),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.star,
                              size: 14,
                              color: Color(0xFFE8641C),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, height: 1.25),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            Format.price(p.price),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE8641C),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            p.deadlineText,
                            style: TextStyle(
                              fontSize: 10,
                              color: p.expired
                                  ? const Color(0xFFB71C1C)
                                  : const Color(0xFF9E9E9E),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
