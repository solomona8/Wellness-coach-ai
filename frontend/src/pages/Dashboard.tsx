import { useQuery } from '@tanstack/react-query'
import { analysisApi, podcastApi } from '../lib/api'
import { format } from 'date-fns'
import { Play, TrendingUp, Moon, Activity, Brain, Heart } from 'lucide-react'

function WellnessScoreCard({
  label,
  score,
  icon: Icon,
  color,
}: {
  label: string
  score: number
  icon: React.ElementType
  color: string
}) {
  const getScoreClass = (s: number) => {
    if (s >= 70) return 'wellness-score-high'
    if (s >= 40) return 'wellness-score-medium'
    return 'wellness-score-low'
  }

  return (
    <div className="card flex items-center gap-4">
      <div className={`p-3 rounded-lg ${color}`}>
        <Icon className="w-6 h-6 text-white" />
      </div>
      <div className="flex-1">
        <p className="text-sm text-gray-500">{label}</p>
        <p className="text-2xl font-bold">{score}</p>
      </div>
      <div className={getScoreClass(score)}>{score}</div>
    </div>
  )
}

export default function Dashboard() {
  const yesterday = format(new Date(Date.now() - 86400000), 'yyyy-MM-dd')

  const { data: analysis, isLoading: analysisLoading } = useQuery({
    queryKey: ['analysis', yesterday],
    queryFn: () => analysisApi.getDaily(yesterday),
  })

  const { data: podcast, isLoading: podcastLoading } = useQuery({
    queryKey: ['podcast', 'today'],
    queryFn: () => podcastApi.getToday(),
  })

  const wellnessScores = analysis?.wellness_scores || {
    sleep: 0,
    activity: 0,
    stress: 0,
    nutrition: 0,
    mindfulness: 0,
    overall: 0,
  }

  return (
    <div className="space-y-8">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Good morning!</h1>
        <p className="text-gray-500">
          Here's your wellness summary for {format(new Date(), 'EEEE, MMMM d')}
        </p>
      </div>

      {/* Today's Podcast */}
      {podcast && (
        <div className="card bg-gradient-to-r from-primary-500 to-primary-600 text-white">
          <div className="flex items-center gap-4">
            <button className="p-4 bg-white/20 rounded-full hover:bg-white/30 transition-colors">
              <Play className="w-8 h-8" />
            </button>
            <div className="flex-1">
              <p className="text-sm opacity-80">Today's Wellness Briefing</p>
              <h2 className="text-xl font-semibold">{podcast.title}</h2>
              <p className="text-sm opacity-80">
                {Math.round((podcast.duration_seconds || 0) / 60)} minutes
              </p>
            </div>
          </div>
        </div>
      )}

      {/* Wellness Scores Grid */}
      <div>
        <h2 className="text-lg font-semibold mb-4">Yesterday's Wellness Scores</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          <WellnessScoreCard
            label="Overall"
            score={wellnessScores.overall}
            icon={TrendingUp}
            color="bg-primary-500"
          />
          <WellnessScoreCard
            label="Sleep"
            score={wellnessScores.sleep}
            icon={Moon}
            color="bg-wellness-sleep"
          />
          <WellnessScoreCard
            label="Activity"
            score={wellnessScores.activity}
            icon={Activity}
            color="bg-wellness-activity"
          />
          <WellnessScoreCard
            label="Stress Management"
            score={wellnessScores.stress}
            icon={Heart}
            color="bg-wellness-stress"
          />
          <WellnessScoreCard
            label="Nutrition"
            score={wellnessScores.nutrition}
            icon={TrendingUp}
            color="bg-wellness-nutrition"
          />
          <WellnessScoreCard
            label="Mindfulness"
            score={wellnessScores.mindfulness}
            icon={Brain}
            color="bg-wellness-mindfulness"
          />
        </div>
      </div>

      {/* Key Insights */}
      {analysis?.key_insights && analysis.key_insights.length > 0 && (
        <div className="card">
          <h2 className="text-lg font-semibold mb-4">Key Insights</h2>
          <ul className="space-y-3">
            {analysis.key_insights.map((insight: string, i: number) => (
              <li key={i} className="flex items-start gap-3">
                <span className="flex-shrink-0 w-6 h-6 rounded-full bg-primary-100 text-primary-600 flex items-center justify-center text-sm font-medium">
                  {i + 1}
                </span>
                <span className="text-gray-700">{insight}</span>
              </li>
            ))}
          </ul>
        </div>
      )}

      {/* Action Items */}
      {analysis?.action_items && analysis.action_items.length > 0 && (
        <div className="card">
          <h2 className="text-lg font-semibold mb-4">Today's Action Items</h2>
          <div className="space-y-3">
            {analysis.action_items.map((item: any, i: number) => (
              <div
                key={i}
                className="flex items-start gap-3 p-3 bg-gray-50 rounded-lg"
              >
                <span className="flex-shrink-0 w-6 h-6 rounded bg-primary-500 text-white flex items-center justify-center text-sm font-medium">
                  {item.priority}
                </span>
                <div>
                  <p className="font-medium text-gray-900">{item.action}</p>
                  <p className="text-sm text-gray-500">{item.rationale}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Loading State */}
      {(analysisLoading || podcastLoading) && (
        <div className="flex items-center justify-center py-12">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-500" />
        </div>
      )}
    </div>
  )
}
