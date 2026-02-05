import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { useState, useEffect, createContext, useContext } from 'react'
import Layout from './components/Layout'
import Login from './pages/Login'
import Dashboard from './pages/Dashboard'
import Forms from './pages/Forms'
import FormDetail from './pages/FormDetail'
import FormBuilder from './pages/FormBuilder'
import Templates from './pages/Templates'
import Settings from './pages/Settings'
import { api } from './services/api'

// Auth Context
const AuthContext = createContext(null)

export const useAuth = () => useContext(AuthContext)

function AuthProvider({ children }) {
  const [user, setUser] = useState(null)
  const [loading, setLoading] = useState(true)
  const [isDemoMode, setIsDemoMode] = useState(false)

  useEffect(() => {
    // Check for stored token
    const token = localStorage.getItem('accessToken')
    const storedUser = localStorage.getItem('user')
    const demoMode = localStorage.getItem('demoMode') === 'true'

    if (storedUser) {
      setUser(JSON.parse(storedUser))
      if (token && !demoMode) {
        api.setToken(token)
      }
      setIsDemoMode(demoMode)
      api.setDemoMode(demoMode)
    }
    setLoading(false)
  }, [])

  const login = async (email, password) => {
    const response = await api.login(email, password)
    localStorage.setItem('accessToken', response.accessToken)
    localStorage.setItem('refreshToken', response.refreshToken)
    localStorage.setItem('user', JSON.stringify(response.user))
    localStorage.setItem('demoMode', 'false')
    api.setToken(response.accessToken)
    api.setDemoMode(false)
    setUser(response.user)
    setIsDemoMode(false)
    return response
  }

  const logout = () => {
    localStorage.removeItem('accessToken')
    localStorage.removeItem('refreshToken')
    localStorage.removeItem('user')
    localStorage.removeItem('demoMode')
    api.setToken(null)
    api.setDemoMode(false)
    setUser(null)
    setIsDemoMode(false)
  }

  // Demo login for testing
  const loginDemo = () => {
    const demoUser = {
      id: 'demo-user',
      name: 'Demo User',
      email: 'demo@example.com',
      role: 'admin'
    }
    localStorage.setItem('user', JSON.stringify(demoUser))
    localStorage.setItem('demoMode', 'true')
    api.setDemoMode(true)
    setUser(demoUser)
    setIsDemoMode(true)
  }

  return (
    <AuthContext.Provider value={{ user, loading, login, logout, loginDemo, isDemoMode }}>
      {children}
    </AuthContext.Provider>
  )
}

// Protected Route
function ProtectedRoute({ children }) {
  const { user, loading } = useAuth()

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-500"></div>
      </div>
    )
  }

  if (!user) {
    return <Navigate to="/login" replace />
  }

  return children
}

function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route
            path="/"
            element={
              <ProtectedRoute>
                <Layout />
              </ProtectedRoute>
            }
          >
            <Route index element={<Dashboard />} />
            <Route path="forms" element={<Forms />} />
            <Route path="forms/:id" element={<FormDetail />} />
            <Route path="builder" element={<FormBuilder />} />
            <Route path="builder/:id" element={<FormBuilder />} />
            <Route path="templates" element={<Templates />} />
            <Route path="settings" element={<Settings />} />
          </Route>
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  )
}

export default App
