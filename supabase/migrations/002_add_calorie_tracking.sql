-- Add calorie tracking to meals
ALTER TABLE meals ADD COLUMN IF NOT EXISTS calories INTEGER;

-- Add photo support
ALTER TABLE meals ADD COLUMN IF NOT EXISTS photo_url TEXT;

-- Add notes to meals
ALTER TABLE meals ADD COLUMN IF NOT EXISTS notes TEXT;

-- Update weights to support kg or jin
ALTER TABLE weights ADD COLUMN IF NOT EXISTS unit TEXT DEFAULT 'kg';

-- User preferences for units
ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS value_text TEXT;

-- RLS already set, no change needed

-- Function to calculate daily totals
CREATE OR REPLACE FUNCTION get_daily_total(user_id UUID, date_param DATE)
RETURNS TABLE (
    weight NUMERIC,
    calories INTEGER,
    water_ml INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE((SELECT weight FROM weights WHERE user_id = $1 AND date = $2 LIMIT 1), 0),
        COALESCE((SELECT SUM(calories) FROM meals WHERE user_id = $1 AND date = $2), 0),
        COALESCE((SELECT SUM(amount_ml) FROM water_intake WHERE user_id = $1 AND date = $2), 0);
END;
$$ LANGUAGE plpgsql;

