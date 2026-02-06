import { useState, useRef } from 'react'
import { Camera, Upload, X, Image, RotateCw, ZoomIn } from 'lucide-react'

/**
 * ImageUpload Component
 * Supports camera capture, file upload, and basic annotations
 */
function ImageUpload({ onSave, onCancel, maxImages = 5, existingImages = [] }) {
  const [images, setImages] = useState(existingImages)
  const [selectedImage, setSelectedImage] = useState(null)
  const [isCapturing, setIsCapturing] = useState(false)
  const fileInputRef = useRef(null)
  const cameraInputRef = useRef(null)
  const videoRef = useRef(null)
  const streamRef = useRef(null)

  const handleFileUpload = (e) => {
    const files = Array.from(e.target.files || [])
    processFiles(files)
  }

  const processFiles = (files) => {
    const remaining = maxImages - images.length
    const filesToProcess = files.slice(0, remaining)

    filesToProcess.forEach(file => {
      if (!file.type.startsWith('image/')) return

      const reader = new FileReader()
      reader.onload = () => {
        const newImage = {
          id: `img-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
          data: reader.result,
          name: file.name,
          size: file.size,
          type: file.type,
          timestamp: new Date().toISOString()
        }
        setImages(prev => [...prev, newImage])
      }
      reader.readAsDataURL(file)
    })
  }

  const startCamera = async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: 'environment' }
      })
      streamRef.current = stream
      if (videoRef.current) {
        videoRef.current.srcObject = stream
      }
      setIsCapturing(true)
    } catch (err) {
      console.error('Camera access denied:', err)
      alert('Camera access denied. Please use file upload instead.')
    }
  }

  const capturePhoto = () => {
    if (!videoRef.current) return

    const canvas = document.createElement('canvas')
    canvas.width = videoRef.current.videoWidth
    canvas.height = videoRef.current.videoHeight
    const ctx = canvas.getContext('2d')
    ctx.drawImage(videoRef.current, 0, 0)

    const imageData = canvas.toDataURL('image/jpeg', 0.8)
    const newImage = {
      id: `img-${Date.now()}`,
      data: imageData,
      name: `Photo_${new Date().toISOString().split('T')[0]}.jpg`,
      size: Math.round(imageData.length * 0.75), // Approximate size
      type: 'image/jpeg',
      timestamp: new Date().toISOString()
    }

    setImages(prev => [...prev, newImage])
    stopCamera()
  }

  const stopCamera = () => {
    if (streamRef.current) {
      streamRef.current.getTracks().forEach(track => track.stop())
      streamRef.current = null
    }
    setIsCapturing(false)
  }

  const removeImage = (id) => {
    setImages(prev => prev.filter(img => img.id !== id))
    if (selectedImage?.id === id) {
      setSelectedImage(null)
    }
  }

  const handleSave = () => {
    onSave(images)
  }

  const formatFileSize = (bytes) => {
    if (bytes < 1024) return `${bytes} B`
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
  }

  return (
    <div className="bg-white rounded-xl shadow-lg p-6 max-w-2xl w-full">
      <h3 className="text-lg font-bold text-gray-900 mb-4">Add Photos</h3>

      {/* Camera View */}
      {isCapturing && (
        <div className="relative mb-4 rounded-lg overflow-hidden bg-black">
          <video
            ref={videoRef}
            autoPlay
            playsInline
            className="w-full h-64 object-cover"
          />
          <div className="absolute bottom-4 left-0 right-0 flex justify-center gap-4">
            <button
              onClick={stopCamera}
              className="p-3 bg-gray-800/80 text-white rounded-full hover:bg-gray-700"
            >
              <X size={24} />
            </button>
            <button
              onClick={capturePhoto}
              className="p-4 bg-white rounded-full hover:bg-gray-100"
            >
              <Camera size={28} className="text-primary-500" />
            </button>
          </div>
        </div>
      )}

      {/* Upload Options */}
      {!isCapturing && images.length < maxImages && (
        <div className="flex gap-4 mb-4">
          <button
            onClick={startCamera}
            className="flex-1 p-4 border-2 border-dashed border-gray-300 rounded-lg hover:border-primary-500 hover:bg-primary-50 transition-colors flex flex-col items-center gap-2"
          >
            <Camera size={32} className="text-gray-400" />
            <span className="text-sm text-gray-600">Take Photo</span>
          </button>
          <button
            onClick={() => fileInputRef.current?.click()}
            className="flex-1 p-4 border-2 border-dashed border-gray-300 rounded-lg hover:border-primary-500 hover:bg-primary-50 transition-colors flex flex-col items-center gap-2"
          >
            <Upload size={32} className="text-gray-400" />
            <span className="text-sm text-gray-600">Upload Files</span>
          </button>
          <input
            ref={fileInputRef}
            type="file"
            accept="image/*"
            multiple
            onChange={handleFileUpload}
            className="hidden"
          />
        </div>
      )}

      {/* Image Preview Grid */}
      {images.length > 0 && (
        <div className="mb-4">
          <div className="flex items-center justify-between mb-2">
            <p className="text-sm text-gray-600">{images.length} of {maxImages} photos</p>
          </div>
          <div className="grid grid-cols-3 gap-3">
            {images.map((image) => (
              <div
                key={image.id}
                className={`relative aspect-square rounded-lg overflow-hidden cursor-pointer group ${
                  selectedImage?.id === image.id ? 'ring-2 ring-primary-500' : ''
                }`}
                onClick={() => setSelectedImage(image)}
              >
                <img
                  src={image.data}
                  alt={image.name}
                  className="w-full h-full object-cover"
                />
                <div className="absolute inset-0 bg-black/0 group-hover:bg-black/20 transition-colors" />
                <button
                  onClick={(e) => { e.stopPropagation(); removeImage(image.id) }}
                  className="absolute top-1 right-1 p-1 bg-red-500 text-white rounded-full opacity-0 group-hover:opacity-100 transition-opacity"
                >
                  <X size={14} />
                </button>
                <button
                  onClick={(e) => { e.stopPropagation(); setSelectedImage(image) }}
                  className="absolute bottom-1 right-1 p-1 bg-white rounded-full opacity-0 group-hover:opacity-100 transition-opacity"
                >
                  <ZoomIn size={14} className="text-gray-700" />
                </button>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Selected Image Preview */}
      {selectedImage && (
        <div className="fixed inset-0 bg-black/80 flex items-center justify-center z-50 p-4">
          <div className="relative max-w-4xl w-full">
            <img
              src={selectedImage.data}
              alt={selectedImage.name}
              className="w-full h-auto max-h-[80vh] object-contain rounded-lg"
            />
            <button
              onClick={() => setSelectedImage(null)}
              className="absolute top-4 right-4 p-2 bg-white rounded-full hover:bg-gray-100"
            >
              <X size={24} />
            </button>
            <div className="absolute bottom-4 left-4 bg-black/60 text-white px-3 py-2 rounded-lg">
              <p className="text-sm">{selectedImage.name}</p>
              <p className="text-xs text-gray-300">{formatFileSize(selectedImage.size)}</p>
            </div>
          </div>
        </div>
      )}

      {/* Empty State */}
      {images.length === 0 && !isCapturing && (
        <div className="text-center py-8 border-2 border-dashed border-gray-200 rounded-lg mb-4">
          <Image size={48} className="mx-auto text-gray-300 mb-2" />
          <p className="text-gray-500">No photos added yet</p>
          <p className="text-sm text-gray-400">Take a photo or upload from your device</p>
        </div>
      )}

      {/* Action Buttons */}
      <div className="flex gap-3">
        <button
          onClick={() => { stopCamera(); onCancel() }}
          className="btn btn-secondary flex-1"
        >
          Cancel
        </button>
        <button
          onClick={handleSave}
          className="btn btn-primary flex-1"
        >
          Save {images.length > 0 ? `(${images.length})` : ''}
        </button>
      </div>
    </div>
  )
}

export default ImageUpload
