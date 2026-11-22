-- Drink App - Supabase Database Schema
-- Initial migration for Supabase RLS setup
-- Run with: supabase db push or psql

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table (Supabase auth handles users)
-- Profiles for user metadata
CREATE TABLE IF NOT EXISTS profiles (
    id UUID REFERENCES auth.users(id) PRIMARY KEY,
    username TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Weights tracking
CREATE TABLE IF NOT EXISTS weights (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    date DATE NOT NULL,
    weight NUMERIC(5,2) NOT NULL, -- in kg or jin, e.g. 65.5
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, date)
);

-- Meals with photos and calories
CREATE TABLE IF NOT EXISTS meals (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    date DATE NOT NULL,
    meal_type TEXT CHECK (meal_type IN ('breakfast', 'lunch', 'dinner', 'snack')) NOT NULL,
    photo_url TEXT, -- Supabase Storage URL
    calories INTEGER,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, date, meal_type)
);

-- Water intake
CREATE TABLE IF NOT EXISTS water_intake (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    date DATE NOT NULL,
    amount_ml INTEGER NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, date)
);

-- User settings
CREATE TABLE IF NOT EXISTS user_settings (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    key TEXT NOT NULL,
    value TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, key)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_weights_user_date ON weights(user_id, date);
CREATE INDEX IF NOT EXISTS idx_meals_user_date ON meals(user_id, date);
CREATE INDEX IF NOT EXISTS idx_water_user_date ON water_intake(user_id, date);

-- RLS Policies
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own profile" ON profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);

ALTER TABLE weights ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can CRUD own weights" ON weights FOR ALL USING (auth.uid() = user_id);

ALTER TABLE meals ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can CRUD own meals" ON meals FOR ALL USING (auth.uid() = user_id);

ALTER TABLE water_intake ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can CRUD own water" ON water_intake FOR ALL USING (auth.uid() = user_id);

ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can CRUD own settings" ON user_settings FOR ALL USING (auth.uid() = user_id);

-- Functions for calculations
CREATE OR REPLACE FUNCTION get_user_daily_total(user_id UUID, table_name TEXT, date_param DATE)
RETURNS INTEGER AS $$
BEGIN
    EXECUTE format('SELECT COALESCE(SUM(amount_ml), 0) FROM %I WHERE user_id = $1 AND date = $2', table_name)
    USING user_id, date_param;
END;
$$ LANGUAGE plpgsql;

