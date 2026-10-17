/// 全局枚举与常量：商品状态、意向状态、分类、校内交付地点
library;

import 'package:flutter/material.dart' show IconData;

/// 商品状态
enum ProductStatus {
  onSale('on_sale', '在售'),
  reserved('reserved', '已预订'),
  completed('completed', '已完成'),
  offShelf('off_shelf', '已下架');

  const ProductStatus(this.value, this.label);

  final String value;
  final String label;

  static ProductStatus fromValue(String? v) =>
      values.firstWhere((e) => e.value == v, orElse: () => onSale);
}

/// 购买意向状态
enum OrderStatus {
  pending('pending', '待处理'),
  accepted('accepted', '已接受'),
  rejected('rejected', '已拒绝'),
  completed('completed', '已完成'),
  cancelled('cancelled', '已取消');

  const OrderStatus(this.value, this.label);

  final String value;
  final String label;

  static OrderStatus fromValue(String? v) =>
      values.firstWhere((e) => e.value == v, orElse: () => pending);
}

/// 商品分类
class Categories {
  Categories._();

  static const String all = '全部';

  static const List<String> list = [
    '数码电子',
    '图书教材',
    '文具用品',
    '生活用品',
    '运动健身',
    '美妆护肤',
    '服装鞋帽',
    '宿舍神器',
    '乐器',
    '票券周边',
    '其他',
  ];

  /// 分类 -> 图标
  ///
  /// 注意：Flutter 新版 IconData 的 codePoint 必须是编译期常量（图标树摇），
  /// 因此用 switch 逐分支返回 const IconData，不能用运行时 Map 查找。
  static IconData iconOf(String category) {
    switch (category) {
      case '数码电子':
        return const IconData(0xe30c, fontFamily: 'MaterialIcons'); // devices
      case '图书教材':
        return const IconData(0xe53b, fontFamily: 'MaterialIcons'); // menu_book
      case '文具用品':
        return const IconData(0xe25c, fontFamily: 'MaterialIcons'); // edit
      case '生活用品':
        return const IconData(0xe58c, fontFamily: 'MaterialIcons'); // chair
      case '运动健身':
        return const IconData(0xe564, fontFamily: 'MaterialIcons'); // sports_soccer
      case '美妆护肤':
        return const IconData(0xe262, fontFamily: 'MaterialIcons'); // face
      case '服装鞋帽':
        return const IconData(0xe256, fontFamily: 'MaterialIcons'); // checkroom
      case '宿舍神器':
        return const IconData(0xe58a, fontFamily: 'MaterialIcons'); // lightbulb
      case '乐器':
        return const IconData(0xe405, fontFamily: 'MaterialIcons'); // music_note
      case '票券周边':
        return const IconData(0xe22f, fontFamily: 'MaterialIcons'); // confirmation_number
      default:
        return const IconData(0xe5cc, fontFamily: 'MaterialIcons'); // category
    }
  }
}

/// 清华校内常用线下交付地点
class CampusPlaces {
  CampusPlaces._();

  static const List<String> list = [
    '紫荆公寓',
    'C楼',
    '观畴园食堂',
    '桃李园食堂',
    '丁香园食堂',
    '听涛园食堂',
    '闻馨园食堂',
    '芝兰园食堂',
    '玉树园食堂',
    '图书馆（李文正馆）',
    '北馆',
    '主楼',
    '六教A区',
    '六教B区',
    '六教C区',
    '三教',
    '四教',
    '五教',
    '李兆基科技大楼',
    '伟伦楼',
    '舜德楼',
    '美术学院楼',
    '东操',
    '西操',
    '紫荆篮球场',
    '游泳馆',
    '综合体育馆',
    '新清华学堂',
    '校医院',
    '南门',
    '东门',
    '西门',
    '紫荆门',
  ];

  /// 校验地点是否在校内地名表内（允许"其他"由用户自定义输入）
  static bool isKnown(String place) => list.contains(place);
}
