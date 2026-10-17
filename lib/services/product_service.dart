import '../models/enums.dart';
import '../models/product.dart';
import 'cloud_client.dart';

/// 商品服务：信息流、搜索、发布、状态管理
class ProductService {
  final CloudClient client;

  ProductService(this.client);

  /// 首页信息流：按分类筛选 + 关键词模糊搜索（标题/描述）
  Future<List<Product>> feed({
    String? category,
    String? keyword,
    int limit = 20,
    int offset = 0,
  }) async {
    final filters = <String, String>{'status': 'neq.off_shelf'};
    if (category != null && category != Categories.all) {
      filters['category'] = 'eq.$category';
    }
    final kw = keyword?.trim() ?? '';
    if (kw.isNotEmpty) {
      filters['or'] = '(title.ilike.*$kw*,description.ilike.*$kw*)';
    }
    final rows = await client.select(
      'products',
      filters: filters,
      order: 'created_at.desc',
      limit: limit,
      offset: offset,
    );
    return rows.map((r) => Product.fromJson(r as Map<String, dynamic>)).toList();
  }

  /// 商品详情
  Future<Product?> detail(int id) async {
    final row = await client.selectSingle(
      'products',
      filters: {'id': 'eq.$id'},
    );
    return row == null ? null : Product.fromJson(row);
  }

  /// 我发布的商品
  Future<List<Product>> myProducts(String ownerId) async {
    final rows = await client.select(
      'products',
      filters: {'owner_id': 'eq.$ownerId'},
      order: 'created_at.desc',
      limit: 100,
    );
    return rows.map((r) => Product.fromJson(r as Map<String, dynamic>)).toList();
  }

  /// 按 id 批量查询（收藏夹用）
  Future<List<Product>> byIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    final rows = await client.select(
      'products',
      filters: {'id': 'in.(${ids.join(',')})'},
      order: 'created_at.desc',
    );
    return rows.map((r) => Product.fromJson(r as Map<String, dynamic>)).toList();
  }

  /// 发布商品。images 为已上传的存储路径。返回新商品 id。
  Future<int> publish({
    required String ownerId,
    required String ownerName,
    required String title,
    required String description,
    required double? price,
    required String category,
    required List<String> images,
    required DateTime? deadline,
    required String location,
  }) async {
    final row = <String, dynamic>{
      'owner_name': ownerName,
      'title': title,
      'description': description,
      'price': price,
      'category': category,
      'images': images,
      'deadline': deadline == null
          ? null
          : '${deadline.year.toString().padLeft(4, '0')}-${deadline.month.toString().padLeft(2, '0')}-${deadline.day.toString().padLeft(2, '0')}',
      'location': location,
      'status': ProductStatus.onSale.value,
    };
    final created = await client.insert('products', row);
    if (created.isEmpty) {
      throw Exception('发布失败，请重试');
    }
    final id = created.first['id'];
    return id is int ? id : int.tryParse('$id') ?? 0;
  }

  /// 更新商品状态（在售/已预订/已完成/已下架）
  Future<void> updateStatus(int id, ProductStatus status) async {
    await client.update(
      'products',
      {'status': status.value},
      filter: {'id': 'eq.$id'},
    );
  }

  /// 删除商品
  Future<void> remove(int id) async {
    await client.delete('products', filter: {'id': 'eq.$id'});
  }
}
