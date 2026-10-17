import 'cloud_client.dart';

/// 图片 URL 缓存：把存储路径批量换成签名下载 URL（带过期时间的内存缓存）
class ImageUrlCache {
  final CloudClient client;

  /// 路径 -> (URL, 过期时间戳ms)
  final Map<String, _CachedUrl> _cache = {};
  final Set<String> _pending = {};

  ImageUrlCache(this.client);

  /// 批量预热：把一批路径换成 URL
  Future<void> warm(List<String> paths) async {
    final need = paths
        .where((p) => p.isNotEmpty && !_cache.containsKey(p) && !_pending.contains(p))
        .toSet()
        .toList();
    if (need.isEmpty) return;
    _pending.addAll(need);
    try {
      final urls = await client.signedUrls(need);
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final p in need) {
        final u = urls[p];
        if (u != null) {
          _cache[p] = _CachedUrl(u, now + 23 * 3600 * 1000);
        }
      }
    } catch (_) {
      // 签名失败时忽略，图片位置显示占位图
    } finally {
      _pending.removeAll(need);
    }
  }

  /// 同步取（未命中返回 null，由调用方决定是否先 warm）
  String? urlOf(String path) {
    final c = _cache[path];
    if (c == null) return null;
    if (DateTime.now().millisecondsSinceEpoch > c.expireAt) {
      _cache.remove(path);
      return null;
    }
    return c.url;
  }
}

class _CachedUrl {
  final String url;
  final int expireAt;
  _CachedUrl(this.url, this.expireAt);
}
