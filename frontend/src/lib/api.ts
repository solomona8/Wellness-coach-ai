import { supabase } from './supabase'

const API_BASE = '/api/v1'

async function getAuthHeaders(): Promise<HeadersInit> {
  const { data } = await supabase.auth.getSession()
  const token = data.session?.access_token

  return {
    'Content-Type': 'application/json',
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
  }
}

async function fetchWithAuth(
  endpoint: string,
  options: RequestInit = {}
): Promise<Response> {
  const headers = await getAuthHeaders()

  const response = await fetch(`${API_BASE}${endpoint}`, {
    ...options,
    headers: {
      ...headers,
      ...options.headers,
    },
  })

  if (!response.ok) {
    const error = await response.json().catch(() => ({}))
    throw new Error(error.detail || `API error: ${response.status}`)
  }

  return response
}

// Analysis API
export const analysisApi = {
  getDaily: async (date: string) => {
    const response = await fetchWithAuth(`/analysis/daily/${date}`)
    return response.json()
  },

  generate: async (params: { date?: string; lookback_days?: number }) => {
    const response = await fetchWithAuth('/analysis/generate', {
      method: 'POST',
      body: JSON.stringify(params),
    })
    return response.json()
  },

  getTrends: async (metrics: string[], days: number) => {
    const params = new URLSearchParams({
      days: days.toString(),
      ...metrics.reduce((acc, m) => ({ ...acc, [`metrics`]: m }), {}),
    })
    const response = await fetchWithAuth(`/analysis/trends?${params}`)
    return response.json()
  },

  getHistory: async (limit = 7) => {
    const response = await fetchWithAuth(`/analysis/history?limit=${limit}`)
    return response.json()
  },
}

// Podcast API
export const podcastApi = {
  getToday: async () => {
    const response = await fetchWithAuth('/podcast/today')
    return response.json()
  },

  getHistory: async (page = 1, perPage = 10) => {
    const response = await fetchWithAuth(
      `/podcast/history?page=${page}&per_page=${perPage}`
    )
    return response.json()
  },

  generate: async (date?: string) => {
    const response = await fetchWithAuth('/podcast/generate', {
      method: 'POST',
      body: JSON.stringify({ podcast_date: date }),
    })
    return response.json()
  },

  markListened: async (podcastId: string) => {
    const response = await fetchWithAuth(`/podcast/listened/${podcastId}`, {
      method: 'POST',
    })
    return response.json()
  },

  getStreamUrl: (podcastId: string) => `${API_BASE}/podcast/stream/${podcastId}`,
}

// Sound Healing API
export const soundApi = {
  getLibrary: async (params?: { category?: string; target_state?: string }) => {
    const searchParams = new URLSearchParams()
    if (params?.category) searchParams.set('category', params.category)
    if (params?.target_state) searchParams.set('target_state', params.target_state)

    const response = await fetchWithAuth(`/sound/library?${searchParams}`)
    return response.json()
  },

  getRecommendations: async (params?: {
    current_hrv?: number
    current_stress?: number
    time_of_day?: string
  }) => {
    const searchParams = new URLSearchParams()
    if (params?.current_hrv)
      searchParams.set('current_hrv', params.current_hrv.toString())
    if (params?.current_stress)
      searchParams.set('current_stress', params.current_stress.toString())
    if (params?.time_of_day)
      searchParams.set('time_of_day', params.time_of_day)

    const response = await fetchWithAuth(`/sound/recommendations?${searchParams}`)
    return response.json()
  },

  generateDynamic: async (params: {
    target_state: string
    duration_seconds?: number
    current_hrv?: number
    current_stress_level?: number
  }) => {
    const response = await fetchWithAuth('/sound/generate', {
      method: 'POST',
      body: JSON.stringify(params),
    })
    return response.json()
  },

  startSession: async (trackId?: string, isDynamic?: boolean) => {
    const response = await fetchWithAuth('/sound/session/start', {
      method: 'POST',
      body: JSON.stringify({
        track_id: trackId,
        is_dynamic: isDynamic || false,
      }),
    })
    return response.json()
  },

  endSession: async (data: {
    duration_listened_seconds: number
    effectiveness_rating?: number
    started_at: string
  }) => {
    const response = await fetchWithAuth('/sound/session/end', {
      method: 'POST',
      body: JSON.stringify(data),
    })
    return response.json()
  },

  getStreamUrl: (trackId: string) => `${API_BASE}/sound/stream/${trackId}`,
}

// Tracking API
export const trackingApi = {
  logMood: async (data: {
    mood_score: number
    stress_level?: number
    energy_level?: number
    emotions?: string[]
    notes?: string
    logged_at: string
  }) => {
    const response = await fetchWithAuth('/tracking/mood', {
      method: 'POST',
      body: JSON.stringify(data),
    })
    return response.json()
  },

  logDiet: async (data: {
    meal_type: string
    description?: string
    estimated_calories?: number
    meal_quality_score?: number
    logged_at: string
  }) => {
    const response = await fetchWithAuth('/tracking/diet', {
      method: 'POST',
      body: JSON.stringify(data),
    })
    return response.json()
  },

  logSubstance: async (data: {
    substance_type: string
    quantity: number
    unit: string
    substance_name?: string
    logged_at: string
  }) => {
    const response = await fetchWithAuth('/tracking/substance', {
      method: 'POST',
      body: JSON.stringify(data),
    })
    return response.json()
  },

  logGratitude: async (data: {
    gratitude_items: string[]
    reflection?: string
    logged_at: string
  }) => {
    const response = await fetchWithAuth('/tracking/gratitude', {
      method: 'POST',
      body: JSON.stringify(data),
    })
    return response.json()
  },

  logMeditation: async (data: {
    duration_minutes: number
    meditation_type?: string
    pre_session_mood?: number
    post_session_mood?: number
    started_at: string
  }) => {
    const response = await fetchWithAuth('/tracking/meditation', {
      method: 'POST',
      body: JSON.stringify(data),
    })
    return response.json()
  },

  getMoodHistory: async (limit = 30) => {
    const response = await fetchWithAuth(`/tracking/mood?limit=${limit}`)
    return response.json()
  },
}

// User API
export const userApi = {
  getProfile: async () => {
    const response = await fetchWithAuth('/user/profile')
    return response.json()
  },

  updateProfile: async (data: {
    display_name?: string
    timezone?: string
    preferred_podcast_time?: string
    voice_preference?: string
    health_goals?: string[]
  }) => {
    const response = await fetchWithAuth('/user/profile', {
      method: 'PUT',
      body: JSON.stringify(data),
    })
    return response.json()
  },

  completeOnboarding: async (healthGoals: string[]) => {
    const response = await fetchWithAuth('/user/onboarding/complete', {
      method: 'POST',
      body: JSON.stringify({ health_goals: healthGoals }),
    })
    return response.json()
  },

  getVoices: async () => {
    const response = await fetchWithAuth('/user/voices')
    return response.json()
  },

  exportData: async () => {
    const response = await fetchWithAuth('/user/export')
    return response.json()
  },
}
