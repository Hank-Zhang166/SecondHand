import 'validators.dart';

/// 基础内容安全：
/// 1. 敏感词过滤（本地词库，命中即拦截）
/// 2. 违规交易行为词拦截（刷单、代考、私下引导脱离平台等）
/// 3. 手机号/微信号违规引流词检测
///
/// 说明：这是客户端第一道防线，生产环境还应配合服务端审核与举报人工处理。
class ContentFilter {
  ContentFilter._();

  static const List<String> _blockedWords = [
    // 违法违规
    '代考', '替考', '考试答案', '作弊器', '论文代写', '代写论文',
    '刷单', '刷信誉', '套现', '洗钱', '走私', '枪', '弹药', '毒品',
    '迷药', '烟', '电子烟', '博彩', '赌球', '六合彩', '彩票预测',
    // 色情低俗
    '色情', '裸聊', '约炮', '援交', '情色',
    // 脱离平台交易（防诈）
    '刷单返利', '杀猪盘', '资金盘', '高利贷', '校园贷',
  ];

  static const List<String> _fraudHints = [
    '加微信', '加V信', '微信转账', '支付宝转账', '扫码付款', '先款后货',
    '预付定金', '押金', '解冻资金', '刷销量',
  ];

  /// 返回 null 表示通过；否则返回拦截原因
  static String? check(String text) {
    final t = text.toLowerCase();
    for (final w in _blockedWords) {
      if (t.contains(w.toLowerCase())) {
        return '内容包含违规词「$w」，请修改后再发布';
      }
    }
    for (final w in _fraudHints) {
      if (t.contains(w.toLowerCase())) {
        return '为保障交易安全，请勿在描述中引导站外付款（如「$w」）';
      }
    }
    return null;
  }

  /// 图片基础校验：类型与大小（发布前调用）
  static String? checkImage(String filename, int bytesLength) {
    final lower = filename.toLowerCase();
    if (!lower.endsWith('.jpg') &&
        !lower.endsWith('.jpeg') &&
        !lower.endsWith('.png')) {
      return '仅支持 JPG / PNG 图片';
    }
    if (bytesLength > 8 * 1024 * 1024) {
      return '单张图片不能超过 8MB（当前 ${(bytesLength / 1024 / 1024).toStringAsFixed(1)}MB）';
    }
    return null;
  }

  /// 手机号格式提示文案
  static String? checkPhone(String s) =>
      Validators.isPhone(s) ? null : '请输入正确的 11 位手机号';
}
