import { Routes, Route, Navigate } from 'react-router-dom'
import { useAuth } from './hooks/useAuth'
import Layout from './components/common/Layout'
import Dashboard from './pages/Dashboard'
import Tracking from './pages/Tracking'
import Insights from './pages/Insights'
import Podcast from './pages/Podcast'
import SoundHealing from './pages/SoundHealing'
import Settings from './pages/Settings'
import Login from './pages/Login'
import Onboarding from './pages/Onboarding'

function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { user, loading } = useAuth()

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-500" />
      </div>
    )
  }

  if (!user) {
    return <Navigate to="/login" replace />
  }

  return <>{children}</>
}

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<Login />} />
      <Route path="/onboarding" element={<Onboarding />} />

      <Route
        path="/"
        element={
          <ProtectedRoute>
            <Layout />
          </ProtectedRoute>
        }
      >
        <Route index element={<Dashboard />} />
        <Route path="tracking" element={<Tracking />} />
        <Route path="insights" element={<Insights />} />
        <Route path="podcast" element={<Podcast />} />
        <Route path="sound-healing" element={<SoundHealing />} />
        <Route path="settings" element={<Settings />} />
      </Route>
    </Routes>
  )
}
