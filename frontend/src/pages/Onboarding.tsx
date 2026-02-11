import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useMutation } from '@tanstack/react-query'
import { userApi } from '../lib/api'
import { Check } from 'lucide-react'

const healthGoals = [
  { id: 'sleep', label: 'Improve Sleep', description: 'Get better quality sleep' },
  { id: 'stress', label: 'Reduce Stress', description: 'Manage stress and anxiety' },
  { id: 'activity', label: 'Stay Active', description: 'Exercise more regularly' },
  { id: 'nutrition', label: 'Eat Better', description: 'Improve eating habits' },
  { id: 'mindfulness', label: 'Practice Mindfulness', description: 'Meditate more often' },
  { id: 'energy', label: 'Boost Energy', description: 'Feel more energized' },
  { id: 'mood', label: 'Improve Mood', description: 'Feel happier daily' },
  { id: 'substance', label: 'Reduce Substances', description: 'Cut back on alcohol/caffeine' },
]

export default function Onboarding() {
  const [selectedGoals, setSelectedGoals] = useState<string[]>([])
  const navigate = useNavigate()

  const mutation = useMutation({
    mutationFn: userApi.completeOnboarding,
    onSuccess: () => {
      navigate('/')
    },
  })

  const toggleGoal = (goalId: string) => {
    setSelectedGoals((prev) =>
      prev.includes(goalId)
        ? prev.filter((g) => g !== goalId)
        : [...prev, goalId]
    )
  }

  const handleComplete = () => {
    mutation.mutate(selectedGoals)
  }

  return (
    <div className="min-h-screen bg-gray-50 py-12 px-4">
      <div className="max-w-2xl mx-auto">
        <div className="text-center mb-8">
          <h1 className="text-3xl font-bold text-gray-900">Welcome to My Wellness Coach</h1>
          <p className="text-gray-500 mt-2">
            Let's personalize your experience. What are your wellness goals?
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-8">
          {healthGoals.map((goal) => (
            <button
              key={goal.id}
              onClick={() => toggleGoal(goal.id)}
              className={`card text-left transition-all ${
                selectedGoals.includes(goal.id)
                  ? 'ring-2 ring-primary-500 bg-primary-50'
                  : 'hover:shadow-md'
              }`}
            >
              <div className="flex items-start justify-between">
                <div>
                  <h3 className="font-medium text-gray-900">{goal.label}</h3>
                  <p className="text-sm text-gray-500">{goal.description}</p>
                </div>
                {selectedGoals.includes(goal.id) && (
                  <div className="p-1 bg-primary-500 rounded-full">
                    <Check className="w-4 h-4 text-white" />
                  </div>
                )}
              </div>
            </button>
          ))}
        </div>

        <div className="flex flex-col gap-4">
          <button
            onClick={handleComplete}
            disabled={selectedGoals.length === 0 || mutation.isPending}
            className="btn-primary w-full"
          >
            {mutation.isPending ? 'Setting up...' : 'Continue'}
          </button>

          <button
            onClick={() => navigate('/')}
            className="text-gray-500 hover:text-gray-700 text-sm"
          >
            Skip for now
          </button>
        </div>

        <p className="text-center text-sm text-gray-400 mt-8">
          You can change these anytime in Settings
        </p>
      </div>
    </div>
  )
}
