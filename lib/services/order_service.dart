import '../models/enums.dart';
import '../models/order_intent.dart';
import 'cloud_client.dart';

/// 购买意向服务
class OrderService {
  final CloudClient client;

  OrderService(this.client);

  /// 买家提交购买意向
  Future<int> createIntent({
    required int productId,
    required String productTitle,
    required String buyerId,
    required String buyerName,
    required String sellerId,
    String note = '',
  }) async {
    final created = await client.insert('orders', {
      'product_id': productId,
      'product_title': productTitle,
      'buyer_name': buyerName,
      'seller_id': sellerId,
      'status': OrderStatus.pending.value,
      'note': note,
    });
    if (created.isEmpty) throw Exception('提交失败，请重试');
    final id = created.first['id'];
    return id is int ? id : int.tryParse('$id') ?? 0;
  }

  /// 买家是否已对某商品提交过有效意向（待处理/已接受）
  Future<OrderIntent?> activeIntentFor({
    required int productId,
    required String buyerId,
  }) async {
    final row = await client.selectSingle(
      'orders',
      columns: '*',
      filters: {
        'product_id': 'eq.$productId',
        'buyer_id': 'eq.$buyerId',
        'status': 'in.(pending,accepted)',
      },
    );
    return row == null ? null : OrderIntent.fromJson(row);
  }

  /// 我的购买意向（买家视角）
  Future<List<OrderIntent>> myIntents(String buyerId) async {
    final rows = await client.select(
      'orders',
      filters: {'buyer_id': 'eq.$buyerId'},
      order: 'created_at.desc',
      limit: 100,
    );
    return rows
        .map((r) => OrderIntent.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// 我收到的意向（卖家视角，可按商品过滤）
  Future<List<OrderIntent>> receivedIntents(
    String sellerId, {
    int? productId,
  }) async {
    final filters = <String, String>{'seller_id': 'eq.$sellerId'};
    if (productId != null) filters['product_id'] = 'eq.$productId';
    final rows = await client.select(
      'orders',
      filters: filters,
      order: 'created_at.desc',
      limit: 200,
    );
    return rows
        .map((r) => OrderIntent.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// 更新意向状态（接受 / 拒绝 / 完成 / 取消）
  Future<void> updateStatus(int id, OrderStatus status) async {
    await client.update(
      'orders',
      {'status': status.value},
      filter: {'id': 'eq.$id'},
    );
  }

  /// 取消意向（买家删除自己的记录）
  Future<void> cancel(int id) async {
    await client.update(
      'orders',
      {'status': OrderStatus.cancelled.value},
      filter: {'id': 'eq.$id'},
    );
  }
}
