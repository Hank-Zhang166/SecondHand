import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/cloud_config.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'pages/messages_page.dart';
import 'pages/profile_page.dart';
import 'pages/publish_page.dart';
import 'services/auth_service.dart';
import 'services/history_store.dart';
import 'state/app_state.dart';

/// 应用根组件：主题 + 登录态守卫 + 主框架（底部导航）
class SecondHandApp extends StatelessWidget {
  const SecondHandApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '清华二手',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const AppBootstrap(),
    );
  }

  ThemeData _buildTheme() {
    const primary = Color(0xFF660874); // 清华紫
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: const Color(0xFFE8641C),
      ),
      scaffoldBackgroundColor: const Color(0xFFF7F5F0),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF212121),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF5F3EE),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: const Color(0xFFF3E5F5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE0DCDC)),
        ),
        labelStyle: const TextStyle(fontSize: 13),
      ),
    );
  }
}

/// 登录态守卫：未登录 -> 登录页；已登录 -> 主框架
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final signedIn = context.select<AuthService, bool>((s) => s.signedIn);
    return signedIn ? const RootShell() : const LoginPage();
  }
}

/// 主框架：底部导航（首页 / 消息 / 我的）+ 中央发布按钮
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => RootShellState();
}

class RootShellState extends State<RootShell> {
  int _tab = 0;
  final _homeKey = GlobalKey<HomePageState>();

  static const _tabs = <BottomNavigationBarItem>[
    BottomNavigationBarItem(
      icon: Icon(Icons.home_outlined),
      activeIcon: Icon(Icons.home),
      label: '首页',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.chat_bubble_outline),
      activeIcon: Icon(Icons.chat_bubble),
      label: '消息',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.person_outline),
      activeIcon: Icon(Icons.person),
      label: '我的',
    ),
  ];

  final _pages = <Widget>[];

  @override
  void initState() {
    super.initState();
    _pages.addAll([
      HomePage(key: _homeKey),
      const MessagesPage(),
      const ProfilePage(),
    ]);
  }

  void _openPublish() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PublishPage()),
    );
    // 发布成功后刷新首页
    _homeKey.currentState?.reload();
    if (mounted) setState(() => _tab = 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: _pages),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _UnreadSummary(),
          BottomNavigationBar(
            currentIndex: _tab,
            items: _tabs,
            selectedItemColor: const Color(0xFF660874),
            unselectedItemColor: const Color(0xFF9E9E9E),
            type: BottomNavigationBarType.fixed,
            onTap: (i) => setState(() => _tab = i),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openPublish,
        backgroundColor: const Color(0xFF660874),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

/// 启动引导：先渲染启动页（保证首帧立即可见），
/// 再在首帧之后安全地完成初始化，任何一步超时/失败都有兜底，
/// 绝不会把用户留在白屏上。
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  String _step = '正在启动…';
  bool _failed = false;
  String? _error;
  AppServices? _services;

  @override
  void initState() {
    super.initState();
    // 推迟到首帧之后：runApp 后的第一帧立即可见（品牌启动页），
    // 插件/网络调用全部在此之后进行，不会阻塞首帧。
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    try {
      // ---------- 步骤 0：后端配置检查 ----------
      if (!CloudConfig.configured) {
        if (mounted) {
          setState(() {
            _failed = true;
            _error = '后端尚未配置。\n\n'
                '请在 lib/config/cloud_config.dart 中填入 Supabase 项目的 '
                'supabaseUrl 与 supabaseAnonKey（获取方式见 README「云端配置」章节）。';
          });
        }
        return;
      }

      // ---------- 步骤 1：本地存储 ----------
      if (mounted) setState(() => _step = '正在初始化本地存储…');
      final prefs = await _openPrefs();

      // ---------- 步骤 2：初始化 Supabase ----------
      if (mounted) setState(() => _step = '正在连接云端服务…');
      await Supabase.initialize(
        url: CloudConfig.supabaseUrl,
        publishableKey: CloudConfig.supabaseAnonKey,
      );

      // ---------- 步骤 3：恢复登录状态 ----------
      if (mounted) setState(() => _step = '正在恢复登录状态…');
      final services = AppServices(prefs);
      await services.auth.restore().timeout(
            const Duration(seconds: 10),
            onTimeout: () {}, // 超时视为未登录，不阻断启动
          );
      // 服务端校验本地会话：失效则静默清除（不弹任何错误），
      // 避免进入应用后请求 401 再被弹回登录页
      if (services.auth.signedIn) {
        await services.auth.validateSession().timeout(
              const Duration(seconds: 10),
              onTimeout: () => true, // 网络超时时保留会话，后续请求自会处理
            );
      }
      services.history.load();

      if (!mounted) return;
      setState(() {
        _services = services;
        _step = '准备就绪';
      });
    } catch (e, st) {
      debugPrint('BOOTSTRAP FAILED: $e\n$st');
      if (!mounted) return;
      setState(() {
        _failed = true;
        _error = '$e';
      });
    }
  }

  /// 打开 SharedPreferences；8 秒超时后用内存兜底，
  /// 保证任何情况下都能进入 UI（白屏的最后一道防线）。
  Future<SharedPreferences> _openPrefs() async {
    try {
      return await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('SharedPreferences failed, fallback to memory: $e');
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.setMockInitialValues(<String, Object>{});
      // ignore: invalid_use_of_visible_for_testing_member
      return SharedPreferences.getInstance();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return StartupErrorScreen(_error ?? '未知错误', onRetry: () {
        setState(() {
          _failed = false;
          _error = null;
          _step = '正在启动…';
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _init());
      });
    }
    final services = _services;
    if (services == null) {
      return _StartupSplash(step: _step);
    }
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: services.auth),
        Provider<AppServices>.value(value: services),
        ChangeNotifierProvider<HistoryStore>.value(value: services.history),
      ],
      child: const RootGate(),
    );
  }
}

/// 品牌启动页：让用户明确知道 App 正在启动、卡在哪一步
class _StartupSplash extends StatelessWidget {
  const _StartupSplash({required this.step});

  final String step;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF660874),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.shopping_bag_outlined,
                  size: 46, color: Color(0xFF660874)),
            ),
            const SizedBox(height: 18),
            const Text(
              '清华二手',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '校内二手 · 面对面交易',
              style: TextStyle(color: Color(0xFFE1BEE7), fontSize: 13),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: 140,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(
                  minHeight: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  backgroundColor: Color(0xFF9C6BAE),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              step,
              style: const TextStyle(color: Color(0xFFE1BEE7), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// release 模式下可见的错误页（替代默认空白 ErrorWidget），
/// 用于定位线上白屏问题；提供重试入口。
class StartupErrorScreen extends StatelessWidget {
  const StartupErrorScreen(this.error, {this.onRetry, super.key});

  final Object? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: Colors.white,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.error_outline,
                    size: 56, color: Color(0xFFD32F2F)),
                const SizedBox(height: 16),
                const Text(
                  '页面加载出现问题',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: SelectableText(
                      '${error ?? '未知错误'}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF616161)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (onRetry != null)
                  FilledButton(
                    onPressed: onRetry,
                    child: const Text('重试'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 底部导航上方的未读消息提示条
class _UnreadSummary extends StatefulWidget {
  const _UnreadSummary();

  @override
  State<_UnreadSummary> createState() => _UnreadSummaryState();
}

class _UnreadSummaryState extends State<_UnreadSummary> {
  Timer? _timer;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
    // 每 30 秒轮询一次未读数（云端暂无推送通道）
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    final auth = context.read<AuthService>();
    final me = auth.userId;
    if (me == null) return;
    try {
      final counts = await context.read<AppServices>().chat.unreadCounts(me);
      final total = counts.values.fold<int>(0, (a, b) => a + b);
      if (mounted && total != _total) setState(() => _total = total);
    } catch (_) {
      // 网络异常时静默
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_total <= 0) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 16),
      color: const Color(0xFFFFF3E0),
      child: Row(
        children: [
          const Icon(Icons.notifications_active_outlined,
              size: 14, color: Color(0xFFE65100)),
          const SizedBox(width: 6),
          Text(
            '你有 $_total 条未读私信，点击「消息」查看',
            style: const TextStyle(fontSize: 12, color: Color(0xFFE65100)),
          ),
        ],
      ),
    );
  }
}
