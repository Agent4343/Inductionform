import { useState, useEffect, useCallback } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import api from '../services/api'
import SignaturePad from '../components/SignaturePad'
import ImageUpload from '../components/ImageUpload'
import VoiceInput from '../components/VoiceInput'
import {
  ArrowLeft,
  Save,
  Send,
  Mic,
  Camera,
  MapPin,
  Check,
  X,
  Loader2,
  FileText,
  ChevronRight,
  ChevronLeft,
  ChevronDown,
  ChevronUp,
  RotateCcw,
  Eye,
  AlertCircle,
  CheckCircle,
  Clock,
  Trash2,
  Copy,
  Download
} from 'lucide-react'
import { downloadFormPDF } from '../utils/pdfExport'

function FormFiller() {
  const { templateId } = useParams()
  const navigate = useNavigate()

  const [template, setTemplate] = useState(null)
  const [formData, setFormData] = useState({})
  const [isLoading, setIsLoading] = useState(true)
  const [isSaving, setIsSaving] = useState(false)
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [lastSaved, setLastSaved] = useState(null)

  // Section states
  const [collapsedSections, setCollapsedSections] = useState({})
  const [currentSectionIndex, setCurrentSectionIndex] = useState(0)

  // Modal states
  const [showSignaturePad, setShowSignaturePad] = useState(false)
  const [showImageUpload, setShowImageUpload] = useState(false)
  const [showVoiceInput, setShowVoiceInput] = useState(false)
  const [showPreview, setShowPreview] = useState(false)
  const [showResetConfirm, setShowResetConfirm] = useState(false)
  const [activeFieldId, setActiveFieldId] = useState(null)

  // Validation
  const [errors, setErrors] = useState({})
  const [touched, setTouched] = useState({})

  // Location state
  const [location, setLocation] = useState(null)
  const [gettingLocation, setGettingLocation] = useState(false)

  // Auto-save timer
  useEffect(() => {
    const autoSaveInterval = setInterval(() => {
      if (Object.keys(formData).length > 0 && template) {
        saveToLocalStorage()
      }
    }, 30000) // Auto-save every 30 seconds

    return () => clearInterval(autoSaveInterval)
  }, [formData, template])

  // Load template
  useEffect(() => {
    loadTemplate()
  }, [templateId])

  // Load saved draft
  useEffect(() => {
    if (template) {
      const savedDraft = localStorage.getItem(`draft-${templateId}`)
      if (savedDraft) {
        try {
          const parsed = JSON.parse(savedDraft)
          setFormData(parsed.formData || {})
          setLastSaved(parsed.savedAt)
        } catch (e) {
          console.log('No valid draft found')
        }
      }
    }
  }, [template, templateId])

  const loadTemplate = async () => {
    try {
      let tmpl = await api.getTemplate(templateId).catch(() => null)

      if (!tmpl) {
        const shared = await api.getSharedTemplates()
        tmpl = shared.find(t => t.id === templateId)
      }

      if (!tmpl) {
        const local = JSON.parse(localStorage.getItem('localTemplates') || '[]')
        tmpl = local.find(t => t.id === templateId)
      }

      if (tmpl) {
        setTemplate(tmpl)
        const initialData = {}
        tmpl.fields?.forEach(field => {
          if (field.type === 'checkbox') {
            initialData[field.id] = false
          } else if (field.type === 'multiSelect') {
            initialData[field.id] = []
          } else {
            initialData[field.id] = ''
          }
        })
        setFormData(prev => ({ ...initialData, ...prev }))
      }
    } catch (err) {
      console.error('Failed to load template:', err)
    } finally {
      setIsLoading(false)
    }
  }

  const updateField = (fieldId, value) => {
    setFormData(prev => ({ ...prev, [fieldId]: value }))
    setTouched(prev => ({ ...prev, [fieldId]: true }))

    // Clear error when field is updated
    if (errors[fieldId]) {
      setErrors(prev => {
        const newErrors = { ...prev }
        delete newErrors[fieldId]
        return newErrors
      })
    }
  }

  const validateForm = () => {
    const newErrors = {}
    template?.fields?.forEach(field => {
      if (field.required && field.type !== 'section') {
        const value = formData[field.id]
        if (value === '' || value === null || value === undefined ||
            (Array.isArray(value) && value.length === 0)) {
          newErrors[field.id] = `${field.label} is required`
        }
      }
    })
    setErrors(newErrors)
    return Object.keys(newErrors).length === 0
  }

  const saveToLocalStorage = () => {
    const draft = {
      formData,
      savedAt: new Date().toISOString()
    }
    localStorage.setItem(`draft-${templateId}`, JSON.stringify(draft))
    setLastSaved(draft.savedAt)
  }

  const getLocation = async (fieldId) => {
    setGettingLocation(true)
    setActiveFieldId(fieldId)
    try {
      const pos = await new Promise((resolve, reject) => {
        navigator.geolocation.getCurrentPosition(resolve, reject, {
          enableHighAccuracy: true,
          timeout: 10000
        })
      })
      const loc = {
        latitude: pos.coords.latitude,
        longitude: pos.coords.longitude,
        accuracy: pos.coords.accuracy,
        timestamp: new Date().toISOString()
      }
      setLocation(loc)
      updateField(fieldId, loc)
    } catch (err) {
      alert('Could not get location. Please check your permissions.')
    } finally {
      setGettingLocation(false)
      setActiveFieldId(null)
    }
  }

  const handleSignatureSave = (signatureData) => {
    if (activeFieldId) {
      updateField(activeFieldId, signatureData)
    }
    setShowSignaturePad(false)
    setActiveFieldId(null)
  }

  const handleImageSave = (images) => {
    if (activeFieldId) {
      updateField(activeFieldId, images)
    }
    setShowImageUpload(false)
    setActiveFieldId(null)
  }

  const handleVoiceResult = (text) => {
    if (activeFieldId) {
      const currentValue = formData[activeFieldId] || ''
      updateField(activeFieldId, currentValue ? `${currentValue} ${text}` : text)
    }
    setShowVoiceInput(false)
    setActiveFieldId(null)
  }

  const resetForm = () => {
    const initialData = {}
    template?.fields?.forEach(field => {
      if (field.type === 'checkbox') {
        initialData[field.id] = false
      } else if (field.type === 'multiSelect') {
        initialData[field.id] = []
      } else {
        initialData[field.id] = ''
      }
    })
    setFormData(initialData)
    setErrors({})
    setTouched({})
    localStorage.removeItem(`draft-${templateId}`)
    setLastSaved(null)
    setShowResetConfirm(false)
  }

  const saveForm = async (submit = false) => {
    if (submit && !validateForm()) {
      // Scroll to first error
      const firstErrorField = Object.keys(errors)[0]
      document.getElementById(`field-${firstErrorField}`)?.scrollIntoView({ behavior: 'smooth' })
      return
    }

    const saveFn = submit ? setIsSubmitting : setIsSaving
    saveFn(true)

    const form = {
      templateId,
      templateName: template.name,
      title: `${template.name} - ${new Date().toLocaleDateString()}`,
      fields: template.fields.map(f => ({
        ...f,
        value: formData[f.id]
      })),
      status: submit ? 'submitted' : 'draft',
      location,
      createdAt: new Date().toISOString()
    }

    try {
      await api.createForm(form)
      localStorage.removeItem(`draft-${templateId}`)
      alert(submit ? 'Form submitted successfully!' : 'Form saved as draft.')
      navigate('/forms')
    } catch (err) {
      const localForms = JSON.parse(localStorage.getItem('localForms') || '[]')
      localForms.push({ ...form, id: `local-${Date.now()}` })
      localStorage.setItem('localForms', JSON.stringify(localForms))
      localStorage.removeItem(`draft-${templateId}`)
      alert(submit ? 'Form saved locally. It will sync when connected.' : 'Draft saved locally.')
      if (submit) navigate('/forms')
    } finally {
      saveFn(false)
    }
  }

  const exportPDF = async () => {
    const form = {
      title: `${template.name} - ${new Date().toLocaleDateString()}`,
      name: template.name,
      description: template.description,
      fields: template.fields.map(f => ({
        ...f,
        value: formData[f.id]
      })),
      createdAt: new Date().toISOString()
    }
    await downloadFormPDF(form, { includeSignatures: true })
  }

  const toggleSection = (sectionId) => {
    setCollapsedSections(prev => ({
      ...prev,
      [sectionId]: !prev[sectionId]
    }))
  }

  // Get sections with their fields
  const getSections = () => {
    if (!template?.fields) return []

    const sections = []
    let currentSection = { id: 'default', label: 'Form Fields', fields: [] }

    template.fields.forEach(field => {
      if (field.type === 'section') {
        if (currentSection.fields.length > 0) {
          sections.push(currentSection)
        }
        currentSection = { id: field.id, label: field.label, description: field.description, fields: [] }
      } else {
        currentSection.fields.push(field)
      }
    })

    if (currentSection.fields.length > 0) {
      sections.push(currentSection)
    }

    return sections
  }

  const sections = getSections()

  // Calculate progress
  const getProgress = () => {
    if (!template?.fields) return { completed: 0, total: 0, percent: 0 }

    const requiredFields = template.fields.filter(f => f.required && f.type !== 'section')
    const completedFields = requiredFields.filter(f => {
      const value = formData[f.id]
      return value !== '' && value !== null && value !== undefined &&
             !(Array.isArray(value) && value.length === 0)
    })

    return {
      completed: completedFields.length,
      total: requiredFields.length,
      percent: requiredFields.length > 0
        ? Math.round((completedFields.length / requiredFields.length) * 100)
        : 100
    }
  }

  const progress = getProgress()

  const renderField = (field) => {
    const value = formData[field.id]
    const hasError = errors[field.id]
    const isTouched = touched[field.id]

    const fieldClasses = `input w-full ${hasError ? 'border-red-500 focus:ring-red-500' : ''}`

    return (
      <div key={field.id} id={`field-${field.id}`} className="mb-5">
        <label className="flex items-center justify-between text-sm font-medium text-gray-700 mb-2">
          <span>
            {field.label}
            {field.required && <span className="text-red-500 ml-1">*</span>}
          </span>
          {isTouched && !hasError && value && (
            <CheckCircle size={16} className="text-green-500" />
          )}
        </label>

        {/* Text input with voice */}
        {['text', 'email', 'phone'].includes(field.type) && (
          <div className="relative">
            <input
              type={field.type === 'email' ? 'email' : field.type === 'phone' ? 'tel' : 'text'}
              value={value || ''}
              onChange={(e) => updateField(field.id, e.target.value)}
              placeholder={field.placeholder}
              className={`${fieldClasses} pr-10`}
            />
            <button
              type="button"
              onClick={() => { setActiveFieldId(field.id); setShowVoiceInput(true) }}
              className="absolute right-2 top-1/2 -translate-y-1/2 p-1.5 hover:bg-gray-100 rounded-full"
              title="Voice input"
            >
              <Mic size={18} className="text-gray-400" />
            </button>
          </div>
        )}

        {/* Textarea with voice */}
        {field.type === 'textarea' && (
          <div className="relative">
            <textarea
              value={value || ''}
              onChange={(e) => updateField(field.id, e.target.value)}
              placeholder={field.placeholder}
              rows={4}
              className={`${fieldClasses} resize-none pr-10`}
            />
            <button
              type="button"
              onClick={() => { setActiveFieldId(field.id); setShowVoiceInput(true) }}
              className="absolute right-2 top-2 p-1.5 hover:bg-gray-100 rounded-full"
              title="Voice input"
            >
              <Mic size={18} className="text-gray-400" />
            </button>
          </div>
        )}

        {/* Number */}
        {field.type === 'number' && (
          <input
            type="number"
            value={value || ''}
            onChange={(e) => updateField(field.id, e.target.value)}
            placeholder={field.placeholder}
            className={fieldClasses}
          />
        )}

        {/* Currency */}
        {field.type === 'currency' && (
          <div className="relative">
            <span className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-500 font-medium">$</span>
            <input
              type="number"
              step="0.01"
              value={value || ''}
              onChange={(e) => updateField(field.id, e.target.value)}
              placeholder="0.00"
              className={`${fieldClasses} pl-8`}
            />
          </div>
        )}

        {/* Date */}
        {field.type === 'date' && (
          <input
            type="date"
            value={value || ''}
            onChange={(e) => updateField(field.id, e.target.value)}
            className={fieldClasses}
          />
        )}

        {/* Time */}
        {field.type === 'time' && (
          <input
            type="time"
            value={value || ''}
            onChange={(e) => updateField(field.id, e.target.value)}
            className={fieldClasses}
          />
        )}

        {/* Checkbox */}
        {field.type === 'checkbox' && (
          <label className="flex items-center gap-3 cursor-pointer p-3 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors">
            <input
              type="checkbox"
              checked={value || false}
              onChange={(e) => updateField(field.id, e.target.checked)}
              className="h-5 w-5 text-primary-500 rounded border-gray-300"
            />
            <span className="text-gray-700">{field.description || 'Check if applicable'}</span>
          </label>
        )}

        {/* Yes/No/NA */}
        {field.type === 'yesNo' && (
          <div className="grid grid-cols-3 gap-2">
            {['Yes', 'No', 'N/A'].map(opt => (
              <button
                key={opt}
                type="button"
                onClick={() => updateField(field.id, opt.toLowerCase())}
                className={`py-3 px-4 rounded-lg border-2 font-medium transition-all ${
                  value === opt.toLowerCase()
                    ? opt === 'Yes' ? 'bg-green-500 border-green-500 text-white shadow-lg scale-105'
                      : opt === 'No' ? 'bg-red-500 border-red-500 text-white shadow-lg scale-105'
                      : 'bg-gray-500 border-gray-500 text-white shadow-lg scale-105'
                    : 'border-gray-200 text-gray-700 hover:border-gray-300 hover:bg-gray-50'
                }`}
              >
                {opt}
              </button>
            ))}
          </div>
        )}

        {/* Dropdown */}
        {field.type === 'dropdown' && (
          <select
            value={value || ''}
            onChange={(e) => updateField(field.id, e.target.value)}
            className={fieldClasses}
          >
            <option value="">Select an option</option>
            {field.options?.map((opt, i) => (
              <option key={i} value={opt}>{opt}</option>
            ))}
          </select>
        )}

        {/* Multi-select */}
        {field.type === 'multiSelect' && (
          <div className="space-y-2 bg-gray-50 rounded-lg p-3">
            {field.options?.map((opt, i) => (
              <label key={i} className="flex items-center gap-3 cursor-pointer p-2 hover:bg-white rounded transition-colors">
                <input
                  type="checkbox"
                  checked={(value || []).includes(opt)}
                  onChange={(e) => {
                    const current = value || []
                    if (e.target.checked) {
                      updateField(field.id, [...current, opt])
                    } else {
                      updateField(field.id, current.filter(v => v !== opt))
                    }
                  }}
                  className="h-5 w-5 text-primary-500 rounded border-gray-300"
                />
                <span className="text-gray-700">{opt}</span>
              </label>
            ))}
          </div>
        )}

        {/* Rating */}
        {field.type === 'rating' && (
          <div className="flex gap-2 items-center">
            {[1, 2, 3, 4, 5].map(star => (
              <button
                key={star}
                type="button"
                onClick={() => updateField(field.id, star)}
                className={`text-4xl transition-all hover:scale-110 ${
                  star <= (value || 0) ? 'text-yellow-400' : 'text-gray-300'
                }`}
              >
                ★
              </button>
            ))}
            {value > 0 && (
              <span className="ml-2 text-gray-500 font-medium">{value}/5</span>
            )}
          </div>
        )}

        {/* Slider */}
        {field.type === 'slider' && (
          <div className="space-y-3">
            <input
              type="range"
              min="0"
              max="100"
              value={value || 50}
              onChange={(e) => updateField(field.id, parseInt(e.target.value))}
              className="w-full h-2 bg-gray-200 rounded-lg appearance-none cursor-pointer accent-primary-500"
            />
            <div className="flex justify-between items-center">
              <span className="text-sm text-gray-500">0</span>
              <span className="px-4 py-1 bg-primary-500 text-white rounded-full font-medium">{value || 50}</span>
              <span className="text-sm text-gray-500">100</span>
            </div>
          </div>
        )}

        {/* Signature */}
        {field.type === 'signature' && (
          <div>
            {value?.signatureData ? (
              <div className="border-2 border-green-200 rounded-lg p-4 bg-green-50">
                <div className="flex items-start justify-between">
                  <div className="flex-1">
                    <img src={value.signatureData} alt="Signature" className="h-20 bg-white rounded border" />
                    <p className="text-sm text-green-700 mt-2 flex items-center gap-1">
                      <CheckCircle size={14} />
                      Signed: {new Date(value.timestamp).toLocaleString()}
                    </p>
                  </div>
                  <button
                    type="button"
                    onClick={() => updateField(field.id, null)}
                    className="p-2 text-red-500 hover:bg-red-50 rounded-lg"
                    title="Clear signature"
                  >
                    <Trash2 size={18} />
                  </button>
                </div>
              </div>
            ) : (
              <button
                type="button"
                onClick={() => { setActiveFieldId(field.id); setShowSignaturePad(true) }}
                className={`w-full py-10 border-2 border-dashed rounded-lg transition-all flex flex-col items-center gap-2 ${
                  hasError ? 'border-red-300 bg-red-50' : 'border-gray-300 hover:border-primary-500 hover:bg-primary-50'
                }`}
              >
                <FileText size={32} className={hasError ? 'text-red-400' : 'text-gray-400'} />
                <span className={hasError ? 'text-red-600' : 'text-gray-600'}>Tap to sign</span>
              </button>
            )}
          </div>
        )}

        {/* Photo */}
        {field.type === 'photo' && (
          <div>
            {value && value.length > 0 ? (
              <div className="space-y-3">
                <div className="grid grid-cols-3 gap-2">
                  {value.map((img, i) => (
                    <div key={i} className="relative group aspect-square">
                      <img
                        src={img.data}
                        alt={`Photo ${i + 1}`}
                        className="w-full h-full object-cover rounded-lg"
                      />
                      <button
                        type="button"
                        onClick={() => updateField(field.id, value.filter((_, idx) => idx !== i))}
                        className="absolute top-1 right-1 p-1 bg-red-500 text-white rounded-full opacity-0 group-hover:opacity-100 transition-opacity"
                      >
                        <X size={12} />
                      </button>
                    </div>
                  ))}
                </div>
                <button
                  type="button"
                  onClick={() => { setActiveFieldId(field.id); setShowImageUpload(true) }}
                  className="text-primary-500 text-sm hover:underline flex items-center gap-1"
                >
                  <Camera size={16} /> Add more photos
                </button>
              </div>
            ) : (
              <button
                type="button"
                onClick={() => { setActiveFieldId(field.id); setShowImageUpload(true) }}
                className={`w-full py-10 border-2 border-dashed rounded-lg transition-all flex flex-col items-center gap-2 ${
                  hasError ? 'border-red-300 bg-red-50' : 'border-gray-300 hover:border-primary-500 hover:bg-primary-50'
                }`}
              >
                <Camera size={32} className={hasError ? 'text-red-400' : 'text-gray-400'} />
                <span className={hasError ? 'text-red-600' : 'text-gray-600'}>Add photos</span>
              </button>
            )}
          </div>
        )}

        {/* Location */}
        {field.type === 'location' && (
          <div>
            {value ? (
              <div className="border-2 border-green-200 rounded-lg p-4 bg-green-50">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2 text-green-700">
                    <MapPin size={18} />
                    <span className="font-mono text-sm">
                      {value.latitude?.toFixed(6)}, {value.longitude?.toFixed(6)}
                    </span>
                  </div>
                  <button
                    type="button"
                    onClick={() => updateField(field.id, null)}
                    className="p-2 text-red-500 hover:bg-red-50 rounded-lg"
                  >
                    <Trash2 size={16} />
                  </button>
                </div>
                <a
                  href={`https://maps.google.com/?q=${value.latitude},${value.longitude}`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-primary-500 text-sm hover:underline mt-2 inline-block"
                >
                  View on map →
                </a>
              </div>
            ) : (
              <button
                type="button"
                onClick={() => getLocation(field.id)}
                disabled={gettingLocation}
                className={`w-full py-6 border-2 border-dashed rounded-lg transition-all flex items-center justify-center gap-2 ${
                  hasError ? 'border-red-300 bg-red-50' : 'border-gray-300 hover:border-primary-500'
                }`}
              >
                {gettingLocation && activeFieldId === field.id ? (
                  <>
                    <Loader2 size={20} className="animate-spin text-primary-500" />
                    <span className="text-gray-600">Getting location...</span>
                  </>
                ) : (
                  <>
                    <MapPin size={20} className={hasError ? 'text-red-400' : 'text-gray-400'} />
                    <span className={hasError ? 'text-red-600' : 'text-gray-600'}>Capture GPS location</span>
                  </>
                )}
              </button>
            )}
          </div>
        )}

        {/* Error message */}
        {hasError && (
          <p className="text-red-500 text-sm mt-1 flex items-center gap-1">
            <AlertCircle size={14} />
            {errors[field.id]}
          </p>
        )}

        {/* Help text */}
        {field.description && field.type !== 'checkbox' && (
          <p className="text-sm text-gray-500 mt-1">{field.description}</p>
        )}
      </div>
    )
  }

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-64">
        <Loader2 size={32} className="animate-spin text-primary-500" />
      </div>
    )
  }

  if (!template) {
    return (
      <div className="text-center py-12">
        <FileText size={48} className="mx-auto mb-4 text-gray-300" />
        <h2 className="text-lg font-medium text-gray-900">Template not found</h2>
        <button onClick={() => navigate('/templates')} className="btn btn-primary mt-4">
          Browse Templates
        </button>
      </div>
    )
  }

  return (
    <div className="max-w-3xl mx-auto pb-24">
      {/* Header */}
      <div className="sticky top-0 z-20 bg-gray-50 -mx-4 px-4 py-3 mb-4 border-b border-gray-200">
        <div className="flex items-center gap-3">
          <button
            onClick={() => navigate(-1)}
            className="p-2 hover:bg-white rounded-lg"
          >
            <ArrowLeft size={20} />
          </button>
          <div className="flex-1 min-w-0">
            <h1 className="text-lg font-bold text-gray-900 truncate">{template.name}</h1>
            <div className="flex items-center gap-3 text-sm text-gray-500">
              <span>{progress.completed}/{progress.total} required</span>
              {lastSaved && (
                <span className="flex items-center gap-1">
                  <Clock size={12} />
                  Saved {new Date(lastSaved).toLocaleTimeString()}
                </span>
              )}
            </div>
          </div>
          <button
            onClick={() => setShowPreview(true)}
            className="p-2 hover:bg-white rounded-lg"
            title="Preview"
          >
            <Eye size={20} className="text-gray-500" />
          </button>
        </div>

        {/* Progress Bar */}
        <div className="mt-3">
          <div className="h-2 bg-gray-200 rounded-full overflow-hidden">
            <div
              className={`h-full transition-all duration-500 ${
                progress.percent === 100 ? 'bg-green-500' : 'bg-primary-500'
              }`}
              style={{ width: `${progress.percent}%` }}
            />
          </div>
        </div>
      </div>

      {/* Sections */}
      <div className="space-y-4">
        {sections.map((section, index) => (
          <div key={section.id} className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
            {/* Section Header */}
            <button
              onClick={() => toggleSection(section.id)}
              className="w-full px-5 py-4 flex items-center justify-between bg-gray-50 hover:bg-gray-100 transition-colors"
            >
              <div className="flex items-center gap-3">
                <span className="w-7 h-7 bg-primary-500 text-white rounded-full flex items-center justify-center text-sm font-medium">
                  {index + 1}
                </span>
                <div className="text-left">
                  <h3 className="font-semibold text-gray-900">{section.label}</h3>
                  {section.description && (
                    <p className="text-sm text-gray-500">{section.description}</p>
                  )}
                </div>
              </div>
              {collapsedSections[section.id] ? (
                <ChevronDown size={20} className="text-gray-400" />
              ) : (
                <ChevronUp size={20} className="text-gray-400" />
              )}
            </button>

            {/* Section Fields */}
            {!collapsedSections[section.id] && (
              <div className="px-5 py-4">
                {section.fields.map(renderField)}
              </div>
            )}
          </div>
        ))}
      </div>

      {/* Bottom Action Bar */}
      <div className="fixed bottom-0 left-0 right-0 bg-white border-t border-gray-200 p-4 lg:pl-[calc(256px+1rem)]">
        <div className="max-w-3xl mx-auto flex gap-3">
          <button
            onClick={() => setShowResetConfirm(true)}
            className="p-3 text-gray-500 hover:bg-gray-100 rounded-lg"
            title="Reset form"
          >
            <RotateCcw size={20} />
          </button>
          <button
            onClick={exportPDF}
            className="p-3 text-gray-500 hover:bg-gray-100 rounded-lg"
            title="Export PDF"
          >
            <Download size={20} />
          </button>
          <div className="flex-1" />
          <button
            onClick={() => saveForm(false)}
            disabled={isSaving}
            className="btn btn-secondary flex items-center gap-2 px-6"
          >
            {isSaving ? <Loader2 size={16} className="animate-spin" /> : <Save size={16} />}
            Save Draft
          </button>
          <button
            onClick={() => saveForm(true)}
            disabled={isSubmitting || progress.percent < 100}
            className="btn btn-primary flex items-center gap-2 px-6 disabled:opacity-50"
          >
            {isSubmitting ? <Loader2 size={16} className="animate-spin" /> : <Send size={16} />}
            Submit
          </button>
        </div>
      </div>

      {/* Preview Modal */}
      {showPreview && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50 overflow-y-auto">
          <div className="bg-white rounded-xl max-w-2xl w-full max-h-[90vh] overflow-y-auto">
            <div className="sticky top-0 bg-white border-b border-gray-200 px-6 py-4 flex items-center justify-between">
              <h3 className="text-lg font-bold text-gray-900">Form Preview</h3>
              <button onClick={() => setShowPreview(false)} className="p-2 hover:bg-gray-100 rounded-lg">
                <X size={20} />
              </button>
            </div>
            <div className="p-6">
              <h2 className="text-xl font-bold text-gray-900 mb-4">{template.name}</h2>
              {sections.map(section => (
                <div key={section.id} className="mb-6">
                  <h4 className="font-semibold text-gray-700 border-b pb-2 mb-3">{section.label}</h4>
                  {section.fields.map(field => {
                    const value = formData[field.id]
                    return (
                      <div key={field.id} className="flex justify-between py-2 border-b border-gray-100">
                        <span className="text-gray-600">{field.label}</span>
                        <span className="text-gray-900 font-medium">
                          {field.type === 'signature' && value?.signatureData ? '✓ Signed' :
                           field.type === 'photo' && value?.length ? `${value.length} photo(s)` :
                           field.type === 'location' && value ? `${value.latitude?.toFixed(4)}, ${value.longitude?.toFixed(4)}` :
                           field.type === 'yesNo' ? (value || '-').toUpperCase() :
                           Array.isArray(value) ? value.join(', ') || '-' :
                           value || '-'}
                        </span>
                      </div>
                    )
                  })}
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* Reset Confirmation Modal */}
      {showResetConfirm && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-xl max-w-sm w-full p-6">
            <h3 className="text-lg font-bold text-gray-900 mb-2">Reset Form?</h3>
            <p className="text-gray-500 mb-6">This will clear all entered data. This action cannot be undone.</p>
            <div className="flex gap-3">
              <button onClick={() => setShowResetConfirm(false)} className="btn btn-secondary flex-1">
                Cancel
              </button>
              <button onClick={resetForm} className="btn bg-red-500 text-white hover:bg-red-600 flex-1">
                Reset
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Modals */}
      {showSignaturePad && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
          <SignaturePad
            onSave={handleSignatureSave}
            onCancel={() => { setShowSignaturePad(false); setActiveFieldId(null) }}
          />
        </div>
      )}

      {showImageUpload && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
          <ImageUpload
            onSave={handleImageSave}
            onCancel={() => { setShowImageUpload(false); setActiveFieldId(null) }}
            existingImages={formData[activeFieldId] || []}
          />
        </div>
      )}

      {showVoiceInput && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
          <VoiceInput
            onResult={handleVoiceResult}
            onCancel={() => { setShowVoiceInput(false); setActiveFieldId(null) }}
          />
        </div>
      )}
    </div>
  )
}

export default FormFiller
