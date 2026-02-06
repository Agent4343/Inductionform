import { useState, useEffect } from 'react'
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
  ChevronLeft
} from 'lucide-react'

function FormFiller() {
  const { templateId } = useParams()
  const navigate = useNavigate()

  const [template, setTemplate] = useState(null)
  const [formData, setFormData] = useState({})
  const [currentSection, setCurrentSection] = useState(0)
  const [isLoading, setIsLoading] = useState(true)
  const [isSaving, setIsSaving] = useState(false)
  const [isSubmitting, setIsSubmitting] = useState(false)

  // Modal states
  const [showSignaturePad, setShowSignaturePad] = useState(false)
  const [showImageUpload, setShowImageUpload] = useState(false)
  const [showVoiceInput, setShowVoiceInput] = useState(false)
  const [activeFieldId, setActiveFieldId] = useState(null)

  // Location state
  const [location, setLocation] = useState(null)
  const [gettingLocation, setGettingLocation] = useState(false)

  useEffect(() => {
    loadTemplate()
  }, [templateId])

  const loadTemplate = async () => {
    try {
      // Try to load from API first
      let tmpl = await api.getTemplate(templateId).catch(() => null)

      // If not found, try shared templates
      if (!tmpl) {
        const shared = await api.getSharedTemplates()
        tmpl = shared.find(t => t.id === templateId)
      }

      // If still not found, check local templates
      if (!tmpl) {
        const local = JSON.parse(localStorage.getItem('localTemplates') || '[]')
        tmpl = local.find(t => t.id === templateId)
      }

      if (tmpl) {
        setTemplate(tmpl)
        // Initialize form data with empty values
        const initialData = {}
        tmpl.fields?.forEach(field => {
          initialData[field.id] = field.type === 'checkbox' ? false : ''
        })
        setFormData(initialData)
      }
    } catch (err) {
      console.error('Failed to load template:', err)
    } finally {
      setIsLoading(false)
    }
  }

  const updateField = (fieldId, value) => {
    setFormData(prev => ({ ...prev, [fieldId]: value }))
  }

  const getLocation = async () => {
    setGettingLocation(true)
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
      if (activeFieldId) {
        updateField(activeFieldId, loc)
      }
    } catch (err) {
      alert('Could not get location. Please check your permissions.')
    } finally {
      setGettingLocation(false)
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

  const saveForm = async (submit = false) => {
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
      alert(submit ? 'Form submitted successfully!' : 'Form saved as draft.')
      navigate('/forms')
    } catch (err) {
      // Save locally as fallback
      const localForms = JSON.parse(localStorage.getItem('localForms') || '[]')
      localForms.push({ ...form, id: `local-${Date.now()}` })
      localStorage.setItem('localForms', JSON.stringify(localForms))
      alert(submit ? 'Form saved locally. It will sync when connected.' : 'Draft saved locally.')
    } finally {
      saveFn(false)
    }
  }

  const getSections = () => {
    if (!template?.fields) return [[]]

    const sections = []
    let currentFields = []

    template.fields.forEach(field => {
      if (field.type === 'section') {
        if (currentFields.length > 0) {
          sections.push(currentFields)
        }
        currentFields = [field]
      } else {
        currentFields.push(field)
      }
    })

    if (currentFields.length > 0) {
      sections.push(currentFields)
    }

    return sections.length > 0 ? sections : [[]]
  }

  const sections = getSections()
  const currentFields = sections[currentSection] || []
  const progress = template?.fields
    ? Math.round((Object.values(formData).filter(v => v !== '' && v !== false && v !== null).length / template.fields.filter(f => f.type !== 'section').length) * 100)
    : 0

  const renderField = (field) => {
    const value = formData[field.id]

    if (field.type === 'section') {
      return (
        <div key={field.id} className="mb-6">
          <h3 className="text-lg font-bold text-gray-900 border-b border-gray-200 pb-2">
            {field.label}
          </h3>
          {field.description && (
            <p className="text-sm text-gray-500 mt-1">{field.description}</p>
          )}
        </div>
      )
    }

    return (
      <div key={field.id} className="mb-6">
        <label className="block text-sm font-medium text-gray-700 mb-2">
          {field.label}
          {field.required && <span className="text-red-500 ml-1">*</span>}
        </label>

        {/* Text input with voice */}
        {['text', 'email', 'phone'].includes(field.type) && (
          <div className="relative">
            <input
              type={field.type === 'email' ? 'email' : field.type === 'phone' ? 'tel' : 'text'}
              value={value || ''}
              onChange={(e) => updateField(field.id, e.target.value)}
              placeholder={field.placeholder}
              className="input w-full pr-10"
            />
            <button
              onClick={() => { setActiveFieldId(field.id); setShowVoiceInput(true) }}
              className="absolute right-2 top-1/2 -translate-y-1/2 p-1 hover:bg-gray-100 rounded"
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
              className="input w-full resize-none"
            />
            <button
              onClick={() => { setActiveFieldId(field.id); setShowVoiceInput(true) }}
              className="absolute right-2 top-2 p-1 hover:bg-gray-100 rounded"
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
            className="input w-full"
          />
        )}

        {/* Currency */}
        {field.type === 'currency' && (
          <div className="relative">
            <span className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-500">$</span>
            <input
              type="number"
              step="0.01"
              value={value || ''}
              onChange={(e) => updateField(field.id, e.target.value)}
              placeholder="0.00"
              className="input w-full pl-8"
            />
          </div>
        )}

        {/* Date */}
        {field.type === 'date' && (
          <input
            type="date"
            value={value || ''}
            onChange={(e) => updateField(field.id, e.target.value)}
            className="input w-full"
          />
        )}

        {/* Time */}
        {field.type === 'time' && (
          <input
            type="time"
            value={value || ''}
            onChange={(e) => updateField(field.id, e.target.value)}
            className="input w-full"
          />
        )}

        {/* Checkbox */}
        {field.type === 'checkbox' && (
          <label className="flex items-center gap-3 cursor-pointer">
            <input
              type="checkbox"
              checked={value || false}
              onChange={(e) => updateField(field.id, e.target.checked)}
              className="h-5 w-5 text-primary-500 rounded"
            />
            <span className="text-gray-700">{field.description || 'Check if applicable'}</span>
          </label>
        )}

        {/* Yes/No/NA */}
        {field.type === 'yesNo' && (
          <div className="flex gap-3">
            {['Yes', 'No', 'N/A'].map(opt => (
              <button
                key={opt}
                onClick={() => updateField(field.id, opt.toLowerCase())}
                className={`flex-1 py-3 px-4 rounded-lg border-2 font-medium transition-colors ${
                  value === opt.toLowerCase()
                    ? opt === 'Yes' ? 'bg-green-500 border-green-500 text-white'
                      : opt === 'No' ? 'bg-red-500 border-red-500 text-white'
                      : 'bg-gray-500 border-gray-500 text-white'
                    : 'border-gray-200 text-gray-700 hover:border-gray-300'
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
            className="input w-full"
          >
            <option value="">Select an option</option>
            {field.options?.map((opt, i) => (
              <option key={i} value={opt}>{opt}</option>
            ))}
          </select>
        )}

        {/* Multi-select */}
        {field.type === 'multiSelect' && (
          <div className="space-y-2">
            {field.options?.map((opt, i) => (
              <label key={i} className="flex items-center gap-3 cursor-pointer">
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
                  className="h-5 w-5 text-primary-500 rounded"
                />
                <span className="text-gray-700">{opt}</span>
              </label>
            ))}
          </div>
        )}

        {/* Rating */}
        {field.type === 'rating' && (
          <div className="flex gap-2">
            {[1, 2, 3, 4, 5].map(star => (
              <button
                key={star}
                onClick={() => updateField(field.id, star)}
                className={`text-3xl transition-colors ${
                  star <= (value || 0) ? 'text-yellow-400' : 'text-gray-300'
                }`}
              >
                ★
              </button>
            ))}
          </div>
        )}

        {/* Slider */}
        {field.type === 'slider' && (
          <div className="space-y-2">
            <input
              type="range"
              min="0"
              max="100"
              value={value || 50}
              onChange={(e) => updateField(field.id, parseInt(e.target.value))}
              className="w-full"
            />
            <div className="flex justify-between text-sm text-gray-500">
              <span>0</span>
              <span className="font-medium text-primary-500">{value || 50}</span>
              <span>100</span>
            </div>
          </div>
        )}

        {/* Signature */}
        {field.type === 'signature' && (
          <div>
            {value?.signatureData ? (
              <div className="border rounded-lg p-4 bg-gray-50">
                <img src={value.signatureData} alt="Signature" className="h-20 mx-auto" />
                <p className="text-sm text-gray-500 text-center mt-2">
                  Signed: {new Date(value.timestamp).toLocaleString()}
                </p>
                <button
                  onClick={() => updateField(field.id, null)}
                  className="text-red-500 text-sm hover:underline block mx-auto mt-2"
                >
                  Clear signature
                </button>
              </div>
            ) : (
              <button
                onClick={() => { setActiveFieldId(field.id); setShowSignaturePad(true) }}
                className="w-full py-8 border-2 border-dashed border-gray-300 rounded-lg hover:border-primary-500 transition-colors flex flex-col items-center gap-2"
              >
                <FileText size={32} className="text-gray-400" />
                <span className="text-gray-600">Tap to sign</span>
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
                    <img
                      key={i}
                      src={img.data}
                      alt={`Photo ${i + 1}`}
                      className="w-full h-24 object-cover rounded-lg"
                    />
                  ))}
                </div>
                <button
                  onClick={() => { setActiveFieldId(field.id); setShowImageUpload(true) }}
                  className="text-primary-500 text-sm hover:underline"
                >
                  Add more photos
                </button>
              </div>
            ) : (
              <button
                onClick={() => { setActiveFieldId(field.id); setShowImageUpload(true) }}
                className="w-full py-8 border-2 border-dashed border-gray-300 rounded-lg hover:border-primary-500 transition-colors flex flex-col items-center gap-2"
              >
                <Camera size={32} className="text-gray-400" />
                <span className="text-gray-600">Add photos</span>
              </button>
            )}
          </div>
        )}

        {/* Location */}
        {field.type === 'location' && (
          <div>
            {value ? (
              <div className="border rounded-lg p-4 bg-gray-50">
                <div className="flex items-center gap-2 text-gray-700">
                  <MapPin size={18} className="text-primary-500" />
                  <span>{value.latitude?.toFixed(6)}, {value.longitude?.toFixed(6)}</span>
                </div>
                <a
                  href={`https://maps.google.com/?q=${value.latitude},${value.longitude}`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-primary-500 text-sm hover:underline block mt-2"
                >
                  View on map →
                </a>
              </div>
            ) : (
              <button
                onClick={() => { setActiveFieldId(field.id); getLocation() }}
                disabled={gettingLocation}
                className="w-full py-4 border-2 border-dashed border-gray-300 rounded-lg hover:border-primary-500 transition-colors flex items-center justify-center gap-2"
              >
                {gettingLocation ? (
                  <>
                    <Loader2 size={20} className="animate-spin text-primary-500" />
                    <span className="text-gray-600">Getting location...</span>
                  </>
                ) : (
                  <>
                    <MapPin size={20} className="text-gray-400" />
                    <span className="text-gray-600">Capture GPS location</span>
                  </>
                )}
              </button>
            )}
          </div>
        )}

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
    <div className="max-w-2xl mx-auto">
      {/* Header */}
      <div className="flex items-center gap-4 mb-6">
        <button
          onClick={() => navigate(-1)}
          className="p-2 hover:bg-gray-100 rounded-lg"
        >
          <ArrowLeft size={20} />
        </button>
        <div className="flex-1">
          <h1 className="text-xl font-bold text-gray-900">{template.name}</h1>
          <p className="text-sm text-gray-500">{template.description}</p>
        </div>
      </div>

      {/* Progress Bar */}
      <div className="bg-white rounded-xl shadow-sm p-4 mb-6">
        <div className="flex items-center justify-between text-sm mb-2">
          <span className="text-gray-500">Progress</span>
          <span className="font-medium text-primary-500">{progress}%</span>
        </div>
        <div className="h-2 bg-gray-100 rounded-full overflow-hidden">
          <div
            className="h-full bg-primary-500 transition-all duration-300"
            style={{ width: `${progress}%` }}
          />
        </div>
        {sections.length > 1 && (
          <div className="flex justify-between mt-2 text-xs text-gray-500">
            <span>Section {currentSection + 1} of {sections.length}</span>
          </div>
        )}
      </div>

      {/* Form Fields */}
      <div className="bg-white rounded-xl shadow-sm p-6 mb-6">
        {currentFields.map(renderField)}
      </div>

      {/* Navigation */}
      <div className="flex gap-3 mb-6">
        {currentSection > 0 && (
          <button
            onClick={() => setCurrentSection(s => s - 1)}
            className="btn btn-secondary flex items-center gap-2"
          >
            <ChevronLeft size={16} />
            Previous
          </button>
        )}
        <div className="flex-1" />
        {currentSection < sections.length - 1 ? (
          <button
            onClick={() => setCurrentSection(s => s + 1)}
            className="btn btn-primary flex items-center gap-2"
          >
            Next
            <ChevronRight size={16} />
          </button>
        ) : (
          <>
            <button
              onClick={() => saveForm(false)}
              disabled={isSaving}
              className="btn btn-secondary flex items-center gap-2"
            >
              {isSaving ? <Loader2 size={16} className="animate-spin" /> : <Save size={16} />}
              Save Draft
            </button>
            <button
              onClick={() => saveForm(true)}
              disabled={isSubmitting}
              className="btn btn-primary flex items-center gap-2"
            >
              {isSubmitting ? <Loader2 size={16} className="animate-spin" /> : <Send size={16} />}
              Submit
            </button>
          </>
        )}
      </div>

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
