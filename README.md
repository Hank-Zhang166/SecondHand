# 清华二手 SecondHand

面向清华大学在校学生的**校园二手物品交易平台**（Flutter Android 客户端）。
交易仅限**校内线下面对面**完成：不实现快递物流、不实现在线支付、不涉及资金流。

- 前端：Flutter 3.47（Dart ^3.13），Material 3 界面
- 后端：WorkBuddy Cloud Service（Serverless：Auth / Database / Storage），App 通过 REST API 直连
- 数据安全：PostgreSQL RLS（行级安全），用户只能读写自己的数据；商品公开可读、仅作者可写

---

## 一、功能清单

### 1. 注册登录
- 手机号（11 位，自动转 +86）或邮箱 + 短信/邮件验证码，**登录注册一体化**：新号码验证通过后自动创建账号
- 60 秒验证码倒计时；`is_user` 自动区分新老用户并给出提示
- 会话持久化（SharedPreferences），App 重启自动恢复；access token 过期自动 refresh；401 自动退出
- 《用户须知》弹窗（交易规则 + 防骗提示），需勾选同意才能继续

### 2. 首页 · 浏览检索
- 关键词模糊搜索（标题 / 描述，`ilike`），实时清空
- 11 个分类横向筛选 chips（数码电子 / 图书教材 / 文具 / 生活 / 运动 / 美妆 / 服装 / 宿舍神器 / 乐器 / 票券 / 其他）
- 双列瀑布信息流，卡片含封面图、标题、价格、交付地点、截止倒计时、状态徽章、“我发布的”角标
- 下拉刷新 + 滚动触底分页（每页 20 条）

### 3. 商品详情
- 多图轮播（指示点）+ 价格 + 标题 + 分类/地点/截止日期 chips
- 完整描述、发布相对时间
- 卖家信息卡（昵称、院系、清华邮箱认证标识）
- 校园交易安全提示卡

### 4. 发布商品
- 相册多选（最多 9 张，`imageQuality: 85` + 1400px 边长压缩）→ 上传云端 `runtime` 存储桶
- 标题（2-30 字）、描述（10-500 字）、价格（或“面议”）、分类
- 交易截止日期（DatePicker，限定明天起 90 天内）
- 交付地点：33 个清华校内常用地点 chips（紫荆公寓 / C楼 / 各食堂 / 图书馆 / 各教学楼 / 操场…）+“其他”自定义
- 发布前数据校验 + 本地内容安全过滤（违规词、站外付款引导词）

### 5. 下单与沟通（站内私信）
- 买家点「我想要」→ 写入 orders 意向 → 自动创建/复用会话 → 发送系统消息通知卖家 → 直达聊天页
- 卖家在意向管理页**接受 / 拒绝**：接受后商品自动标记「已预订」并通知买家；可标记「完成交易」
- 私信聊天：气泡对话、系统消息（居中灰条）、未读红点、打开会话自动已读
- 「消息」Tab 展示会话列表（对方昵称、商品上下文、最后消息、相对时间）；底部导航上方有未读汇总提示条（30s 轮询）

### 6. 个人中心
- 我的发布：状态筛选（在售/已预订/已完成/已下架），弹窗管理状态、重新上架、下架、删除
- 我的订单（买家视角）：意向列表、取消意向、联系卖家
- 我的收藏：云端同步的收藏夹（可取消）
- 浏览历史：本地记录（最多 100 条）、一键清空
- 编辑资料：头像上传、昵称、学号（9-10 位校验）、院系；清华邮箱认证标识
- 用户须知与防骗指南、退出登录

### 7. 商品状态机
`在售 → 已预订 → 已完成`，任一状态可下架 / 重新上架；首页过滤已下架（作者本人可见自己的）。

### 8. 校园场景与安全
- 交付地点限定校内常用地点（可自定义补充）
- 学生身份最简校验：清华邮箱（`@mails.tsinghua.edu.cn` / `@tsinghua.edu.cn`）认证标识 + 学号选填
- 图片压缩 + 类型/大小（≤8MB）校验
- 数据校验（手机号/邮箱/学号/价格/标题/描述/截止日期）
- 内容安全：违规词库 + 站外付款防诈引导词拦截
- 所有数据访问受 RLS 约束（详见 `docs/schema.sql`）

---

## 二、技术架构

```
┌─────────────────────────── Android APK (Flutter) ───────────────────────────┐
│ pages/     登录 首页 详情 发布 消息 聊天 我的发布 意向管理 订单 收藏 历史 我的  │
│ widgets/   商品卡片 状态徽章 云图(签名URL) 空状态                              │
│ services/  CloudClient(HTTP契约) Auth Product Order Chat Favorite History    │
│ models/    Product OrderIntent Conversation ChatMessage UserProfile Enums    │
│ state/     AppServices(共享单 CloudClient)                                    │
│ utils/     Validators ContentFilter Format                                    │
└────────────────────────────────────┬─────────────────────────────────────────┘
                                     │ HTTPS（PostgREST 风格 REST）
┌────────────────────────────────────▼─────────────────────────────────────────┐
│ WorkBuddy Cloud Service                                                      │
│  /.cloud/auth/v1/**        验证码/登录/注册/刷新/user/me                       │
│  /.cloud/database/rest/**  PostgreSQL（RLS 数据隔离）                         │
│  /.cloud/storage/**        runtime 桶：上传 /object/<bucket>/<path>            │
│                            签名下载 URL /object/sign/<bucket>                │
└──────────────────────────────────────────────────────────────────────────────┘
```

- 状态管理：Provider（`AuthService`/`HistoryStore` 为 ChangeNotifier）
- 图片加载：`cached_network_image`，存储路径 → 签名 URL（23h 内存缓存，按需批量换取）
- 无本地数据库依赖，云端为唯一数据源；浏览历史为纯本地

---

## 三、云端数据结构

7 张表，全部启用 RLS，DDL 见 [`docs/schema.sql`](docs/schema.sql)（幂等，可重复执行）。

| 表 | 说明 | 关键字段 | RLS 策略 |
|---|---|---|---|
| `profiles` | 用户资料 | owner_id(唯一) nickname avatar_path student_id department thu_email_verified | 仅本人读写 |
| `products` | 商品 | owner_id owner_name title description price category images[] deadline location status | 公开读（`status<>'off_shelf' OR 作者`），仅作者写 |
| `orders` | 购买意向 | product_id product_title buyer_id buyer_name seller_id status note | 买卖双方可见，买家创建、双方可更新 |
| `conversations` | 私信会话 | user_a user_b product_id product_title last_message last_message_at | 仅参与者可见 |
| `messages` | 私信消息 | conversation_id sender_id content kind read_at | 仅会话参与者（EXISTS 子查询） |
| `favorites` | 收藏 | owner_id product_id（唯一） | 仅本人 |
| `reports` | 举报 | owner_id target_type target_id reason status | 仅本人创建 |

- `owner_id` / `sender_id` 等由数据库 `DEFAULT auth.uid()` 自动填充，客户端不传
- 共 10 个索引（信息流排序、意向查询、消息查询、收藏唯一约束等）
- 商品状态：`on_sale` / `reserved` / `completed` / `off_shelf`
- 意向状态：`pending` / `accepted` / `rejected` / `completed` / `cancelled`

### 云端连接配置

`lib/config/cloud_config.dart`：

```dart
endpoint       = https://thu-secondhand.app.workbuddy.host
publishableKey = wbpk_Rlao24qmxVBqxkoexLCoMU_1X14KcczjPblWcTsaTXfbc54ez0xeEoc
storageBucket  = runtime
```

如需指向自己的云端环境，修改该文件即可（其余代码无硬编码）。

---

## 四、目录结构

```
SecondHand/
├── lib/
│   ├── main.dart                 入口：SharedPreferences + AppServices + Provider
│   ├── app.dart                  MaterialApp 主题、登录态守卫、底部导航框架
│   ├── config/cloud_config.dart 云端 endpoint / publishableKey / 路径常量
│   ├── state/app_state.dart      全局服务容器（共享单 CloudClient）
│   ├── services/                 云端 HTTP 客户端与各业务服务
│   │   ├── cloud_client.dart     认证 / PostgREST / 存储 三段 API 封装
│   │   ├── auth_service.dart     会话持久化、验证码登录、资料
│   │   ├── product_service.dart  信息流 / 搜索 / 发布 / 状态管理
│   │   ├── order_service.dart    购买意向
│   │   ├── chat_service.dart     会话 / 消息 / 已读 / 未读统计
│   │   ├── favorite_service.dart 收藏
│   │   ├── history_store.dart    本地浏览历史
│   │   └── image_url_cache.dart  签名 URL 缓存
│   ├── models/                   Product / OrderIntent / Conversation / ChatMessage / UserProfile / Enums
│   ├── pages/                    13 个页面
│   ├── widgets/                  ProductImage / ProductCard / StatusBadge / EmptyState
│   └── utils/                    Validators / ContentFilter / Format
├── android/                      Android 工程（com.thu.secondhand）
├── docs/schema.sql               云端 7 表 DDL + RLS + 索引
└── test/widget_test.dart         校验与内容安全单元测试（8 例）
```

---

## 五、运行与打包 APK

### 环境要求
- Flutter 3.47+（Dart SDK ^3.13）
- JDK 17
- Android SDK（platforms;android-35/36、build-tools;35.0.0）

### 安装依赖
```bash
flutter pub get
```

### 开发调试（连接真机或模拟器）
```bash
flutter run
```

### 代码检查与测试
```bash
flutter analyze     # 静态分析（当前 0 issue）
flutter test        # 单元测试（8 例全过）
```

### 打包可安装 APK
```bash
flutter build apk --release
```
产物：`build/app/outputs/flutter-apk/app-release.apk`（约 20MB，debug 签名，可直接安装）。

> 国内网络提示：`android/build.gradle.kts` 与 `settings.gradle.kts` 已配置阿里云 Maven 镜像，
> `gradle-wrapper.properties` 使用腾讯云 Gradle 发行包镜像，无需翻墙即可完成构建。
> 若使用模拟器测试，建议用 x86_64 镜像；`flutter build apk --split-per-abi` 可进一步减小包体。

### 首次使用
1. 安装 APK，输入手机号或清华邮箱获取验证码（新用户自动注册）
2. 建议「我的 → 编辑资料」补全昵称 / 学号 / 院系
3. 首页浏览或搜索 → 详情页「我想要」→ 站内私信协商时间地点 → 校内见面交易

---

## 六、设计取舍与已知限制

- **无支付 / 无物流**：刻意不为资金流提供任何通道，防诈引导贯穿登录须知、详情页、私信过滤
- **消息无推送**：云端无推送通道，未读采用打开 App 时 + 30s 轮询 + 打开会话置底已读
- **图片压缩在前端**：多选时按质量 85 / 1400px 压缩，未引入额外原生图片库
- **内容安全为客户端第一道防线**：本地词库拦截 + 举报表（`reports`）留痕，生产环境应叠加服务端审核
- **release 使用 debug 签名**：便于直接安装体验；正式发布请替换为自己的签名配置
