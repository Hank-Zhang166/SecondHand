import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../utils/format.dart';
import '../widgets/product_image.dart';
import 'bind_phone_page.dart';
import 'favorites_page.dart';
import 'history_page.dart';
import 'my_orders_page.dart';
import 'my_posts_page.dart';
import 'profile_edit_page.dart';

/// 个人中心
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    // 确保资料已加载
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthService>();
      if (!auth.profileLoaded) auth.ensureProfile();
    });
  }

  Future<void> _logout() async {
    final auth = context.read<AuthService>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定退出当前账号吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('退出',
                style: TextStyle(color: Color(0xFFB71C1C))),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await auth.logout();
  }

  void _showNotice() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('用户须知与防骗指南'),
        content: const SingleChildScrollView(
          child: Text(
            '1. 本平台仅面向清华大学在校学生，交易仅限校内线下面对面完成，'
            '不提供任何支付与快递服务。\n\n'
            '2. 交易请选择人流量大的校内公共场所（如食堂、教学楼、图书馆），'
            '尽量结伴而行。\n\n'
            '3. 任何要求你脱离平台扫码付款、先交定金/押金、转账到'
            '个人账户的行为都可能是诈骗，请立即停止交易并举报。\n\n'
            '4. 请勿购买代考、代写、刷单等违规服务，发布违规内容将被'
            '限制账号功能。\n\n'
            '5. 请如实描述商品成色，当面确认商品后再完成交易。',
            style: TextStyle(fontSize: 13, height: 1.6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final profile = auth.profile;
    final user = auth.user;
    final verified = profile?.thuEmailVerified == true;
    final complete = profile != null && profile.studentId.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        children: [
          // 个人信息头部
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const ProfileEditPage()),
                    );
                  },
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0xFFF3E5F5),
                    child: profile != null && profile.avatarPath.isNotEmpty
                        ? ClipOval(
                            child: ProductImage(
                              profile.avatarPath,
                              width: 60,
                              height: 60,
                              radius: 30,
                            ),
                          )
                        : Text(
                            (profile?.displayName ?? '同').substring(0, 1),
                            style: const TextStyle(
                                fontSize: 22,
                                color: Color(0xFF660874),
                                fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            profile?.displayName ?? '清华同学',
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w600),
                          ),
                          if (verified) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3E5F5),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('清华认证',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF660874))),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.phone != null
                            ? Format.maskPhone(user!.phone)
                            : (user?.email ?? '未绑定账号'),
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF9E9E9E)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        verified ? '已通过清华邮箱认证' : '未认证学生身份',
                        style: TextStyle(
                          fontSize: 11,
                          color: verified
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFE65100),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        profile?.phoneBound == true
                            ? '已绑定手机号 ${Format.maskPhone(profile!.phone)}'
                            : '未绑定手机号（绑定后可用手机号登录）',
                        style: TextStyle(
                          fontSize: 11,
                          color: profile?.phoneBound == true
                              ? const Color(0xFF9E9E9E)
                              : const Color(0xFFE65100),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFFBDBDBD)),
              ],
            ),
          ),
          // 资料完善引导
          if (!complete)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 16, color: Color(0xFFF9A825)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '完善学号与院系信息，让交易更可信',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFF8D6E63)),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const ProfileEditPage()),
                      );
                      await auth.reloadProfile();
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('去完善'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          // 功能入口
          _menuGroup([
            _MenuItem(
              icon: Icons.sell_outlined,
              title: '我的发布',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MyPostsPage()),
              ),
            ),
            _MenuItem(
              icon: Icons.receipt_long_outlined,
              title: '我的订单',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MyOrdersPage()),
              ),
            ),
            _MenuItem(
              icon: Icons.star_border,
              title: '我的收藏',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FavoritesPage()),
              ),
            ),
            _MenuItem(
              icon: Icons.history,
              title: '浏览历史',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HistoryPage()),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          _menuGroup([
            _MenuItem(
              icon: Icons.edit_outlined,
              title: '编辑资料',
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const ProfileEditPage()),
                );
                await auth.reloadProfile();
              },
            ),
            _MenuItem(
              icon: Icons.phone_android,
              title: '绑定手机号',
              subtitle: profile?.phoneBound == true
                  ? '已绑定，点击更换'
                  : '绑定后可用手机号登录',
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BindPhonePage()),
                );
                await auth.reloadProfile();
              },
            ),
            _MenuItem(
              icon: Icons.shield_outlined,
              title: '用户须知与防骗指南',
              onTap: _showNotice,
            ),
          ]),
          const SizedBox(height: 12),
          _menuGroup([
            _MenuItem(
              icon: Icons.logout,
              title: '退出登录',
              titleColor: const Color(0xFFB71C1C),
              onTap: _logout,
            ),
          ]),
          const SizedBox(height: 30),
          const Center(
            child: Text(
              '清华二手 v1.0.2 · 仅限校内线下交易',
              style: TextStyle(fontSize: 10, color: Color(0xFFBDBDBD)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _menuGroup(List<_MenuItem> items) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
              ListTile(
                leading: Icon(items[i].icon,
                    size: 20,
                    color: items[i].titleColor ?? const Color(0xFF616161)),
                title: Text(
                  items[i].title,
                  style: TextStyle(
                      fontSize: 14, color: items[i].titleColor),
                ),
                subtitle: items[i].subtitle == null
                    ? null
                    : Text(
                        items[i].subtitle!,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF9E9E9E)),
                      ),
                trailing: const Icon(Icons.chevron_right,
                    size: 18, color: Color(0xFFBDBDBD)),
                onTap: items[i].onTap,
              ),
            if (i != items.length - 1)
              const Divider(height: 1, indent: 52, color: Color(0xFFF5F5F5)),
          ],
        ],
      ),
    );
  }
}

class _MenuItem {
  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.titleColor,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? titleColor;
  final String? subtitle;
}
