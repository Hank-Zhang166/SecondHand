# SecondHand · Supabase 云端接入完整指南

> 本 App 采用「邮箱 + 6 位数字验证码」登录注册一体化流程。
> 登录失败 99% 是因为**邮件模板没有配置成 6 位验证码**——Supabase 默认发送的是
> 一封带「点击链接」的邮件，里面根本没有 6 位数字，App 自然无法校验。
> 按下面五步操作即可修复。

---

## 第 0 步：先理解为什么会登录失败（重要）

App 调用的是 `signInWithOtp` + `verifyOtp`（6 位数字验证码）。但 Supabase 的邮件模板
默认长这样：

```
Confirm your email address
Follow the link below to confirm this email address and finish signing up.
[Confirm email address]  ← 一个链接，不是 6 位数字！
```

用户收到的是**链接**，不是**验证码**，于是无论怎么输入都会提示「验证码不正确或已过期」。

解决办法只有一个：把邮件模板里的 `{{ .ConfirmationURL }}`（链接）换成
`{{ .Token }}`（6 位数字验证码）。这一步必须做，而且**新用户和已有用户各用一套模板**，
两套都要改：

| 场景 | Supabase 模板名 | 说明 |
|---|---|---|
| 新用户首次注册登录 | **Confirm signup** | 邮箱不存在时自动建号并发送 |
| 已有用户再次登录 | **Magic link** | 邮箱已存在时发送 |

---

## 第 1 步：创建 Supabase 项目

1. 打开 <https://supabase.com>，右上角用 GitHub 账号登录。
2. **New project**：
   - Name 填 `thu-secondhand`
   - Region 选 **Singapore（ap-southeast-1，离国内最近）**
   - Database Password 点 Generate 后**务必保存**（数据库密码，不要提交到仓库）
3. 等项目就绪（约 1–2 分钟）。

## 第 2 步：执行建表脚本

1. 进入 **SQL Editor → New query**。
2. 把仓库里的 [`docs/schema_supabase.sql`](schema_supabase.sql) **全文粘贴**进去。
3. 点 **Run**。脚本幂等，可重复执行；会建 7 张表 + RLS + 索引 + `runtime` 存储桶。

## 第 3 步：配置邮件模板为「6 位验证码」（登录修复的关键）

进入 **Authentication → Email Templates**，分别编辑下面两个模板。

### 3.1 「Confirm signup」模板

**Subject** 填：

```text
验证你的清华二手账号
```

**Message body**（HTML）粘贴：

```html
<div style="font-family:sans-serif;max-width:480px;margin:0 auto;padding:24px;background:#F7F5F0;border-radius:12px">
  <div style="text-align:center;margin-bottom:16px">
    <div style="display:inline-block;width:56px;height:56px;line-height:56px;background:#660874;color:#ffffff;border-radius:14px;font-size:28px">🎓</div>
    <h2 style="color:#660874;margin:8px 0 0">清华二手</h2>
    <p style="color:#9e9e9e;font-size:12px;margin:4px 0 0">校园二手物品 · 校内面对面交易</p>
  </div>
  <p style="font-size:14px;color:#333333">你的注册验证码是：</p>
  <p style="font-size:32px;font-weight:bold;color:#660874;letter-spacing:6px;text-align:center;margin:12px 0">{{ .Token }}</p>
  <p style="font-size:12px;color:#999999">验证码 10 分钟内有效，请勿转发给他人。如非本人操作，请忽略本邮件。</p>
</div>
```

### 3.2 「Magic link」模板

**Subject** 填：

```text
你的清华二手登录验证码
```

**Message body**（HTML）粘贴：

```html
<div style="font-family:sans-serif;max-width:480px;margin:0 auto;padding:24px;background:#F7F5F0;border-radius:12px">
  <div style="text-align:center;margin-bottom:16px">
    <div style="display:inline-block;width:56px;height:56px;line-height:56px;background:#660874;color:#ffffff;border-radius:14px;font-size:28px">🎓</div>
    <h2 style="color:#660874;margin:8px 0 0">清华二手</h2>
    <p style="color:#9e9e9e;font-size:12px;margin:4px 0 0">校园二手物品 · 校内面对面交易</p>
  </div>
  <p style="font-size:14px;color:#333333">你的登录验证码是：</p>
  <p style="font-size:32px;font-weight:bold;color:#660874;letter-spacing:6px;text-align:center;margin:12px 0">{{ .Token }}</p>
  <p style="font-size:12px;color:#999999">验证码 10 分钟内有效，请勿转发给他人。如非本人操作，请忽略本邮件。</p>
</div>
```

> 关键：模板里必须保留 `{{ .Token }}`（6 位数字验证码变量），
> 且**不要**再放 `{{ .ConfirmationURL }}`。保存后立即生效。

## 第 4 步：复制项目地址与密钥

1. 打开 **Project Settings → API**。
2. 复制两个值：
   - **Project URL**：形如 `https://xxxx.supabase.co`
   - **Publishable key**（可发布密钥，形如 `sb_publishable_...`）——
     就是新版 Supabase 里等价于旧 `anon public` key 的那个，**可安全放进 App**。

> 千万不要复制 **Secret key**（`sb_secret_...`）！它拥有完整权限，只能放服务端，
> 一旦写进客户端代码等于把整个数据库拱手送人。

## 第 5 步：填入 App 配置并重新打包

打开 `lib/config/cloud_config.dart`，把第 4 步的两个值填进去：

```dart
static const String supabaseUrl = 'https://xxxx.supabase.co';
static const String supabaseAnonKey = 'sb_publishable_....';
```

然后重新打包：

```bash
flutter pub get
flutter build apk --release
```

产物：`build/app/outputs/flutter-apk/app-release.apk`。

---

## 常见问题排查

- **登录页提示「验证码不正确或已过期」，但邮箱里是链接不是数字**：第 3 步的模板没配好，
  检查两个模板里是否都有 `{{ .Token }}` 且没有 `{{ .ConfirmationURL }}`。
- **新用户能注册但老用户收不到验证码（或反之）**：只改了其中一个模板，
  请把「Confirm signup」和「Magic link」两个都改。
- **验证码进了垃圾邮件**：把发件域名加入邮箱白名单，或在
  **Project Settings → Authentication → SMTP** 配置自有 SMTP（可选）。
- **App 启动提示「后端尚未配置」**：`cloud_config.dart` 里的 URL/key 还是占位符。
