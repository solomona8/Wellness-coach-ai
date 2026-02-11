// Supabase database types
// Generate with: npx supabase gen types typescript --local > src/lib/database.types.ts

export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export interface Database {
  public: {
    Tables: {
      user_profiles: {
        Row: {
          id: string
          display_name: string | null
          avatar_url: string | null
          timezone: string
          preferred_podcast_time: string
          voice_preference: string
          notification_settings: Json
          onboarding_completed: boolean
          health_goals: Json
          created_at: string
          updated_at: string
        }
        Insert: {
          id: string
          display_name?: string | null
          avatar_url?: string | null
          timezone?: string
          preferred_podcast_time?: string
          voice_preference?: string
          notification_settings?: Json
          onboarding_completed?: boolean
          health_goals?: Json
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          display_name?: string | null
          avatar_url?: string | null
          timezone?: string
          preferred_podcast_time?: string
          voice_preference?: string
          notification_settings?: Json
          onboarding_completed?: boolean
          health_goals?: Json
          updated_at?: string
        }
      }
      health_metrics: {
        Row: {
          id: string
          user_id: string
          metric_type: string
          value: number
          unit: string
          metadata: Json
          source: string
          recorded_at: string
          synced_at: string
        }
        Insert: {
          id?: string
          user_id: string
          metric_type: string
          value: number
          unit: string
          metadata?: Json
          source?: string
          recorded_at: string
          synced_at?: string
        }
        Update: {
          metric_type?: string
          value?: number
          unit?: string
          metadata?: Json
          source?: string
          recorded_at?: string
        }
      }
      sleep_sessions: {
        Row: {
          id: string
          user_id: string
          start_time: string
          end_time: string
          total_duration_minutes: number | null
          deep_sleep_minutes: number | null
          rem_sleep_minutes: number | null
          light_sleep_minutes: number | null
          awake_minutes: number | null
          sleep_score: number | null
          source: string
          raw_data: Json
          created_at: string
        }
        Insert: {
          id?: string
          user_id: string
          start_time: string
          end_time: string
          total_duration_minutes?: number | null
          deep_sleep_minutes?: number | null
          rem_sleep_minutes?: number | null
          light_sleep_minutes?: number | null
          awake_minutes?: number | null
          sleep_score?: number | null
          source?: string
          raw_data?: Json
          created_at?: string
        }
        Update: {
          start_time?: string
          end_time?: string
          total_duration_minutes?: number | null
          deep_sleep_minutes?: number | null
          rem_sleep_minutes?: number | null
          light_sleep_minutes?: number | null
          awake_minutes?: number | null
          sleep_score?: number | null
        }
      }
      daily_analyses: {
        Row: {
          id: string
          user_id: string
          analysis_date: string
          summary: string
          key_insights: Json
          action_items: Json
          detected_patterns: Json
          correlations: Json
          wellness_scores: Json
          recommendations: Json
          concerns: Json
          raw_claude_response: Json
          generated_at: string
        }
        Insert: {
          id?: string
          user_id: string
          analysis_date: string
          summary: string
          key_insights?: Json
          action_items?: Json
          detected_patterns?: Json
          correlations?: Json
          wellness_scores?: Json
          recommendations?: Json
          concerns?: Json
          raw_claude_response?: Json
          generated_at?: string
        }
        Update: {
          summary?: string
          key_insights?: Json
          action_items?: Json
          detected_patterns?: Json
          correlations?: Json
          wellness_scores?: Json
          recommendations?: Json
          concerns?: Json
        }
      }
      daily_podcasts: {
        Row: {
          id: string
          user_id: string
          analysis_id: string | null
          podcast_date: string
          title: string | null
          script: string
          audio_url: string | null
          duration_seconds: number | null
          voice_id: string | null
          listened: boolean
          listened_at: string | null
          generated_at: string
        }
        Insert: {
          id?: string
          user_id: string
          analysis_id?: string | null
          podcast_date: string
          title?: string | null
          script: string
          audio_url?: string | null
          duration_seconds?: number | null
          voice_id?: string | null
          listened?: boolean
          listened_at?: string | null
          generated_at?: string
        }
        Update: {
          listened?: boolean
          listened_at?: string | null
        }
      }
      sound_healing_tracks: {
        Row: {
          id: string
          title: string
          description: string | null
          category: string
          frequency_hz: number | null
          secondary_frequency_hz: number | null
          target_state: string
          duration_seconds: number
          audio_url: string
          thumbnail_url: string | null
          is_dynamic: boolean
          generation_params: Json
          popularity_score: number
          created_at: string
        }
        Insert: {
          id?: string
          title: string
          description?: string | null
          category: string
          frequency_hz?: number | null
          secondary_frequency_hz?: number | null
          target_state: string
          duration_seconds: number
          audio_url: string
          thumbnail_url?: string | null
          is_dynamic?: boolean
          generation_params?: Json
          popularity_score?: number
          created_at?: string
        }
        Update: {
          title?: string
          description?: string | null
          category?: string
          target_state?: string
          popularity_score?: number
        }
      }
    }
    Views: {}
    Functions: {}
    Enums: {}
  }
}
