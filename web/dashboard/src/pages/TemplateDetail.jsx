import { useState, useEffect } from 'react'
import { useParams, useNavigate, Link } from 'react-router-dom'
import api from '../services/api'
import {
  ArrowLeft,
  FileText,
  Clock,
  Tag,
  Copy,
  Plus,
  ChevronDown,
  ChevronUp,
  Shield,
  Clipboard,
  Wrench,
  Users,
  Truck,
  Building,
  Heart,
  AlertTriangle
} from 'lucide-react'

function TemplateDetail() {
  const { id } = useParams()
  const navigate = useNavigate()
  const [template, setTemplate] = useState(null)
  const [isLoading, setIsLoading] = useState(true)
  const [expandedSections, setExpandedSections] = useState({})

  useEffect(() => {
    loadTemplate()
  }, [id])

  const loadTemplate = async () => {
    try {
      const data = await api.getTemplate(id)
      setTemplate(data)
      // Expand all sections by default
      const sections = {}
      if (data.fields) {
        data.fields.forEach((field, index) => {
          if (field.type === 'section') {
            sections[index] = true
          }
        })
      }
      setExpandedSections(sections)
    } catch (err) {
      console.error('Failed to load template:', err)
    } finally {
      setIsLoading(false)
    }
  }

  const toggleSection = (index) => {
    setExpandedSections((prev) => ({
      ...prev,
      [index]: !prev[index]
    }))
  }

  const getCategoryIcon = (category) => {
    const icons = {
      safety: Shield,
      inspection: Clipboard,
      maintenance: Wrench,
      hr: Users,
      delivery: Truck,
      facility: Building,
      health: Heart,
      incident: AlertTriangle,
      operations: Wrench,
      permits: Clipboard,
      logistics: Truck
    }
    return icons[category] || FileText
  }

  const getCategoryColor = (category) => {
    const colors = {
      safety: 'bg-red-100 text-red-600 border-red-200',
      inspection: 'bg-blue-100 text-blue-600 border-blue-200',
      maintenance: 'bg-yellow-100 text-yellow-600 border-yellow-200',
      hr: 'bg-purple-100 text-purple-600 border-purple-200',
      delivery: 'bg-green-100 text-green-600 border-green-200',
      facility: 'bg-indigo-100 text-indigo-600 border-indigo-200',
      health: 'bg-pink-100 text-pink-600 border-pink-200',
      incident: 'bg-orange-100 text-orange-600 border-orange-200',
      operations: 'bg-yellow-100 text-yellow-600 border-yellow-200',
      permits: 'bg-blue-100 text-blue-600 border-blue-200',
      logistics: 'bg-green-100 text-green-600 border-green-200'
    }
    return colors[category] || 'bg-gray-100 text-gray-600 border-gray-200'
  }

  const getFieldIcon = (type) => {
    const icons = {
      text: '📝',
      textarea: '📄',
      number: '🔢',
      email: '📧',
      phone: '📞',
      date: '📅',
      time: '⏰',
      checkbox: '☑️',
      yesNo: '✓/✗',
      dropdown: '▼',
      multiSelect: '☑️',
      signature: '✍️',
      photo: '📷',
      location: '📍',
      currency: '💰',
      rating: '⭐',
      slider: '━━●━━',
      section: '📂'
    }
    return icons[type] || '📋'
  }

  const getFieldTypeLabel = (type) => {
    const labels = {
      text: 'Text',
      textarea: 'Text Area',
      number: 'Number',
      email: 'Email',
      phone: 'Phone',
      date: 'Date',
      time: 'Time',
      checkbox: 'Checkbox',
      yesNo: 'Yes/No',
      dropdown: 'Dropdown',
      multiSelect: 'Multi-Select',
      signature: 'Signature',
      photo: 'Photo',
      location: 'Location',
      currency: 'Currency',
      rating: 'Rating',
      slider: 'Slider',
      section: 'Section Header'
    }
    return labels[type] || type
  }

  const handleUseTemplate = () => {
    // Navigate to form builder with this template
    navigate(`/builder?template=${id}`)
  }

  const handleDuplicateTemplate = () => {
    // For now, just show alert - would need backend support
    alert('Template duplication will be available soon. Use the iOS app to create custom templates.')
  }

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-screen">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-500" />
      </div>
    )
  }

  if (!template) {
    return (
      <div className="flex flex-col items-center justify-center h-screen">
        <FileText size={64} className="text-gray-300 mb-4" />
        <h2 className="text-xl font-semibold text-gray-900 mb-2">Template not found</h2>
        <p className="text-gray-500 mb-6">The template you're looking for doesn't exist.</p>
        <Link
          to="/templates"
          className="inline-flex items-center gap-2 px-4 py-2 bg-primary-500 text-white rounded-lg hover:bg-primary-600"
        >
          <ArrowLeft size={18} />
          Back to Templates
        </Link>
      </div>
    )
  }

  const CategoryIcon = getCategoryIcon(template.category)

  // Group fields by sections
  const sections = []
  let currentSection = { header: null, fields: [] }

  template.fields?.forEach((field, index) => {
    if (field.type === 'section') {
      if (currentSection.fields.length > 0 || currentSection.header) {
        sections.push({ ...currentSection, index: sections.length })
      }
      currentSection = { header: field, fields: [], index: sections.length }
    } else {
      currentSection.fields.push({ ...field, originalIndex: index })
    }
  })

  if (currentSection.fields.length > 0 || currentSection.header) {
    sections.push({ ...currentSection, index: sections.length })
  }

  return (
    <div className="space-y-6 pb-6">
      {/* Header */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
        <div className="flex items-start justify-between gap-4 mb-6">
          <div className="flex items-start gap-4 flex-1">
            <Link
              to="/templates"
              className="p-2 hover:bg-gray-100 rounded-lg transition-colors flex-shrink-0"
            >
              <ArrowLeft size={20} className="text-gray-600" />
            </Link>

            <div className="flex-1">
              <div className="flex items-center gap-2 mb-2">
                <div className={`inline-flex items-center gap-2 px-3 py-1 rounded-full text-sm font-medium border ${getCategoryColor(template.category)}`}>
                  <CategoryIcon size={14} />
                  {template.category?.charAt(0).toUpperCase() + template.category?.slice(1) || 'General'}
                </div>
              </div>

              <h1 className="text-2xl font-bold text-gray-900 mb-2">{template.name}</h1>
              
              {template.description && (
                <p className="text-gray-600 mb-4">{template.description}</p>
              )}

              <div className="flex flex-wrap gap-4 text-sm text-gray-500">
                <div className="flex items-center gap-1">
                  <FileText size={16} />
                  <span>{template.fieldCount || template.fields?.length || 0} fields</span>
                </div>
                <div className="flex items-center gap-1">
                  <Clock size={16} />
                  <span>{template.estimatedTime || 'Variable'}</span>
                </div>
                {template.version && (
                  <div className="flex items-center gap-1">
                    <Tag size={16} />
                    <span>Version {template.version}</span>
                  </div>
                )}
              </div>
            </div>
          </div>

          {/* Actions */}
          <div className="flex items-center gap-2 flex-shrink-0">
            <button
              onClick={handleDuplicateTemplate}
              className="inline-flex items-center gap-2 px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition-colors"
            >
              <Copy size={18} />
              Duplicate
            </button>
            <button
              onClick={handleUseTemplate}
              className="inline-flex items-center gap-2 px-4 py-2 bg-primary-500 text-white rounded-lg hover:bg-primary-600 transition-colors"
            >
              <Plus size={18} />
              Use Template
            </button>
          </div>
        </div>
      </div>

      {/* Template Fields */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-100">
        <div className="p-6 border-b border-gray-100">
          <h2 className="text-lg font-semibold text-gray-900">Form Fields</h2>
          <p className="text-sm text-gray-500 mt-1">
            {sections.length} section{sections.length !== 1 ? 's' : ''} • {template.fields?.length || 0} total fields
          </p>
        </div>

        <div className="divide-y divide-gray-100">
          {sections.length === 0 ? (
            <div className="p-8 text-center text-gray-500">
              <FileText size={48} className="mx-auto mb-3 text-gray-300" />
              <p>No fields defined in this template</p>
            </div>
          ) : (
            sections.map((section) => (
              <div key={section.index} className="p-6">
                {/* Section Header */}
                {section.header && (
                  <button
                    onClick={() => toggleSection(section.index)}
                    className="w-full flex items-center justify-between mb-4 p-3 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors"
                  >
                    <div className="flex items-center gap-3">
                      <span className="text-2xl">{getFieldIcon('section')}</span>
                      <div className="text-left">
                        <h3 className="font-semibold text-gray-900">{section.header.label}</h3>
                        {section.header.description && (
                          <p className="text-sm text-gray-500">{section.header.description}</p>
                        )}
                      </div>
                    </div>
                    <div className="flex items-center gap-3">
                      <span className="text-sm text-gray-500">{section.fields.length} field{section.fields.length !== 1 ? 's' : ''}</span>
                      {expandedSections[section.index] ? (
                        <ChevronUp size={20} className="text-gray-400" />
                      ) : (
                        <ChevronDown size={20} className="text-gray-400" />
                      )}
                    </div>
                  </button>
                )}

                {/* Section Fields */}
                {(expandedSections[section.index] || !section.header) && (
                  <div className="space-y-3">
                    {section.fields.length === 0 ? (
                      <p className="text-sm text-gray-400 italic pl-3">No fields in this section</p>
                    ) : (
                      section.fields.map((field) => (
                        <div
                          key={field.id || field.originalIndex}
                          className="flex items-start gap-3 p-3 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors"
                        >
                          <span className="text-xl flex-shrink-0">{getFieldIcon(field.type)}</span>
                          <div className="flex-1 min-w-0">
                            <div className="flex items-center gap-2 mb-1">
                              <h4 className="font-medium text-gray-900">{field.label}</h4>
                              {field.required && (
                                <span className="text-xs text-red-500 font-medium">Required</span>
                              )}
                            </div>
                            {field.description && (
                              <p className="text-sm text-gray-600 mb-2">{field.description}</p>
                            )}
                            {field.placeholder && (
                              <p className="text-xs text-gray-400 italic">Placeholder: {field.placeholder}</p>
                            )}
                            {field.options && field.options.length > 0 && (
                              <div className="mt-2">
                                <p className="text-xs text-gray-500 mb-1">Options:</p>
                                <div className="flex flex-wrap gap-1">
                                  {field.options.map((option, idx) => (
                                    <span
                                      key={idx}
                                      className="inline-block px-2 py-0.5 bg-white border border-gray-200 rounded text-xs text-gray-600"
                                    >
                                      {option}
                                    </span>
                                  ))}
                                </div>
                              </div>
                            )}
                          </div>
                          <span className="text-xs text-gray-500 bg-white px-2 py-1 rounded border border-gray-200 whitespace-nowrap">
                            {getFieldTypeLabel(field.type)}
                          </span>
                        </div>
                      ))
                    )}
                  </div>
                )}
              </div>
            ))
          )}
        </div>
      </div>

      {/* Info Box */}
      <div className="bg-blue-50 border border-blue-100 rounded-xl p-5">
        <h3 className="font-semibold text-blue-900 mb-2">Using This Template</h3>
        <p className="text-blue-700 text-sm mb-3">
          Click "Use Template" to create a new form based on this template. You can then fill in the form fields
          and submit it for approval.
        </p>
        <p className="text-blue-600 text-xs">
          Templates can be customized and managed through the iOS app's Form Builder feature.
        </p>
      </div>
    </div>
  )
}

export default TemplateDetail
