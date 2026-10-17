import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/cloud_client.dart';
import '../state/app_state.dart';
import '../utils/validators.dart';

/// 绑定手机号：短信验证码验证通过后写入 profiles.phone。
/// 绑定成功后，手机号 + 短信验证码即可作为第二种登录方式。
class BindPhonePage extends StatefulWidget {
  const BindPhonePage({super.key});

  @override
  State<BindPhonePage> createState() => _BindPhonePageState();
}

class _BindPhonePageState extends State<BindPhonePage> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  String? _verificationId;
  int _countdown = 0;
  Timer? _timer;
  bool _sending = false;
  bool _submitting = false;

  String get _phone => _phoneController.text.trim();

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _sendCode() async {
    final phone = _phone;
    if (!Validators.isPhone(phone)) {
      _toast('请输入正确的 11 位手机号');
      return;
    }
    setState(() => _sending = true);
    try {
      final challenge =
          await context.read<AppServices>().client.sendOtp(phone: phone);
      if (!mounted) return;
      setState(() {
        _verificationId = challenge.verificationId;
        _countdown = 60;
      });
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          if (_countdown > 0) _countdown--;
          if (_countdown == 0) _timer?.cancel();
        });
      });
      _toast('验证码已发送');
    } on CloudException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('验证码发送失败，请检查网络后重试');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _bind() async {
    final phone = _phone;
    if (!Validators.isPhone(phone)) {
      _toast('请输入正确的 11 位手机号');
      return;
    }
    final code = _codeController.text.trim();
    if (code.length != 6) {
      _toast('请输入 6 位验证码');
      return;
    }
    if (_verificationId == null) {
      _toast('请先获取验证码');
      return;
    }
    setState(() => _submitting = true);
    // 先取好服务引用，避免异步间隙后使用 context
    final client = context.read<AppServices>().client;
    final auth = context.read<AuthService>();
    try {
      // 先验证码校验（token 仅用于证明验证码正确，不用于登录）
      await client.verifyOtp(
            verificationId: _verificationId!,
            code: code,
          );
      // 校验通过，写入 profiles
      await auth.updateProfile(phone: phone);
      if (!mounted) return;
      _toast('手机号绑定成功，下次可使用手机号登录');
      Navigator.pop(context);
    } on CloudException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('绑定失败，请稍后重试');
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
      appBar: AppBar(title: const Text('绑定手机号')),
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
                    '绑定后，手机号 + 短信验证码可作为第二种登录方式；'
                    '也可以在发布商品时更快联系。',
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
              leading: const Icon(Icons.phone_android, color: Color(0xFF660874)),
              title: const Text('当前绑定'),
              subtitle: Text(boundPhone),
              trailing: TextButton(
                onPressed: () {
                  setState(() {
                    _phoneController.text = boundPhone;
                    _verificationId = null;
                    _countdown = 0;
                  });
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: const InputDecoration(
                    labelText: '验证码',
                    hintText: '请输入 6 位验证码',
                    prefixIcon: Icon(Icons.sms_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 108,
                child: OutlinedButton(
                  onPressed: (_sending || _countdown > 0) ? null : _sendCode,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFF660874)),
                    foregroundColor: const Color(0xFF660874),
                  ),
                  child: Text(
                    _countdown > 0 ? '${_countdown}s 后重发' : '获取验证码',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submitting ? null : _bind,
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(hasBound ? '更换绑定' : '立即绑定'),
          ),
        ],
      ),
    );
  }
}
