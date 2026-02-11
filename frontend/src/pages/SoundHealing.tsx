import { useState, useRef } from 'react'
import { useQuery, useMutation } from '@tanstack/react-query'
import { soundApi } from '../lib/api'
import { Play, Pause, Waves, Brain, Moon, Heart } from 'lucide-react'

const categories = [
  { id: 'all', label: 'All', icon: Waves },
  { id: 'binaural_beats', label: 'Binaural', icon: Brain },
  { id: 'solfeggio', label: 'Solfeggio', icon: Heart },
  { id: 'nature', label: 'Nature', icon: Moon },
]

const targetStates = [
  { id: 'relaxation', label: 'Relaxation', color: 'bg-blue-100 text-blue-700' },
  { id: 'sleep', label: 'Sleep', color: 'bg-purple-100 text-purple-700' },
  { id: 'focus', label: 'Focus', color: 'bg-yellow-100 text-yellow-700' },
  { id: 'meditation', label: 'Meditation', color: 'bg-green-100 text-green-700' },
  { id: 'energy', label: 'Energy', color: 'bg-orange-100 text-orange-700' },
]

export default function SoundHealing() {
  const [activeCategory, setActiveCategory] = useState('all')
  const [activeState, setActiveState] = useState<string | null>(null)
  const [currentTrack, setCurrentTrack] = useState<any>(null)
  const [isPlaying, setIsPlaying] = useState(false)
  const audioRef = useRef<HTMLAudioElement>(null)

  const { data: recommendations } = useQuery({
    queryKey: ['sound', 'recommendations'],
    queryFn: () => soundApi.getRecommendations(),
  })

  const { data: library } = useQuery({
    queryKey: ['sound', 'library', activeCategory, activeState],
    queryFn: () =>
      soundApi.getLibrary({
        category: activeCategory !== 'all' ? activeCategory : undefined,
        target_state: activeState || undefined,
      }),
  })

  const generateMutation = useMutation({
    mutationFn: soundApi.generateDynamic,
  })

  const playTrack = (track: any) => {
    setCurrentTrack(track)
    setIsPlaying(true)
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

  const handleGenerateDynamic = async (targetState: string) => {
    const result = await generateMutation.mutateAsync({
      target_state: targetState,
      duration_seconds: 600,
    })
    setCurrentTrack({
      id: 'dynamic',
      title: `Dynamic ${targetState} Session`,
      audio_url: result.audio_url,
      target_state: targetState,
      is_dynamic: true,
    })
    setIsPlaying(true)
  }

  return (
    <div className="space-y-8">
      <h1 className="text-2xl font-bold">Sound Healing</h1>

      {/* Recommendations */}
      {recommendations && recommendations.length > 0 && (
        <div>
          <h2 className="text-lg font-semibold mb-4">Recommended for You</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {recommendations.slice(0, 4).map((rec: any, i: number) => (
              <div
                key={i}
                className="card cursor-pointer hover:shadow-md transition-shadow"
                onClick={() =>
                  rec.type === 'dynamic'
                    ? handleGenerateDynamic(rec.dynamic_params?.target_state || 'relaxation')
                    : playTrack(rec.track)
                }
              >
                <div className="flex items-center gap-4">
                  <div className="p-3 bg-primary-100 rounded-lg">
                    <Waves className="w-6 h-6 text-primary-600" />
                  </div>
                  <div className="flex-1">
                    <p className="font-medium">
                      {rec.type === 'dynamic'
                        ? 'Generate Custom Sound'
                        : rec.track?.title}
                    </p>
                    <p className="text-sm text-gray-500">{rec.reason}</p>
                  </div>
                  <Play className="w-5 h-5 text-gray-400" />
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Generate Dynamic */}
      <div className="card">
        <h2 className="text-lg font-semibold mb-4">Generate Custom Sound</h2>
        <p className="text-gray-500 mb-4">
          Create personalized binaural beats based on your current state.
        </p>
        <div className="flex flex-wrap gap-2">
          {targetStates.map((state) => (
            <button
              key={state.id}
              onClick={() => handleGenerateDynamic(state.id)}
              disabled={generateMutation.isPending}
              className={`px-4 py-2 rounded-lg font-medium transition-colors ${state.color} hover:opacity-80`}
            >
              {state.label}
            </button>
          ))}
        </div>
        {generateMutation.isPending && (
          <p className="mt-4 text-sm text-gray-500">Generating your custom sound...</p>
        )}
      </div>

      {/* Category Filters */}
      <div className="flex gap-2 overflow-x-auto pb-2">
        {categories.map((cat) => (
          <button
            key={cat.id}
            onClick={() => setActiveCategory(cat.id)}
            className={`flex items-center gap-2 px-4 py-2 rounded-lg font-medium whitespace-nowrap transition-colors ${
              activeCategory === cat.id
                ? 'bg-primary-500 text-white'
                : 'bg-white text-gray-700 hover:bg-gray-100'
            }`}
          >
            <cat.icon className="w-4 h-4" />
            {cat.label}
          </button>
        ))}
      </div>

      {/* State Filters */}
      <div className="flex flex-wrap gap-2">
        {targetStates.map((state) => (
          <button
            key={state.id}
            onClick={() =>
              setActiveState(activeState === state.id ? null : state.id)
            }
            className={`px-3 py-1 rounded-full text-sm transition-colors ${
              activeState === state.id
                ? 'bg-primary-500 text-white'
                : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
            }`}
          >
            {state.label}
          </button>
        ))}
      </div>

      {/* Library */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {library?.map((track: any) => (
          <div
            key={track.id}
            className="card cursor-pointer hover:shadow-md transition-shadow"
            onClick={() => playTrack(track)}
          >
            <div className="flex items-start justify-between mb-3">
              <div className="p-2 bg-primary-100 rounded-lg">
                <Waves className="w-5 h-5 text-primary-600" />
              </div>
              <span className="text-xs px-2 py-1 bg-gray-100 rounded">
                {Math.round(track.duration_seconds / 60)} min
              </span>
            </div>
            <h3 className="font-medium mb-1">{track.title}</h3>
            <p className="text-sm text-gray-500 mb-2">{track.description}</p>
            {track.frequency_hz && (
              <p className="text-xs text-gray-400">{track.frequency_hz} Hz</p>
            )}
          </div>
        ))}
      </div>

      {/* Audio Player */}
      {currentTrack && (
        <div className="card sticky bottom-4 shadow-lg">
          <audio
            ref={audioRef}
            src={
              currentTrack.is_dynamic
                ? currentTrack.audio_url
                : soundApi.getStreamUrl(currentTrack.id)
            }
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
              <p className="font-medium">{currentTrack.title}</p>
              <p className="text-sm text-gray-500 capitalize">
                {currentTrack.target_state}
              </p>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
