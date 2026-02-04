import { useState, useEffect } from 'react'
import { useParams, useNavigate, Link } from 'react-router-dom'
import api from '../services/api'
import { downloadFormPDF, printFormPDF, getFormPDFBase64 } from '../utils/pdfExport'
import {
  ArrowLeft,
  FileText,
  User,
  Calendar,
  MapPin,
  Clock,
  CheckCircle,
  XCircle,
  Download,
  Printer,
  Mail,
  Edit,
  PenLine,
  Camera,
  AlertCircle
} from 'lucide-react'

function FormDetail() {
  const { id } = useParams()
  const navigate = useNavigate()
  const [form, setForm] = useState(null)
  const [isLoading, setIsLoading] = useState(true)
  const [isApproving, setIsApproving] = useState(false)
  const [showRejectModal, setShowRejectModal] = useState(false)
  const [rejectReason, setRejectReason] = useState('')

  useEffect(() => {
    loadForm()
  }, [id])

  const loadForm = async () => {
    try {
      const data = await api.getForm(id)
      setForm(data)
    } catch (err) {
      console.error('Failed to load form:', err)
    } finally {
      setIsLoading(false)
    }
  }

  const handleApprove = async () => {
    setIsApproving(true)
    try {
      await api.updateFormStatus(id, 'approved')
      setForm((prev) => ({ ...prev, status: 'approved' }))
    } catch (err) {
      console.error('Failed to approve form:', err)
    } finally {
      setIsApproving(false)
    }
  }

  const handleReject = async () => {
    if (!rejectReason.trim()) return
    try {
      await api.updateFormStatus(id, 'rejected', rejectReason)
      setForm((prev) => ({ ...prev, status: 'rejected', rejectReason }))
      setShowRejectModal(false)
    } catch (err) {
      console.error('Failed to reject form:', err)
    }
  }

  const handleDownloadPDF = async () => {
    try {
      await downloadFormPDF(form, { includeSignatures: true })
    } catch (err) {
      console.error('Failed to generate PDF:', err)
      alert('Failed to generate PDF. Please try again.')
    }
  }

  const handlePrintPDF = async () => {
    try {
      await printFormPDF(form, { includeSignatures: true })
    } catch (err) {
      console.error('Failed to print PDF:', err)
      alert('Failed to print. Please try again.')
    }
  }

  const handleEmailPDF = async () => {
    try {
      const pdfBase64 = await getFormPDFBase64(form, { includeSignatures: true })
      const subject = encodeURIComponent(`Form: ${form.title || form.templateName}`)
      const body = encodeURIComponent(`Please find attached the form "${form.title || form.templateName}".\n\nStatus: ${form.status}\nSubmitted: ${new Date(form.createdAt).toLocaleString()}`)
      window.location.href = `mailto:?subject=${subject}&body=${body}`
    } catch (err) {
      console.error('Failed to prepare email:', err)
      alert('Failed to prepare email. Please try again.')
    }
  }

  const getStatusBadge = (status) => {
    const config = {
      draft: { bg: 'bg-gray-100', text: 'text-gray-700', icon: Edit },
      submitted: { bg: 'bg-blue-100', text: 'text-blue-700', icon: FileText },
      pending: { bg: 'bg-yellow-100', text: 'text-yellow-700', icon: Clock },
      approved: { bg: 'bg-green-100', text: 'text-green-700', icon: CheckCircle },
      rejected: { bg: 'bg-red-100', text: 'text-red-700', icon: XCircle }
    }
    return config[status] || config.draft
  }

  const getFieldIcon = (type) => {
    const icons = {
      signature: PenLine,
      photo: Camera,
      location: MapPin,
      date: Calendar,
      time: Clock
    }
    return icons[type] || FileText
  }

  const renderFieldValue = (field) => {
    const { type, value, label } = field

    if (!value && value !== 0 && value !== false) {
      return <span className="text-gray-400 italic">Not provided</span>
    }

    switch (type) {
      case 'signature':
        return (
          <div className="mt-2">
            <img
              src={value}
              alt="Signature"
              className="max-w-xs h-20 border border-gray-200 rounded-lg bg-white p-2"
            />
            {field.signatureData && (
              <div className="mt-2 text-xs text-gray-500 space-y-1">
                <p>Signed: {new Date(field.signatureData.timestamp).toLocaleString()}</p>
                {field.signatureData.ip && <p>IP: {field.signatureData.ip}</p>}
                {field.signatureData.consent && (
                  <p className="flex items-center gap-1 text-green-600">
                    <CheckCircle size={12} /> Legally binding consent given
                  </p>
                )}
              </div>
            )}
          </div>
        )

      case 'photo':
        const photos = Array.isArray(value) ? value : [value]
        return (
          <div className="mt-2 flex flex-wrap gap-2">
            {photos.map((photo, i) => (
              <img
                key={i}
                src={photo}
                alt={`Photo ${i + 1}`}
                className="w-24 h-24 object-cover rounded-lg border border-gray-200"
              />
            ))}
          </div>
        )

      case 'location':
        return (
          <div className="flex items-center gap-2 text-gray-700">
            <MapPin size={14} className="text-gray-400" />
            <span>{value.latitude?.toFixed(6)}, {value.longitude?.toFixed(6)}</span>
            <a
              href={`https://maps.google.com/?q=${value.latitude},${value.longitude}`}
              target="_blank"
              rel="noopener noreferrer"
              className="text-primary-500 text-sm hover:underline"
            >
              View on map
            </a>
          </div>
        )

      case 'date':
        return <span className="text-gray-900">{new Date(value).toLocaleDateString()}</span>

      case 'time':
        return <span className="text-gray-900">{value}</span>

      case 'checkbox':
      case 'yesNo':
        return (
          <span className={`inline-flex items-center gap-1 ${
            value === true || value === 'yes' ? 'text-green-600' : 'text-red-600'
          }`}>
            {value === true || value === 'yes' ? (
              <><CheckCircle size={14} /> Yes</>
            ) : (
              <><XCircle size={14} /> No</>
            )}
          </span>
        )

      case 'multiSelect':
        const items = Array.isArray(value) ? value : [value]
        return (
          <div className="flex flex-wrap gap-2 mt-1">
            {items.map((item, i) => (
              <span key={i} className="px-2 py-1 bg-gray-100 rounded text-sm text-gray-700">
                {item}
              </span>
            ))}
          </div>
        )

      case 'rating':
        return (
          <div className="flex items-center gap-1">
            {[1, 2, 3, 4, 5].map((star) => (
              <span key={star} className={star <= value ? 'text-yellow-400' : 'text-gray-300'}>
                ★
              </span>
            ))}
            <span className="ml-2 text-gray-600">{value}/5</span>
          </div>
        )

      default:
        return <span className="text-gray-900">{String(value)}</span>
    }
  }

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-500" />
      </div>
    )
  }

  if (!form) {
    return (
      <div className="text-center py-12">
        <AlertCircle size={48} className="mx-auto mb-4 text-gray-300" />
        <h2 className="text-lg font-medium text-gray-900">Form not found</h2>
        <p className="text-gray-500 mt-1">The form you're looking for doesn't exist.</p>
        <Link to="/forms" className="btn btn-primary mt-4 inline-block">
          Back to Forms
        </Link>
      </div>
    )
  }

  const statusConfig = getStatusBadge(form.status)
  const StatusIcon = statusConfig.icon

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div className="flex items-center gap-4">
          <button
            onClick={() => navigate(-1)}
            className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
          >
            <ArrowLeft size={20} />
          </button>
          <div>
            <h1 className="text-2xl font-bold text-gray-900">{form.title || form.templateName}</h1>
            <p className="text-gray-500">{form.templateName}</p>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <button onClick={handleDownloadPDF} className="btn btn-secondary flex items-center gap-2">
            <Download size={16} />
            <span className="hidden sm:inline">Download PDF</span>
          </button>
          <button onClick={handlePrintPDF} className="btn btn-secondary flex items-center gap-2">
            <Printer size={16} />
            <span className="hidden sm:inline">Print</span>
          </button>
          <button onClick={handleEmailPDF} className="btn btn-secondary flex items-center gap-2">
            <Mail size={16} />
            <span className="hidden sm:inline">Email</span>
          </button>
        </div>
      </div>

      {/* Status & Meta */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-5">
        <div className="flex flex-wrap items-center gap-4">
          <div className={`inline-flex items-center gap-2 px-3 py-1.5 rounded-full ${statusConfig.bg}`}>
            <StatusIcon size={16} className={statusConfig.text} />
            <span className={`font-medium ${statusConfig.text}`}>
              {form.status?.charAt(0).toUpperCase() + form.status?.slice(1) || 'Draft'}
            </span>
          </div>

          <div className="flex items-center gap-2 text-gray-600">
            <User size={16} className="text-gray-400" />
            <span>{form.submittedBy || 'Unknown'}</span>
          </div>

          <div className="flex items-center gap-2 text-gray-600">
            <Calendar size={16} className="text-gray-400" />
            <span>{new Date(form.createdAt).toLocaleString()}</span>
          </div>

          {form.location && (
            <div className="flex items-center gap-2 text-gray-600">
              <MapPin size={16} className="text-gray-400" />
              <span>{form.location.latitude?.toFixed(4)}, {form.location.longitude?.toFixed(4)}</span>
            </div>
          )}
        </div>

        {/* Approval Actions */}
        {form.status === 'submitted' || form.status === 'pending' ? (
          <div className="mt-4 pt-4 border-t border-gray-100 flex gap-3">
            <button
              onClick={handleApprove}
              disabled={isApproving}
              className="btn btn-primary flex items-center gap-2"
            >
              <CheckCircle size={16} />
              {isApproving ? 'Approving...' : 'Approve'}
            </button>
            <button
              onClick={() => setShowRejectModal(true)}
              className="btn bg-red-500 text-white hover:bg-red-600 flex items-center gap-2"
            >
              <XCircle size={16} />
              Reject
            </button>
          </div>
        ) : null}

        {form.status === 'rejected' && form.rejectReason && (
          <div className="mt-4 pt-4 border-t border-gray-100">
            <p className="text-sm text-red-600">
              <strong>Rejection Reason:</strong> {form.rejectReason}
            </p>
          </div>
        )}
      </div>

      {/* Form Fields */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-100">
        <div className="p-5 border-b border-gray-100">
          <h2 className="font-semibold text-gray-900">Form Data</h2>
        </div>
        <div className="divide-y divide-gray-100">
          {form.fields?.map((field, index) => {
            const FieldIcon = getFieldIcon(field.type)

            if (field.type === 'section') {
              return (
                <div key={index} className="px-5 py-4 bg-gray-50">
                  <h3 className="font-semibold text-gray-900">{field.label}</h3>
                  {field.description && (
                    <p className="text-sm text-gray-500 mt-1">{field.description}</p>
                  )}
                </div>
              )
            }

            return (
              <div key={index} className="px-5 py-4">
                <div className="flex items-start gap-3">
                  <div className="w-8 h-8 bg-gray-100 rounded-lg flex items-center justify-center flex-shrink-0 mt-0.5">
                    <FieldIcon size={16} className="text-gray-500" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <label className="block text-sm font-medium text-gray-700">
                      {field.label}
                      {field.required && <span className="text-red-500 ml-1">*</span>}
                    </label>
                    <div className="mt-1">{renderFieldValue(field)}</div>
                  </div>
                </div>
              </div>
            )
          })}
        </div>
      </div>

      {/* Audit Trail */}
      {form.auditTrail && form.auditTrail.length > 0 && (
        <div className="bg-white rounded-xl shadow-sm border border-gray-100">
          <div className="p-5 border-b border-gray-100">
            <h2 className="font-semibold text-gray-900">Audit Trail</h2>
          </div>
          <div className="p-5">
            <div className="space-y-4">
              {form.auditTrail.map((entry, index) => (
                <div key={index} className="flex items-start gap-3">
                  <div className="w-2 h-2 bg-primary-500 rounded-full mt-2" />
                  <div>
                    <p className="text-gray-900">{entry.action}</p>
                    <p className="text-sm text-gray-500">
                      {entry.user} • {new Date(entry.timestamp).toLocaleString()}
                    </p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* Reject Modal */}
      {showRejectModal && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-xl max-w-md w-full p-6">
            <h3 className="text-lg font-semibold text-gray-900 mb-4">Reject Form</h3>
            <textarea
              value={rejectReason}
              onChange={(e) => setRejectReason(e.target.value)}
              placeholder="Enter reason for rejection..."
              className="input w-full h-32 resize-none"
            />
            <div className="mt-4 flex gap-3 justify-end">
              <button
                onClick={() => setShowRejectModal(false)}
                className="btn btn-secondary"
              >
                Cancel
              </button>
              <button
                onClick={handleReject}
                disabled={!rejectReason.trim()}
                className="btn bg-red-500 text-white hover:bg-red-600 disabled:opacity-50"
              >
                Reject Form
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

export default FormDetail
