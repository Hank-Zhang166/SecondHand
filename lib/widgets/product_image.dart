import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

/// 云端商品图片：传入存储路径，内部换取签名 URL 后加载
class ProductImage extends StatefulWidget {
  const ProductImage(
    this.path, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.radius = 8,
  });

  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double radius;

  @override
  State<ProductImage> createState() => _ProductImageState();
}

class _ProductImageState extends State<ProductImage> {
  @override
  void initState() {
    super.initState();
    _ensureUrl();
  }

  @override
  void didUpdateWidget(ProductImage old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) _ensureUrl();
  }

  void _ensureUrl() {
    final cache = context.read<AppServices>().imageUrls;
    if (widget.path.isEmpty) return;
    if (cache.urlOf(widget.path) != null) return;
    // 未命中缓存：后台换取签名 URL，完成后刷新
    Future.microtask(() async {
      await cache.warm([widget.path]);
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0E8),
        borderRadius: BorderRadius.circular(widget.radius),
      ),
      child: const Center(
        child: Icon(Icons.image_outlined, color: Color(0xFFC9BFA8), size: 28),
      ),
    );
    if (widget.path.isEmpty) return placeholder;

    final url = context.select<AppServices, String?>(
      (s) => s.imageUrls.urlOf(widget.path),
    );
    if (url == null) return placeholder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: CachedNetworkImage(
        imageUrl: url,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        placeholder: (_, _) => placeholder,
        errorWidget: (_, _, _) => Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F0E8),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
          child: const Center(
            child: Icon(Icons.broken_image_outlined,
                color: Color(0xFFC9BFA8), size: 28),
          ),
        ),
      ),
    );
  }
}
