import 'enums.dart';

/// 二手商品
class Product {
  final int id;
  final String ownerId;
  final String ownerName;
  final String title;
  final String description;
  final double? price; // null 表示面议
  final String category;
  final List<String> images; // 存储路径列表
  final DateTime? deadline; // 交易截止日期
  final String location; // 线下交付地点
  final ProductStatus status;
  final DateTime createdAt;

  Product({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.title,
    required this.description,
    required this.price,
    required this.category,
    required this.images,
    required this.deadline,
    required this.location,
    required this.status,
    required this.createdAt,
  });

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'] is int ? j['id'] as int : int.tryParse('${j['id']}') ?? 0,
        ownerId: '${j['owner_id'] ?? ''}',
        ownerName: ('${j['owner_name'] ?? ''}').trim().isEmpty
            ? '清华同学'
            : '${j['owner_name']}',
        title: '${j['title'] ?? ''}',
        description: '${j['description'] ?? ''}',
        price: j['price'] == null ? null : (j['price'] as num).toDouble(),
        category: '${j['category'] ?? '其他'}',
        images: (j['images'] as List?)?.map((e) => '$e').toList() ?? const [],
        deadline: DateTime.tryParse('${j['deadline']}'),
        location: '${j['location'] ?? ''}',
        status: ProductStatus.fromValue(j['status'] as String?),
        createdAt:
            DateTime.tryParse('${j['created_at']}') ?? DateTime.now(),
      );

  bool isMine(String? uid) => uid != null && uid == ownerId;

  String get priceText =>
      price == null ? '面议' : '¥${_trimPrice(price!)}';

  static String _trimPrice(double p) {
    if (p == p.roundToDouble()) return p.toInt().toString();
    return p.toStringAsFixed(2);
  }

  /// 距截止日期的剩余天数（已过期返回 0）
  int? get daysLeft {
    if (deadline == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(deadline!.year, deadline!.month, deadline!.day);
    final diff = d.difference(today).inDays;
    return diff < 0 ? 0 : diff;
  }

  bool get expired => daysLeft == 0;

  String get deadlineText {
    if (deadline == null) return '不限';
    final d = daysLeft!;
    if (d == 0) return '今天截止';
    return '剩 $d 天';
  }

  String get coverPath => images.isNotEmpty ? images.first : '';
}
