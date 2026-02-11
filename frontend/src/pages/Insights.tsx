import { useQuery } from '@tanstack/react-query'
import { analysisApi } from '../lib/api'
import { format } from 'date-fns'

export default function Insights() {
  const { data: history, isLoading } = useQuery({
    queryKey: ['analysis', 'history'],
    queryFn: () => analysisApi.getHistory(14),
  })

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-12">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-500" />
      </div>
    )
  }

  return (
    <div className="space-y-8">
      <h1 className="text-2xl font-bold">Insights & Patterns</h1>

      {/* Trends Overview */}
      <div className="card">
        <h2 className="text-lg font-semibold mb-4">Weekly Trends</h2>
        <p className="text-gray-500">
          Your wellness scores over the past week. Connect your iOS app for HealthKit data.
        </p>
      </div>

      {/* Recent Analyses */}
      <div className="space-y-4">
        <h2 className="text-lg font-semibold">Recent Analyses</h2>
        {history && history.length > 0 ? (
          history.map((analysis: any) => (
            <div key={analysis.id} className="card">
              <div className="flex items-center justify-between mb-4">
                <h3 className="font-medium">
                  {format(new Date(analysis.analysis_date), 'EEEE, MMMM d')}
                </h3>
                <span className="text-2xl font-bold text-primary-600">
                  {analysis.wellness_scores?.overall || '-'}
                </span>
              </div>
              <p className="text-gray-600 mb-4">{analysis.summary}</p>
              {analysis.key_insights && (
                <ul className="space-y-2">
                  {analysis.key_insights.slice(0, 2).map((insight: string, i: number) => (
                    <li key={i} className="text-sm text-gray-500 flex items-start gap-2">
                      <span className="text-primary-500">•</span>
                      {insight}
                    </li>
                  ))}
                </ul>
              )}
            </div>
          ))
        ) : (
          <div className="card text-center py-8">
            <p className="text-gray-500">
              No analyses yet. Start tracking your wellness data to see insights!
            </p>
          </div>
        )}
      </div>
    </div>
  )
}
