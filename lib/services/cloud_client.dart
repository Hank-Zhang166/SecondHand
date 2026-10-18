import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../config/cloud_config.dart';

/// 云端调用异常：携带 HTTP 状态码与业务错误码，方便 UI 区别处理
class CloudException implements Exception {
  final int statusCode;
  final String code;
  final String message;

  CloudException(this.statusCode, this.code, this.message);

  @override
  String toString() => message;
}

/// 云端登录用户
class AuthUser {
  final String id;
  final String? phone;
  final String? email;
  final String? name;
  final String? avatarUrl;

  const AuthUser({
    required this.id,
    this.phone,
    this.email,
    this.name,
    this.avatarUrl,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final meta = (json['user_metadata'] is Map)
        ? json['user_metadata'] as Map
        : const {};

    String? pick(List<String> keys) {
      for (final k in keys) {
        final v = json[k] ?? meta[k];
        if (v is String && v.isNotEmpty) return v;
      }
      return null;
    }

    return AuthUser(
      id: pick(['sub', 'uid', 'id']) ?? '',
      phone: pick(['phone_number', 'phone']),
      email: pick(['email']),
      name: pick(['name', 'nickname', 'full_name']),
      avatarUrl: pick(['avatar_url', 'avatarUrl', 'picture']),
    );
  }

  /// 由 Supabase 用户对象构造
  factory AuthUser.fromSupabase(sb.User u) => AuthUser(
        id: u.id,
        phone: u.phone,
        email: u.email,
        name: (u.userMetadata?['name'] is String)
            ? u.userMetadata!['name'] as String
            : null,
      );

  Map<String, dynamic> toJson() => {
        'sub': id,
        'phone_number': phone,
        'email': email,
        'name': name,
        'avatar_url': avatarUrl,
      };
}

/// 登录会话
class Session {
  final String accessToken;
  final String refreshToken;
  final int expiresAt; // Unix 毫秒
  final AuthUser user;

  Session({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.user,
  });

  bool get expired =>
      DateTime.now().millisecondsSinceEpoch >= expiresAt - 90 * 1000;

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'expires_at': expiresAt,
        'user': user.toJson(),
      };

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        accessToken: json['access_token'] as String? ?? '',
        refreshToken: json['refresh_token'] as String? ?? '',
        expiresAt: (json['expires_at'] as num?)?.toInt() ?? 0,
        user: AuthUser.fromJson(
            (json['user'] as Map?)?.cast<String, dynamic>() ?? const {}),
      );
}

/// 验证码挑战（发送验证码后的结果）
class OtpChallenge {
  final String verificationId;
  final bool isExistingUser;

  OtpChallenge(this.verificationId, this.isExistingUser);
}

/// 云端客户端（Supabase 适配层）
///
/// 对外暴露与原实现一致的 API（认证 / 数据库 PostgREST 风格 / 存储），
/// 内部全部转发到 Supabase 官方 SDK（GitHub 80k★ 开源 BaaS）。
/// 这样上层 8 个业务 service 无需任何改动。
class CloudClient {
  CloudClient({this.accessToken, this.onUnauthorized});

  /// 登录后由 AuthService 注入的 access token（null 表示未登录）
  String? accessToken;

  /// 会话失效（401）回调，由 AppServices 注入
  void Function()? onUnauthorized;

  sb.SupabaseClient get _sb => sb.Supabase.instance.client;

  /// 手机号规范化：11 位大陆号转 "+86 <号码>"，带 0086/86 前缀先剥离
  static String normalizePhone(String input) {
    var digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0086')) digits = digits.substring(4);
    if (digits.startsWith('86') && digits.length == 13) {
      digits = digits.substring(2);
    }
    return RegExp(r'^1\d{10}$').hasMatch(digits) ? '+86 $digits' : input;
  }

  /// 把后端原始错误映射为面向用户的中文文案
  String _friendlyMessage(String raw, int status, String code) {
    final lower = raw.toLowerCase();
    if (lower.contains('session is invalid') ||
        lower.contains('expired or issued') ||
        lower.contains('invalid_grant') ||
        lower.contains('jwt')) {
      return '登录状态已失效，请重新登录';
    }
    if (lower.contains('rate limit') ||
        lower.contains('too many') ||
        lower.contains('resource_exhausted') ||
        status == 429) {
      return '操作太频繁了，请 1 分钟后再试';
    }
    if (raw.contains('验证码') || lower.contains('token has expired')) {
      return '验证码不正确或已过期，请重新获取';
    }
    if (lower.contains('user not found') || lower.contains('not exist')) {
      return '账号不存在，请先注册';
    }
    if (lower.contains('already') || lower.contains('duplicate')) {
      return '该账号已存在，请直接登录';
    }
    if (status == 401) return '登录状态已失效，请重新登录';
    if (status == 403 || lower.contains('rls') || lower.contains('policy')) {
      return '没有权限执行此操作';
    }
    if (status == 0) return '网络连接失败，请检查网络后重试';
    return '服务开小差了，请稍后重试';
  }

  Never _fail(Object e, Object st) {
    int status = 0;
    String code = 'UNKNOWN';
    String message = '服务开小差了，请稍后重试';
    if (e is sb.AuthException) {
      status = int.tryParse(e.statusCode ?? '') ?? 0;
      code = e.code ?? 'AUTH_ERROR';
      message = e.message;
    } else if (e is sb.PostgrestException) {
      status = 400;
      code = e.code ?? 'DB_ERROR';
      message = e.message;
    } else if (e is sb.StorageException) {
      status = int.tryParse(e.statusCode ?? '') ?? 0;
      code = e.error ?? 'STORAGE_ERROR';
      message = e.message;
    } else {
      code = 'EXCEPTION';
      message = '$e';
    }
    debugLog('CloudClient fail: $message');
    throw CloudException(status, code, _friendlyMessage(message, status, code));
  }

  void debugLog(String msg) {
    // ignore: avoid_print
    print(msg);
  }

  // ==================== 认证模块（Supabase Auth） ====================

  /// 发送邮箱验证码（6 位）。Supabase 自动识别新老用户：
  /// 验证通过时新用户自动创建账号，实现"注册+登录一体化"。
  Future<OtpChallenge> sendOtp({String? phone, String? email}) async {
    if (phone != null && phone.isNotEmpty) {
      // 手机号验证码需要短信服务商配置（Supabase 免费档默认不含），
      // 当前版本仅支持邮箱渠道
      throw CloudException(
          0, 'PHONE_UNSUPPORTED', '当前版本仅支持邮箱验证码登录');
    }
    if (email == null || email.isEmpty) {
      throw CloudException(0, 'BAD_ARGS', '请填写邮箱');
    }
    try {
      await _sb.auth.signInWithOtp(
        email: email,
        shouldCreateUser: true,
      );
      return OtpChallenge('', false);
    } catch (e, st) {
      _fail(e, st);
    }
  }

  /// 校验邮箱验证码。验证通过即登录成功（新用户自动注册），返回会话。
  Future<Session> verifyOtp({
    required String email,
    required String code,
  }) async {
    try {
      final res = await _sb.auth.verifyOTP(
        email: email,
        token: code,
        type: sb.OtpType.email,
      );
      final session = res.session;
      if (session == null) {
        throw CloudException(0, 'NO_SESSION', '验证异常，请重新获取验证码');
      }
      return _toSession(session);
    } catch (e, st) {
      if (e is CloudException) rethrow;
      _fail(e, st);
    }
  }

  /// 刷新会话
  Future<Session> refresh() async {
    try {
      final res = await _sb.auth.refreshSession();
      final session = res.session;
      if (session == null) {
        throw CloudException(401, 'NO_SESSION', '登录状态已失效，请重新登录');
      }
      return _toSession(session);
    } catch (e, st) {
      if (e is CloudException) rethrow;
      _fail(e, st);
    }
  }

  /// 当前登录用户（null 表示未登录）
  AuthUser? currentUser() {
    final u = _sb.auth.currentUser;
    return u == null ? null : AuthUser.fromSupabase(u);
  }

  /// 当前会话
  Session? currentSession() {
    final s = _sb.auth.currentSession;
    return s == null ? null : _toSession(s);
  }

  Session _toSession(sb.Session s) {
    final expiresIn = s.expiresIn ?? 3600;
    final session = Session(
      accessToken: s.accessToken,
      refreshToken: s.refreshToken ?? '',
      expiresAt: DateTime.now().millisecondsSinceEpoch +
          (expiresIn > 0 ? expiresIn : 3600) * 1000,
      user: AuthUser.fromSupabase(s.user),
    );
    accessToken = session.accessToken;
    return session;
  }

  // ==================== 数据库模块（PostgREST 风格） ====================

  /// 查询。filters 形如 {'status': 'eq.on_sale', 'price': 'gte.10'}
  Future<List<dynamic>> select(
    String table, {
    String columns = '*',
    Map<String, String>? filters,
    String? order, // 'created_at.desc'
    int? limit,
    int? offset,
  }) async {
    try {
      dynamic q = _sb.from(table).select(columns);
      if (filters != null) {
        filters.forEach((k, v) {
          final idx = v.indexOf('.');
          if (idx < 0) {
            q = q.eq(k, v);
            return;
          }
          final op = v.substring(0, idx);
          final val = v.substring(idx + 1);
          switch (op) {
            case 'eq':
              q = q.eq(k, val);
            case 'neq':
              q = q.neq(k, val);
            case 'gt':
              q = q.gt(k, val);
            case 'gte':
              q = q.gte(k, val);
            case 'lt':
              q = q.lt(k, val);
            case 'lte':
              q = q.lte(k, val);
            case 'like':
              q = q.ilike(k, '%$val%');
            default:
              q = q.eq(k, v);
          }
        });
      }
      if (order != null && order.contains('.')) {
        final parts = order.split('.');
        q = q.order(parts[0], ascending: parts[1] != 'desc');
      }
      if (limit != null) {
        final from = offset ?? 0;
        q = q.range(from, from + limit - 1);
      } else if (offset != null) {
        q = q.range(offset, offset + 999);
      }
      final res = await q;
      return res is List ? res : [];
    } catch (e, st) {
      _fail(e, st);
    }
  }

  /// 单行查询（maybeSingle 语义）
  Future<Map<String, dynamic>?> selectSingle(
    String table, {
    String columns = '*',
    required Map<String, String> filters,
  }) async {
    final rows =
        await select(table, columns: columns, filters: filters, limit: 1);
    return rows.isEmpty ? null : rows.first as Map<String, dynamic>;
  }

  /// 插入（owner_id 由数据库 DEFAULT auth.uid() 自动填充，客户端不要传）
  Future<List<dynamic>> insert(String table, Map<String, dynamic> row) async {
    try {
      final res =
          await _sb.from(table).insert(row.cast<String, Object>()).select();
      return res;
    } catch (e, st) {
      _fail(e, st);
    }
  }

  /// 更新。filter 形如 {'id': 'eq.5'}，必须带条件，禁止全表更新
  Future<List<dynamic>> update(
    String table,
    Map<String, dynamic> values, {
    required Map<String, String> filter,
  }) async {
    try {
      final plain = <String, Object>{};
      filter.forEach((k, v) {
        final idx = v.indexOf('.');
        plain[k] = idx < 0 ? v : v.substring(idx + 1);
      });
      final res = await _sb.from(table)
          .update(values.cast<String, Object>())
          .match(plain)
          .select();
      return res;
    } catch (e, st) {
      _fail(e, st);
    }
  }

  /// 删除。filter 形如 {'id': 'eq.5'}
  Future<List<dynamic>> delete(
    String table, {
    required Map<String, String> filter,
  }) async {
    try {
      final plain = <String, Object>{};
      filter.forEach((k, v) {
        final idx = v.indexOf('.');
        plain[k] = idx < 0 ? v : v.substring(idx + 1);
      });
      final res = await _sb.from(table).delete().match(plain).select();
      return res;
    } catch (e, st) {
      _fail(e, st);
    }
  }

  // ==================== 存储模块 ====================

  /// 上传文件到 runtime 桶，返回存储路径（相对路径，入库用）
  Future<String> uploadBytes(
    String path,
    List<int> bytes, {
    String contentType = 'image/jpeg',
  }) async {
    try {
      await _sb.storage.from(CloudConfig.storageBucket).uploadBinary(
            path,
            Uint8List.fromList(bytes),
            fileOptions: sb.FileOptions(contentType: contentType),
          );
      return path;
    } catch (e, st) {
      _fail(e, st);
    }
  }

  /// 批量获取签名下载 URL，返回 {存储路径: 可访问 URL}
  Future<Map<String, String>> signedUrls(List<String> paths) async {
    if (paths.isEmpty) return {};
    try {
      final results = await _sb.storage
          .from(CloudConfig.storageBucket)
          .createSignedUrlsResult(paths, 86400);
      final result = <String, String>{};
      for (final item in results) {
        if (item is sb.SignedUrlSuccess) {
          result[item.path] = item.signedUrl;
        }
      }
      return result;
    } catch (e, st) {
      _fail(e, st);
    }
  }

  void dispose() {}
}
