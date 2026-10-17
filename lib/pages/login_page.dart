import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/cloud_client.dart';
import '../state/app_state.dart';
import '../utils/validators.dart';

/// 登录 / 注册页：手机号或清华邮箱 + 验证码（一体化登录注册）
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  int _tab = 0; // 0 手机号 / 1 邮箱
  final _accountController = TextEditingController();
  final _codeController = TextEditingController();

  String? _verificationId;
  bool _isExistingUser = false;
  bool _codeSent = false;
  int _countdown = 0;
  Timer? _timer;
  bool _sending = false;
  bool _submitting = false;
  bool _agreed = false;

  @override
  void dispose() {
    _timer?.cancel();
    _accountController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  bool get _isEmail => _tab == 1;

  String get _account => _accountController.text.trim();

  String? _validateAccount() {
    final v = _account;
    if (v.isEmpty) return _isEmail ? '请输入邮箱' : '请输入手机号';
    if (_isEmail) {
      if (!Validators.isEmail(v)) return '邮箱格式不正确';
    } else if (!Validators.isPhone(v)) {
      return '请输入正确的 11 位手机号';
    }
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
      final challenge = await context.read<AppServices>().client.sendOtp(
            phone: _isEmail ? null : _account,
            email: _isEmail ? _account : null,
          );
      if (!mounted) return;
      setState(() {
        _verificationId = challenge.verificationId;
        _isExistingUser = challenge.isExistingUser;
        _codeSent = true;
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
      _toast('验证码已发送${_isExistingUser ? '，欢迎回来' : '，验证后将自动注册'}');
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
    if (_verificationId == null) {
      _toast('请先获取验证码');
      return;
    }
    setState(() => _submitting = true);
    try {
      await context.read<AuthService>().loginWithOtp(
            phoneOrEmail: _account,
            isEmail: _isEmail,
            verificationId: _verificationId!,
            isExistingUser: _isExistingUser,
            code: code,
          );
      // 登录成功后 _RootGate 会自动切换到主框架
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
                  style: TextStyle(fontSize: 13, color: Color(0xFF9E9E9E)),
                ),
                const SizedBox(height: 32),
                // 账号类型 Tab
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE7F1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      _tabButton('手机号', 0),
                      _tabButton('清华邮箱', 1),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _accountController,
                  keyboardType: _isEmail
                      ? TextInputType.emailAddress
                      : TextInputType.phone,
                  inputFormatters: [
                    if (!_isEmail)
                      FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(_isEmail ? 60 : 11),
                  ],
                  decoration: InputDecoration(
                    hintText: _isEmail ? '请输入清华邮箱' : '请输入 11 位手机号',
                    prefixIcon: Icon(_isEmail ? Icons.mail_outline : Icons.phone_android),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                if (_isEmail) ...[
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
                ],
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
                      : Text(_isExistingUser && _codeSent ? '登录' : '登录 / 注册'),
                ),
                const SizedBox(height: 14),
                Text(
                  _codeSent
                      ? (_isExistingUser
                          ? '该账号已注册，验证后直接登录'
                          : '首次使用，验证通过后将自动创建账号')
                      : '未注册的手机号/邮箱验证通过后会自动创建账号',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabButton(String label, int index) {
    final selected = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_tab == index) return;
          setState(() {
            _tab = index;
            _accountController.clear();
            _codeController.clear();
            _verificationId = null;
            _codeSent = false;
            _countdown = 0;
            _timer?.cancel();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: selected ? const Color(0xFF660874) : const Color(0xFF757575),
            ),
          ),
        ),
      ),
    );
  }
}
