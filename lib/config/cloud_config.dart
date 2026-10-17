/// 云端配置
///
/// 以下三个值来自云服务激活后返回的 publicConfig，
/// 是唯一可以安全写入 App 前端的公开配置：
/// - endpoint：数据平面地址（认证 / 数据库 / 存储都走它）
/// - publishableKey：应用标识，本身不带任何权限，由服务端校验
/// - storageBucket：文件存储桶名
///
/// 更换云环境时只需修改这里。
class CloudConfig {
  CloudConfig._();

  /// 数据平面基础地址
  static const String endpoint = 'https://thu-secondhand.app.workbuddy.host';

  /// 应用发布密钥（可公开，仅用于标识应用）
  static const String publishableKey =
      'wbpk_Rlao24qmxVBqxkoexLCoMU_1X14KcczjPblWcTsaTXfbc54ez0xeEoc';

  /// 文件存储桶
  static const String storageBucket = 'runtime';

  /// App 展示名
  static const String appDisplayName = '清华二手';

  /// 接口路径前缀（与云端 SDK 约定一致，请勿改动）
  static const String authPath = '/.cloud/auth/v1';
  static const String databasePath = '/.cloud/database/rest';
  static const String storagePath = '/.cloud/storage';
}
