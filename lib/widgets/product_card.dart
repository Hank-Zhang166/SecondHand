import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/product.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import 'product_image.dart';

/// 商品状态徽章
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});

  final ProductStatus status;

  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final Color fg;
    switch (status) {
      case ProductStatus.onSale:
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        break;
      case ProductStatus.reserved:
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFE65100);
        break;
      case ProductStatus.completed:
        bg = const Color(0xFFE3F2FD);
        fg = const Color(0xFF1565C0);
        break;
      case ProductStatus.offShelf:
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
      child: Text(
        status.label,
        style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w500),
      ),
    );
  }
}

/// 商品卡片（信息流 / 收藏 / 历史通用）
class ProductCard extends StatelessWidget {
  const ProductCard(this.product, {super.key, this.onTap});

  final Product product;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    final mine = product.isMine(services.auth.userId);
    return Card(
      elevation: 0.5,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ProductImage(
                    product.coverPath,
                    fit: BoxFit.cover,
                    radius: 0,
                  ),
                  if (product.status != ProductStatus.onSale)
                    Positioned(
                      left: 6,
                      top: 6,
                      child: StatusBadge(product.status),
                    ),
                  if (mine)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('我发布的',
                            style: TextStyle(fontSize: 10, color: Colors.white)),
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
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, height: 1.25),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        Format.price(product.price),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE8641C),
                        ),
                      ),
                      const Spacer(),
                      if (product.status == ProductStatus.onSale &&
                          product.expired)
                        const Text('已截止',
                            style: TextStyle(
                                fontSize: 10, color: Color(0xFFB71C1C))),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.place_outlined,
                          size: 11, color: Color(0xFF9E9E9E)),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          product.location.isEmpty ? '校内' : product.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 10, color: Color(0xFF9E9E9E)),
                        ),
                      ),
                      Text(
                        product.deadlineText,
                        style: TextStyle(
                          fontSize: 10,
                          color: product.expired
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
  }
}
