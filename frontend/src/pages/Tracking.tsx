import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { trackingApi } from '../lib/api'
import { Smile, Utensils, Wine, Heart, Brain } from 'lucide-react'

type TrackingTab = 'mood' | 'diet' | 'substance' | 'gratitude' | 'meditation'

const tabs: { id: TrackingTab; label: string; icon: React.ElementType }[] = [
  { id: 'mood', label: 'Mood', icon: Smile },
  { id: 'diet', label: 'Diet', icon: Utensils },
  { id: 'substance', label: 'Substances', icon: Wine },
  { id: 'gratitude', label: 'Gratitude', icon: Heart },
  { id: 'meditation', label: 'Meditation', icon: Brain },
]

const emotions = [
  'Happy', 'Calm', 'Energized', 'Focused', 'Grateful',
  'Anxious', 'Stressed', 'Tired', 'Sad', 'Irritable',
]

export default function Tracking() {
  const [activeTab, setActiveTab] = useState<TrackingTab>('mood')

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold">Daily Tracking</h1>

      {/* Tabs */}
      <div className="flex gap-2 overflow-x-auto pb-2">
        {tabs.map((tab) => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id)}
            className={`flex items-center gap-2 px-4 py-2 rounded-lg font-medium whitespace-nowrap transition-colors ${
              activeTab === tab.id
                ? 'bg-primary-500 text-white'
                : 'bg-white text-gray-700 hover:bg-gray-100'
            }`}
          >
            <tab.icon className="w-4 h-4" />
            {tab.label}
          </button>
        ))}
      </div>

      {/* Forms */}
      <div className="card">
        {activeTab === 'mood' && <MoodForm />}
        {activeTab === 'diet' && <DietForm />}
        {activeTab === 'substance' && <SubstanceForm />}
        {activeTab === 'gratitude' && <GratitudeForm />}
        {activeTab === 'meditation' && <MeditationForm />}
      </div>
    </div>
  )
}

function MoodForm() {
  const [selectedEmotions, setSelectedEmotions] = useState<string[]>([])
  const { register, handleSubmit, reset } = useForm()
  const queryClient = useQueryClient()

  const mutation = useMutation({
    mutationFn: trackingApi.logMood,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['mood'] })
      reset()
      setSelectedEmotions([])
    },
  })

  const onSubmit = (data: any) => {
    mutation.mutate({
      ...data,
      mood_score: parseInt(data.mood_score),
      stress_level: data.stress_level ? parseInt(data.stress_level) : undefined,
      energy_level: data.energy_level ? parseInt(data.energy_level) : undefined,
      emotions: selectedEmotions,
      logged_at: new Date().toISOString(),
    })
  }

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
      <div>
        <label className="label">How are you feeling? (1-10)</label>
        <input
          type="range"
          min="1"
          max="10"
          {...register('mood_score')}
          className="w-full"
        />
        <div className="flex justify-between text-sm text-gray-500">
          <span>Very low</span>
          <span>Excellent</span>
        </div>
      </div>

      <div>
        <label className="label">Stress Level (1-10)</label>
        <input
          type="range"
          min="1"
          max="10"
          {...register('stress_level')}
          className="w-full"
        />
      </div>

      <div>
        <label className="label">Energy Level (1-10)</label>
        <input
          type="range"
          min="1"
          max="10"
          {...register('energy_level')}
          className="w-full"
        />
      </div>

      <div>
        <label className="label">Emotions</label>
        <div className="flex flex-wrap gap-2">
          {emotions.map((emotion) => (
            <button
              key={emotion}
              type="button"
              onClick={() =>
                setSelectedEmotions((prev) =>
                  prev.includes(emotion)
                    ? prev.filter((e) => e !== emotion)
                    : [...prev, emotion]
                )
              }
              className={`px-3 py-1 rounded-full text-sm transition-colors ${
                selectedEmotions.includes(emotion)
                  ? 'bg-primary-500 text-white'
                  : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
              }`}
            >
              {emotion}
            </button>
          ))}
        </div>
      </div>

      <div>
        <label className="label">Notes (optional)</label>
        <textarea
          {...register('notes')}
          className="input h-24 resize-none"
          placeholder="Any additional thoughts..."
        />
      </div>

      <button
        type="submit"
        disabled={mutation.isPending}
        className="btn-primary w-full"
      >
        {mutation.isPending ? 'Saving...' : 'Log Mood'}
      </button>

      {mutation.isSuccess && (
        <p className="text-green-600 text-sm text-center">Mood logged successfully!</p>
      )}
    </form>
  )
}

function DietForm() {
  const { register, handleSubmit, reset } = useForm()
  const queryClient = useQueryClient()

  const mutation = useMutation({
    mutationFn: trackingApi.logDiet,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['diet'] })
      reset()
    },
  })

  const onSubmit = (data: any) => {
    mutation.mutate({
      ...data,
      estimated_calories: data.estimated_calories
        ? parseInt(data.estimated_calories)
        : undefined,
      meal_quality_score: data.meal_quality_score
        ? parseInt(data.meal_quality_score)
        : undefined,
      logged_at: new Date().toISOString(),
    })
  }

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
      <div>
        <label className="label">Meal Type</label>
        <select {...register('meal_type')} className="input">
          <option value="breakfast">Breakfast</option>
          <option value="lunch">Lunch</option>
          <option value="dinner">Dinner</option>
          <option value="snack">Snack</option>
        </select>
      </div>

      <div>
        <label className="label">Description</label>
        <textarea
          {...register('description')}
          className="input h-24 resize-none"
          placeholder="What did you eat?"
        />
      </div>

      <div>
        <label className="label">Estimated Calories (optional)</label>
        <input
          type="number"
          {...register('estimated_calories')}
          className="input"
          placeholder="e.g., 500"
        />
      </div>

      <div>
        <label className="label">Meal Quality (1-5)</label>
        <select {...register('meal_quality_score')} className="input">
          <option value="">Select...</option>
          <option value="1">1 - Poor</option>
          <option value="2">2 - Below Average</option>
          <option value="3">3 - Average</option>
          <option value="4">4 - Good</option>
          <option value="5">5 - Excellent</option>
        </select>
      </div>

      <button
        type="submit"
        disabled={mutation.isPending}
        className="btn-primary w-full"
      >
        {mutation.isPending ? 'Saving...' : 'Log Meal'}
      </button>
    </form>
  )
}

function SubstanceForm() {
  const { register, handleSubmit, reset } = useForm()
  const queryClient = useQueryClient()

  const mutation = useMutation({
    mutationFn: trackingApi.logSubstance,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['substance'] })
      reset()
    },
  })

  const onSubmit = (data: any) => {
    mutation.mutate({
      ...data,
      quantity: parseFloat(data.quantity),
      logged_at: new Date().toISOString(),
    })
  }

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
      <div>
        <label className="label">Substance Type</label>
        <select {...register('substance_type')} className="input">
          <option value="alcohol">Alcohol</option>
          <option value="caffeine">Caffeine</option>
          <option value="cannabis">Cannabis</option>
          <option value="nicotine">Nicotine</option>
          <option value="supplement">Supplement</option>
          <option value="prescription">Prescription</option>
          <option value="other">Other</option>
        </select>
      </div>

      <div>
        <label className="label">Name (optional)</label>
        <input
          {...register('substance_name')}
          className="input"
          placeholder="e.g., Coffee, Wine"
        />
      </div>

      <div className="grid grid-cols-2 gap-4">
        <div>
          <label className="label">Quantity</label>
          <input
            type="number"
            step="0.1"
            {...register('quantity')}
            className="input"
            required
          />
        </div>
        <div>
          <label className="label">Unit</label>
          <input
            {...register('unit')}
            className="input"
            placeholder="e.g., drinks, mg, cups"
            required
          />
        </div>
      </div>

      <button
        type="submit"
        disabled={mutation.isPending}
        className="btn-primary w-full"
      >
        {mutation.isPending ? 'Saving...' : 'Log Substance'}
      </button>
    </form>
  )
}

function GratitudeForm() {
  const [items, setItems] = useState<string[]>(['', '', ''])
  const { register, handleSubmit, reset } = useForm()
  const queryClient = useQueryClient()

  const mutation = useMutation({
    mutationFn: trackingApi.logGratitude,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['gratitude'] })
      reset()
      setItems(['', '', ''])
    },
  })

  const onSubmit = (data: any) => {
    const filledItems = items.filter((item) => item.trim())
    if (filledItems.length === 0) return

    mutation.mutate({
      gratitude_items: filledItems,
      reflection: data.reflection,
      logged_at: new Date().toISOString(),
    })
  }

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
      <div>
        <label className="label">What are you grateful for today?</label>
        {items.map((item, i) => (
          <input
            key={i}
            value={item}
            onChange={(e) => {
              const newItems = [...items]
              newItems[i] = e.target.value
              setItems(newItems)
            }}
            className="input mb-2"
            placeholder={`Gratitude ${i + 1}`}
          />
        ))}
        {items.length < 5 && (
          <button
            type="button"
            onClick={() => setItems([...items, ''])}
            className="text-primary-600 text-sm hover:underline"
          >
            + Add another
          </button>
        )}
      </div>

      <div>
        <label className="label">Reflection (optional)</label>
        <textarea
          {...register('reflection')}
          className="input h-24 resize-none"
          placeholder="Any thoughts or reflections..."
        />
      </div>

      <button
        type="submit"
        disabled={mutation.isPending}
        className="btn-primary w-full"
      >
        {mutation.isPending ? 'Saving...' : 'Log Gratitude'}
      </button>
    </form>
  )
}

function MeditationForm() {
  const { register, handleSubmit, reset } = useForm()
  const queryClient = useQueryClient()

  const mutation = useMutation({
    mutationFn: trackingApi.logMeditation,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['meditation'] })
      reset()
    },
  })

  const onSubmit = (data: any) => {
    mutation.mutate({
      duration_minutes: parseInt(data.duration_minutes),
      meditation_type: data.meditation_type || undefined,
      pre_session_mood: data.pre_session_mood
        ? parseInt(data.pre_session_mood)
        : undefined,
      post_session_mood: data.post_session_mood
        ? parseInt(data.post_session_mood)
        : undefined,
      started_at: new Date().toISOString(),
    })
  }

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
      <div>
        <label className="label">Duration (minutes)</label>
        <input
          type="number"
          {...register('duration_minutes')}
          className="input"
          min="1"
          required
        />
      </div>

      <div>
        <label className="label">Type</label>
        <select {...register('meditation_type')} className="input">
          <option value="">Select...</option>
          <option value="guided">Guided</option>
          <option value="unguided">Unguided</option>
          <option value="breathing">Breathing</option>
          <option value="body_scan">Body Scan</option>
          <option value="loving_kindness">Loving Kindness</option>
          <option value="visualization">Visualization</option>
        </select>
      </div>

      <div className="grid grid-cols-2 gap-4">
        <div>
          <label className="label">Pre-session Mood (1-10)</label>
          <input
            type="number"
            min="1"
            max="10"
            {...register('pre_session_mood')}
            className="input"
          />
        </div>
        <div>
          <label className="label">Post-session Mood (1-10)</label>
          <input
            type="number"
            min="1"
            max="10"
            {...register('post_session_mood')}
            className="input"
          />
        </div>
      </div>

      <button
        type="submit"
        disabled={mutation.isPending}
        className="btn-primary w-full"
      >
        {mutation.isPending ? 'Saving...' : 'Log Meditation'}
      </button>
    </form>
  )
}
