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

  /// App 启动时恢复本地会话；超过 30 天免登录窗口或刷新失败则清除
  Future<void> restore() async {
    final token = prefs.getString(_kAccess);
    final refresh = prefs.getString(_kRefresh);
    final expires = prefs.getInt(_kExpires) ?? 0;
    final loginAt = prefs.getInt(_kLoginAt) ?? 0;
    if (token == null || token.isEmpty || refresh == null) return;

    // 30 天免登录窗口：超时视为需要重新登录
    if (loginAt > 0 &&
        DateTime.now().millisecondsSinceEpoch - loginAt >
            sessionWindow.inMilliseconds) {
      await _clearLocal();
      return;
    }

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

  /// 启动时用服务端校验本地会话是否依然有效。
  /// 失效（过期 / 被其他端顶掉 / 云端环境重建）时先尝试刷新一次，
  /// 仍失败则静默清除，不弹错误——用户只会看到登录页。
  Future<bool> validateSession() async {
    final s = _session;
    if (s == null) return false;
    try {
      await client.currentUser();
      return true;
    } catch (_) {
      // currentUser 的 401 会触发 onUnauthorized → 会话已被清。
      // 先用原 refresh_token 尝试刷新，成功则恢复会话并重试校验。
      try {
        final fresh = await client.refresh(s.refreshToken);
        _session = fresh;
        client.accessToken = fresh.accessToken;
        _persist(fresh);
        notifyListeners();
        await client.currentUser();
        return true;
      } catch (_) {
        await _silentLogout();
        return false;
      }
    }
  }

  /// 用当前会话的 refresh_token 换一个新会话并持久化
  Future<void> _refreshCurrent() async {
    final s = _session;
    if (s == null || s.refreshToken.isEmpty) return;
    final fresh = await client.refresh(s.refreshToken);
    _session = fresh;
    client.accessToken = fresh.accessToken;
    _persist(fresh);
    notifyListeners();
  }

  /// 确保当前会话的 access token 是新鲜的（与云端 SDK 的 ensure() 对齐，
  /// 且更保守）：登录成功后总是用 refresh_token 换一次新令牌再进入应用。
  /// 首次签发的令牌可能不被数据平面接受（401 invalid_grant），
  /// 刷新后的令牌可以稳定用于数据库/存储请求。
  /// 刷新失败时不阻断登录——恢复原会话，由后续请求决定行为。
  Future<void> ensureFreshToken() async {
    final s = _session;
    if (s == null || s.refreshToken.isEmpty) return;
    try {
      await _refreshCurrent();
    } catch (_) {
      // 刷新失败（其 401 可能已触发登出）：恢复刚登录的原会话
      if (_session == null) {
        _session = s;
        client.accessToken = s.accessToken;
        _persist(s);
        notifyListeners();
      }
    }
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
  /// 3. is_user ? signin : signup，任一步失败时互为兜底，
  ///    确保"输入邮箱+验证码 → 直接进入应用"，绝不出现
  ///    "注册成功请登录"或要求重复输入的中断。
  ///
  /// [allowSignup] 为 false 时（手机号登录渠道）只允许登录，
  /// 未注册的号码会得到明确提示，不会静默创建账号。
  Future<AuthUser> loginWithOtp({
    required String phoneOrEmail,
    required bool isEmail,
    required String verificationId,
    required bool isExistingUser,
    required String code,
    bool allowSignup = true,
  }) async {
    final token = await client.verifyOtp(
      verificationId: verificationId,
      code: code,
    );
    if (token.isEmpty) {
      throw CloudException(0, 'BAD_TOKEN', '验证异常，请重新获取验证码');
    }

    final username =
        isEmail ? phoneOrEmail : CloudClient.normalizePhone(phoneOrEmail);
    final phone = isEmail ? null : phoneOrEmail;
    final email = isEmail ? phoneOrEmail : null;

    Session session;
    try {
      session = isExistingUser
          ? await client.signInWithOtp(
              username: username,
              verificationToken: token,
            )
          : await client.signUpWithOtp(
              verificationToken: token,
              phone: phone,
              email: email,
            );
    } on CloudException catch (e) {
      // 兜底：云端 is_user 判断与实际不一致时，换另一条路再试一次，
      // 避免用户被卡在"注册过却让登录 / 没注册过却让注册"的死角。
      final looksLikeMissingUser = e.code == 'NOT_FOUND' ||
          e.message.contains('不存在') ||
          e.message.contains('not exist');
      final looksLikeExistingUser = e.message.contains('已存在') ||
          e.message.contains('already') ||
          e.message.contains('registered') ||
          e.message.contains('user_already');
      if (isExistingUser && looksLikeMissingUser && allowSignup) {
        session = await client.signUpWithOtp(
          verificationToken: token,
          phone: phone,
          email: email,
        );
      } else if (!isExistingUser && looksLikeExistingUser) {
        session = await client.signInWithOtp(
          username: username,
          verificationToken: token,
        );
      } else if (!allowSignup && looksLikeMissingUser) {
        throw CloudException(
          404,
          'PHONE_NOT_REGISTERED',
          isEmail
              ? '该邮箱尚未注册'
              : '该手机号尚未注册。请先用邮箱注册登录，再到「我的」绑定手机号',
        );
      } else {
        rethrow;
      }
    }
    await _adoptSession(session);
    return session.user;
  }

  /// 手机号验证码登录（第二种登录方式）。
  /// 注意：手机号渠道只允许登录已通过邮箱注册并绑定手机号的账号，
  /// 不会创建新账号（注册仅限邮箱）。
  Future<AuthUser> loginWithPhoneOtp({
    required String phone,
    required String verificationId,
    required bool isExistingUser,
    required String code,
  }) async {
    return loginWithOtp(
      phoneOrEmail: phone,
      isEmail: false,
      verificationId: verificationId,
      isExistingUser: isExistingUser,
      code: code,
      allowSignup: false,
    );
  }

  Future<void> _adoptSession(Session session) async {
    _session = session;
    client.accessToken = session.accessToken;
    _persist(session);
    notifyListeners();
    // 与 SDK 对齐：首次签发的令牌若已临过期，先刷新再进入应用，
    // 否则数据平面会以 401 invalid_grant 拒绝后续所有请求
    await ensureFreshToken();
    // 登录后确保资料行存在，并加载资料；失败不阻断登录
    await ensureProfile();
  }

  void _persist(Session s) {
    prefs.setString(_kAccess, s.accessToken);
    prefs.setString(_kRefresh, s.refreshToken);
    prefs.setInt(_kExpires, s.expiresAt);
    prefs.setString(_kUser, jsonEncode(s.user.toJson()));
    prefs.setInt(_kLoginAt, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> _clearLocal() async {
    await prefs.remove(_kAccess);
    await prefs.remove(_kRefresh);
    await prefs.remove(_kExpires);
    await prefs.remove(_kUser);
    await prefs.remove(_kLoginAt);
  }

  /// 静默登出：仅清理本地状态，不向用户展示任何错误
  Future<void> _silentLogout() async {
    _session = null;
    _profile = null;
    _profileLoaded = false;
    client.accessToken = null;
    await _clearLocal();
    notifyListeners();
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

  bool _isTsinghuaEmail(String? email) => isTsinghuaEmail(email);
}
