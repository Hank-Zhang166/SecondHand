import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 浏览历史（本地存储，最多保留 100 条）
class HistoryStore with ChangeNotifier {
  HistoryStore(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'sh_browse_history';
  static const _max = 100;

  List<HistoryEntry> _items = const [];

  List<HistoryEntry> get items => _items;

  void load() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      _items = const [];
      return;
    }
    try {
      final list = jsonDecode(raw) as List;
      _items = list
          .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _items = const [];
    }
    notifyListeners();
  }

  /// 记录一次浏览（同一商品只保留最新一条，置顶）
  void add(int productId) {
    final now = DateTime.now();
    _items = [
      HistoryEntry(productId: productId, viewedAt: now),
      ..._items.where((e) => e.productId != productId),
    ].take(_max).toList();
    _save();
    notifyListeners();
  }

  void clear() {
    _items = const [];
    _save();
    notifyListeners();
  }

  void _save() {
    _prefs.setString(
        _key, jsonEncode(_items.map((e) => e.toJson()).toList()));
  }
}

class HistoryEntry {
  final int productId;
  final DateTime viewedAt;

  HistoryEntry({required this.productId, required this.viewedAt});

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'viewed_at': viewedAt.toIso8601String(),
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
        productId: j['product_id'] is int
            ? j['product_id'] as int
            : int.tryParse('${j['product_id']}') ?? 0,
        viewedAt:
            DateTime.tryParse('${j['viewed_at']}') ?? DateTime.now(),
      );
}
