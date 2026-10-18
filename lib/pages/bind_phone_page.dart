import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../utils/validators.dart';

/// 联系手机号：保存到 profiles.phone，用于发布商品时展示给买家联系。
///
/// 说明：邮箱验证码登录由 Supabase Auth 提供；手机号短信登录需要
/// 额外的短信服务商配置（Supabase 免费档默认不含），当前版本
/// 暂不提供手机号登录，手机号仅作为站内联系信息保存。
class BindPhonePage extends StatefulWidget {
  const BindPhonePage({super.key});

  @override
  State<BindPhonePage> createState() => _BindPhonePageState();
}

class _BindPhonePageState extends State<BindPhonePage> {
  final _phoneController = TextEditingController();

  bool _submitting = false;

  String get _phone => _phoneController.text.trim();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _save() async {
    final phone = _phone;
    if (!Validators.isPhone(phone)) {
      _toast('请输入正确的 11 位手机号');
      return;
    }
    setState(() => _submitting = true);
    // 先取好服务引用，避免异步间隙后使用 context
    final auth = context.read<AuthService>();
    try {
      await auth.updateProfile(phone: phone);
      if (!mounted) return;
      _toast('联系手机号已保存');
      Navigator.pop(context);
    } catch (_) {
      _toast('保存失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final boundPhone = auth.profile?.phone ?? '';
    final hasBound = boundPhone.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('联系手机号')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E5F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: Color(0xFF660874)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '保存后，买家在商品详情页可以看到你的联系手机号，'
                    '更方便校内线下交易。手机号仅用于站内联系展示。',
                    style: TextStyle(fontSize: 12, color: Color(0xFF4A148C)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (hasBound) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading:
                  const Icon(Icons.phone_android, color: Color(0xFF660874)),
              title: const Text('当前手机号'),
              subtitle: Text(boundPhone),
              trailing: TextButton(
                onPressed: () {
                  setState(() => _phoneController.text = boundPhone);
                },
                child: const Text('更换'),
              ),
            ),
            const Divider(height: 28),
          ],
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(11),
            ],
            decoration: const InputDecoration(
              labelText: '手机号',
              hintText: '请输入 11 位手机号',
              prefixIcon: Icon(Icons.phone_android),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submitting ? null : _save,
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(hasBound ? '更换手机号' : '保存'),
          ),
        ],
      ),
    );
  }
}
