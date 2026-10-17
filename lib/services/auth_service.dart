import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cloud_client.dart';
import '../models/user_profile.dart';

/// 认证服务：会话持久化、验证码登录注册、资料加载
class AuthService with ChangeNotifier {
  final CloudClient client;
  final SharedPreferences prefs;

  static const _kAccess = 'sh_access_token';
  static const _kRefresh = 'sh_refresh_token';
  static const _kExpires = 'sh_expires_at';
  static const _kUser = 'sh_user_json';

  Session? _session;
  UserProfile? _profile;
  bool _profileLoaded = false;

  AuthService({required this.client, required this.prefs});

  AuthUser? get user => _session?.user;
  String? get userId => _session?.user.id;
  bool get signedIn => _session != null;
  UserProfile? get profile => _profile;
  bool get profileLoaded => _profileLoaded;

  /// App 启动时恢复本地会话；过期则尝试刷新
  Future<void> restore() async {
    final token = prefs.getString(_kAccess);
    final refresh = prefs.getString(_kRefresh);
    final expires = prefs.getInt(_kExpires) ?? 0;
    if (token == null || token.isEmpty || refresh == null) return;

    var session = Session(
      accessToken: token,
      refreshToken: refresh,
      expiresAt: expires,
      user: AuthUser.fromJson(_readUserJson()),
    );
    if (session.expired) {
      try {
        session = await client.refresh(refresh);
      } catch (_) {
        await _clearLocal();
        return;
      }
    }
    _session = session;
    client.accessToken = session.accessToken;
    _persist(session);
    notifyListeners();
  }

  Map<String, dynamic> _readUserJson() {
    final s = prefs.getString(_kUser);
    if (s == null) return const {};
    try {
      final v = jsonDecode(s);
      return v is Map ? v.cast<String, dynamic>() : const {};
    } catch (_) {
      return const {};
    }
  }

  /// 验证码登录/注册一体化流程：
  /// 1. sendOtp 拿到 verificationId 与 is_user
  /// 2. verifyOtp 拿 verification_token
  /// 3. is_user ? signin : signup
  Future<AuthUser> loginWithOtp({
    required String phoneOrEmail,
    required bool isEmail,
    required String verificationId,
    required bool isExistingUser,
    required String code,
  }) async {
    final token = await client.verifyOtp(
      verificationId: verificationId,
      code: code,
      phone: isEmail ? null : phoneOrEmail,
      email: isEmail ? phoneOrEmail : null,
    );
    final session = isExistingUser
        ? await client.signInWithOtp(
            username: isEmail ? phoneOrEmail : '+86 $phoneOrEmail',
            verificationToken: token,
          )
        : await client.signUpWithOtp(
            verificationToken: token,
            phone: isEmail ? null : phoneOrEmail,
            email: isEmail ? phoneOrEmail : null,
          );
    await _adoptSession(session);
    return session.user;
  }

  Future<void> _adoptSession(Session session) async {
    _session = session;
    client.accessToken = session.accessToken;
    _persist(session);
    notifyListeners();
    // 登录后确保资料行存在，并加载资料
    await ensureProfile();
  }

  void _persist(Session s) {
    prefs.setString(_kAccess, s.accessToken);
    prefs.setString(_kRefresh, s.refreshToken);
    prefs.setInt(_kExpires, s.expiresAt);
    prefs.setString(_kUser, jsonEncode(s.user.toJson()));
  }

  Future<void> _clearLocal() async {
    await prefs.remove(_kAccess);
    await prefs.remove(_kRefresh);
    await prefs.remove(_kExpires);
    await prefs.remove(_kUser);
  }

  Future<void> logout() async {
    _session = null;
    _profile = null;
    _profileLoaded = false;
    client.accessToken = null;
    await _clearLocal();
    notifyListeners();
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
          'thu_email_verified': _isTsinghuaEmail(user?.email),
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

  /// 更新资料（昵称 / 学号 / 院系 / 头像）
  Future<void> updateProfile({
    String? nickname,
    String? studentId,
    String? department,
    String? avatarPath,
  }) async {
    final uid = userId;
    if (uid == null) return;
    final values = <String, dynamic>{};
    if (nickname != null) values['nickname'] = nickname;
    if (studentId != null) values['student_id'] = studentId;
    if (department != null) values['department'] = department;
    if (avatarPath != null) values['avatar_path'] = avatarPath;
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

  bool _isTsinghuaEmail(String? email) => isTsinghuaEmail(email);
}
