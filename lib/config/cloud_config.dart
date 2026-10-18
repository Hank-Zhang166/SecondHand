/// 云端配置（Supabase）
///
/// 后端为 GitHub 80k★ 的开源 BaaS 项目 Supabase（supabase_flutter 官方 SDK）。
/// 以下两个值来自 Supabase 控制台 Project Settings → API：
/// - supabaseUrl：项目 API 地址（anon 角色可安全暴露在前端）
/// - supabaseAnonKey：可发布密钥（publishable key，等价于旧版 anon key，
///   本身不带权限，由服务端 RLS 规则管控，可安全放进客户端代码）
///
/// 邮箱验证码登录由 Supabase Auth 提供：输入邮箱 → 收 6 位码 →
/// 验证成功即完成注册+登录（新用户自动创建账号）。
class CloudConfig {
  CloudConfig._();

  /// Supabase 项目 API 地址
  static const String supabaseUrl = 'https://eaimrisyepvsiuqclotq.supabase.co';

  /// Supabase 可发布密钥（publishable key，可公开，仅用于标识应用）
  static const String supabaseAnonKey =
      'sb_publishable_MLBM8zEABz94b4yHeDR0og_t45z5NUr';

  /// 文件存储桶名（与 schema 建表脚本一致）
  static const String storageBucket = 'runtime';

  /// App 展示名
  static const String appDisplayName = '清华二手';

  /// 是否已填入真实配置（未填入时 App 给出明确提示而不是静默失败）
  static bool get configured =>
      !supabaseUrl.contains('YOUR_PROJECT') &&
      !supabaseAnonKey.contains('YOUR_ANON_KEY');
}
