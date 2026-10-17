import 'package:intl/intl.dart';

/// 格式化工具
class Format {
  Format._();

  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _dateTimeFormat =
      DateFormat('yyyy-MM-dd HH:mm');

  static String date(DateTime? d) => d == null ? '不限' : _dateFormat.format(d);

  static String dateTime(DateTime d) => _dateTimeFormat.format(d);

  /// 相对时间：刚刚 / x 分钟前 / x 小时前 / 昨天 / x 天前 / 日期
  static String relative(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    if (diff.inDays == 1) return '昨天';
    if (diff.inDays < 30) return '${diff.inDays} 天前';
    return _dateFormat.format(d);
  }

  /// 价格展示：面议 / ¥12 / ¥12.50
  static String price(double? p) {
    if (p == null) return '面议';
    if (p == p.roundToDouble()) return '¥${p.toInt()}';
    return '¥${p.toStringAsFixed(2)}';
  }

  /// 手机号脱敏：138****1234
  static String maskPhone(String? phone) {
    if (phone == null || phone.length < 7) return phone ?? '';
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7) return phone;
    return '${digits.substring(0, 3)}****${digits.substring(digits.length - 4)}';
  }
}
