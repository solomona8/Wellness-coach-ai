import { useState, useRef } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { podcastApi } from '../lib/api'
import { format } from 'date-fns'
import { Play, Pause, Volume2 } from 'lucide-react'

export default function Podcast() {
  const [currentPodcast, setCurrentPodcast] = useState<any>(null)
  const [isPlaying, setIsPlaying] = useState(false)
  const audioRef = useRef<HTMLAudioElement>(null)
  const queryClient = useQueryClient()

  const { data: todaysPodcast } = useQuery({
    queryKey: ['podcast', 'today'],
    queryFn: () => podcastApi.getToday().catch(() => null),
  })

  const { data: history } = useQuery({
    queryKey: ['podcast', 'history'],
    queryFn: () => podcastApi.getHistory(1, 10),
  })

  const markListenedMutation = useMutation({
    mutationFn: podcastApi.markListened,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['podcast'] })
    },
  })

  const playPodcast = (podcast: any) => {
    setCurrentPodcast(podcast)
    setIsPlaying(true)
    if (!podcast.listened) {
      markListenedMutation.mutate(podcast.id)
    }
  }

  const togglePlay = () => {
    if (audioRef.current) {
      if (isPlaying) {
        audioRef.current.pause()
      } else {
        audioRef.current.play()
      }
      setIsPlaying(!isPlaying)
    }
  }

  return (
    <div className="space-y-8">
      <h1 className="text-2xl font-bold">Daily Podcast</h1>

      {/* Today's Podcast */}
      {todaysPodcast && (
        <div className="card bg-gradient-to-r from-primary-500 to-primary-600 text-white">
          <div className="flex items-center justify-between mb-4">
            <span className="text-sm opacity-80">Today's Briefing</span>
            {!todaysPodcast.listened && (
              <span className="px-2 py-1 bg-white/20 rounded text-xs">New</span>
            )}
          </div>
          <h2 className="text-xl font-semibold mb-2">{todaysPodcast.title}</h2>
          <p className="text-sm opacity-80 mb-4">
            {Math.round((todaysPodcast.duration_seconds || 0) / 60)} minutes
          </p>
          <button
            onClick={() => playPodcast(todaysPodcast)}
            className="flex items-center gap-2 px-4 py-2 bg-white text-primary-600 rounded-lg font-medium hover:bg-gray-100 transition-colors"
          >
            <Play className="w-5 h-5" />
            Play Now
          </button>
        </div>
      )}

      {/* Audio Player */}
      {currentPodcast && (
        <div className="card sticky bottom-4 shadow-lg">
          <audio
            ref={audioRef}
            src={podcastApi.getStreamUrl(currentPodcast.id)}
            autoPlay
            onEnded={() => setIsPlaying(false)}
          />
          <div className="flex items-center gap-4">
            <button
              onClick={togglePlay}
              className="p-3 bg-primary-500 text-white rounded-full hover:bg-primary-600 transition-colors"
            >
              {isPlaying ? (
                <Pause className="w-6 h-6" />
              ) : (
                <Play className="w-6 h-6" />
              )}
            </button>
            <div className="flex-1">
              <p className="font-medium">{currentPodcast.title}</p>
              <p className="text-sm text-gray-500">
                {format(new Date(currentPodcast.podcast_date), 'MMMM d, yyyy')}
              </p>
            </div>
            <Volume2 className="w-5 h-5 text-gray-400" />
          </div>
        </div>
      )}

      {/* History */}
      <div>
        <h2 className="text-lg font-semibold mb-4">Previous Episodes</h2>
        {history?.podcasts && history.podcasts.length > 0 ? (
          <div className="space-y-3">
            {history.podcasts.map((podcast: any) => (
              <div
                key={podcast.id}
                className="card flex items-center gap-4 cursor-pointer hover:bg-gray-50 transition-colors"
                onClick={() => playPodcast(podcast)}
              >
                <button className="p-2 bg-gray-100 rounded-full hover:bg-gray-200">
                  <Play className="w-5 h-5 text-gray-600" />
                </button>
                <div className="flex-1">
                  <p className="font-medium">{podcast.title}</p>
                  <p className="text-sm text-gray-500">
                    {format(new Date(podcast.podcast_date), 'MMMM d, yyyy')} •{' '}
                    {Math.round((podcast.duration_seconds || 0) / 60)} min
                  </p>
                </div>
                {podcast.listened && (
                  <span className="text-xs text-gray-400">Played</span>
                )}
              </div>
            ))}
          </div>
        ) : (
          <div className="card text-center py-8">
            <p className="text-gray-500">No podcast history yet.</p>
          </div>
        )}
      </div>
    </div>
  )
}
