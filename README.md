# 清华二手 SecondHand

面向清华大学在校学生的**校园二手物品交易平台**（Flutter Android 客户端）。
交易仅限**校内线下面对面**完成：不实现快递物流、不实现在线支付、不涉及资金流。

- 前端：Flutter 3.47（Dart ^3.13），Material 3 界面
- 后端：云服务（Serverless：Auth / Database / Storage），App 通过 REST API 直连
- 数据安全：PostgreSQL RLS（行级安全），用户只能读写自己的数据；商品公开可读、仅作者可写

---

## 一、功能清单

### 1. 注册登录
- **注册仅支持清华邮箱**：输入邮箱 + 验证码即可，**登录注册一体化**——未注册的邮箱验证通过后自动创建账号并直接进入应用，绝不出现“注册成功，请登录”或要求重复输入的中断
- 手机号 + 短信验证码作为**第二种登录方式**（登录页次级入口）：仅允许登录已注册账号，不创建新账号；需先用邮箱注册，并在「我的 → 绑定手机号」完成绑定
- 60 秒验证码倒计时；验证码错误、账号不存在/已存在等场景自动走兜底分支（signin ↔ signup 互为兜底）
- **30 天账号记忆**：同一设备登录成功后 30 天内无需再次登录；启动时自动恢复会话、静默刷新，并用服务端校验本地会话（失效则静默清除，不弹任何英文错误）
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
- **联系手机号**：保存到 profiles.phone（Supabase 免费档默认不含短信服务商，暂不提供手机号登录；手机号仅作为站内联系信息展示给买家）
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
│ 云服务（Serverless：Auth / Database / Storage）                                │
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

7 张表，全部启用 RLS，Supabase 版 DDL 见 [`docs/schema_supabase.sql`](docs/schema_supabase.sql)（在 Supabase 控制台 SQL Editor 一次性执行，幂等可重复）。

| 表 | 说明 | 关键字段 | RLS 策略 |
|---|---|---|---|
| `profiles` | 用户资料 | owner_id(唯一) nickname avatar_path student_id department thu_email_verified | 仅本人读写 |
| `products` | 商品 | owner_id owner_name title description price category images[] deadline location status | 公开读（`status<>'off_shelf' OR 作者`），仅作者写 |
| `orders` | 购买意向 | product_id product_title buyer_id buyer_name seller_id status note | 买卖双方可见，买家创建、双方可更新 |
| `conversations` | 私信会话 | user_a user_b product_id product_title last_message last_message_at | 仅参与者可见 |
| `messages` | 私信消息 | conversation_id sender_id content kind read_at | 仅会话参与者（EXISTS 子查询） |
| `favorites` | 收藏 | owner_id product_id（唯一） | 仅本人 |
| `reports` | 举报 | owner_id target_type target_id reason status | 仅本人创建 |

- `owner_id` / `sender_id` 等由数据库 `DEFAULT auth.uid()::text` 自动填充，客户端不传（Supabase 的 `auth.uid()` 返回 uuid，转 text 后存入 TEXT 列）
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
产物：`build/app/outputs/flutter-apk/app-release.apk`（约 52.8MB，通用包含全部 ABI，debug 签名可直接安装；
也可从 GitHub Releases 直接下载，或执行 `flutter build apk --split-per-abi` 得到单 ABI 约 15-20MB 的包）。

> 国内网络提示：`android/build.gradle.kts` 与 `settings.gradle.kts` 已配置阿里云 Maven 镜像，
> `gradle-wrapper.properties` 使用腾讯云 Gradle 发行包镜像，无需翻墙即可完成构建。
> 若使用模拟器测试，建议用 x86_64 镜像；`flutter build apk --split-per-abi` 可进一步减小包体。

### 首次使用
1. 安装 APK，输入清华邮箱获取验证码（未注册邮箱自动创建账号并直接进入）
2. 建议「我的 → 编辑资料」补全昵称 / 学号 / 院系；「我的 → 绑定手机号」绑定后可用手机号登录
3. 首页浏览或搜索 → 详情页「我想要」→ 站内私信协商时间地点 → 校内见面交易

### 启动流程与白屏排障（重要）

启动链路经过加固，任何一步失败都不会把用户留在白屏上：

1. `main()` 同步 `runApp`：不 await 任何插件/网络调用，保证首帧立即可见
2. `AppBootstrap` 先渲染品牌启动页（含当前步骤文案），再在首帧后初始化：
   - 本地存储（SharedPreferences，8 秒超时，失败自动降级为内存存储）
   - 登录态恢复（`auth.restore()`，10 秒超时，超时视为未登录继续进入）
   - 服务端校验本地会话（`user/me`，失效则静默清除，不弹错误）
3. `ErrorWidget.builder` 在 release 下也渲染**可见错误页**（默认空白是白屏根因之一）
4. `AndroidManifest.xml` 中 `EnableImpeller=false`：回退 Skia 渲染，规避部分机型 Impeller 白屏
5. 云端 HTTP 全部带 15 秒超时，弱网不会无限等待
6. 原生启动背景已改为清华紫 + 品牌 Logo（`drawable/launch_background.xml`），彻底消除白色闪屏

遇到异常启动时：白屏且无文字 → 多为原生渲染问题（确认已用带 `EnableImpeller=false` 的新包）；
卡在启动页某一步 → 按步骤文案定位（本地存储/网络）；显示错误页 → 页面上有具体异常信息，请截图反馈。

### 验证码邮件去除平台 Logo（邮箱模板定制）

验证码邮件由云服务的邮件通道下发，默认模板带有平台品牌 Logo。去除方法：
进入**云服务管理面板 → 应用「清华二手」→ 登录方式 / 用户认证 → 邮箱 → 邮件模板**，
将模板模式改为**自定义**，粘贴以下内容（必须保留 `{{.VerificationCode}}` 变量）：

```html
<div style="font-family:sans-serif;max-width:480px;margin:0 auto;padding:24px;background:#F7F5F0;border-radius:12px">
  <div style="text-align:center;margin-bottom:16px">
    <div style="display:inline-block;width:56px;height:56px;line-height:56px;background:#660874;color:#ffffff;border-radius:14px;font-size:28px">🎓</div>
    <h2 style="color:#660874;margin:8px 0 0">清华二手</h2>
    <p style="color:#9e9e9e;font-size:12px;margin:4px 0 0">校园二手物品 · 校内面对面交易</p>
  </div>
  <p style="font-size:14px;color:#333333">你的验证码是：</p>
  <p style="font-size:32px;font-weight:bold;color:#660874;letter-spacing:6px;text-align:center;margin:12px 0">{{.VerificationCode}}</p>
  <p style="font-size:12px;color:#999999">验证码 10 分钟内有效，请勿转发给他人。如非本人操作，请忽略本邮件。</p>
</div>
```

中文（registerSignInZhCN）与英文（registerSignInEnUS）模板可分别设置；保存后立即生效，
新发送的验证码邮件即为清华二手品牌样式，不再带任何平台 Logo。

---

## 六、设计取舍与已知限制

- **无支付 / 无物流**：刻意不为资金流提供任何通道，防诈引导贯穿登录须知、详情页、私信过滤
- **消息无推送**：云端无推送通道，未读采用打开 App 时 + 30s 轮询 + 打开会话置底已读
- **图片压缩在前端**：多选时按质量 85 / 1400px 压缩，未引入额外原生图片库
- **内容安全为客户端第一道防线**：本地词库拦截 + 举报表（`reports`）留痕，生产环境应叠加服务端审核
- **手机号登录是独立身份**：云端认证平台未开放「手机号绑定到已有账号」（provider bind）能力，
  因此手机号渠道只用于登录（不注册），绑定手机号用于个人资料展示；若需手机号直接登录同一账号，
  需要平台开放账号绑定能力或自建身份映射服务
- **30 天免登录依赖刷新令牌有效期**：本地按 30 天窗口保持会话并自动刷新；
  若云端刷新令牌先行失效，用户需重新登录（此时为静默登出，无错误弹窗）
- **release 使用 debug 签名**：便于直接安装体验；正式发布请替换为自己的签名配置
