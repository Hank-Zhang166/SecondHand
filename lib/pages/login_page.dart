import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/cloud_client.dart';
import '../utils/validators.dart';

/// 登录 / 注册页（邮箱 + 密码）
///
/// 不使用验证码与邮件确认：新用户由云端数据库触发器自动确认，
/// 注册成功后直接返回会话，因此不依赖任何邮件/短信通道。
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _register = false;
  bool _obscure = true;
  bool _submitting = false;
  bool _agreed = false;

  String get _email => _emailController.text.trim();
  String get _password => _passwordController.text;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validate() {
    if (_email.isEmpty) return '请输入邮箱';
    if (!Validators.isEmail(_email)) return '邮箱格式不正确';
    if (_password.length < 6) return '密码至少 6 位';
    return null;
  }

  Future<void> _submit() async {
    final err = _validate();
    if (err != null) {
      _toast(err);
      return;
    }
    if (!_agreed) {
      _toast('请先阅读并同意用户须知');
      return;
    }
    setState(() => _submitting = true);
    try {
      final auth = context.read<AuthService>();
      if (_register) {
        final user = await auth.signUp(email: _email, password: _password);
        if (user == null) {
          _toast('账号已创建，请切换到「登录」再试一次');
        }
      } else {
        await auth.signIn(email: _email, password: _password);
      }
      // 登录成功后 RootGate 自动切换到主框架
    } on CloudException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('操作失败，请稍后重试');
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
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: const Color(0xFF660874),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.school, size: 40, color: Colors.white),
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
                const SizedBox(height: 26),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(value: false, label: Text('登录')),
                    ButtonSegment<bool>(value: true, label: Text('注册')),
                  ],
                  selected: {_register},
                  onSelectionChanged: (s) => setState(() => _register = s.first),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  inputFormatters: [LengthLimitingTextInputFormatter(60)],
                  decoration: const InputDecoration(
                    hintText: '请输入邮箱',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscure,
                  inputFormatters: [LengthLimitingTextInputFormatter(64)],
                  decoration: InputDecoration(
                    hintText: '请输入密码（至少 6 位）',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Checkbox(
                      value: _agreed,
                      onChanged: (v) => setState(() => _agreed = v ?? false),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                      : Text(_register ? '注册并登录' : '登录'),
                ),
                const SizedBox(height: 14),
                Text(
                  _register
                      ? '注册成功会自动登录，无需邮箱验证码'
                      : '首次使用请先切换到「注册」创建账号',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
