// 基础单元测试：数据校验与内容安全工具
import 'package:flutter_test/flutter_test.dart';
import 'package:secondhand/services/cloud_client.dart';
import 'package:secondhand/utils/content_filter.dart';
import 'package:secondhand/utils/validators.dart';

void main() {
  group('Validators', () {
    test('手机号校验', () {
      expect(Validators.isPhone('13800138000'), true);
      expect(Validators.isPhone('23800138000'), false);
      expect(Validators.isPhone('1380013800'), false);
    });

    test('邮箱格式校验', () {
      expect(Validators.isEmail('zhangsan@example.com'), true);
      expect(Validators.isEmail('not-an-email'), false);
    });

    test('学号校验', () {
      expect(Validators.isStudentId('2021310001'), true);
      expect(Validators.isStudentId('12345'), false);
    });

    test('标题与描述长度校验', () {
      expect(Validators.isTitle('九成新 iPad'), true);
      expect(Validators.isTitle('a'), false);
      expect(Validators.isDescription('这是一段足够长度的商品描述文本。'), true);
      expect(Validators.isDescription('太短'), false);
    });

    test('截止日期校验：明天起 90 天内', () {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final tooLate = DateTime.now().add(const Duration(days: 91));
      expect(Validators.isDeadline(tomorrow), true);
      expect(Validators.isDeadline(tooLate), false);
    });
  });

  group('CloudClient.normalizePhone', () {
    test('11 位大陆号码转 +86 格式', () {
      expect(CloudClient.normalizePhone('13800138000'), '+86 13800138000');
    });

    test('带 86 / 0086 前缀先剥离', () {
      expect(CloudClient.normalizePhone('8613800138000'), '+86 13800138000');
      expect(CloudClient.normalizePhone('008613800138000'), '+86 13800138000');
    });

    test('非大陆号码原样返回', () {
      expect(CloudClient.normalizePhone('+852 12345678'), '+852 12345678');
    });
  });

  group('ContentFilter', () {
    test('违规词拦截', () {
      expect(ContentFilter.check('出考试答案'), isNotNull);
      expect(ContentFilter.check('正常二手教材'), isNull);
    });

    test('站外付款引导拦截', () {
      expect(ContentFilter.check('加微信 zhangsan'), isNotNull);
    });

    test('图片类型与大小校验', () {
      expect(ContentFilter.checkImage('a.jpg', 1024), isNull);
      expect(ContentFilter.checkImage('a.gif', 1024), isNotNull);
      expect(ContentFilter.checkImage('a.jpg', 9 * 1024 * 1024), isNotNull);
    });
  });
}
