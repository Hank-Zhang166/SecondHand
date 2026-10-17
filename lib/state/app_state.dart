import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/cloud_client.dart';
import '../services/favorite_service.dart';
import '../services/history_store.dart';
import '../services/image_url_cache.dart';
import '../services/order_service.dart';
import '../services/product_service.dart';

/// 全局服务容器：一处创建，全 App 共享同一个 CloudClient
class AppServices {
  final CloudClient client;
  final AuthService auth;
  final ProductService products;
  final OrderService orders;
  final ChatService chat;
  final FavoriteService favorites;
  final HistoryStore history;
  final ImageUrlCache imageUrls;

  factory AppServices(SharedPreferences prefs) {
    final client = CloudClient();
    final auth = AuthService(client: client, prefs: prefs);
    final services = AppServices._(client, auth, prefs);
    // 会话失效（401）时自动退出登录
    client.onUnauthorized = () => auth.logout();
    return services;
  }

  AppServices._(this.client, this.auth, SharedPreferences prefs)
      : products = ProductService(client),
        orders = OrderService(client),
        chat = ChatService(client),
        favorites = FavoriteService(client),
        history = HistoryStore(prefs),
        imageUrls = ImageUrlCache(client);
}
