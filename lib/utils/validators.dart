/// 数据校验工具：手机号、邮箱、学号、价格、标题、描述、截止日期
class Validators {
  Validators._();

  /// 大陆手机号：11 位，1 开头
  static bool isPhone(String s) => RegExp(r'^1\d{10}$').hasMatch(s);

  /// 清华邮箱（学生邮箱或教职工邮箱）——学生身份最简校验依据
  static bool isTsinghuaEmail(String s) =>
      s.trim().toLowerCase().endsWith('@mails.tsinghua.edu.cn') ||
      s.trim().toLowerCase().endsWith('@tsinghua.edu.cn');

  static bool isEmail(String s) =>
      RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$').hasMatch(s.trim());

  /// 清华学号：9-10 位数字
  static bool isStudentId(String s) => RegExp(r'^\d{9,10}$').hasMatch(s);

  /// 价格：0.01 ~ 999999 的数字
  static bool isPrice(String s) {
    final v = double.tryParse(s.trim());
    return v != null && v > 0 && v <= 999999;
  }

  /// 标题：2-30 字
  static bool isTitle(String s) {
    final t = s.trim();
    return t.length >= 2 && t.length <= 30;
  }

  /// 描述：10-500 字
  static bool isDescription(String s) {
    final t = s.trim();
    return t.length >= 10 && t.length <= 500;
  }

  /// 截止日期：明天起 90 天内
  static bool isDeadline(DateTime d) {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final latest = DateTime(now.year, now.month, now.day + 90);
    final day = DateTime(d.year, d.month, d.day);
    return !day.isBefore(tomorrow) && !day.isAfter(latest);
  }
}
