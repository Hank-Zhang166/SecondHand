import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'services/auth_service.dart';
import 'services/history_store.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  // 全局服务容器：共享同一个 CloudClient / AuthService
  final services = AppServices(prefs);
  await services.auth.restore(); // 恢复本地会话（过期则自动刷新）
  services.history.load(); // 加载本地浏览历史

  runApp(
    MultiProvider(
      providers: [
        Provider<AppServices>.value(value: services),
        ChangeNotifierProvider<AuthService>.value(value: services.auth),
        ChangeNotifierProvider<HistoryStore>.value(value: services.history),
      ],
      child: const SecondHandApp(),
    ),
  );
}
