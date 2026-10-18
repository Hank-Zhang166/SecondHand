import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/cloud_client.dart';
import '../state/app_state.dart';
import '../utils/validators.dart';

/// 登录 / 注册页
///
/// 仅支持清华邮箱注册（验证码一体化：输入邮箱 + 验证码即可，
/// 未注册邮箱自动创建账号，绝不再跳"注册成功请登录"）。
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _accountController = TextEditingController();
  final _codeController = TextEditingController();

  int _countdown = 0;
  Timer? _timer;
  bool _sending = false;
  bool _submitting = false;
  bool _agreed = false;

  String get _account => _accountController.text.trim();

  @override
  void dispose() {
    _timer?.cancel();
    _accountController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String? _validateAccount() {
    final v = _account;
    if (v.isEmpty) return '请输入邮箱';
    if (!Validators.isEmail(v)) return '邮箱格式不正确';
    return null;
  }

  Future<void> _sendCode() async {
    final err = _validateAccount();
    if (err != null) {
      _toast(err);
      return;
    }
    if (!_agreed) {
      _toast('请先阅读并同意用户须知');
      return;
    }
    setState(() => _sending = true);
    try {
      await context.read<AppServices>().client.sendOtp(email: _account);
      if (!mounted) return;
      setState(() => _countdown = 60);
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          if (_countdown > 0) _countdown--;
          if (_countdown == 0) _timer?.cancel();
        });
      });
      _toast('验证码已发送，请查收邮件');
    } on CloudException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('验证码发送失败，请检查网络后重试');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _submit() async {
    final accountErr = _validateAccount();
    if (accountErr != null) {
      _toast(accountErr);
      return;
    }
    if (!_agreed) {
      _toast('请先阅读并同意用户须知');
      return;
    }
    final code = _codeController.text.trim();
    if (code.length != 6) {
      _toast('请输入 6 位验证码');
      return;
    }
    setState(() => _submitting = true);
    try {
      final auth = context.read<AuthService>();
      // 邮箱：注册 + 登录一体化，验证通过直接进入应用
      await auth.loginWithOtp(email: _account, code: code);
      // 登录成功后 RootGate 会自动切换到主框架
    } on CloudException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('登录失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showNotice() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('用户须知'),
        content: const SingleChildScrollView(
          child: Text(
            '「清华二手」是面向清华大学在校学生的校园二手物品交易平台。\n\n'
            '一、本平台仅提供物品信息发布与站内沟通服务，不涉及任何支付与快递物流环节，'
            '所有交易均通过买卖双方校内线下面对面完成。\n\n'
            '二、请勿在站内或线下交易中诱导对方脱离平台付款；对要求先付款、交押金、'
            '扫码转账的行为请保持警惕，谨防诈骗。\n\n'
            '三、禁止发布违法违规、假冒伪劣、代考代写等违规商品与服务，'
            '平台设有内容审核与举报机制，违规账号将被限制使用。\n\n'
            '四、请如实填写商品信息，尊重他人隐私，友善沟通。',
            style: TextStyle(fontSize: 13, height: 1.6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 36),
                // 品牌区
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: const Color(0xFF660874),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.school,
                      size: 40, color: Colors.white),
                ),
                const SizedBox(height: 14),
                const Text(
                  '清华二手',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  '校园二手物品 · 校内面对面交易',
                  style: TextStyle(
                      fontSize: 13, color: Color(0xFF9E9E9E)),
                ),
                const SizedBox(height: 32),
                // 账号输入
                TextField(
                  controller: _accountController,
                  keyboardType: TextInputType.emailAddress,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(60),
                  ],
                  decoration: const InputDecoration(
                    hintText: '请输入清华邮箱',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '建议使用 @mails.tsinghua.edu.cn 学生邮箱，'
                    '可作为学生身份校验依据',
                    style:
                        TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)),
                  ),
                ),
                const SizedBox(height: 12),
                // 验证码
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
                          hintText: '请输入 6 位验证码',
                          prefixIcon: Icon(Icons.sms_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 108,
                      child: OutlinedButton(
                        onPressed:
                            (_sending || _countdown > 0) ? null : _sendCode,
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
                const SizedBox(height: 18),
                // 用户须知
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Checkbox(
                      value: _agreed,
                      onChanged: (v) =>
                          setState(() => _agreed = v ?? false),
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: _showNotice,
                        child: const Text.rich(
                          TextSpan(
                            text: '我已阅读并同意',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF757575)),
                            children: [
                              TextSpan(
                                text: '《用户须知》',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF660874),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              TextSpan(
                                text: '（仅限清华校内线下交易）',
                                style: TextStyle(
                                    fontSize: 12, color: Color(0xFF757575)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('登录 / 注册'),
                ),
                const SizedBox(height: 14),
                const Text(
                  '未注册的邮箱验证通过后将自动创建账号，无需单独注册',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
