import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { userApi } from '../lib/api'
import { useAuth } from '../hooks/useAuth'
import { User, Bell, Clock, Download, Trash2 } from 'lucide-react'

export default function Settings() {
  const { user } = useAuth()
  const queryClient = useQueryClient()

  const { data: profile, isLoading } = useQuery({
    queryKey: ['user', 'profile'],
    queryFn: userApi.getProfile,
  })

  const { data: voices } = useQuery({
    queryKey: ['user', 'voices'],
    queryFn: userApi.getVoices,
  })

  const updateMutation = useMutation({
    mutationFn: userApi.updateProfile,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['user', 'profile'] })
    },
  })

  const [displayName, setDisplayName] = useState('')
  const [timezone, setTimezone] = useState('')
  const [podcastTime, setPodcastTime] = useState('')
  const [voicePreference, setVoicePreference] = useState('')

  // Initialize form when profile loads
  useState(() => {
    if (profile) {
      setDisplayName(profile.display_name || '')
      setTimezone(profile.timezone || 'UTC')
      setPodcastTime(profile.preferred_podcast_time || '07:00')
      setVoicePreference(profile.voice_preference || 'default')
    }
  })

  const handleSave = () => {
    updateMutation.mutate({
      display_name: displayName,
      timezone,
      preferred_podcast_time: podcastTime,
      voice_preference: voicePreference,
    })
  }

  const handleExport = async () => {
    const data = await userApi.exportData()
    const blob = new Blob([JSON.stringify(data, null, 2)], {
      type: 'application/json',
    })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = 'wellness-data-export.json'
    a.click()
    URL.revokeObjectURL(url)
  }

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-12">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-500" />
      </div>
    )
  }

  return (
    <div className="space-y-8 max-w-2xl">
      <h1 className="text-2xl font-bold">Settings</h1>

      {/* Profile */}
      <div className="card">
        <div className="flex items-center gap-3 mb-6">
          <User className="w-5 h-5 text-gray-400" />
          <h2 className="text-lg font-semibold">Profile</h2>
        </div>

        <div className="space-y-4">
          <div>
            <label className="label">Email</label>
            <input
              type="email"
              value={user?.email || ''}
              disabled
              className="input bg-gray-50"
            />
          </div>

          <div>
            <label className="label">Display Name</label>
            <input
              type="text"
              value={displayName}
              onChange={(e) => setDisplayName(e.target.value)}
              className="input"
              placeholder="Your name"
            />
          </div>

          <div>
            <label className="label">Timezone</label>
            <select
              value={timezone}
              onChange={(e) => setTimezone(e.target.value)}
              className="input"
            >
              <option value="UTC">UTC</option>
              <option value="America/New_York">Eastern Time</option>
              <option value="America/Chicago">Central Time</option>
              <option value="America/Denver">Mountain Time</option>
              <option value="America/Los_Angeles">Pacific Time</option>
              <option value="Europe/London">London</option>
              <option value="Europe/Paris">Paris</option>
              <option value="Asia/Tokyo">Tokyo</option>
            </select>
          </div>
        </div>
      </div>

      {/* Podcast Settings */}
      <div className="card">
        <div className="flex items-center gap-3 mb-6">
          <Clock className="w-5 h-5 text-gray-400" />
          <h2 className="text-lg font-semibold">Podcast Preferences</h2>
        </div>

        <div className="space-y-4">
          <div>
            <label className="label">Preferred Delivery Time</label>
            <input
              type="time"
              value={podcastTime}
              onChange={(e) => setPodcastTime(e.target.value)}
              className="input"
            />
            <p className="text-sm text-gray-500 mt-1">
              Your daily podcast will be ready at this time.
            </p>
          </div>

          <div>
            <label className="label">Voice</label>
            <select
              value={voicePreference}
              onChange={(e) => setVoicePreference(e.target.value)}
              className="input"
            >
              {voices?.map((voice: any) => (
                <option key={voice.id} value={voice.id}>
                  {voice.name} - {voice.description}
                </option>
              ))}
            </select>
          </div>
        </div>
      </div>

      {/* Notifications */}
      <div className="card">
        <div className="flex items-center gap-3 mb-6">
          <Bell className="w-5 h-5 text-gray-400" />
          <h2 className="text-lg font-semibold">Notifications</h2>
        </div>

        <div className="space-y-4">
          {[
            { key: 'podcast_ready', label: 'Podcast ready' },
            { key: 'daily_reminder', label: 'Daily tracking reminder' },
            { key: 'weekly_summary', label: 'Weekly summary' },
            { key: 'achievement_alerts', label: 'Achievement alerts' },
            { key: 'sound_healing_suggestions', label: 'Sound healing suggestions' },
          ].map((item) => (
            <label key={item.key} className="flex items-center justify-between">
              <span>{item.label}</span>
              <input
                type="checkbox"
                defaultChecked={
                  profile?.notification_settings?.[item.key] ?? true
                }
                className="w-5 h-5 rounded border-gray-300 text-primary-500 focus:ring-primary-500"
              />
            </label>
          ))}
        </div>
      </div>

      {/* Save Button */}
      <button
        onClick={handleSave}
        disabled={updateMutation.isPending}
        className="btn-primary w-full"
      >
        {updateMutation.isPending ? 'Saving...' : 'Save Changes'}
      </button>

      {updateMutation.isSuccess && (
        <p className="text-green-600 text-sm text-center">Settings saved!</p>
      )}

      {/* Data Management */}
      <div className="card border-red-200">
        <h2 className="text-lg font-semibold mb-4">Data Management</h2>

        <div className="space-y-4">
          <button
            onClick={handleExport}
            className="btn-outline w-full flex items-center justify-center gap-2"
          >
            <Download className="w-4 h-4" />
            Export My Data
          </button>

          <button className="w-full flex items-center justify-center gap-2 px-4 py-2 text-red-600 border border-red-300 rounded-lg hover:bg-red-50 transition-colors">
            <Trash2 className="w-4 h-4" />
            Delete Account
          </button>
        </div>
      </div>
    </div>
  )
}
