import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/cloud_client.dart';
import '../state/app_state.dart';
import '../utils/validators.dart';
import '../widgets/product_image.dart';

/// 编辑资料：头像、昵称、学号、院系
class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _nicknameController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _departmentController = TextEditingController();

  String _avatarPath = '';
  bool _saving = false;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthService>();
    final profile = auth.profile;
    _nicknameController.text = profile?.nickname ?? '';
    _studentIdController.text = profile?.studentId ?? '';
    _departmentController.text = profile?.department ?? '';
    _avatarPath = profile?.avatarPath ?? '';
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _studentIdController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickAvatar() async {
    final services = context.read<AppServices>();
    final auth = context.read<AuthService>();
    final me = services.auth.userId;
    if (me == null) return;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 400,
        maxHeight: 400,
      );
      if (picked == null) return;
      if (!mounted) return;
      setState(() => _uploadingAvatar = true);
      final bytes = await picked.readAsBytes();
      final path = 'avatars/$me/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final uploaded = await services.client.uploadBytes(path, bytes);
      if (!mounted) return;
      setState(() => _avatarPath = uploaded);
      // 立即保存头像
      await auth.updateProfile(avatarPath: uploaded);
      if (mounted) _toast('头像已更新');
    } on CloudException catch (e) {
      if (mounted) _toast(e.message);
    } catch (_) {
      if (mounted) _toast('头像上传失败，请重试');
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _save() async {
    final nickname = _nicknameController.text.trim();
    final studentId = _studentIdController.text.trim();
    final department = _departmentController.text.trim();

    if (nickname.length < 2 || nickname.length > 20) {
      _toast('昵称需 2-20 个字');
      return;
    }
    if (studentId.isNotEmpty && !Validators.isStudentId(studentId)) {
      _toast('学号格式不正确（9-10 位数字）');
      return;
    }
    if (department.length > 30) {
      _toast('院系名称过长');
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<AuthService>().updateProfile(
            nickname: nickname,
            studentId: studentId,
            department: department,
          );
      if (!mounted) return;
      _toast('已保存');
      Navigator.of(context).pop();
    } on CloudException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('保存失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final email = auth.user?.email;
    final verified = auth.profile?.thuEmailVerified == true;

    return Scaffold(
      appBar: AppBar(title: const Text('编辑资料')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 头像
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: const Color(0xFFF3E5F5),
                  child: _avatarPath.isNotEmpty
                      ? ClipOval(
                          child: ProductImage(_avatarPath,
                              width: 80, height: 80, radius: 40),
                        )
                      : Text(
                          (_nicknameController.text.trim().isEmpty
                                  ? '同'
                                  : _nicknameController.text.trim())
                              .substring(0, 1),
                          style: const TextStyle(
                              fontSize: 28,
                              color: Color(0xFF660874),
                              fontWeight: FontWeight.bold),
                        ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: _uploadingAvatar ? null : _pickAvatar,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: Color(0xFF660874),
                        shape: BoxShape.circle,
                      ),
                      child: _uploadingAvatar
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.camera_alt,
                              size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 昵称
          const Text('昵称',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF616161))),
          const SizedBox(height: 6),
          TextField(
            controller: _nicknameController,
            maxLength: 20,
            decoration: const InputDecoration(hintText: '怎么称呼你？'),
          ),
          const SizedBox(height: 12),

          // 学号
          const Text('学号（选填，用于学生身份辅助校验）',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF616161))),
          const SizedBox(height: 6),
          TextField(
            controller: _studentIdController,
            keyboardType: TextInputType.number,
            maxLength: 10,
            decoration: const InputDecoration(hintText: '9-10 位学号'),
          ),
          const SizedBox(height: 12),

          // 院系
          const Text('院系（选填）',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF616161))),
          const SizedBox(height: 6),
          TextField(
            controller: _departmentController,
            maxLength: 30,
            decoration: const InputDecoration(hintText: '例如：计算机系'),
          ),
          const SizedBox(height: 16),

          // 邮箱（只读）
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3EE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.mail_outline,
                    size: 16, color: Color(0xFF9E9E9E)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    email ?? '未绑定邮箱',
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF616161)),
                  ),
                ),
                Text(
                  verified ? '已认证' : '非清华邮箱',
                  style: TextStyle(
                    fontSize: 11,
                    color: verified
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFF9E9E9E),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('保存'),
          ),
        ],
      ),
    );
  }
}
