import { useRef, useState, useEffect } from 'react'
import { Eraser, Check, RotateCcw, Type, PenLine } from 'lucide-react'

/**
 * SignaturePad Component
 * Captures legally-binding digital signatures with PIPEDA compliance
 */
function SignaturePad({ onSave, onCancel, signerName = '', signerEmail = '' }) {
  const canvasRef = useRef(null)
  const [isDrawing, setIsDrawing] = useState(false)
  const [hasSignature, setHasSignature] = useState(false)
  const [signatureType, setSignatureType] = useState('drawn') // 'drawn', 'typed', 'initials'
  const [typedSignature, setTypedSignature] = useState('')
  const [initials, setInitials] = useState('')
  const [consent, setConsent] = useState(false)
  const [ctx, setCtx] = useState(null)

  useEffect(() => {
    const canvas = canvasRef.current
    if (canvas) {
      const context = canvas.getContext('2d')
      context.strokeStyle = '#1e40af'
      context.lineWidth = 2
      context.lineCap = 'round'
      context.lineJoin = 'round'
      setCtx(context)

      // Set canvas size
      const rect = canvas.getBoundingClientRect()
      canvas.width = rect.width
      canvas.height = rect.height
    }
  }, [])

  const getCoordinates = (e) => {
    const canvas = canvasRef.current
    const rect = canvas.getBoundingClientRect()

    if (e.touches) {
      return {
        x: e.touches[0].clientX - rect.left,
        y: e.touches[0].clientY - rect.top
      }
    }
    return {
      x: e.clientX - rect.left,
      y: e.clientY - rect.top
    }
  }

  const startDrawing = (e) => {
    if (signatureType !== 'drawn') return
    e.preventDefault()
    const { x, y } = getCoordinates(e)
    ctx.beginPath()
    ctx.moveTo(x, y)
    setIsDrawing(true)
  }

  const draw = (e) => {
    if (!isDrawing || signatureType !== 'drawn') return
    e.preventDefault()
    const { x, y } = getCoordinates(e)
    ctx.lineTo(x, y)
    ctx.stroke()
    setHasSignature(true)
  }

  const stopDrawing = () => {
    if (isDrawing) {
      ctx.closePath()
      setIsDrawing(false)
    }
  }

  const clearSignature = () => {
    const canvas = canvasRef.current
    ctx.clearRect(0, 0, canvas.width, canvas.height)
    setHasSignature(false)
    setTypedSignature('')
    setInitials('')
  }

  const drawTypedSignature = (text, isInitials = false) => {
    const canvas = canvasRef.current
    ctx.clearRect(0, 0, canvas.width, canvas.height)

    if (!text) {
      setHasSignature(false)
      return
    }

    ctx.font = isInitials ? 'bold 48px "Brush Script MT", cursive' : 'italic 32px "Brush Script MT", cursive'
    ctx.fillStyle = '#1e40af'
    ctx.textAlign = 'center'
    ctx.textBaseline = 'middle'
    ctx.fillText(text, canvas.width / 2, canvas.height / 2)
    setHasSignature(true)
  }

  const handleTypedChange = (e) => {
    const value = e.target.value
    setTypedSignature(value)
    drawTypedSignature(value, false)
  }

  const handleInitialsChange = (e) => {
    const value = e.target.value.toUpperCase().slice(0, 4)
    setInitials(value)
    drawTypedSignature(value, true)
  }

  const handleSave = async () => {
    if (!hasSignature || !consent) return

    const canvas = canvasRef.current
    const signatureData = canvas.toDataURL('image/png')

    // Get location if available
    let location = null
    try {
      const pos = await new Promise((resolve, reject) => {
        navigator.geolocation.getCurrentPosition(resolve, reject, { timeout: 5000 })
      })
      location = {
        latitude: pos.coords.latitude,
        longitude: pos.coords.longitude
      }
    } catch (e) {
      console.log('Location not available')
    }

    // Generate signature certificate
    const certificate = {
      signatureData,
      signatureType,
      signerName,
      signerEmail,
      timestamp: new Date().toISOString(),
      userAgent: navigator.userAgent,
      screenResolution: `${window.screen.width}x${window.screen.height}`,
      timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
      location,
      consent: true,
      consentText: 'I agree that this electronic signature is legally binding.',
      legalReference: 'PIPEDA (Canada) Electronic Signature Compliance'
    }

    onSave(certificate)
  }

  return (
    <div className="bg-white rounded-xl shadow-lg p-6 max-w-lg w-full">
      <h3 className="text-lg font-bold text-gray-900 mb-4">Digital Signature</h3>

      {/* Signature Type Tabs */}
      <div className="flex gap-2 mb-4">
        <button
          onClick={() => { setSignatureType('drawn'); clearSignature() }}
          className={`flex-1 py-2 px-4 rounded-lg flex items-center justify-center gap-2 transition-colors ${
            signatureType === 'drawn'
              ? 'bg-primary-500 text-white'
              : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
          }`}
        >
          <PenLine size={16} />
          Draw
        </button>
        <button
          onClick={() => { setSignatureType('typed'); clearSignature() }}
          className={`flex-1 py-2 px-4 rounded-lg flex items-center justify-center gap-2 transition-colors ${
            signatureType === 'typed'
              ? 'bg-primary-500 text-white'
              : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
          }`}
        >
          <Type size={16} />
          Type
        </button>
        <button
          onClick={() => { setSignatureType('initials'); clearSignature() }}
          className={`flex-1 py-2 px-4 rounded-lg flex items-center justify-center gap-2 transition-colors ${
            signatureType === 'initials'
              ? 'bg-primary-500 text-white'
              : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
          }`}
        >
          Initials
        </button>
      </div>

      {/* Input for typed/initials */}
      {signatureType === 'typed' && (
        <input
          type="text"
          value={typedSignature}
          onChange={handleTypedChange}
          placeholder="Type your full name"
          className="input w-full mb-4"
        />
      )}
      {signatureType === 'initials' && (
        <input
          type="text"
          value={initials}
          onChange={handleInitialsChange}
          placeholder="Your initials (max 4)"
          maxLength={4}
          className="input w-full mb-4 text-center text-2xl font-bold uppercase"
        />
      )}

      {/* Signature Canvas */}
      <div className="relative border-2 border-gray-200 rounded-lg bg-gray-50 mb-4">
        <canvas
          ref={canvasRef}
          onMouseDown={startDrawing}
          onMouseMove={draw}
          onMouseUp={stopDrawing}
          onMouseLeave={stopDrawing}
          onTouchStart={startDrawing}
          onTouchMove={draw}
          onTouchEnd={stopDrawing}
          className="w-full h-32 cursor-crosshair touch-none"
        />
        {!hasSignature && signatureType === 'drawn' && (
          <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
            <p className="text-gray-400">Sign here</p>
          </div>
        )}
        <button
          onClick={clearSignature}
          className="absolute top-2 right-2 p-2 bg-white rounded-full shadow hover:bg-gray-100"
          title="Clear"
        >
          <Eraser size={16} className="text-gray-500" />
        </button>
      </div>

      {/* Consent Checkbox */}
      <label className="flex items-start gap-3 mb-4 cursor-pointer">
        <input
          type="checkbox"
          checked={consent}
          onChange={(e) => setConsent(e.target.checked)}
          className="mt-1 h-5 w-5 text-primary-500 rounded border-gray-300"
        />
        <span className="text-sm text-gray-600">
          I agree that this electronic signature is legally binding and equivalent to my handwritten signature
          under PIPEDA (Canada) and applicable electronic signature laws.
        </span>
      </label>

      {/* Legal Notice */}
      <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-3 mb-4">
        <p className="text-xs text-yellow-800">
          <strong>Legal Notice:</strong> By signing, you acknowledge that your signature will be recorded with
          timestamp, device information, and location (if available) for verification purposes.
        </p>
      </div>

      {/* Action Buttons */}
      <div className="flex gap-3">
        <button
          onClick={onCancel}
          className="btn btn-secondary flex-1"
        >
          Cancel
        </button>
        <button
          onClick={handleSave}
          disabled={!hasSignature || !consent}
          className="btn btn-primary flex-1 flex items-center justify-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          <Check size={16} />
          Sign & Accept
        </button>
      </div>
    </div>
  )
}

export default SignaturePad
