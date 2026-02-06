import { useState, useRef } from 'react'
import { useNavigate } from 'react-router-dom'
import api from '../services/api'
import {
  Plus,
  GripVertical,
  Trash2,
  Copy,
  Settings,
  Eye,
  Save,
  Upload,
  Image,
  Wand2,
  ChevronDown,
  ChevronUp,
  X,
  FileText,
  Type,
  AlignLeft,
  Hash,
  Mail,
  Phone,
  Calendar,
  Clock,
  CheckSquare,
  ThumbsUp,
  List,
  CheckCheck,
  PenLine,
  Camera,
  MapPin,
  DollarSign,
  Star,
  SlidersHorizontal,
  LayoutList,
  Mic,
  Loader2
} from 'lucide-react'

// Field type definitions - matches iOS app's 18 field types
const FIELD_TYPES = [
  { type: 'section', label: 'Section Header', icon: LayoutList, color: 'bg-gray-500' },
  { type: 'text', label: 'Text Input', icon: Type, color: 'bg-blue-500' },
  { type: 'textarea', label: 'Text Area', icon: AlignLeft, color: 'bg-blue-500' },
  { type: 'number', label: 'Number', icon: Hash, color: 'bg-green-500' },
  { type: 'email', label: 'Email', icon: Mail, color: 'bg-purple-500' },
  { type: 'phone', label: 'Phone', icon: Phone, color: 'bg-purple-500' },
  { type: 'date', label: 'Date', icon: Calendar, color: 'bg-orange-500' },
  { type: 'time', label: 'Time', icon: Clock, color: 'bg-orange-500' },
  { type: 'checkbox', label: 'Checkbox', icon: CheckSquare, color: 'bg-teal-500' },
  { type: 'yesNo', label: 'Yes/No/NA', icon: ThumbsUp, color: 'bg-teal-500' },
  { type: 'dropdown', label: 'Dropdown', icon: List, color: 'bg-indigo-500' },
  { type: 'multiSelect', label: 'Multi-Select', icon: CheckCheck, color: 'bg-indigo-500' },
  { type: 'signature', label: 'Signature', icon: PenLine, color: 'bg-red-500' },
  { type: 'photo', label: 'Photo', icon: Camera, color: 'bg-pink-500' },
  { type: 'location', label: 'GPS Location', icon: MapPin, color: 'bg-emerald-500' },
  { type: 'currency', label: 'Currency', icon: DollarSign, color: 'bg-green-600' },
  { type: 'rating', label: 'Star Rating', icon: Star, color: 'bg-yellow-500' },
  { type: 'slider', label: 'Slider', icon: SlidersHorizontal, color: 'bg-cyan-500' },
]

function FormBuilder() {
  const navigate = useNavigate()
  const fileInputRef = useRef(null)
  const aiInputRef = useRef(null)

  // Form metadata
  const [formName, setFormName] = useState('')
  const [formDescription, setFormDescription] = useState('')
  const [formCategory, setFormCategory] = useState('Safety')
  const [formLogo, setFormLogo] = useState(null)

  // Fields
  const [fields, setFields] = useState([])
  const [selectedFieldId, setSelectedFieldId] = useState(null)
  const [draggedIndex, setDraggedIndex] = useState(null)

  // UI state
  const [showPreview, setShowPreview] = useState(false)
  const [showAIModal, setShowAIModal] = useState(false)
  const [aiPrompt, setAiPrompt] = useState('')
  const [aiLoading, setAiLoading] = useState(false)

  // Categories
  const categories = ['Safety', 'Operations', 'Maintenance', 'HR', 'Logistics', 'Permits', 'Quality', 'Other']

  // Add a new field
  const addField = (type) => {
    const fieldType = FIELD_TYPES.find(f => f.type === type)
    const newField = {
      id: `field-${Date.now()}`,
      type,
      label: fieldType?.label || 'New Field',
      required: false,
      placeholder: '',
      options: type === 'dropdown' || type === 'multiSelect' ? ['Option 1', 'Option 2'] : [],
      description: ''
    }
    setFields([...fields, newField])
    setSelectedFieldId(newField.id)
  }

  // Update a field
  const updateField = (id, updates) => {
    setFields(fields.map(f => f.id === id ? { ...f, ...updates } : f))
  }

  // Delete a field
  const deleteField = (id) => {
    setFields(fields.filter(f => f.id !== id))
    if (selectedFieldId === id) setSelectedFieldId(null)
  }

  // Duplicate a field
  const duplicateField = (id) => {
    const field = fields.find(f => f.id === id)
    if (field) {
      const newField = { ...field, id: `field-${Date.now()}`, label: `${field.label} (copy)` }
      const index = fields.findIndex(f => f.id === id)
      const newFields = [...fields]
      newFields.splice(index + 1, 0, newField)
      setFields(newFields)
    }
  }

  // Drag and drop
  const handleDragStart = (index) => {
    setDraggedIndex(index)
  }

  const handleDragOver = (e, index) => {
    e.preventDefault()
    if (draggedIndex === null || draggedIndex === index) return

    const newFields = [...fields]
    const [removed] = newFields.splice(draggedIndex, 1)
    newFields.splice(index, 0, removed)
    setFields(newFields)
    setDraggedIndex(index)
  }

  const handleDragEnd = () => {
    setDraggedIndex(null)
  }

  // Move field up/down
  const moveField = (index, direction) => {
    const newIndex = index + direction
    if (newIndex < 0 || newIndex >= fields.length) return
    const newFields = [...fields]
    const [removed] = newFields.splice(index, 1)
    newFields.splice(newIndex, 0, removed)
    setFields(newFields)
  }

  // Logo upload
  const handleLogoUpload = (e) => {
    const file = e.target.files?.[0]
    if (file) {
      const reader = new FileReader()
      reader.onload = () => setFormLogo(reader.result)
      reader.readAsDataURL(file)
    }
  }

  // AI Generate Form
  const generateWithAI = async () => {
    if (!aiPrompt.trim()) return
    setAiLoading(true)

    // Simulate AI generation (in production, call your AI API)
    setTimeout(() => {
      // Generate fields based on prompt keywords
      const generatedFields = []
      const prompt = aiPrompt.toLowerCase()

      // Always add header
      generatedFields.push({
        id: `field-${Date.now()}-0`,
        type: 'section',
        label: formName || 'Form Details',
        required: false,
        options: []
      })

      // Add date
      generatedFields.push({
        id: `field-${Date.now()}-1`,
        type: 'date',
        label: 'Date',
        required: true,
        options: []
      })

      // Detect intent from prompt
      if (prompt.includes('safety') || prompt.includes('inspection')) {
        generatedFields.push(
          { id: `field-${Date.now()}-2`, type: 'dropdown', label: 'Location', required: true, options: ['Area A', 'Area B', 'Area C'] },
          { id: `field-${Date.now()}-3`, type: 'text', label: 'Inspector Name', required: true, options: [] },
          { id: `field-${Date.now()}-4`, type: 'section', label: 'Safety Checks', required: false, options: [] },
          { id: `field-${Date.now()}-5`, type: 'yesNo', label: 'PPE available and in good condition?', required: true, options: [] },
          { id: `field-${Date.now()}-6`, type: 'yesNo', label: 'Emergency exits clear?', required: true, options: [] },
          { id: `field-${Date.now()}-7`, type: 'yesNo', label: 'Fire extinguishers accessible?', required: true, options: [] },
          { id: `field-${Date.now()}-8`, type: 'yesNo', label: 'Any hazards identified?', required: true, options: [] },
          { id: `field-${Date.now()}-9`, type: 'textarea', label: 'Describe hazards (if any)', required: false, options: [] },
          { id: `field-${Date.now()}-10`, type: 'photo', label: 'Photo evidence', required: false, options: [] }
        )
      } else if (prompt.includes('incident') || prompt.includes('accident')) {
        generatedFields.push(
          { id: `field-${Date.now()}-2`, type: 'time', label: 'Time of Incident', required: true, options: [] },
          { id: `field-${Date.now()}-3`, type: 'dropdown', label: 'Incident Type', required: true, options: ['Injury', 'Near Miss', 'Property Damage', 'Other'] },
          { id: `field-${Date.now()}-4`, type: 'text', label: 'Location', required: true, options: [] },
          { id: `field-${Date.now()}-5`, type: 'section', label: 'Injured Person', required: false, options: [] },
          { id: `field-${Date.now()}-6`, type: 'text', label: 'Name', required: false, options: [] },
          { id: `field-${Date.now()}-7`, type: 'textarea', label: 'Description of Incident', required: true, options: [] },
          { id: `field-${Date.now()}-8`, type: 'photo', label: 'Photo of Scene', required: false, options: [] },
          { id: `field-${Date.now()}-9`, type: 'textarea', label: 'Corrective Actions', required: true, options: [] }
        )
      } else if (prompt.includes('delivery') || prompt.includes('receipt')) {
        generatedFields.push(
          { id: `field-${Date.now()}-2`, type: 'time', label: 'Delivery Time', required: true, options: [] },
          { id: `field-${Date.now()}-3`, type: 'text', label: 'Order Number', required: true, options: [] },
          { id: `field-${Date.now()}-4`, type: 'text', label: 'Recipient Name', required: true, options: [] },
          { id: `field-${Date.now()}-5`, type: 'textarea', label: 'Delivery Address', required: true, options: [] },
          { id: `field-${Date.now()}-6`, type: 'textarea', label: 'Items Delivered', required: true, options: [] },
          { id: `field-${Date.now()}-7`, type: 'dropdown', label: 'Condition', required: true, options: ['Good', 'Damaged', 'Partial'] },
          { id: `field-${Date.now()}-8`, type: 'photo', label: 'Photo of Delivery', required: false, options: [] }
        )
      } else if (prompt.includes('equipment') || prompt.includes('checklist')) {
        generatedFields.push(
          { id: `field-${Date.now()}-2`, type: 'text', label: 'Equipment ID', required: true, options: [] },
          { id: `field-${Date.now()}-3`, type: 'dropdown', label: 'Equipment Type', required: true, options: ['Forklift', 'Crane', 'Vehicle', 'Other'] },
          { id: `field-${Date.now()}-4`, type: 'section', label: 'Pre-Use Checks', required: false, options: [] },
          { id: `field-${Date.now()}-5`, type: 'yesNo', label: 'Visual inspection OK?', required: true, options: [] },
          { id: `field-${Date.now()}-6`, type: 'yesNo', label: 'Safety features working?', required: true, options: [] },
          { id: `field-${Date.now()}-7`, type: 'yesNo', label: 'Controls functioning?', required: true, options: [] },
          { id: `field-${Date.now()}-8`, type: 'yesNo', label: 'Safe to operate?', required: true, options: [] },
          { id: `field-${Date.now()}-9`, type: 'textarea', label: 'Defects found', required: false, options: [] }
        )
      } else {
        // Generic form
        generatedFields.push(
          { id: `field-${Date.now()}-2`, type: 'text', label: 'Name', required: true, options: [] },
          { id: `field-${Date.now()}-3`, type: 'textarea', label: 'Description', required: false, options: [] },
          { id: `field-${Date.now()}-4`, type: 'dropdown', label: 'Category', required: false, options: ['Option 1', 'Option 2', 'Option 3'] },
          { id: `field-${Date.now()}-5`, type: 'textarea', label: 'Notes', required: false, options: [] }
        )
      }

      // Always add signature at the end
      generatedFields.push(
        { id: `field-${Date.now()}-sig`, type: 'section', label: 'Verification', required: false, options: [] },
        { id: `field-${Date.now()}-sig2`, type: 'signature', label: 'Signature', required: true, options: [] },
        { id: `field-${Date.now()}-loc`, type: 'location', label: 'GPS Location', required: false, options: [] }
      )

      setFields(generatedFields)
      setAiLoading(false)
      setShowAIModal(false)
      setAiPrompt('')
    }, 1500)
  }

  // Save form
  const [isSaving, setIsSaving] = useState(false)

  const saveForm = async () => {
    if (!formName.trim()) {
      alert('Please enter a form name')
      return
    }
    if (fields.length === 0) {
      alert('Please add at least one field')
      return
    }

    setIsSaving(true)

    const templateData = {
      name: formName,
      description: formDescription,
      category: formCategory,
      logo: formLogo,
      fields: fields.map((f, i) => ({
        id: f.id,
        type: f.type,
        label: f.label,
        required: f.required,
        placeholder: f.placeholder || '',
        options: f.options || [],
        description: f.description || '',
        order: i
      })),
      version: '1.0',
      createdAt: new Date().toISOString()
    }

    try {
      await api.createTemplate(templateData)
      alert('Template saved successfully!')
      navigate('/templates')
    } catch (err) {
      console.error('Failed to save template:', err)
      // Save locally as fallback
      const localTemplates = JSON.parse(localStorage.getItem('localTemplates') || '[]')
      localTemplates.push({ ...templateData, id: `local-${Date.now()}` })
      localStorage.setItem('localTemplates', JSON.stringify(localTemplates))
      alert('Template saved locally. It will sync when connected.')
      navigate('/templates')
    } finally {
      setIsSaving(false)
    }
  }

  // Get selected field
  const selectedField = fields.find(f => f.id === selectedFieldId)

  return (
    <div className="h-[calc(100vh-4rem)] flex flex-col">
      {/* Header */}
      <div className="bg-white border-b border-gray-200 p-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-4">
            <h1 className="text-xl font-bold text-gray-900">Form Builder</h1>
            <button
              onClick={() => setShowAIModal(true)}
              className="btn bg-gradient-to-r from-purple-500 to-pink-500 text-white hover:from-purple-600 hover:to-pink-600 flex items-center gap-2"
            >
              <Wand2 size={16} />
              Generate with AI
            </button>
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={() => setShowPreview(!showPreview)}
              className="btn btn-secondary flex items-center gap-2"
            >
              <Eye size={16} />
              {showPreview ? 'Edit' : 'Preview'}
            </button>
            <button
              onClick={saveForm}
              disabled={isSaving}
              className="btn btn-primary flex items-center gap-2 disabled:opacity-50"
            >
              {isSaving ? (
                <>
                  <Loader2 size={16} className="animate-spin" />
                  Saving...
                </>
              ) : (
                <>
                  <Save size={16} />
                  Save Template
                </>
              )}
            </button>
          </div>
        </div>
      </div>

      <div className="flex-1 flex overflow-hidden">
        {/* Left Sidebar - Field Types */}
        <div className="w-64 bg-gray-50 border-r border-gray-200 p-4 overflow-y-auto">
          <h2 className="font-semibold text-gray-700 mb-3">Add Fields</h2>
          <div className="space-y-2">
            {FIELD_TYPES.map((fieldType) => {
              const Icon = fieldType.icon
              return (
                <button
                  key={fieldType.type}
                  onClick={() => addField(fieldType.type)}
                  className="w-full flex items-center gap-3 p-2 rounded-lg hover:bg-white hover:shadow-sm transition-all text-left"
                >
                  <div className={`w-8 h-8 ${fieldType.color} rounded-lg flex items-center justify-center`}>
                    <Icon size={16} className="text-white" />
                  </div>
                  <span className="text-sm text-gray-700">{fieldType.label}</span>
                </button>
              )
            })}
          </div>

          {/* Logo Upload */}
          <div className="mt-6 pt-6 border-t border-gray-200">
            <h2 className="font-semibold text-gray-700 mb-3">Form Logo</h2>
            <input
              type="file"
              ref={fileInputRef}
              onChange={handleLogoUpload}
              accept="image/*"
              className="hidden"
            />
            {formLogo ? (
              <div className="relative">
                <img src={formLogo} alt="Logo" className="w-full h-24 object-contain bg-white rounded-lg border" />
                <button
                  onClick={() => setFormLogo(null)}
                  className="absolute top-1 right-1 p-1 bg-red-500 text-white rounded-full"
                >
                  <X size={12} />
                </button>
              </div>
            ) : (
              <button
                onClick={() => fileInputRef.current?.click()}
                className="w-full p-4 border-2 border-dashed border-gray-300 rounded-lg hover:border-primary-500 transition-colors"
              >
                <Upload size={24} className="mx-auto text-gray-400 mb-2" />
                <p className="text-sm text-gray-500">Upload logo</p>
              </button>
            )}
          </div>
        </div>

        {/* Center - Form Canvas */}
        <div className="flex-1 p-6 overflow-y-auto bg-gray-100">
          <div className="max-w-2xl mx-auto">
            {/* Form Header */}
            <div className="bg-white rounded-xl shadow-sm p-6 mb-4">
              {formLogo && (
                <img src={formLogo} alt="Logo" className="h-16 object-contain mb-4" />
              )}
              <input
                type="text"
                value={formName}
                onChange={(e) => setFormName(e.target.value)}
                placeholder="Form Name"
                className="text-2xl font-bold w-full border-none focus:outline-none focus:ring-0 placeholder-gray-300"
              />
              <input
                type="text"
                value={formDescription}
                onChange={(e) => setFormDescription(e.target.value)}
                placeholder="Form description (optional)"
                className="text-gray-500 w-full border-none focus:outline-none focus:ring-0 placeholder-gray-300 mt-2"
              />
              <div className="mt-4">
                <select
                  value={formCategory}
                  onChange={(e) => setFormCategory(e.target.value)}
                  className="input text-sm"
                >
                  {categories.map(cat => (
                    <option key={cat} value={cat}>{cat}</option>
                  ))}
                </select>
              </div>
            </div>

            {/* Fields */}
            {fields.length === 0 ? (
              <div className="bg-white rounded-xl shadow-sm p-12 text-center">
                <FileText size={48} className="mx-auto text-gray-300 mb-4" />
                <p className="text-gray-500 mb-2">No fields yet</p>
                <p className="text-sm text-gray-400">Click a field type on the left to add it, or use AI to generate a form</p>
              </div>
            ) : (
              <div className="space-y-3">
                {fields.map((field, index) => {
                  const fieldType = FIELD_TYPES.find(f => f.type === field.type)
                  const Icon = fieldType?.icon || FileText
                  const isSelected = selectedFieldId === field.id

                  return (
                    <div
                      key={field.id}
                      draggable
                      onDragStart={() => handleDragStart(index)}
                      onDragOver={(e) => handleDragOver(e, index)}
                      onDragEnd={handleDragEnd}
                      onClick={() => setSelectedFieldId(field.id)}
                      className={`bg-white rounded-xl shadow-sm p-4 cursor-pointer transition-all ${
                        isSelected ? 'ring-2 ring-primary-500' : 'hover:shadow-md'
                      } ${draggedIndex === index ? 'opacity-50' : ''}`}
                    >
                      <div className="flex items-start gap-3">
                        <div className="flex flex-col items-center gap-1 pt-1">
                          <GripVertical size={16} className="text-gray-400 cursor-grab" />
                        </div>
                        <div className={`w-8 h-8 ${fieldType?.color || 'bg-gray-500'} rounded-lg flex items-center justify-center flex-shrink-0`}>
                          <Icon size={16} className="text-white" />
                        </div>
                        <div className="flex-1 min-w-0">
                          {field.type === 'section' ? (
                            <h3 className="font-semibold text-gray-900">{field.label}</h3>
                          ) : (
                            <>
                              <p className="font-medium text-gray-900">
                                {field.label}
                                {field.required && <span className="text-red-500 ml-1">*</span>}
                              </p>
                              <p className="text-sm text-gray-400">{fieldType?.label}</p>
                            </>
                          )}
                        </div>
                        <div className="flex items-center gap-1">
                          <button
                            onClick={(e) => { e.stopPropagation(); moveField(index, -1) }}
                            className="p-1 hover:bg-gray-100 rounded"
                            disabled={index === 0}
                          >
                            <ChevronUp size={16} className={index === 0 ? 'text-gray-300' : 'text-gray-500'} />
                          </button>
                          <button
                            onClick={(e) => { e.stopPropagation(); moveField(index, 1) }}
                            className="p-1 hover:bg-gray-100 rounded"
                            disabled={index === fields.length - 1}
                          >
                            <ChevronDown size={16} className={index === fields.length - 1 ? 'text-gray-300' : 'text-gray-500'} />
                          </button>
                          <button
                            onClick={(e) => { e.stopPropagation(); duplicateField(field.id) }}
                            className="p-1 hover:bg-gray-100 rounded"
                          >
                            <Copy size={16} className="text-gray-500" />
                          </button>
                          <button
                            onClick={(e) => { e.stopPropagation(); deleteField(field.id) }}
                            className="p-1 hover:bg-red-100 rounded"
                          >
                            <Trash2 size={16} className="text-red-500" />
                          </button>
                        </div>
                      </div>
                    </div>
                  )
                })}
              </div>
            )}
          </div>
        </div>

        {/* Right Sidebar - Field Properties */}
        {selectedField && (
          <div className="w-80 bg-white border-l border-gray-200 p-4 overflow-y-auto">
            <div className="flex items-center justify-between mb-4">
              <h2 className="font-semibold text-gray-900">Field Properties</h2>
              <button onClick={() => setSelectedFieldId(null)} className="p-1 hover:bg-gray-100 rounded">
                <X size={16} className="text-gray-500" />
              </button>
            </div>

            <div className="space-y-4">
              {/* Label */}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Label</label>
                <input
                  type="text"
                  value={selectedField.label}
                  onChange={(e) => updateField(selectedField.id, { label: e.target.value })}
                  className="input w-full"
                />
              </div>

              {/* Required */}
              {selectedField.type !== 'section' && (
                <div className="flex items-center justify-between">
                  <label className="text-sm font-medium text-gray-700">Required</label>
                  <input
                    type="checkbox"
                    checked={selectedField.required}
                    onChange={(e) => updateField(selectedField.id, { required: e.target.checked })}
                    className="h-5 w-5 text-primary-500 rounded border-gray-300"
                  />
                </div>
              )}

              {/* Placeholder */}
              {['text', 'textarea', 'number', 'email', 'phone'].includes(selectedField.type) && (
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Placeholder</label>
                  <input
                    type="text"
                    value={selectedField.placeholder || ''}
                    onChange={(e) => updateField(selectedField.id, { placeholder: e.target.value })}
                    className="input w-full"
                  />
                </div>
              )}

              {/* Options for dropdown/multiSelect */}
              {['dropdown', 'multiSelect'].includes(selectedField.type) && (
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Options</label>
                  <div className="space-y-2">
                    {selectedField.options?.map((option, i) => (
                      <div key={i} className="flex items-center gap-2">
                        <input
                          type="text"
                          value={option}
                          onChange={(e) => {
                            const newOptions = [...selectedField.options]
                            newOptions[i] = e.target.value
                            updateField(selectedField.id, { options: newOptions })
                          }}
                          className="input flex-1"
                        />
                        <button
                          onClick={() => {
                            const newOptions = selectedField.options.filter((_, idx) => idx !== i)
                            updateField(selectedField.id, { options: newOptions })
                          }}
                          className="p-2 hover:bg-red-100 rounded"
                        >
                          <X size={14} className="text-red-500" />
                        </button>
                      </div>
                    ))}
                    <button
                      onClick={() => {
                        const newOptions = [...(selectedField.options || []), `Option ${(selectedField.options?.length || 0) + 1}`]
                        updateField(selectedField.id, { options: newOptions })
                      }}
                      className="text-sm text-primary-500 hover:text-primary-600 flex items-center gap-1"
                    >
                      <Plus size={14} /> Add option
                    </button>
                  </div>
                </div>
              )}

              {/* Description */}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Help Text</label>
                <textarea
                  value={selectedField.description || ''}
                  onChange={(e) => updateField(selectedField.id, { description: e.target.value })}
                  className="input w-full h-20 resize-none"
                  placeholder="Optional help text for this field"
                />
              </div>
            </div>
          </div>
        )}
      </div>

      {/* AI Modal */}
      {showAIModal && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-xl max-w-lg w-full p-6">
            <div className="flex items-center gap-3 mb-4">
              <div className="w-10 h-10 bg-gradient-to-r from-purple-500 to-pink-500 rounded-lg flex items-center justify-center">
                <Wand2 size={20} className="text-white" />
              </div>
              <div>
                <h3 className="text-lg font-semibold text-gray-900">AI Form Generator</h3>
                <p className="text-sm text-gray-500">Describe the form you need</p>
              </div>
            </div>

            <textarea
              value={aiPrompt}
              onChange={(e) => setAiPrompt(e.target.value)}
              placeholder="Example: Create a daily safety inspection form for a warehouse with PPE checks, emergency equipment verification, and hazard reporting..."
              className="input w-full h-32 resize-none mb-4"
            />

            <div className="mb-4">
              <p className="text-sm text-gray-500 mb-2">Or upload a paper form to digitize:</p>
              <input
                type="file"
                ref={aiInputRef}
                accept="image/*,.pdf"
                className="hidden"
              />
              <button
                onClick={() => aiInputRef.current?.click()}
                className="w-full p-4 border-2 border-dashed border-gray-300 rounded-lg hover:border-primary-500 transition-colors"
              >
                <Upload size={24} className="mx-auto text-gray-400 mb-2" />
                <p className="text-sm text-gray-500">Upload image or PDF</p>
              </button>
            </div>

            <div className="flex gap-3 justify-end">
              <button
                onClick={() => setShowAIModal(false)}
                className="btn btn-secondary"
              >
                Cancel
              </button>
              <button
                onClick={generateWithAI}
                disabled={!aiPrompt.trim() || aiLoading}
                className="btn btn-primary flex items-center gap-2"
              >
                {aiLoading ? (
                  <>
                    <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white" />
                    Generating...
                  </>
                ) : (
                  <>
                    <Wand2 size={16} />
                    Generate Form
                  </>
                )}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

export default FormBuilder
