import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/order_intent.dart';
import '../models/product.dart';
import '../models/user_profile.dart';
import '../services/cloud_client.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/empty_state.dart';
import '../widgets/product_image.dart';
import 'chat_page.dart';
import 'product_intents_page.dart';

/// 商品详情页：图片、信息、卖家、收藏、购买意向、卖家状态管理
class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({super.key, required this.productId});

  final int productId;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  Product? _product;
  UserProfile? _sellerProfile;
  bool _loading = true;
  bool _favorited = false;
  OrderIntent? _myIntent; // 买家视角：我的意向
  List<OrderIntent> _received = const []; // 卖家视角：收到的意向
  int _currentImage = 0;
  final _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final services = context.read<AppServices>();
    final me = services.auth.userId;
    setState(() => _loading = true);
    try {
      final p = await services.products.detail(widget.productId);
      if (!mounted) return;
      if (p == null) {
        setState(() => _loading = false);
        return;
      }
      if (p.images.isNotEmpty) {
        await services.imageUrls.warm(p.images.toSet().toList());
      }
      // 记录浏览历史
      services.history.add(p.id);
      // 并行加载卖家资料 / 收藏状态 / 意向
      final isMine = p.isMine(me);
      final results = await Future.wait([
        _loadSellerProfile(p.ownerId),
        me == null
            ? Future.value(false)
            : services.favorites.isFavorited(me, p.id),
        if (isMine)
          services.orders.receivedIntents(p.ownerId, productId: p.id)
        else if (me != null)
          services.orders.activeIntentFor(productId: p.id, buyerId: me)
        else
          Future.value(null),
      ]);
      if (!mounted) return;
      setState(() {
        _product = p;
        _sellerProfile = results[0] as UserProfile?;
        _favorited = results[1] as bool;
        if (isMine) {
          _received = (results[2] as List<OrderIntent>?) ?? const [];
        } else {
          _myIntent = results[2] as OrderIntent?;
        }
        _loading = false;
      });
    } on CloudException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<UserProfile?> _loadSellerProfile(String ownerId) async {
    try {
      final row = await context.read<AppServices>().client.selectSingle(
            'profiles',
            filters: {'owner_id': 'eq.$ownerId'},
          );
      return row == null ? null : UserProfile.fromJson(row);
    } catch (_) {
      return null;
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _toggleFavorite() async {
    final services = context.read<AppServices>();
    final me = services.auth.userId;
    final p = _product;
    if (me == null || p == null) return;
    try {
      final now = await services.favorites.toggle(me, p.id);
      if (!mounted) return;
      setState(() => _favorited = now);
      _toast(now ? '已收藏' : '已取消收藏');
    } on CloudException catch (e) {
      _toast(e.message);
    }
  }

  /// 买家提交购买意向 -> 自动建立私信会话并通知卖家
  Future<void> _submitIntent() async {
    final services = context.read<AppServices>();
    final me = services.auth.userId;
    final p = _product;
    if (me == null || p == null) return;
    if (_myIntent != null) {
      _toast('你已提交过购买意向，请在「我的-我的订单」中查看进度');
      return;
    }
    final buyerName = services.auth.profile?.displayName ?? '同学';
    try {
      await services.orders.createIntent(
        productId: p.id,
        productTitle: p.title,
        buyerId: me,
        buyerName: buyerName,
        sellerId: p.ownerId,
      );
      final conversation = await services.chat.findOrCreateConversation(
        meId: me,
        peerId: p.ownerId,
        productId: p.id,
        productTitle: p.title,
      );
      await services.chat.sendSystem(
        conversationId: conversation.id,
        content: '买家提交了购买意向，请与买家协商交易时间与地点',
      );
      if (!mounted) return;
      _toast('已提交购买意向，快去和卖家私信吧');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChatPage(
            conversationId: conversation.id,
            peerName: p.ownerName,
            productTitle: p.title,
          ),
        ),
      );
    } on CloudException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('提交失败，请稍后重试');
    }
  }

  /// 卖家管理商品状态
  Future<void> _updateStatus(ProductStatus status) async {
    final p = _product;
    if (p == null) return;
    try {
      await context.read<AppServices>().products.updateStatus(p.id, status);
      if (!mounted) return;
      setState(() {
        _product = Product(
          id: p.id,
          ownerId: p.ownerId,
          ownerName: p.ownerName,
          title: p.title,
          description: p.description,
          price: p.price,
          category: p.category,
          images: p.images,
          deadline: p.deadline,
          location: p.location,
          status: status,
          createdAt: p.createdAt,
        );
      });
      _toast('已更新为「${status.label}」');
    } on CloudException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _chatWithBuyer(OrderIntent intent) async {
    final services = context.read<AppServices>();
    final me = services.auth.userId;
    final p = _product;
    if (me == null || p == null) return;
    try {
      final conversation = await services.chat.findOrCreateConversation(
        meId: me,
        peerId: intent.buyerId,
        productId: p.id,
        productTitle: p.title,
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatPage(
            conversationId: conversation.id,
            peerName: intent.buyerName,
            productTitle: p.title,
          ),
        ),
      );
    } on CloudException catch (e) {
      _toast(e.message);
    }
  }

  void _showSellerMenu() {
    final p = _product;
    if (p == null) return;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('查看购买意向'),
              trailing: _received.isNotEmpty
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8641C),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${_received.length}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12)),
                    )
                  : null,
              onTap: () {
                Navigator.pop(context);
                _openIntents();
              },
            ),
            if (p.status == ProductStatus.onSale)
              ListTile(
                leading: const Icon(Icons.bookmark_border),
                title: const Text('标记为「已预订」'),
                onTap: () {
                  Navigator.pop(context);
                  _updateStatus(ProductStatus.reserved);
                },
              ),
            if (p.status != ProductStatus.completed)
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: const Text('标记为「已完成」'),
                onTap: () {
                  Navigator.pop(context);
                  _updateStatus(ProductStatus.completed);
                },
              ),
            if (p.status == ProductStatus.offShelf ||
                p.status == ProductStatus.completed ||
                p.status == ProductStatus.reserved)
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('重新上架'),
                onTap: () {
                  Navigator.pop(context);
                  _updateStatus(ProductStatus.onSale);
                },
              ),
            if (p.status != ProductStatus.offShelf)
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('下架商品'),
                onTap: () {
                  Navigator.pop(context);
                  _updateStatus(ProductStatus.offShelf);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _openIntents() {
    final p = _product;
    if (p == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductIntentsPage(
          productId: p.id,
          productTitle: p.title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    final me = services.auth.userId;
    if (_loading && _product == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final p = _product;
    if (p == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(icon: Icons.error_outline, text: '商品不存在或已删除'),
      );
    }
    final isMine = p.isMine(me);
    final acceptedIntent = _received
        .where((e) => e.status == OrderStatus.accepted)
        .firstOrNull;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => _loadAll(),
        child: CustomScrollView(
          slivers: [
            // 图片轮播
            SliverAppBar(
              expandedHeight: 320,
              pinned: true,
              automaticallyImplyLeading: true,
              flexibleSpace: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: p.images.isEmpty ? 1 : p.images.length,
                    onPageChanged: (i) => setState(() => _currentImage = i),
                    itemBuilder: (_, i) {
                      if (p.images.isEmpty) {
                        return Container(
                          color: const Color(0xFFF5F0E8),
                          child: const Center(
                            child: Icon(Icons.image_outlined,
                                size: 48, color: Color(0xFFC9BFA8)),
                          ),
                        );
                      }
                      return ProductImage(
                        p.images[i],
                        fit: BoxFit.cover,
                        radius: 0,
                      );
                    },
                  ),
                  if (p.images.length > 1)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 10,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          p.images.length,
                          (i) => Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentImage == i
                                  ? Colors.white
                                  : Colors.white54,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SliverList(
              delegate: SliverChildListDelegate.fixed([
                // 价格与标题
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            p.priceText,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE8641C),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${Format.relative(p.createdAt)}发布',
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF9E9E9E)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        p.title,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _infoChip(Icons.category_outlined, p.category),
                          _infoChip(Icons.place_outlined,
                              p.location.isEmpty ? '校内' : p.location),
                          _infoChip(
                            p.expired
                                ? Icons.event_busy_outlined
                                : Icons.event_outlined,
                            '截止 ${Format.date(p.deadline)}',
                            highlight: p.expired,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // 商品描述
                Container(
                  color: Colors.white,
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('商品描述',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(
                        p.description,
                        style: const TextStyle(
                            fontSize: 14, height: 1.6, color: Color(0xFF424242)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // 卖家信息
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFFF3E5F5),
                        child: Text(
                          (_sellerProfile?.displayName ?? p.ownerName)
                              .substring(0, 1),
                          style: const TextStyle(
                              color: Color(0xFF660874),
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  isMine
                                      ? '${_sellerProfile?.displayName ?? p.ownerName}（我）'
                                      : (_sellerProfile?.displayName ??
                                          p.ownerName),
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500),
                                ),
                                if (_sellerProfile?.thuEmailVerified == true)
                                  Container(
                                    margin: const EdgeInsets.only(left: 6),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3E5F5),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('清华认证',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFF660874))),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _sellerProfile?.department.isNotEmpty == true
                                  ? _sellerProfile!.department
                                  : '清华同学',
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFF9E9E9E)),
                            ),
                          ],
                        ),
                      ),
                      if (!isMine)
                        TextButton(
                          onPressed: () {
                            if (acceptedIntent != null) {
                              _chatWithBuyer(acceptedIntent);
                            } else {
                              _toast('提交购买意向后即可与卖家私信');
                            }
                          },
                          child: const Text('联系TA'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // 安全提示
                Container(
                  color: const Color(0xFFFFF8E1),
                  padding: const EdgeInsets.all(12),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.shield_outlined,
                          size: 16, color: Color(0xFFF9A825)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '平台不提供支付与快递服务。请在校内公共场所当面交付、'
                          '当面确认商品，请勿脱离平台私下转账付款。',
                          style: TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: Color(0xFF8D6E63)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ]),
            ),
          ],
        ),
      ),
      // 底部操作栏
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
          ),
          child: isMine
              ? Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showSellerMenu,
                        icon: const Icon(Icons.settings_outlined, size: 18),
                        label: const Text('管理状态'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _openIntents,
                        icon: const Icon(Icons.people_outline, size: 18),
                        label: Text(
                          _received.isNotEmpty
                              ? '购买意向 (${_received.length})'
                              : '购买意向',
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    IconButton(
                      onPressed: _toggleFavorite,
                      icon: Icon(
                        _favorited ? Icons.star : Icons.star_border,
                        color: _favorited
                            ? const Color(0xFFE8641C)
                            : const Color(0xFF757575),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: _submitIntent,
                        child: Text(_myIntent == null
                            ? '我想要'
                            : _myIntent!.status == OrderStatus.pending
                                ? '意向待卖家确认'
                                : _myIntent!.status == OrderStatus.accepted
                                    ? '联系卖家'
                                    : '我想要'),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: highlight
            ? const Color(0xFFFFEBEE)
            : const Color(0xFFF5F3EE),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 13,
              color: highlight
                  ? const Color(0xFFB71C1C)
                  : const Color(0xFF757575)),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: highlight
                  ? const Color(0xFFB71C1C)
                  : const Color(0xFF616161),
            ),
          ),
        ],
      ),
    );
  }
}
