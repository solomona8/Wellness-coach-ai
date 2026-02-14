-- Migration: Add resting_heart_rate to health_metrics CHECK constraint
-- and add tldr column to daily_podcasts
-- Run this in Supabase SQL Editor

-- =====================================================
-- 1. Fix health_metrics CHECK constraint
-- Add 'resting_heart_rate' as a valid metric_type
-- =====================================================
ALTER TABLE public.health_metrics
    DROP CONSTRAINT IF EXISTS health_metrics_metric_type_check;

ALTER TABLE public.health_metrics
    ADD CONSTRAINT health_metrics_metric_type_check
    CHECK (metric_type IN ('heart_rate', 'resting_heart_rate', 'hrv', 'glucose', 'mindfulness', 'active_energy', 'exercise_time'));

-- =====================================================
-- 2. Add tldr column to daily_podcasts
-- Used for podcast TLDR summary with action items
-- =====================================================
ALTER TABLE public.daily_podcasts
    ADD COLUMN IF NOT EXISTS tldr TEXT;
