import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

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
      DateTime.now().millisecondsSinceEpoch >= expiresAt - 60 * 1000;

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

/// 云端 HTTP 客户端
///
/// 完整复刻 WorkBuddy 云端 SDK 的 HTTP 契约：
/// - 所有请求携带 `x-wb-webapp-access-key` 头（应用标识）
/// - 登录后自动携带 `Authorization: Bearer <token>`
/// - 认证：/.cloud/auth/v1/**（验证码 / 登录 / 注册 / 刷新）
/// - 数据库：/.cloud/database/rest/**（PostgREST 风格）
/// - 存储：/.cloud/storage/**（上传 / 签名 URL）
class CloudClient {
  CloudClient({this.accessToken, this.onUnauthorized});

  /// 登录后由 AuthService 注入的 access token（null 表示未登录）
  String? accessToken;

  /// 会话失效（401）回调，由 AppServices 注入
  void Function()? onUnauthorized;
  final http.Client _http = http.Client();

  /// 所有网络请求统一超时，防止挂起阻塞 UI
  static const _timeout = Duration(seconds: 15);

  Future<http.Response> _get(Uri url, {Map<String, String>? headers}) =>
      _http.get(url, headers: headers).timeout(_timeout);

  Future<http.Response> _post(Uri url,
          {Map<String, String>? headers, Object? body}) =>
      _http.post(url, headers: headers, body: body).timeout(_timeout);

  Future<http.Response> _patch(Uri url,
          {Map<String, String>? headers, Object? body}) =>
      _http.patch(url, headers: headers, body: body).timeout(_timeout);

  Future<http.Response> _delete(Uri url, {Map<String, String>? headers}) =>
      _http.delete(url, headers: headers).timeout(_timeout);

  Map<String, String> _headers({bool json = true}) {
    final h = <String, String>{
      'x-wb-webapp-access-key': CloudConfig.publishableKey,
    };
    if (json) h['Content-Type'] = 'application/json';
    if (accessToken != null && accessToken!.isNotEmpty) {
      h['Authorization'] = 'Bearer $accessToken';
    }
    return h;
  }

  Never _fail(http.Response r) {
    String code = 'HTTP_${r.statusCode}';
    String message = '网络请求失败（${r.statusCode}），请稍后重试';
    try {
      final body = jsonDecode(r.body);
      if (body is Map) {
        if (body['code'] is String) code = body['code'] as String;
        if (body['message'] is String) message = body['message'] as String;
        if (body['error_description'] is String) {
          message = body['error_description'] as String;
        }
      }
    } catch (_) {
      // 响应不是 JSON，使用默认文案
    }
    if (r.statusCode == 401) onUnauthorized?.call();
    throw CloudException(r.statusCode, code, message);
  }

  // ==================== 认证模块 ====================

  /// 发送验证码。phone 传 11 位手机号（自动转成 +86 格式），email 传邮箱。
  Future<OtpChallenge> sendOtp({String? phone, String? email}) async {
    final body = <String, dynamic>{};
    if (phone != null && phone.isNotEmpty) {
      body['phone_number'] = '+86 $phone';
      body['target'] = 'ANY';
    } else if (email != null && email.isNotEmpty) {
      body['email'] = email;
      body['usage'] = 'email';
    } else {
      throw CloudException(0, 'BAD_ARGS', '请填写手机号或邮箱');
    }
    final r = await _post(
      Uri.parse('${CloudConfig.endpoint}${CloudConfig.authPath}/verification'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    if (r.statusCode != 200) _fail(r);
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    return OtpChallenge(
      data['verification_id'] as String? ?? '',
      data['is_user'] == true,
    );
  }

  /// 校验验证码，返回一次性 verification_token
  Future<String> verifyOtp({
    required String verificationId,
    required String code,
    String? phone,
    String? email,
  }) async {
    final body = <String, dynamic>{
      'verification_id': verificationId,
      'verification_code': code,
    };
    if (phone != null && phone.isNotEmpty) body['phone_number'] = '+86 $phone';
    if (email != null && email.isNotEmpty) body['email'] = email;
    final r = await _post(
      Uri.parse(
          '${CloudConfig.endpoint}${CloudConfig.authPath}/verification/verify'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    if (r.statusCode != 200) _fail(r);
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    return data['verification_token'] as String? ?? '';
  }

  /// 老用户：验证码登录
  Future<Session> signInWithOtp({
    required String username,
    required String verificationToken,
  }) async {
    final r = await _post(
      Uri.parse('${CloudConfig.endpoint}${CloudConfig.authPath}/signin'),
      headers: _headers(),
      body: jsonEncode(
          {'username': username, 'verification_token': verificationToken}),
    );
    if (r.statusCode != 200) _fail(r);
    return _parseSession(r.body);
  }

  /// 新用户：验证码注册（OTP-only，不设密码）
  Future<Session> signUpWithOtp({
    required String verificationToken,
    String? phone,
    String? email,
  }) async {
    final body = <String, dynamic>{'verification_token': verificationToken};
    if (phone != null && phone.isNotEmpty) body['phone_number'] = '+86 $phone';
    if (email != null && email.isNotEmpty) body['email'] = email;
    final r = await _post(
      Uri.parse('${CloudConfig.endpoint}${CloudConfig.authPath}/signup'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    if (r.statusCode != 200) _fail(r);
    return _parseSession(r.body);
  }

  /// 密码登录
  Future<Session> signInWithPassword({
    required String username,
    required String password,
  }) async {
    final r = await _post(
      Uri.parse('${CloudConfig.endpoint}${CloudConfig.authPath}/signin'),
      headers: _headers(),
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (r.statusCode != 200) _fail(r);
    return _parseSession(r.body);
  }

  /// 刷新会话
  Future<Session> refresh(String refreshToken) async {
    final r = await _post(
      Uri.parse('${CloudConfig.endpoint}${CloudConfig.authPath}/token'),
      headers: _headers(),
      body: jsonEncode(
          {'grant_type': 'refresh_token', 'refresh_token': refreshToken}),
    );
    if (r.statusCode != 200) _fail(r);
    return _parseSession(r.body);
  }

  /// 当前登录用户
  Future<AuthUser> currentUser() async {
    final r = await _get(
      Uri.parse('${CloudConfig.endpoint}${CloudConfig.authPath}/user/me'),
      headers: _headers(),
    );
    if (r.statusCode != 200) _fail(r);
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    final nested = data['user'];
    return AuthUser.fromJson(
        nested is Map ? nested.cast<String, dynamic>() : data);
  }

  Session _parseSession(String body) {
    final data = jsonDecode(body) as Map<String, dynamic>;
    final expiresIn = (data['expires_in'] is num)
        ? (data['expires_in'] as num).toInt()
        : 3600;
    final nested = data['user'];
    final userJson =
        nested is Map ? nested.cast<String, dynamic>() : data;
    return Session(
      accessToken: data['access_token'] as String? ?? '',
      refreshToken: data['refresh_token'] as String? ?? '',
      expiresAt:
          DateTime.now().millisecondsSinceEpoch + expiresIn * 1000,
      user: AuthUser.fromJson(userJson),
    );
  }

  // ==================== 数据库模块（PostgREST） ====================

  /// 查询。filters 形如 {'status': 'eq.on_sale', 'price': 'gte.10'}
  Future<List<dynamic>> select(
    String table, {
    String columns = '*',
    Map<String, String>? filters,
    String? order, // 'created_at.desc'
    int? limit,
    int? offset,
  }) async {
    final q = <String, String>{'select': columns};
    if (filters != null) q.addAll(filters);
    if (order != null) q['order'] = order;
    if (limit != null) q['limit'] = '$limit';
    if (offset != null) q['offset'] = '$offset';
    final uri = Uri.parse('${CloudConfig.endpoint}${CloudConfig.databasePath}/$table')
        .replace(queryParameters: q);
    final r = await _get(uri, headers: _headers());
    if (r.statusCode != 200 && r.statusCode != 206) _fail(r);
    final data = jsonDecode(r.body);
    return data is List ? data : [];
  }

  /// 单行查询（maybeSingle 语义）
  Future<Map<String, dynamic>?> selectSingle(
    String table, {
    String columns = '*',
    required Map<String, String> filters,
  }) async {
    final rows = await select(table, columns: columns, filters: filters, limit: 1);
    return rows.isEmpty ? null : rows.first as Map<String, dynamic>;
  }

  /// 插入（owner_id 由数据库 DEFAULT auth.uid() 自动填充，客户端不要传）
  Future<List<dynamic>> insert(String table, Map<String, dynamic> row) async {
    final r = await _post(
      Uri.parse('${CloudConfig.endpoint}${CloudConfig.databasePath}/$table'),
      headers: {..._headers(), 'Prefer': 'return=representation'},
      body: jsonEncode(row),
    );
    if (r.statusCode != 200 && r.statusCode != 201) _fail(r);
    final data = jsonDecode(r.body);
    return data is List ? data : [];
  }

  /// 更新。filter 形如 {'id': 'eq.5'}，必须带条件，禁止全表更新
  Future<List<dynamic>> update(
    String table,
    Map<String, dynamic> values, {
    required Map<String, String> filter,
  }) async {
    final uri = Uri.parse(
            '${CloudConfig.endpoint}${CloudConfig.databasePath}/$table')
        .replace(queryParameters: filter);
    final r = await _patch(
      uri,
      headers: {..._headers(), 'Prefer': 'return=representation'},
      body: jsonEncode(values),
    );
    if (r.statusCode != 200) _fail(r);
    final data = jsonDecode(r.body);
    return data is List ? data : [];
  }

  /// 删除。filter 形如 {'id': 'eq.5'}
  Future<List<dynamic>> delete(
    String table, {
    required Map<String, String> filter,
  }) async {
    final uri = Uri.parse(
            '${CloudConfig.endpoint}${CloudConfig.databasePath}/$table')
        .replace(queryParameters: filter);
    final r = await _delete(
      uri,
      headers: {..._headers(), 'Prefer': 'return=representation'},
    );
    if (r.statusCode != 200) _fail(r);
    final data = jsonDecode(r.body);
    return data is List ? data : [];
  }

  // ==================== 存储模块 ====================

  /// 上传文件到 runtime 桶，返回存储路径（相对路径，入库用）
  Future<String> uploadBytes(
    String path,
    List<int> bytes, {
    String contentType = 'image/jpeg',
  }) async {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse(
          '${CloudConfig.endpoint}${CloudConfig.storagePath}/object/${CloudConfig.storageBucket}/$path'),
    );
    req.headers['x-wb-webapp-access-key'] = CloudConfig.publishableKey;
    if (accessToken != null && accessToken!.isNotEmpty) {
      req.headers['Authorization'] = 'Bearer $accessToken';
    }
    req.files.add(http.MultipartFile.fromBytes(
      'file',
      Uint8List.fromList(bytes),
      filename: path.split('/').last,
      contentType: http.MediaType.parse(contentType),
    ));
    final resp = await _http.send(req).timeout(_timeout);
    final body = await resp.stream.bytesToString();
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      _fail(http.Response(body, resp.statusCode));
    }
    final data = jsonDecode(body) as Map<String, dynamic>;
    return (data['path'] ?? data['fullPath'] ?? path) as String;
  }

  /// 批量获取签名下载 URL，返回 {存储路径: 可访问 URL}
  Future<Map<String, String>> signedUrls(List<String> paths) async {
    if (paths.isEmpty) return {};
    final r = await _post(
      Uri.parse(
          '${CloudConfig.endpoint}${CloudConfig.storagePath}/object/sign/${CloudConfig.storageBucket}'),
      headers: _headers(),
      body: jsonEncode({'expiresIn': 86400, 'paths': paths}),
    );
    if (r.statusCode != 200) _fail(r);
    final data = jsonDecode(r.body);
    final result = <String, String>{};
    if (data is List) {
      for (final item in data) {
        if (item is Map) {
          final path = item['path'] as String?;
          final signed = item['signedURL'] ?? item['signedUrl'];
          if (path != null && signed is String && signed.isNotEmpty) {
            result[path] =
                '${CloudConfig.endpoint}${CloudConfig.storagePath}$signed';
          }
        }
      }
    } else if (data is Map) {
      // 兼容 {path: signedURL} 形式
      data.forEach((k, v) {
        if (v is String && v.isNotEmpty) {
          result[k] =
              '${CloudConfig.endpoint}${CloudConfig.storagePath}$v';
        }
      });
    }
    return result;
  }

  void dispose() => _http.close();
}
