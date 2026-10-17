import 'enums.dart';

/// 购买意向（买家 -> 卖家）
class OrderIntent {
  final int id;
  final int productId;
  final String productTitle;
  final String buyerId;
  final String buyerName;
  final String sellerId;
  final OrderStatus status;
  final String note;
  final DateTime createdAt;

  OrderIntent({
    required this.id,
    required this.productId,
    required this.productTitle,
    required this.buyerId,
    required this.buyerName,
    required this.sellerId,
    required this.status,
    required this.note,
    required this.createdAt,
  });

  factory OrderIntent.fromJson(Map<String, dynamic> j) => OrderIntent(
        id: j['id'] is int ? j['id'] as int : int.tryParse('${j['id']}') ?? 0,
        productId:
            j['product_id'] is int ? j['product_id'] as int : int.tryParse('${j['product_id']}') ?? 0,
        productTitle: '${j['product_title'] ?? ''}',
        buyerId: '${j['buyer_id'] ?? ''}',
        buyerName: ('${j['buyer_name'] ?? ''}').trim().isEmpty
            ? '同学'
            : '${j['buyer_name']}',
        sellerId: '${j['seller_id'] ?? ''}',
        status: OrderStatus.fromValue(j['status'] as String?),
        note: '${j['note'] ?? ''}',
        createdAt:
            DateTime.tryParse('${j['created_at']}') ?? DateTime.now(),
      );
}
