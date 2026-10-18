import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'cloud_client.dart';
import '../models/user_profile.dart';

/// 认证服务：会话持久化、邮箱验证码登录注册、资料加载
///
/// 后端为 Supabase Auth：邮箱 + 6 位验证码，验证通过即登录
/// （新用户自动创建账号）。会话由 SDK 自动持久化并自动刷新，
/// 同一设备登录后 30 天内无需再次登录。
class AuthService with ChangeNotifier {
  final CloudClient client;
  final SharedPreferences prefs;

  static const _kLoginAt = 'sh_login_at';

  /// 同一设备登录成功后 30 天内免登录
  static const sessionWindow = Duration(days: 30);

  Session? _session;
  UserProfile? _profile;
  bool _profileLoaded = false;

  AuthService({required this.client, required this.prefs});

  AuthUser? get user => _session?.user;
  String? get userId => _session?.user.id;
  bool get signedIn => _session != null;
  UserProfile? get profile => _profile;
  bool get profileLoaded => _profileLoaded;

  /// App 启动时恢复本地会话；超过 30 天免登录窗口则清除
  Future<void> restore() async {
    final loginAt = prefs.getInt(_kLoginAt) ?? 0;
    final current = client.currentSession();
    if (current == null) return;

    // 30 天免登录窗口：超时视为需要重新登录
    if (loginAt > 0 &&
        DateTime.now().millisecondsSinceEpoch - loginAt >
            sessionWindow.inMilliseconds) {
      await logout();
      return;
    }
    _session = current;
    client.accessToken = current.accessToken;
    notifyListeners();
  }

  /// 启动时用服务端校验本地会话是否依然有效。
  /// 失效时静默清除，不弹错误——用户只会看到登录页。
  Future<bool> validateSession() async {
    final s = _session;
    if (s == null) return false;
    final u = client.currentUser();
    if (u == null || u.id.isEmpty) {
      await _silentLogout();
      return false;
    }
    try {
      // 用一次真实数据请求确认令牌有效
      await client.selectSingle('profiles', filters: {'owner_id': 'eq.${u.id}'});
      return true;
    } catch (_) {
      try {
        final fresh = await client.refresh();
        _session = fresh;
        client.accessToken = fresh.accessToken;
        notifyListeners();
        return true;
      } catch (_) {
        await _silentLogout();
        return false;
      }
    }
  }

  /// 邮箱验证码登录/注册一体化流程：
  /// 1. sendOtp：Supabase 发送 6 位验证码
  /// 2. verifyOtp：验证通过即登录成功（新用户自动注册）
  ///
  /// 绝不会出现"注册成功请登录"或要求重复输入的中断。
  Future<AuthUser> loginWithOtp({
    required String email,
    required String code,
  }) async {
    final session = await client.verifyOtp(email: email, code: code);
    await _adoptSession(session);
    return session.user;
  }

  Future<void> _adoptSession(Session session) async {
    _session = session;
    client.accessToken = session.accessToken;
    prefs.setInt(_kLoginAt, DateTime.now().millisecondsSinceEpoch);
    notifyListeners();
    // 登录后确保资料行存在，并加载资料；失败不阻断登录
    await ensureProfile();
  }

  /// 静默登出：仅清理本地状态，不向用户展示任何错误
  Future<void> _silentLogout() async {
    _session = null;
    _profile = null;
    _profileLoaded = false;
    client.accessToken = null;
    await prefs.remove(_kLoginAt);
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await sb.Supabase.instance.client.auth.signOut();
    } catch (_) {
      // 网络异常时也继续清理本地状态
    }
    await _silentLogout();
  }

  // ==================== 用户资料 ====================

  /// 确保 profiles 表有当前用户的行（新用户首次登录自动创建）
  Future<void> ensureProfile() async {
    final uid = userId;
    if (uid == null) return;
    try {
      final row = await client.selectSingle(
        'profiles',
        filters: {'owner_id': 'eq.$uid'},
      );
      if (row != null) {
        _profile = UserProfile.fromJson(row);
      } else {
        final created = await client.insert('profiles', {
          'owner_name': user?.name ?? '清华同学',
          'nickname': user?.name?.isNotEmpty == true ? user!.name! : '清华同学',
          'student_id': '',
          'department': '',
          'thu_email_verified': isTsinghuaEmail(user?.email),
        });
        if (created.isNotEmpty) {
          _profile = UserProfile.fromJson(created.first);
        }
      }
      _profileLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('ensureProfile failed: $e');
    }
  }

  /// 刷新资料
  Future<void> reloadProfile() async {
    _profileLoaded = false;
    notifyListeners();
    await ensureProfile();
  }

  /// 更新资料（昵称 / 学号 / 院系 / 头像 / 手机号）
  Future<void> updateProfile({
    String? nickname,
    String? studentId,
    String? department,
    String? avatarPath,
    String? phone,
  }) async {
    final uid = userId;
    if (uid == null) return;
    final values = <String, dynamic>{};
    if (nickname != null) values['nickname'] = nickname;
    if (studentId != null) values['student_id'] = studentId;
    if (department != null) values['department'] = department;
    if (avatarPath != null) values['avatar_path'] = avatarPath;
    if (phone != null) values['phone'] = phone;
    if (values.isEmpty) return;
    final rows = await client.update(
      'profiles',
      values,
      filter: {'owner_id': 'eq.$uid'},
    );
    if (rows.isNotEmpty) {
      _profile = UserProfile.fromJson(rows.first);
      notifyListeners();
    }
  }

  /// 账号邮箱是否为清华邮箱（学生身份的最简校验依据）
  static bool isTsinghuaEmail(String? email) =>
      email != null &&
      (email.endsWith('@mails.tsinghua.edu.cn') ||
          email.endsWith('@tsinghua.edu.cn'));
}
