import { useState, useEffect } from 'react'
import { Link } from 'react-router-dom'
import { useAuth } from '../App'
import api from '../services/api'
import {
  FileText,
  CheckCircle,
  Clock,
  AlertCircle,
  TrendingUp,
  Users,
  Calendar,
  ArrowRight
} from 'lucide-react'

function Dashboard() {
  const { user } = useAuth()
  const [stats, setStats] = useState(null)
  const [recentForms, setRecentForms] = useState([])
  const [isLoading, setIsLoading] = useState(true)

  useEffect(() => {
    loadDashboardData()
  }, [])

  const loadDashboardData = async () => {
    try {
      const [statsData, formsData] = await Promise.all([
        api.getStats(),
        api.getForms({ limit: 5, sort: 'createdAt', order: 'desc' })
      ])
      setStats(statsData)
      setRecentForms(formsData.forms || formsData)
    } catch (err) {
      console.error('Failed to load dashboard data:', err)
    } finally {
      setIsLoading(false)
    }
  }

  const statCards = stats ? [
    {
      title: 'Total Forms',
      value: stats.totalForms || 0,
      icon: FileText,
      color: 'bg-blue-500',
      change: '+12%'
    },
    {
      title: 'Completed',
      value: stats.completedForms || 0,
      icon: CheckCircle,
      color: 'bg-green-500',
      change: '+8%'
    },
    {
      title: 'Pending',
      value: stats.pendingForms || 0,
      icon: Clock,
      color: 'bg-yellow-500',
      change: '-3%'
    },
    {
      title: 'Requires Action',
      value: stats.requiresAction || 0,
      icon: AlertCircle,
      color: 'bg-red-500',
      change: '0%'
    }
  ] : []

  const getStatusBadge = (status) => {
    const styles = {
      draft: 'bg-gray-100 text-gray-700',
      submitted: 'bg-blue-100 text-blue-700',
      approved: 'bg-green-100 text-green-700',
      rejected: 'bg-red-100 text-red-700',
      pending: 'bg-yellow-100 text-yellow-700'
    }
    return styles[status] || styles.draft
  }

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-500" />
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Welcome Section */}
      <div className="bg-gradient-to-r from-primary-500 to-primary-600 rounded-xl p-6 text-white">
        <h1 className="text-2xl font-bold">
          Welcome back, {user?.name || 'User'}
        </h1>
        <p className="mt-1 text-primary-100">
          Here's what's happening with your forms today.
        </p>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {statCards.map((stat) => (
          <div key={stat.title} className="bg-white rounded-xl p-5 shadow-sm border border-gray-100">
            <div className="flex items-center justify-between">
              <div className={`${stat.color} p-3 rounded-lg`}>
                <stat.icon size={20} className="text-white" />
              </div>
              <span className={`text-sm font-medium ${
                stat.change.startsWith('+') ? 'text-green-600' :
                stat.change.startsWith('-') ? 'text-red-600' : 'text-gray-500'
              }`}>
                {stat.change}
              </span>
            </div>
            <div className="mt-4">
              <p className="text-2xl font-bold text-gray-900">{stat.value}</p>
              <p className="text-sm text-gray-500">{stat.title}</p>
            </div>
          </div>
        ))}
      </div>

      {/* Content Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Recent Forms */}
        <div className="lg:col-span-2 bg-white rounded-xl shadow-sm border border-gray-100">
          <div className="p-5 border-b border-gray-100 flex items-center justify-between">
            <h2 className="font-semibold text-gray-900">Recent Forms</h2>
            <Link to="/forms" className="text-primary-500 hover:text-primary-600 text-sm font-medium flex items-center gap-1">
              View all <ArrowRight size={14} />
            </Link>
          </div>
          <div className="divide-y divide-gray-100">
            {recentForms.length === 0 ? (
              <div className="p-8 text-center text-gray-500">
                <FileText size={40} className="mx-auto mb-3 text-gray-300" />
                <p>No forms yet</p>
                <p className="text-sm mt-1">Forms submitted from the mobile app will appear here.</p>
              </div>
            ) : (
              recentForms.map((form) => (
                <Link
                  key={form.id}
                  to={`/forms/${form.id}`}
                  className="p-4 flex items-center justify-between hover:bg-gray-50 transition-colors"
                >
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 bg-primary-50 rounded-lg flex items-center justify-center">
                      <FileText size={18} className="text-primary-500" />
                    </div>
                    <div>
                      <p className="font-medium text-gray-900">{form.title || form.templateName}</p>
                      <p className="text-sm text-gray-500">
                        {form.submittedBy || 'Unknown'} • {new Date(form.createdAt).toLocaleDateString()}
                      </p>
                    </div>
                  </div>
                  <span className={`px-2.5 py-1 rounded-full text-xs font-medium ${getStatusBadge(form.status)}`}>
                    {form.status || 'draft'}
                  </span>
                </Link>
              ))
            )}
          </div>
        </div>

        {/* Quick Actions & Activity */}
        <div className="space-y-6">
          {/* Quick Actions */}
          <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-5">
            <h2 className="font-semibold text-gray-900 mb-4">Quick Actions</h2>
            <div className="space-y-2">
              <Link
                to="/templates"
                className="flex items-center gap-3 p-3 rounded-lg hover:bg-gray-50 transition-colors"
              >
                <div className="w-8 h-8 bg-blue-100 rounded-lg flex items-center justify-center">
                  <FileText size={16} className="text-blue-600" />
                </div>
                <span className="text-sm font-medium text-gray-700">Browse Templates</span>
              </Link>
              <Link
                to="/forms?status=pending"
                className="flex items-center gap-3 p-3 rounded-lg hover:bg-gray-50 transition-colors"
              >
                <div className="w-8 h-8 bg-yellow-100 rounded-lg flex items-center justify-center">
                  <Clock size={16} className="text-yellow-600" />
                </div>
                <span className="text-sm font-medium text-gray-700">Review Pending</span>
              </Link>
              <Link
                to="/settings"
                className="flex items-center gap-3 p-3 rounded-lg hover:bg-gray-50 transition-colors"
              >
                <div className="w-8 h-8 bg-gray-100 rounded-lg flex items-center justify-center">
                  <Users size={16} className="text-gray-600" />
                </div>
                <span className="text-sm font-medium text-gray-700">Manage Team</span>
              </Link>
            </div>
          </div>

          {/* This Week */}
          <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-5">
            <h2 className="font-semibold text-gray-900 mb-4">This Week</h2>
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <TrendingUp size={16} className="text-green-500" />
                  <span className="text-sm text-gray-600">Forms Submitted</span>
                </div>
                <span className="font-semibold">{stats?.weeklySubmissions || 0}</span>
              </div>
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <CheckCircle size={16} className="text-blue-500" />
                  <span className="text-sm text-gray-600">Approvals</span>
                </div>
                <span className="font-semibold">{stats?.weeklyApprovals || 0}</span>
              </div>
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <Calendar size={16} className="text-purple-500" />
                  <span className="text-sm text-gray-600">Active Users</span>
                </div>
                <span className="font-semibold">{stats?.activeUsers || 1}</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

export default Dashboard
