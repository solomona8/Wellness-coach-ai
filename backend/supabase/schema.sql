-- Wellness Monitoring App Database Schema
-- Run this in Supabase SQL Editor

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- USER PROFILES
-- =====================================================
CREATE TABLE IF NOT EXISTS public.user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT,
    avatar_url TEXT,
    timezone TEXT DEFAULT 'UTC',
    preferred_podcast_time TIME DEFAULT '07:00',
    voice_preference TEXT DEFAULT 'default',
    notification_settings JSONB DEFAULT '{
        "podcast_ready": true,
        "daily_reminder": true,
        "weekly_summary": true,
        "achievement_alerts": true,
        "sound_healing_suggestions": true
    }',
    onboarding_completed BOOLEAN DEFAULT FALSE,
    health_goals JSONB DEFAULT '[]',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- HEALTH DATA (from HealthKit)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.health_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    metric_type TEXT NOT NULL CHECK (metric_type IN ('heart_rate', 'hrv', 'glucose', 'mindfulness', 'active_energy', 'exercise_time')),
    value NUMERIC NOT NULL,
    unit TEXT NOT NULL,
    metadata JSONB DEFAULT '{}',
    source TEXT DEFAULT 'healthkit',
    recorded_at TIMESTAMPTZ NOT NULL,
    synced_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, metric_type, recorded_at, source)
);

CREATE TABLE IF NOT EXISTS public.sleep_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    total_duration_minutes INTEGER,
    deep_sleep_minutes INTEGER,
    rem_sleep_minutes INTEGER,
    light_sleep_minutes INTEGER,
    awake_minutes INTEGER,
    sleep_score NUMERIC CHECK (sleep_score >= 0 AND sleep_score <= 100),
    source TEXT DEFAULT 'healthkit',
    raw_data JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.exercise_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    exercise_type TEXT NOT NULL CHECK (exercise_type IN ('vigorous', 'moderate', 'light', 'resistance', 'flexibility')),
    activity_name TEXT,
    duration_minutes INTEGER NOT NULL CHECK (duration_minutes > 0),
    calories_burned NUMERIC,
    heart_rate_avg NUMERIC,
    heart_rate_max NUMERIC,
    metadata JSONB DEFAULT '{}',
    started_at TIMESTAMPTZ NOT NULL,
    ended_at TIMESTAMPTZ,
    source TEXT DEFAULT 'healthkit',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- MANUAL TRACKING
-- =====================================================
CREATE TABLE IF NOT EXISTS public.diet_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    meal_type TEXT NOT NULL CHECK (meal_type IN ('breakfast', 'lunch', 'dinner', 'snack')),
    description TEXT,
    photo_url TEXT,
    estimated_calories NUMERIC,
    macros JSONB DEFAULT '{}',
    ingredients JSONB DEFAULT '[]',
    meal_quality_score INTEGER CHECK (meal_quality_score >= 1 AND meal_quality_score <= 5),
    logged_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.substance_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    substance_type TEXT NOT NULL CHECK (substance_type IN ('alcohol', 'caffeine', 'cannabis', 'prescription', 'supplement', 'nicotine', 'other')),
    substance_name TEXT,
    quantity NUMERIC NOT NULL,
    unit TEXT NOT NULL,
    notes TEXT,
    logged_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.mood_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    mood_score INTEGER NOT NULL CHECK (mood_score >= 1 AND mood_score <= 10),
    stress_level INTEGER CHECK (stress_level >= 1 AND stress_level <= 10),
    energy_level INTEGER CHECK (energy_level >= 1 AND energy_level <= 10),
    anxiety_level INTEGER CHECK (anxiety_level >= 1 AND anxiety_level <= 10),
    emotions JSONB DEFAULT '[]',
    notes TEXT,
    logged_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.negativity_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    exposure_type TEXT NOT NULL CHECK (exposure_type IN ('news', 'social_media', 'conflict', 'work_stress', 'relationship', 'other')),
    intensity INTEGER NOT NULL CHECK (intensity >= 1 AND intensity <= 10),
    duration_minutes INTEGER,
    description TEXT,
    coping_strategy_used TEXT,
    logged_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.gratitude_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    gratitude_items JSONB NOT NULL DEFAULT '[]',
    reflection TEXT,
    logged_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.meditation_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    duration_minutes INTEGER NOT NULL CHECK (duration_minutes > 0),
    meditation_type TEXT CHECK (meditation_type IN ('guided', 'unguided', 'breathing', 'body_scan', 'loving_kindness', 'visualization', 'other')),
    guide_name TEXT,
    pre_session_mood INTEGER CHECK (pre_session_mood >= 1 AND pre_session_mood <= 10),
    post_session_mood INTEGER CHECK (post_session_mood >= 1 AND post_session_mood <= 10),
    notes TEXT,
    session_source TEXT DEFAULT 'manual',
    started_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- AI ANALYSIS
-- =====================================================
CREATE TABLE IF NOT EXISTS public.daily_analyses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    analysis_date DATE NOT NULL,
    summary TEXT NOT NULL,
    key_insights JSONB DEFAULT '[]',
    action_items JSONB DEFAULT '[]',
    detected_patterns JSONB DEFAULT '[]',
    correlations JSONB DEFAULT '[]',
    wellness_scores JSONB DEFAULT '{}',
    recommendations JSONB DEFAULT '[]',
    concerns JSONB DEFAULT '[]',
    raw_claude_response JSONB DEFAULT '{}',
    generated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, analysis_date)
);

-- =====================================================
-- PODCASTS
-- =====================================================
CREATE TABLE IF NOT EXISTS public.daily_podcasts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    analysis_id UUID REFERENCES public.daily_analyses(id),
    podcast_date DATE NOT NULL,
    title TEXT,
    script TEXT NOT NULL,
    audio_url TEXT,
    duration_seconds INTEGER,
    voice_id TEXT,
    listened BOOLEAN DEFAULT FALSE,
    listened_at TIMESTAMPTZ,
    generated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, podcast_date)
);

-- =====================================================
-- SOUND HEALING
-- =====================================================
CREATE TABLE IF NOT EXISTS public.sound_healing_tracks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT,
    category TEXT NOT NULL CHECK (category IN ('binaural_beats', 'solfeggio', 'nature', 'tibetan_bowls', 'white_noise', 'custom')),
    frequency_hz NUMERIC,
    secondary_frequency_hz NUMERIC,
    target_state TEXT NOT NULL CHECK (target_state IN ('relaxation', 'focus', 'sleep', 'meditation', 'energy', 'stress_relief', 'healing')),
    duration_seconds INTEGER NOT NULL,
    audio_url TEXT NOT NULL,
    thumbnail_url TEXT,
    is_dynamic BOOLEAN DEFAULT FALSE,
    generation_params JSONB DEFAULT '{}',
    popularity_score NUMERIC DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.sound_healing_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    track_id UUID REFERENCES public.sound_healing_tracks(id),
    is_dynamic BOOLEAN DEFAULT FALSE,
    dynamic_params JSONB DEFAULT '{}',
    duration_listened_seconds INTEGER,
    pre_session_hrv NUMERIC,
    post_session_hrv NUMERIC,
    effectiveness_rating INTEGER CHECK (effectiveness_rating >= 1 AND effectiveness_rating <= 5),
    notes TEXT,
    started_at TIMESTAMPTZ NOT NULL,
    ended_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.sound_recommendations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    track_id UUID REFERENCES public.sound_healing_tracks(id),
    recommendation_reason TEXT,
    based_on_metrics JSONB DEFAULT '{}',
    priority INTEGER DEFAULT 1,
    recommended_at TIMESTAMPTZ DEFAULT NOW(),
    dismissed BOOLEAN DEFAULT FALSE,
    used BOOLEAN DEFAULT FALSE
);

-- =====================================================
-- SYNC (for iOS offline support)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.sync_status (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    device_id TEXT NOT NULL,
    last_sync_at TIMESTAMPTZ,
    pending_changes INTEGER DEFAULT 0,
    sync_errors JSONB DEFAULT '[]',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, device_id)
);

-- =====================================================
-- INDEXES
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_health_metrics_user_date ON public.health_metrics(user_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_health_metrics_type ON public.health_metrics(metric_type, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_sleep_sessions_user_date ON public.sleep_sessions(user_id, start_time DESC);
CREATE INDEX IF NOT EXISTS idx_exercise_sessions_user_date ON public.exercise_sessions(user_id, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_diet_entries_user_date ON public.diet_entries(user_id, logged_at DESC);
CREATE INDEX IF NOT EXISTS idx_substance_entries_user_date ON public.substance_entries(user_id, logged_at DESC);
CREATE INDEX IF NOT EXISTS idx_mood_entries_user_date ON public.mood_entries(user_id, logged_at DESC);
CREATE INDEX IF NOT EXISTS idx_negativity_entries_user_date ON public.negativity_entries(user_id, logged_at DESC);
CREATE INDEX IF NOT EXISTS idx_gratitude_entries_user_date ON public.gratitude_entries(user_id, logged_at DESC);
CREATE INDEX IF NOT EXISTS idx_meditation_sessions_user_date ON public.meditation_sessions(user_id, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_daily_analyses_user_date ON public.daily_analyses(user_id, analysis_date DESC);
CREATE INDEX IF NOT EXISTS idx_daily_podcasts_user_date ON public.daily_podcasts(user_id, podcast_date DESC);
CREATE INDEX IF NOT EXISTS idx_sound_tracks_category ON public.sound_healing_tracks(category, target_state);
CREATE INDEX IF NOT EXISTS idx_sound_sessions_user_date ON public.sound_healing_sessions(user_id, started_at DESC);

-- =====================================================
-- ROW LEVEL SECURITY
-- =====================================================

-- Enable RLS on all tables
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.health_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sleep_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exercise_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.diet_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.substance_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mood_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.negativity_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gratitude_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meditation_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_analyses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_podcasts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sound_healing_tracks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sound_healing_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sound_recommendations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sync_status ENABLE ROW LEVEL SECURITY;

-- User profiles policies
CREATE POLICY "Users can view own profile" ON public.user_profiles
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.user_profiles
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON public.user_profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

-- Generic user data policies (apply to all user data tables)
DO $$
DECLARE
    tbl TEXT;
BEGIN
    FOR tbl IN SELECT unnest(ARRAY[
        'health_metrics', 'sleep_sessions', 'exercise_sessions',
        'diet_entries', 'substance_entries', 'mood_entries',
        'negativity_entries', 'gratitude_entries', 'meditation_sessions',
        'daily_analyses', 'daily_podcasts', 'sound_healing_sessions',
        'sound_recommendations', 'sync_status'
    ])
    LOOP
        EXECUTE format('
            CREATE POLICY "Users can view own %I" ON public.%I
                FOR SELECT USING (auth.uid() = user_id);

            CREATE POLICY "Users can insert own %I" ON public.%I
                FOR INSERT WITH CHECK (auth.uid() = user_id);

            CREATE POLICY "Users can update own %I" ON public.%I
                FOR UPDATE USING (auth.uid() = user_id);

            CREATE POLICY "Users can delete own %I" ON public.%I
                FOR DELETE USING (auth.uid() = user_id);
        ', tbl, tbl, tbl, tbl, tbl, tbl, tbl, tbl);
    END LOOP;
END $$;

-- Sound healing tracks are public read
CREATE POLICY "Anyone can view sound tracks" ON public.sound_healing_tracks
    FOR SELECT USING (true);

-- Service role policies for backend operations
CREATE POLICY "Service role full access to health_metrics" ON public.health_metrics
    FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

CREATE POLICY "Service role full access to daily_analyses" ON public.daily_analyses
    FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

CREATE POLICY "Service role full access to daily_podcasts" ON public.daily_podcasts
    FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

-- =====================================================
-- TRIGGERS
-- =====================================================

-- Auto-create user profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.user_profiles (id)
    VALUES (NEW.id)
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- Update timestamp trigger
CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_user_profiles_updated_at
    BEFORE UPDATE ON public.user_profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at();

-- =====================================================
-- SEED DATA: Sound Healing Tracks
-- =====================================================
INSERT INTO public.sound_healing_tracks (title, description, category, frequency_hz, secondary_frequency_hz, target_state, duration_seconds, audio_url) VALUES
    ('Delta Sleep', 'Deep delta waves for restorative sleep', 'binaural_beats', 200, 202, 'sleep', 3600, 'https://storage.example.com/tracks/delta_sleep.mp3'),
    ('Alpha Relaxation', 'Gentle alpha waves for calm relaxation', 'binaural_beats', 200, 210, 'relaxation', 1800, 'https://storage.example.com/tracks/alpha_relax.mp3'),
    ('Beta Focus', 'Beta waves for enhanced concentration', 'binaural_beats', 200, 214, 'focus', 2700, 'https://storage.example.com/tracks/beta_focus.mp3'),
    ('Theta Meditation', 'Theta waves for deep meditation', 'binaural_beats', 200, 206, 'meditation', 2400, 'https://storage.example.com/tracks/theta_med.mp3'),
    ('396 Hz Liberation', 'Solfeggio frequency for releasing fear', 'solfeggio', 396, NULL, 'stress_relief', 1800, 'https://storage.example.com/tracks/396hz.mp3'),
    ('528 Hz Transformation', 'The love frequency for healing', 'solfeggio', 528, NULL, 'healing', 2400, 'https://storage.example.com/tracks/528hz.mp3'),
    ('639 Hz Connection', 'Frequency for harmonious relationships', 'solfeggio', 639, NULL, 'relaxation', 1800, 'https://storage.example.com/tracks/639hz.mp3'),
    ('852 Hz Intuition', 'Awakening inner strength', 'solfeggio', 852, NULL, 'meditation', 2100, 'https://storage.example.com/tracks/852hz.mp3'),
    ('Rain Forest', 'Natural rainforest ambience', 'nature', NULL, NULL, 'relaxation', 3600, 'https://storage.example.com/tracks/rainforest.mp3'),
    ('Ocean Waves', 'Calming ocean sounds', 'nature', NULL, NULL, 'sleep', 7200, 'https://storage.example.com/tracks/ocean.mp3'),
    ('Mountain Stream', 'Gentle flowing water', 'nature', NULL, NULL, 'focus', 3600, 'https://storage.example.com/tracks/stream.mp3'),
    ('Tibetan Singing Bowls', 'Traditional healing bowl sounds', 'tibetan_bowls', 432, NULL, 'meditation', 2400, 'https://storage.example.com/tracks/tibetan_bowls.mp3'),
    ('Crystal Bowls Healing', 'Crystal singing bowl harmonics', 'tibetan_bowls', 440, NULL, 'healing', 1800, 'https://storage.example.com/tracks/crystal_bowls.mp3'),
    ('Pink Noise Sleep', 'Balanced pink noise for sleep', 'white_noise', NULL, NULL, 'sleep', 28800, 'https://storage.example.com/tracks/pink_noise.mp3'),
    ('Brown Noise Focus', 'Deep brown noise for concentration', 'white_noise', NULL, NULL, 'focus', 14400, 'https://storage.example.com/tracks/brown_noise.mp3')
ON CONFLICT DO NOTHING;

-- Grant permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated;
