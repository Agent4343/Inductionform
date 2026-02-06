import { useState, useEffect, useRef } from 'react'
import { Mic, MicOff, Square, Loader2 } from 'lucide-react'

/**
 * VoiceInput Component
 * Uses Web Speech API for speech-to-text input
 */
function VoiceInput({ onResult, onCancel, placeholder = 'Speak now...', continuous = false }) {
  const [isListening, setIsListening] = useState(false)
  const [transcript, setTranscript] = useState('')
  const [interimTranscript, setInterimTranscript] = useState('')
  const [error, setError] = useState(null)
  const [isSupported, setIsSupported] = useState(true)
  const recognitionRef = useRef(null)

  useEffect(() => {
    // Check browser support
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition

    if (!SpeechRecognition) {
      setIsSupported(false)
      setError('Speech recognition is not supported in this browser. Please use Chrome, Edge, or Safari.')
      return
    }

    const recognition = new SpeechRecognition()
    recognition.continuous = continuous
    recognition.interimResults = true
    recognition.lang = 'en-US'

    recognition.onstart = () => {
      setIsListening(true)
      setError(null)
    }

    recognition.onresult = (event) => {
      let finalTranscript = ''
      let interim = ''

      for (let i = event.resultIndex; i < event.results.length; i++) {
        const result = event.results[i]
        if (result.isFinal) {
          finalTranscript += result[0].transcript
        } else {
          interim += result[0].transcript
        }
      }

      if (finalTranscript) {
        setTranscript(prev => prev + finalTranscript)
      }
      setInterimTranscript(interim)
    }

    recognition.onerror = (event) => {
      console.error('Speech recognition error:', event.error)
      setIsListening(false)

      switch (event.error) {
        case 'not-allowed':
          setError('Microphone access denied. Please allow microphone access and try again.')
          break
        case 'no-speech':
          setError('No speech detected. Please try again.')
          break
        case 'network':
          setError('Network error. Please check your connection.')
          break
        default:
          setError(`Error: ${event.error}`)
      }
    }

    recognition.onend = () => {
      setIsListening(false)
    }

    recognitionRef.current = recognition

    return () => {
      if (recognitionRef.current) {
        recognitionRef.current.abort()
      }
    }
  }, [continuous])

  const startListening = () => {
    if (!recognitionRef.current) return

    setTranscript('')
    setInterimTranscript('')
    setError(null)

    try {
      recognitionRef.current.start()
    } catch (err) {
      console.error('Failed to start recognition:', err)
    }
  }

  const stopListening = () => {
    if (recognitionRef.current) {
      recognitionRef.current.stop()
    }
  }

  const handleSave = () => {
    onResult(transcript.trim())
  }

  const handleCancel = () => {
    stopListening()
    onCancel()
  }

  if (!isSupported) {
    return (
      <div className="bg-white rounded-xl shadow-lg p-6 max-w-md w-full">
        <div className="text-center">
          <MicOff size={48} className="mx-auto text-gray-300 mb-4" />
          <h3 className="text-lg font-semibold text-gray-900 mb-2">Voice Input Not Supported</h3>
          <p className="text-gray-500 mb-4">{error}</p>
          <button onClick={onCancel} className="btn btn-secondary">
            Close
          </button>
        </div>
      </div>
    )
  }

  return (
    <div className="bg-white rounded-xl shadow-lg p-6 max-w-md w-full">
      <h3 className="text-lg font-bold text-gray-900 mb-4">Voice Input</h3>

      {/* Microphone Button */}
      <div className="flex justify-center mb-6">
        <button
          onClick={isListening ? stopListening : startListening}
          className={`w-20 h-20 rounded-full flex items-center justify-center transition-all ${
            isListening
              ? 'bg-red-500 hover:bg-red-600 animate-pulse'
              : 'bg-primary-500 hover:bg-primary-600'
          }`}
        >
          {isListening ? (
            <Square size={32} className="text-white" />
          ) : (
            <Mic size={32} className="text-white" />
          )}
        </button>
      </div>

      {/* Status */}
      <div className="text-center mb-4">
        {isListening ? (
          <div className="flex items-center justify-center gap-2 text-red-500">
            <Loader2 size={16} className="animate-spin" />
            <span>Listening...</span>
          </div>
        ) : (
          <p className="text-gray-500">
            {transcript ? 'Tap to continue recording' : placeholder}
          </p>
        )}
      </div>

      {/* Transcript Display */}
      <div className="bg-gray-50 rounded-lg p-4 min-h-[100px] mb-4">
        {transcript || interimTranscript ? (
          <p className="text-gray-900">
            {transcript}
            <span className="text-gray-400">{interimTranscript}</span>
          </p>
        ) : (
          <p className="text-gray-400 text-center">Your speech will appear here...</p>
        )}
      </div>

      {/* Error Display */}
      {error && (
        <div className="bg-red-50 border border-red-200 rounded-lg p-3 mb-4">
          <p className="text-sm text-red-600">{error}</p>
        </div>
      )}

      {/* Tips */}
      <div className="bg-blue-50 border border-blue-200 rounded-lg p-3 mb-4">
        <p className="text-xs text-blue-600">
          <strong>Tip:</strong> Speak clearly and at a moderate pace for best results.
          Say punctuation marks like "period" or "comma" if needed.
        </p>
      </div>

      {/* Action Buttons */}
      <div className="flex gap-3">
        <button onClick={handleCancel} className="btn btn-secondary flex-1">
          Cancel
        </button>
        <button
          onClick={() => setTranscript('')}
          disabled={!transcript}
          className="btn btn-secondary disabled:opacity-50"
        >
          Clear
        </button>
        <button
          onClick={handleSave}
          disabled={!transcript.trim()}
          className="btn btn-primary flex-1 disabled:opacity-50"
        >
          Use Text
        </button>
      </div>
    </div>
  )
}

export default VoiceInput
