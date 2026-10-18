-- SecondHand（清华二手）Supabase 数据结构
-- 在 Supabase 控制台 SQL Editor 中一次性执行（幂等可重复执行）
-- 执行路径：Supabase 控制台 → SQL Editor → New query → 粘贴本文件全部内容 → Run

-- SecondHand（清华二手）云端数据结构
-- 在云数据库执行，幂等可重复执行

DO $$
BEGIN
  -- ========== profiles 用户资料 ==========
  CREATE TABLE IF NOT EXISTS public.profiles (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    owner_id TEXT NOT NULL DEFAULT auth.uid()::text UNIQUE,
    owner_name TEXT,
    nickname TEXT,
    avatar_path TEXT,
    student_id TEXT,
    department TEXT,
    phone TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
  );
  ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone TEXT;

  -- ========== products 二手商品 ==========
  CREATE TABLE IF NOT EXISTS public.products (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    owner_id TEXT NOT NULL DEFAULT auth.uid()::text,
    owner_name TEXT,
    title TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    price NUMERIC(10,2),
    category TEXT NOT NULL,
    images TEXT[] NOT NULL DEFAULT '{}',
    deadline DATE,
    location TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL DEFAULT 'on_sale',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
  );

  -- ========== orders 购买意向 ==========
  CREATE TABLE IF NOT EXISTS public.orders (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id BIGINT NOT NULL,
    product_title TEXT NOT NULL DEFAULT '',
    buyer_id TEXT NOT NULL DEFAULT auth.uid()::text,
    buyer_name TEXT,
    seller_id TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    note TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
  );

  -- ========== conversations 私信会话 ==========
  CREATE TABLE IF NOT EXISTS public.conversations (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id BIGINT,
    product_title TEXT,
    user_a TEXT NOT NULL,
    user_b TEXT NOT NULL,
    last_message TEXT NOT NULL DEFAULT '',
    last_message_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
  );

  -- ========== messages 私信消息 ==========
  CREATE TABLE IF NOT EXISTS public.messages (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    conversation_id BIGINT NOT NULL,
    sender_id TEXT NOT NULL DEFAULT auth.uid()::text,
    content TEXT NOT NULL,
    kind TEXT NOT NULL DEFAULT 'text',
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
  );

  -- ========== favorites 收藏 ==========
  CREATE TABLE IF NOT EXISTS public.favorites (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    owner_id TEXT NOT NULL DEFAULT auth.uid()::text,
    product_id BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (owner_id, product_id)
  );

  -- ========== reports 举报 ==========
  CREATE TABLE IF NOT EXISTS public.reports (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    owner_id TEXT NOT NULL DEFAULT auth.uid()::text,
    target_type TEXT NOT NULL,
    target_id TEXT NOT NULL,
    reason TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
  );

  -- ========== 表级授权 ==========
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.profiles TO authenticated, anon;
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.products TO authenticated, anon;
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.orders TO authenticated, anon;
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.conversations TO authenticated, anon;
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.messages TO authenticated, anon;
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.favorites TO authenticated, anon;
  GRANT SELECT, INSERT ON TABLE public.reports TO authenticated, anon;

  -- ========== 启用 RLS ==========
  ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

  -- ========== profiles：公开读，仅本人写 ==========
  DROP POLICY IF EXISTS profiles_read_all ON public.profiles;
  CREATE POLICY profiles_read_all ON public.profiles FOR SELECT TO authenticated, anon USING (true);
  DROP POLICY IF EXISTS profiles_insert_own ON public.profiles;
  CREATE POLICY profiles_insert_own ON public.profiles FOR INSERT TO authenticated, anon WITH CHECK (owner_id = auth.uid()::text);
  DROP POLICY IF EXISTS profiles_update_own ON public.profiles;
  CREATE POLICY profiles_update_own ON public.profiles FOR UPDATE TO authenticated, anon USING (owner_id = auth.uid()::text) WITH CHECK (owner_id = auth.uid()::text);
  DROP POLICY IF EXISTS profiles_delete_own ON public.profiles;
  CREATE POLICY profiles_delete_own ON public.profiles FOR DELETE TO authenticated, anon USING (owner_id = auth.uid()::text);

  -- ========== products：公开读（下架仅本人可见），仅作者写 ==========
  DROP POLICY IF EXISTS products_read ON public.products;
  CREATE POLICY products_read ON public.products FOR SELECT TO authenticated, anon USING (status <> 'off_shelf' OR owner_id = auth.uid()::text);
  DROP POLICY IF EXISTS products_insert_own ON public.products;
  CREATE POLICY products_insert_own ON public.products FOR INSERT TO authenticated, anon WITH CHECK (owner_id = auth.uid()::text);
  DROP POLICY IF EXISTS products_update_own ON public.products;
  CREATE POLICY products_update_own ON public.products FOR UPDATE TO authenticated, anon USING (owner_id = auth.uid()::text) WITH CHECK (owner_id = auth.uid()::text);
  DROP POLICY IF EXISTS products_delete_own ON public.products;
  CREATE POLICY products_delete_own ON public.products FOR DELETE TO authenticated, anon USING (owner_id = auth.uid()::text);

  -- ========== orders：买家或卖家可见，买家创建，双方更新，买家删除 ==========
  DROP POLICY IF EXISTS orders_read_party ON public.orders;
  CREATE POLICY orders_read_party ON public.orders FOR SELECT TO authenticated, anon USING (buyer_id = auth.uid()::text OR seller_id = auth.uid()::text);
  DROP POLICY IF EXISTS orders_insert_buyer ON public.orders;
  CREATE POLICY orders_insert_buyer ON public.orders FOR INSERT TO authenticated, anon WITH CHECK (buyer_id = auth.uid()::text);
  DROP POLICY IF EXISTS orders_update_party ON public.orders;
  CREATE POLICY orders_update_party ON public.orders FOR UPDATE TO authenticated, anon USING (buyer_id = auth.uid()::text OR seller_id = auth.uid()::text) WITH CHECK (buyer_id = auth.uid()::text OR seller_id = auth.uid()::text);
  DROP POLICY IF EXISTS orders_delete_buyer ON public.orders;
  CREATE POLICY orders_delete_buyer ON public.orders FOR DELETE TO authenticated, anon USING (buyer_id = auth.uid()::text);

  -- ========== conversations：仅参与者 ==========
  DROP POLICY IF EXISTS conversations_read_party ON public.conversations;
  CREATE POLICY conversations_read_party ON public.conversations FOR SELECT TO authenticated, anon USING (user_a = auth.uid()::text OR user_b = auth.uid()::text);
  DROP POLICY IF EXISTS conversations_insert_party ON public.conversations;
  CREATE POLICY conversations_insert_party ON public.conversations FOR INSERT TO authenticated, anon WITH CHECK (user_a = auth.uid()::text OR user_b = auth.uid()::text);
  DROP POLICY IF EXISTS conversations_update_party ON public.conversations;
  CREATE POLICY conversations_update_party ON public.conversations FOR UPDATE TO authenticated, anon USING (user_a = auth.uid()::text OR user_b = auth.uid()::text) WITH CHECK (user_a = auth.uid()::text OR user_b = auth.uid()::text);
  DROP POLICY IF EXISTS conversations_delete_party ON public.conversations;
  CREATE POLICY conversations_delete_party ON public.conversations FOR DELETE TO authenticated, anon USING (user_a = auth.uid()::text OR user_b = auth.uid()::text);

  -- ========== messages：仅会话参与者 ==========
  DROP POLICY IF EXISTS messages_read_party ON public.messages;
  CREATE POLICY messages_read_party ON public.messages FOR SELECT TO authenticated, anon USING (EXISTS (SELECT 1 FROM public.conversations c WHERE c.id = messages.conversation_id AND (c.user_a = auth.uid()::text OR c.user_b = auth.uid()::text)));
  DROP POLICY IF EXISTS messages_insert_party ON public.messages;
  CREATE POLICY messages_insert_party ON public.messages FOR INSERT TO authenticated, anon WITH CHECK (sender_id = auth.uid()::text AND EXISTS (SELECT 1 FROM public.conversations c WHERE c.id = messages.conversation_id AND (c.user_a = auth.uid()::text OR c.user_b = auth.uid()::text)));
  DROP POLICY IF EXISTS messages_update_party ON public.messages;
  CREATE POLICY messages_update_party ON public.messages FOR UPDATE TO authenticated, anon USING (EXISTS (SELECT 1 FROM public.conversations c WHERE c.id = messages.conversation_id AND (c.user_a = auth.uid()::text OR c.user_b = auth.uid()::text)));
  DROP POLICY IF EXISTS messages_delete_sender ON public.messages;
  CREATE POLICY messages_delete_sender ON public.messages FOR DELETE TO authenticated, anon USING (sender_id = auth.uid()::text);

  -- ========== favorites：仅本人 ==========
  DROP POLICY IF EXISTS favorites_read_own ON public.favorites;
  CREATE POLICY favorites_read_own ON public.favorites FOR SELECT TO authenticated, anon USING (owner_id = auth.uid()::text);
  DROP POLICY IF EXISTS favorites_insert_own ON public.favorites;
  CREATE POLICY favorites_insert_own ON public.favorites FOR INSERT TO authenticated, anon WITH CHECK (owner_id = auth.uid()::text);
  DROP POLICY IF EXISTS favorites_delete_own ON public.favorites;
  CREATE POLICY favorites_delete_own ON public.favorites FOR DELETE TO authenticated, anon USING (owner_id = auth.uid()::text);

  -- ========== reports：本人提交、本人可见 ==========
  DROP POLICY IF EXISTS reports_insert_own ON public.reports;
  CREATE POLICY reports_insert_own ON public.reports FOR INSERT TO authenticated, anon WITH CHECK (owner_id = auth.uid()::text);
  DROP POLICY IF EXISTS reports_read_own ON public.reports;
  CREATE POLICY reports_read_own ON public.reports FOR SELECT TO authenticated, anon USING (owner_id = auth.uid()::text);


-- ========== 文件存储桶（商品图片等） ==========
INSERT INTO storage.buckets (id, name, public)
VALUES ('runtime', 'runtime', true)
ON CONFLICT (id) DO NOTHING;

  -- ========== 索引 ==========
  CREATE INDEX IF NOT EXISTS idx_products_owner ON public.products (owner_id);
  CREATE INDEX IF NOT EXISTS idx_products_status_created ON public.products (status, created_at DESC);
  CREATE INDEX IF NOT EXISTS idx_products_category ON public.products (category);
  CREATE INDEX IF NOT EXISTS idx_orders_buyer ON public.orders (buyer_id);
  CREATE INDEX IF NOT EXISTS idx_orders_seller ON public.orders (seller_id);
  CREATE INDEX IF NOT EXISTS idx_orders_product ON public.orders (product_id);
  CREATE INDEX IF NOT EXISTS idx_conv_a ON public.conversations (user_a);
  CREATE INDEX IF NOT EXISTS idx_conv_b ON public.conversations (user_b);
  CREATE INDEX IF NOT EXISTS idx_messages_conv ON public.messages (conversation_id, created_at);
  CREATE INDEX IF NOT EXISTS idx_favorites_owner ON public.favorites (owner_id);

  -- ========== 表注释 ==========
  COMMENT ON TABLE public.profiles IS '用户资料：昵称/头像/学号/院系/联系手机号';
  COMMENT ON TABLE public.products IS '二手商品：标题/描述/价格/分类/图片/截止日期/交付地点/状态';
  COMMENT ON TABLE public.orders IS '购买意向：买家提交，卖家接受或拒绝';
  COMMENT ON TABLE public.conversations IS '私信会话（买卖双方，可关联商品）';
  COMMENT ON TABLE public.messages IS '私信消息';
  COMMENT ON TABLE public.favorites IS '商品收藏';
  COMMENT ON TABLE public.reports IS '内容安全举报';
END $$;

-- ========== 自动确认新用户（邮箱 + 密码登录的关键） ==========
-- Supabase 免费项目的 Auth 默认要求邮箱确认（Confirm email），
-- 这会导致密码注册后拿不到会话。本触发器在写入 auth.users 时
-- 直接把 email_confirmed_at 设为当前时间，效果等同于关闭
-- "Confirm email"：新用户注册即可登录，且不会发送确认邮件。
create or replace function public.auto_confirm_email()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.email_confirmed_at is null then
    new.email_confirmed_at := now();
  end if;
  return new;
end;
$$;

drop trigger if exists auto_confirm_email on auth.users;
create trigger auto_confirm_email
before insert on auth.users
for each row
execute function public.auto_confirm_email();
