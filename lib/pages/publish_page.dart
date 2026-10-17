import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../services/cloud_client.dart';
import '../state/app_state.dart';
import '../utils/content_filter.dart';
import '../utils/validators.dart';

/// 发布商品页：图片（多选+压缩）、标题、描述、价格、分类、截止日期、交付地点
class PublishPage extends StatefulWidget {
  const PublishPage({super.key});

  @override
  State<PublishPage> createState() => _PublishPageState();
}

class _PublishPageState extends State<PublishPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _customLocationController = TextEditingController();

  final List<XFile> _images = [];
  String _category = '其他';
  String _location = CampusPlaces.list.first;
  bool _customLocation = false;
  bool _negotiable = false;
  DateTime _deadline =
      DateTime.now().add(const Duration(days: 7));
  bool _submitting = false;
  String _progressText = '';

  static const _maxImages = 9;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _customLocationController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final remain = _maxImages - _images.length;
    if (remain <= 0) {
      _toast('最多上传 $_maxImages 张图片');
      return;
    }
    try {
      final picker = ImagePicker();
      final picked = await picker.pickMultiImage(
        imageQuality: 85, // 压缩质量
        maxWidth: 1400,
        maxHeight: 1400,
      );
      if (picked.isEmpty) return;
      setState(() {
        _images.addAll(picked.take(remain));
      });
    } catch (_) {
      _toast('打开相册失败，请检查相册权限');
    }
  }

  void _removeImage(int i) {
    setState(() => _images.removeAt(i));
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 90)),
      helpText: '选择交易截止日期',
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  String? _validateLocation() {
    final v = _customLocation
        ? _customLocationController.text.trim()
        : _location;
    if (v.isEmpty) return '请填写交付地点';
    if (v.length > 30) return '地点名称过长';
    return null;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final services = context.read<AppServices>();
    final me = services.auth.userId;
    if (me == null) return;

    final title = _titleController.text.trim();
    final desc = _descController.text.trim();
    final location =
        _customLocation ? _customLocationController.text.trim() : _location;

    // 数据校验
    if (!Validators.isTitle(title)) {
      _toast('标题需 2-30 个字');
      return;
    }
    if (!Validators.isDescription(desc)) {
      _toast('描述需 10-500 个字');
      return;
    }
    if (!_negotiable && !Validators.isPrice(_priceController.text)) {
      _toast('请填写正确价格（0.01 - 999999），或选择「面议」');
      return;
    }
    if (!Validators.isDeadline(_deadline)) {
      _toast('截止日期需在明天起 90 天内');
      return;
    }
    final locErr = _validateLocation();
    if (locErr != null) {
      _toast(locErr);
      return;
    }

    // 内容安全
    final contentErr = ContentFilter.check('$title $desc');
    if (contentErr != null) {
      _toast(contentErr);
      return;
    }

    setState(() {
      _submitting = true;
      _progressText = _images.isEmpty ? '正在发布…' : '正在上传图片…';
    });

    try {
      // 1. 上传图片（已压缩）
      final paths = <String>[];
      for (var i = 0; i < _images.length; i++) {
        final f = _images[i];
        setState(() => _progressText = '正在上传图片 ${i + 1}/${_images.length}');
        final bytes = await f.readAsBytes();
        final imgErr = ContentFilter.checkImage(f.name, bytes.length);
        if (imgErr != null) throw CloudException(0, 'BAD_IMAGE', imgErr);
        final path =
            'products/$me/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final uploaded = await services.client.uploadBytes(path, bytes);
        paths.add(uploaded);
      }

      // 2. 写入商品数据
      setState(() => _progressText = '正在发布…');
      await services.products.publish(
        ownerId: me,
        ownerName: services.auth.profile?.displayName ?? '清华同学',
        title: title,
        description: desc,
        price: _negotiable ? null : double.parse(_priceController.text.trim()),
        category: _category,
        images: paths,
        deadline: _deadline,
        location: location,
      );

      if (!mounted) return;
      _toast('发布成功！');
      Navigator.of(context).pop();
    } on CloudException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('发布失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('发布商品')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            // 图片
            _sectionTitle('商品图片（最多 $_maxImages 张）'),
            const SizedBox(height: 8),
            _buildImagePicker(),
            const SizedBox(height: 16),

            // 标题
            _sectionTitle('标题'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              maxLength: 30,
              decoration: const InputDecoration(hintText: '例如：九成新 iPad 2021 款'),
              validator: (v) =>
                  Validators.isTitle(v ?? '') ? null : '标题需 2-30 个字',
            ),
            const SizedBox(height: 8),

            // 描述
            _sectionTitle('描述'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descController,
              maxLines: 5,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText: '成色、购买时间、使用情况、转让原因…',
                alignLabelWithHint: true,
              ),
              validator: (v) =>
                  Validators.isDescription(v ?? '') ? null : '描述需 10-500 个字',
            ),
            const SizedBox(height: 8),

            // 价格
            _sectionTitle('价格'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    enabled: !_negotiable,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '0.00',
                      prefixText: '¥ ',
                      fillColor: _negotiable
                          ? const Color(0xFFEEEEEE)
                          : const Color(0xFFF5F3EE),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilterChip(
                  label: const Text('面议'),
                  selected: _negotiable,
                  onSelected: (v) => setState(() => _negotiable = v),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 分类
            _sectionTitle('分类'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: Categories.list
                  .map((c) => ChoiceChip(
                        avatar: Icon(Categories.iconOf(c), size: 15),
                        label: Text(c),
                        selected: _category == c,
                        onSelected: (_) => setState(() => _category = c),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),

            // 截止日期
            _sectionTitle('交易截止日期'),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickDeadline,
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text(
                '${_deadline.year}-${_deadline.month.toString().padLeft(2, '0')}-${_deadline.day.toString().padLeft(2, '0')}',
              ),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                side: const BorderSide(color: Color(0xFFE0DCDC)),
              ),
            ),
            const SizedBox(height: 16),

            // 交付地点
            _sectionTitle('线下交付地点（校内）'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...CampusPlaces.list.take(12).map(
                      (p) => ChoiceChip(
                        label: Text(p),
                        selected: !_customLocation && _location == p,
                        onSelected: (_) => setState(() {
                          _customLocation = false;
                          _location = p;
                        }),
                      ),
                    ),
                ChoiceChip(
                  label: const Text('其他'),
                  selected: _customLocation,
                  onSelected: (v) => setState(() => _customLocation = v),
                ),
              ],
            ),
            if (_customLocation) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _customLocationController,
                decoration: const InputDecoration(hintText: '请输入校内具体地点'),
              ),
            ],
            const SizedBox(height: 24),

            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        Text(_progressText,
                            style: const TextStyle(fontSize: 13)),
                      ],
                    )
                  : const Text('发布'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(
        t,
        style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF424242)),
      );

  Widget _buildImagePicker() {
    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ..._images.asMap().entries.map((e) {
            final i = e.key;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(e.value.path),
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    right: 2,
                    top: 2,
                    child: GestureDetector(
                      onTap: () => _removeImage(i),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          GestureDetector(
            onTap: _pickImages,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3EE),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE0DCDC)),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined,
                      color: Color(0xFF9E9E9E), size: 26),
                  SizedBox(height: 4),
                  Text('添加图片',
                      style:
                          TextStyle(fontSize: 11, color: Color(0xFF9E9E9E))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
