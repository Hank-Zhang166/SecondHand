# SecondHand · Supabase 云端接入指南（邮箱 + 密码版）

> 当前版本使用「邮箱 + 密码」登录，**不需要验证码、不需要邮件确认**。
> 新用户由数据库触发器自动确认，注册成功即登录。
> 因此不再依赖邮件模板，也不受 Supabase 内置邮件限流影响。

---

## 为什么不用手机号 + 短信验证码

Supabase 自身不提供短信通道，手机号登录必须接入 Twilio / Vonage 等第三方
短信服务商：需要额外注册、绑卡、按条计费，试用期还只允许向已验证号码发送。
对本课程项目来说，它既不能免费开箱即用，也不会比邮箱 + 密码更省事。

邮箱 + 密码则完全在 Supabase 免费额度内，且**不发送任何邮件**。

## 第 1 步：创建 Supabase 项目

1. 打开 <https://supabase.com>，用 GitHub 账号登录。
2. **New project**：
   - Name：`thu-secondhand`
   - Region：**Singapore / Seoul**（离国内近即可）
   - Database Password：点 Generate 后保存（不要提交到仓库）
3. 等待项目就绪。

## 第 2 步：执行建表脚本

1. 进入 **SQL Editor → New query**。
2. 粘贴并执行 [`schema_supabase.sql`](schema_supabase.sql) 全文。
3. 脚本会完成：
   - 建 7 张业务表（profiles / products / orders / conversations / messages / favorites / reports）
   - 开启 RLS 并创建访问策略
   - 创建 `runtime` 存储桶与索引
   - **创建 `auto_confirm_email` 触发器**：新用户写入 `auth.users` 时自动确认，
     因此密码注册后可直接拿到会话，无需邮箱确认

> 如果之前已经建过表，脚本可重复执行；新增的触发器部分也会补齐。

## 第 3 步：复制项目地址与密钥

进入 **Project Settings → API**：

- **Project URL**：`https://xxxx.supabase.co`
- **Publishable key**：`sb_publishable_...`（等价于旧版 anon key，可安全放进 App）

> 不要使用 **Secret key**（`sb_secret_...`），它拥有完整权限，只能放服务端。

## 第 4 步：填入 App 配置

编辑 `lib/config/cloud_config.dart`：

```dart
static const String supabaseUrl = 'https://xxxx.supabase.co';
static const String supabaseAnonKey = 'sb_publishable_....';
```

## 第 5 步：打包运行

```bash
flutter pub get
flutter build apk --release
```

产物：`build/app/outputs/flutter-apk/app-release.apk`。

---

## 常见问题

- **提示「邮箱或密码不正确」**：确认邮箱拼写与密码；首次使用请先切到「注册」。
- **提示「该邮箱已注册」**：切换到「登录」即可。
- **注册后又回到登录页**：说明自动确认触发器没有生效。检查 SQL Editor 中
  `auto_confirm_email` 触发器是否创建成功，或重新执行一遍
  [`schema_supabase.sql`](schema_supabase.sql)。
- **App 启动提示「后端尚未配置」**：`cloud_config.dart` 里仍是占位符。
- **免费额度够不够**：FREE 档包含 50,000 月活、500MB 数据库、5GB 流量，
  课程项目完全够用；邮箱 + 密码登录不消耗邮件额度。
