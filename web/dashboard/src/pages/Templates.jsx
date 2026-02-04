import { useState, useEffect } from 'react'
import { Link } from 'react-router-dom'
import api from '../services/api'
import {
  FileText,
  Search,
  Grid,
  List,
  Star,
  Clock,
  Users,
  Shield,
  Wrench,
  Clipboard,
  Truck,
  Building,
  Heart,
  AlertTriangle
} from 'lucide-react'

function Templates() {
  const [templates, setTemplates] = useState([])
  const [isLoading, setIsLoading] = useState(true)
  const [searchQuery, setSearchQuery] = useState('')
  const [selectedCategory, setSelectedCategory] = useState('all')
  const [viewMode, setViewMode] = useState('grid')

  useEffect(() => {
    loadTemplates()
  }, [])

  const loadTemplates = async () => {
    try {
      const data = await api.getTemplates()
      setTemplates(data.templates || data)
    } catch (err) {
      console.error('Failed to load templates:', err)
    } finally {
      setIsLoading(false)
    }
  }

  const categories = [
    { id: 'all', name: 'All Templates', icon: Grid },
    { id: 'safety', name: 'Safety', icon: Shield },
    { id: 'inspection', name: 'Inspection', icon: Clipboard },
    { id: 'maintenance', name: 'Maintenance', icon: Wrench },
    { id: 'hr', name: 'HR & Training', icon: Users },
    { id: 'delivery', name: 'Delivery', icon: Truck },
    { id: 'facility', name: 'Facility', icon: Building },
    { id: 'health', name: 'Health', icon: Heart },
    { id: 'incident', name: 'Incident', icon: AlertTriangle }
  ]

  const getCategoryIcon = (category) => {
    const cat = categories.find((c) => c.id === category)
    return cat?.icon || FileText
  }

  const getCategoryColor = (category) => {
    const colors = {
      safety: 'bg-red-100 text-red-600',
      inspection: 'bg-blue-100 text-blue-600',
      maintenance: 'bg-yellow-100 text-yellow-600',
      hr: 'bg-purple-100 text-purple-600',
      delivery: 'bg-green-100 text-green-600',
      facility: 'bg-indigo-100 text-indigo-600',
      health: 'bg-pink-100 text-pink-600',
      incident: 'bg-orange-100 text-orange-600'
    }
    return colors[category] || 'bg-gray-100 text-gray-600'
  }

  const filteredTemplates = templates.filter((template) => {
    const matchesSearch = template.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      template.description?.toLowerCase().includes(searchQuery.toLowerCase())
    const matchesCategory = selectedCategory === 'all' || template.category === selectedCategory
    return matchesSearch && matchesCategory
  })

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Templates</h1>
          <p className="text-gray-500">Browse and manage form templates</p>
        </div>
      </div>

      {/* Search & Filters */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-4">
        <div className="flex flex-col sm:flex-row gap-4">
          {/* Search */}
          <div className="flex-1 relative">
            <Search size={18} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Search templates..."
              className="input pl-10 w-full"
            />
          </div>

          {/* View Toggle */}
          <div className="flex items-center gap-1 bg-gray-100 rounded-lg p-1">
            <button
              onClick={() => setViewMode('grid')}
              className={`p-2 rounded-md transition-colors ${
                viewMode === 'grid' ? 'bg-white shadow-sm' : 'hover:bg-gray-200'
              }`}
            >
              <Grid size={18} className={viewMode === 'grid' ? 'text-primary-500' : 'text-gray-500'} />
            </button>
            <button
              onClick={() => setViewMode('list')}
              className={`p-2 rounded-md transition-colors ${
                viewMode === 'list' ? 'bg-white shadow-sm' : 'hover:bg-gray-200'
              }`}
            >
              <List size={18} className={viewMode === 'list' ? 'text-primary-500' : 'text-gray-500'} />
            </button>
          </div>
        </div>

        {/* Category Pills */}
        <div className="mt-4 flex flex-wrap gap-2">
          {categories.map((category) => {
            const Icon = category.icon
            return (
              <button
                key={category.id}
                onClick={() => setSelectedCategory(category.id)}
                className={`inline-flex items-center gap-2 px-3 py-1.5 rounded-full text-sm font-medium transition-colors ${
                  selectedCategory === category.id
                    ? 'bg-primary-500 text-white'
                    : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                }`}
              >
                <Icon size={14} />
                {category.name}
              </button>
            )
          })}
        </div>
      </div>

      {/* Templates */}
      {isLoading ? (
        <div className="flex items-center justify-center h-64">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-500" />
        </div>
      ) : filteredTemplates.length === 0 ? (
        <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-12 text-center">
          <FileText size={48} className="mx-auto mb-4 text-gray-300" />
          <h3 className="text-lg font-medium text-gray-900 mb-1">No templates found</h3>
          <p className="text-gray-500">
            {searchQuery
              ? 'Try adjusting your search or filters'
              : 'Templates will appear here once created'}
          </p>
        </div>
      ) : viewMode === 'grid' ? (
        /* Grid View */
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {filteredTemplates.map((template) => {
            const CategoryIcon = getCategoryIcon(template.category)
            return (
              <div
                key={template.id}
                className="bg-white rounded-xl shadow-sm border border-gray-100 p-5 hover:shadow-md transition-shadow"
              >
                <div className="flex items-start justify-between mb-4">
                  <div className={`p-3 rounded-lg ${getCategoryColor(template.category)}`}>
                    <CategoryIcon size={20} />
                  </div>
                  {template.featured && (
                    <Star size={16} className="text-yellow-400 fill-yellow-400" />
                  )}
                </div>

                <h3 className="font-semibold text-gray-900 mb-1">{template.name}</h3>
                <p className="text-sm text-gray-500 line-clamp-2 mb-4">
                  {template.description || 'No description available'}
                </p>

                <div className="flex items-center justify-between text-sm">
                  <div className="flex items-center gap-3 text-gray-500">
                    <span className="flex items-center gap-1">
                      <FileText size={14} />
                      {template.fieldCount || 0} fields
                    </span>
                    <span className="flex items-center gap-1">
                      <Clock size={14} />
                      {template.estimatedTime || '5 min'}
                    </span>
                  </div>
                </div>

                <div className="mt-4 pt-4 border-t border-gray-100">
                  <button className="text-primary-500 hover:text-primary-600 text-sm font-medium">
                    View Template →
                  </button>
                </div>
              </div>
            )
          })}
        </div>
      ) : (
        /* List View */
        <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
          <div className="divide-y divide-gray-100">
            {filteredTemplates.map((template) => {
              const CategoryIcon = getCategoryIcon(template.category)
              return (
                <div
                  key={template.id}
                  className="p-4 flex items-center gap-4 hover:bg-gray-50 transition-colors"
                >
                  <div className={`p-3 rounded-lg flex-shrink-0 ${getCategoryColor(template.category)}`}>
                    <CategoryIcon size={20} />
                  </div>

                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2">
                      <h3 className="font-semibold text-gray-900">{template.name}</h3>
                      {template.featured && (
                        <Star size={14} className="text-yellow-400 fill-yellow-400" />
                      )}
                    </div>
                    <p className="text-sm text-gray-500 truncate">
                      {template.description || 'No description available'}
                    </p>
                  </div>

                  <div className="flex items-center gap-6 text-sm text-gray-500">
                    <span className="hidden sm:flex items-center gap-1">
                      <FileText size={14} />
                      {template.fieldCount || 0} fields
                    </span>
                    <span className="hidden md:flex items-center gap-1">
                      <Clock size={14} />
                      {template.estimatedTime || '5 min'}
                    </span>
                    <span className="hidden lg:inline capitalize px-2 py-1 rounded bg-gray-100 text-gray-600">
                      {template.category}
                    </span>
                  </div>

                  <button className="text-primary-500 hover:text-primary-600 text-sm font-medium whitespace-nowrap">
                    View →
                  </button>
                </div>
              )
            })}
          </div>
        </div>
      )}

      {/* Info Box */}
      <div className="bg-blue-50 border border-blue-100 rounded-xl p-5">
        <h3 className="font-semibold text-blue-900 mb-2">Creating Templates</h3>
        <p className="text-blue-700 text-sm">
          Templates are created and managed through the iOS app. Use the Form Builder in the app to create
          custom templates with 18+ field types, conditional logic, and workflow automation.
        </p>
      </div>
    </div>
  )
}

export default Templates
