import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'pages/messages_page.dart';
import 'pages/profile_page.dart';
import 'pages/publish_page.dart';
import 'services/auth_service.dart';
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
      home: const _RootGate(),
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
class _RootGate extends StatelessWidget {
  const _RootGate();

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
