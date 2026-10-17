import 'cloud_client.dart';

/// 收藏服务（云端同步）
class FavoriteService {
  final CloudClient client;

  FavoriteService(this.client);

  /// 我收藏的商品 id 列表（按收藏时间倒序）
  Future<List<int>> myFavoriteIds(String ownerId) async {
    final rows = await client.select(
      'favorites',
      columns: 'product_id,created_at',
      filters: {'owner_id': 'eq.$ownerId'},
      order: 'created_at.desc',
      limit: 500,
    );
    return rows.map((r) {
      final v = r['product_id'];
      return v is int ? v : int.tryParse('$v') ?? 0;
    }).toList();
  }

  /// 是否已收藏
  Future<bool> isFavorited(String ownerId, int productId) async {
    final row = await client.selectSingle(
      'favorites',
      columns: 'id',
      filters: {'owner_id': 'eq.$ownerId', 'product_id': 'eq.$productId'},
    );
    return row != null;
  }

  /// 收藏 / 取消收藏，返回最终是否收藏
  Future<bool> toggle(String ownerId, int productId) async {
    final existing = await client.selectSingle(
      'favorites',
      columns: 'id',
      filters: {'owner_id': 'eq.$ownerId', 'product_id': 'eq.$productId'},
    );
    if (existing != null) {
      await client.delete(
        'favorites',
        filter: {'owner_id': 'eq.$ownerId', 'product_id': 'eq.$productId'},
      );
      return false;
    }
    await client.insert('favorites', {'product_id': productId});
    return true;
  }
}
