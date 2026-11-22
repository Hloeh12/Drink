-- ============================================================================
-- 打卡助手 · Supabase 数据库迁移
-- ============================================================================
-- 用途：为打卡助手 iOS App 创建多人云同步所需的数据库表、RLS 策略和存储桶。
--
-- 使用方法：
--   方式 1（推荐）：在 Supabase Dashboard → SQL Editor 中粘贴本文件并运行
--   方式 2：supabase db push（如果使用 Supabase CLI）
--
-- 前置条件：
--   1. 已创建 Supabase 项目
--   2. 已在 Authentication → Providers 中启用 Apple 登录
--      （填入 Apple Services ID / Key ID / Team ID / Private Key）
--   3. 项目 URL 和 anon key 填入 iOS 代码 SupabaseConfig
-- ============================================================================

-- ============================================================================
-- 1. profiles 表（用户资料，注册时自动创建）
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.profiles (
    id          UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    email       TEXT,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 注册时自动创建 profile 的触发器
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email)
    VALUES (NEW.id, NEW.email);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- ============================================================================
-- 2. water_intake 表（喝水记录）
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.water_intake (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id     UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    date        DATE NOT NULL,
    amount_ml   INTEGER NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, date)
);

CREATE INDEX IF NOT EXISTS idx_water_intake_user_date
    ON public.water_intake(user_id, date DESC);

-- ============================================================================
-- 3. weights 表（体重记录）
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.weights (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id     UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    date        DATE NOT NULL,
    weight      NUMERIC(6,1) NOT NULL,
    unit        TEXT DEFAULT 'jin',
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, date)
);

CREATE INDEX IF NOT EXISTS idx_weights_user_date
    ON public.weights(user_id, date DESC);

-- ============================================================================
-- 4. meals 表（餐食记录，含热量和照片）
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.meals (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id             UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    date                DATE NOT NULL,
    breakfast           TEXT DEFAULT '',
    lunch               TEXT DEFAULT '',
    dinner              TEXT DEFAULT '',
    snack               TEXT DEFAULT '',
    breakfast_calories  INTEGER DEFAULT 0,
    lunch_calories      INTEGER DEFAULT 0,
    dinner_calories     INTEGER DEFAULT 0,
    snack_calories      INTEGER DEFAULT 0,
    breakfast_photo     TEXT,
    lunch_photo         TEXT,
    dinner_photo        TEXT,
    snack_photo         TEXT,
    weight              TEXT,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, date)
);

CREATE INDEX IF NOT EXISTS idx_meals_user_date
    ON public.meals(user_id, date DESC);

-- ============================================================================
-- 5. user_settings 表（用户设置同步）
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.user_settings (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id     UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    key         TEXT NOT NULL,
    value       TEXT,
    updated_at  TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, key)
);

-- ============================================================================
-- 6. RLS 行级安全策略
-- ============================================================================
-- 每个用户只能访问自己的数据，确保多用户隔离
-- ============================================================================

-- profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "profiles_select_own" ON public.profiles;
CREATE POLICY "profiles_select_own" ON public.profiles
    FOR SELECT USING (auth.uid() = id);
DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;
CREATE POLICY "profiles_update_own" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);

-- water_intake
ALTER TABLE public.water_intake ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "water_intake_all_own" ON public.water_intake;
CREATE POLICY "water_intake_all_own" ON public.water_intake
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- weights
ALTER TABLE public.weights ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "weights_all_own" ON public.weights;
CREATE POLICY "weights_all_own" ON public.weights
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- meals
ALTER TABLE public.meals ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "meals_all_own" ON public.meals;
CREATE POLICY "meals_all_own" ON public.meals
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- user_settings
ALTER TABLE public.user_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "settings_all_own" ON public.user_settings;
CREATE POLICY "settings_all_own" ON public.user_settings
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ============================================================================
-- 7. 存储桶（餐食照片）
-- ============================================================================

INSERT INTO storage.buckets (id, name, public)
VALUES ('meals', 'meals', true)
ON CONFLICT (id) DO NOTHING;

-- 存储桶 RLS：用户只能管理自己的照片
DROP POLICY IF EXISTS "meals_bucket_insert_own" ON storage.objects;
CREATE POLICY "meals_bucket_insert_own" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'meals'
        AND auth.uid() = (storage.foldername(name))[1]::uuid
    );

DROP POLICY IF EXISTS "meals_bucket_read_public" ON storage.objects;
CREATE POLICY "meals_bucket_read_public" ON storage.objects
    FOR SELECT USING (bucket_id = 'meals');

DROP POLICY IF EXISTS "meals_bucket_delete_own" ON storage.objects;
CREATE POLICY "meals_bucket_delete_own" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'meals'
        AND auth.uid() = (storage.foldername(name))[1]::uuid
    );

-- ============================================================================
-- 8. updated_at 自动更新触发器
-- ============================================================================

CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_user_settings_updated ON public.user_settings;
CREATE TRIGGER trg_user_settings_updated
    BEFORE UPDATE ON public.user_settings
    FOR EACH ROW EXECUTE PROCEDURE public.update_updated_at();

-- ============================================================================
-- 完成
-- ============================================================================
-- 运行完成后：
--   1. 在 Authentication → Providers 中启用 Apple 并配置 OAuth
--   2. 将项目 URL 和 anon key 填入 iOS 代码中的 SupabaseConfig
--   3. 确保 Apple Developer Account 中的 Sign in with Apple 配置了
--      Return URLs: https://<project>.supabase.co/auth/v1/callback
-- ============================================================================
