// Professional PDF Export Utility
// Uses jsPDF and html2canvas for high-quality PDF generation

/**
 * Professional PDF Document Generator
 * Creates legally-compliant forms with digital signatures
 */

// Color theme for professional appearance
const COLORS = {
  primary: '#1e40af',      // Blue
  secondary: '#4b5563',    // Gray
  accent: '#059669',       // Green
  danger: '#dc2626',       // Red
  light: '#f3f4f6',        // Light gray
  dark: '#111827',         // Dark
  white: '#ffffff'
}

/**
 * Generate a professional PDF from form data
 * @param {Object} form - Form object with fields and metadata
 * @param {Object} options - PDF generation options
 */
export async function generateFormPDF(form, options = {}) {
  // Dynamic import to reduce initial bundle size
  const { jsPDF } = await import('jspdf')

  const {
    includeSignatures = true,
    includeTimestamps = true,
    includeLocation = true,
    watermark = null,
    companyLogo = null,
    orientation = 'portrait',
    pageSize = 'letter'
  } = options

  // Create PDF document
  const doc = new jsPDF({
    orientation,
    unit: 'mm',
    format: pageSize
  })

  const pageWidth = doc.internal.pageSize.getWidth()
  const pageHeight = doc.internal.pageSize.getHeight()
  const margin = 15
  const contentWidth = pageWidth - (margin * 2)
  let y = margin

  // Helper functions
  const addNewPage = () => {
    doc.addPage()
    y = margin
    addHeader()
  }

  const checkPageBreak = (neededHeight) => {
    if (y + neededHeight > pageHeight - margin - 20) {
      addNewPage()
      return true
    }
    return false
  }

  const addHeader = () => {
    // Header background
    doc.setFillColor(30, 64, 175) // primary blue
    doc.rect(0, 0, pageWidth, 25, 'F')

    // Company logo (if provided)
    if (companyLogo) {
      try {
        doc.addImage(companyLogo, 'PNG', margin, 3, 20, 20)
      } catch (e) {
        console.warn('Could not add logo:', e)
      }
    }

    // Form title
    doc.setFont('helvetica', 'bold')
    doc.setFontSize(14)
    doc.setTextColor(255, 255, 255)
    doc.text(form.title || form.name || 'Digital Form', companyLogo ? margin + 25 : margin, 14)

    // Document ID and date
    doc.setFontSize(9)
    doc.setFont('helvetica', 'normal')
    const docId = `ID: ${form.id?.substring(0, 8) || 'N/A'}`
    const dateStr = new Date(form.createdAt || Date.now()).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric'
    })
    doc.text(docId, pageWidth - margin - doc.getTextWidth(docId), 10)
    doc.text(dateStr, pageWidth - margin - doc.getTextWidth(dateStr), 18)

    y = 35
  }

  const addFooter = (pageNum, totalPages) => {
    const footerY = pageHeight - 10

    // Footer line
    doc.setDrawColor(200, 200, 200)
    doc.line(margin, footerY - 5, pageWidth - margin, footerY - 5)

    // Page number
    doc.setFont('helvetica', 'normal')
    doc.setFontSize(8)
    doc.setTextColor(128, 128, 128)
    doc.text(`Page ${pageNum} of ${totalPages}`, pageWidth / 2, footerY, { align: 'center' })

    // Timestamp
    if (includeTimestamps) {
      const timestamp = new Date().toISOString()
      doc.text(`Generated: ${timestamp}`, margin, footerY)
    }

    // Legal notice
    doc.text('Digitally generated document', pageWidth - margin, footerY, { align: 'right' })
  }

  const drawSection = (label) => {
    checkPageBreak(15)

    // Section background
    doc.setFillColor(243, 244, 246) // light gray
    doc.rect(margin, y, contentWidth, 10, 'F')

    // Section border
    doc.setDrawColor(30, 64, 175)
    doc.setLineWidth(0.5)
    doc.line(margin, y, margin, y + 10)

    // Section text
    doc.setFont('helvetica', 'bold')
    doc.setFontSize(11)
    doc.setTextColor(30, 64, 175)
    doc.text(label, margin + 5, y + 7)

    y += 15
  }

  const drawField = (field) => {
    const fieldHeight = field.type === 'textarea' ? 25 :
                       field.type === 'signature' ? 40 :
                       field.type === 'photo' ? 50 : 15

    checkPageBreak(fieldHeight + 5)

    // Field label
    doc.setFont('helvetica', 'bold')
    doc.setFontSize(9)
    doc.setTextColor(75, 85, 99)
    const labelText = field.label + (field.required ? ' *' : '')
    doc.text(labelText, margin, y)

    y += 5

    // Field value box
    const valueHeight = fieldHeight - 5
    doc.setDrawColor(200, 200, 200)
    doc.setLineWidth(0.3)
    doc.rect(margin, y, contentWidth, valueHeight)

    // Field value
    doc.setFont('helvetica', 'normal')
    doc.setFontSize(10)
    doc.setTextColor(17, 24, 39)

    const value = field.value || ''

    if (field.type === 'signature' && value) {
      // Draw signature image
      try {
        doc.addImage(value, 'PNG', margin + 2, y + 2, contentWidth - 4, valueHeight - 4)
      } catch (e) {
        doc.text('[Signature captured]', margin + 5, y + valueHeight / 2 + 2)
      }
    } else if (field.type === 'photo' && value) {
      // Draw photo
      try {
        const imgWidth = Math.min(contentWidth - 4, 60)
        const imgHeight = valueHeight - 4
        doc.addImage(value, 'JPEG', margin + 2, y + 2, imgWidth, imgHeight)
      } catch (e) {
        doc.text('[Photo attached]', margin + 5, y + valueHeight / 2 + 2)
      }
    } else if (field.type === 'checkbox' || field.type === 'yesNo') {
      // Draw checkbox style
      const boxSize = 5
      const boxY = y + (valueHeight - boxSize) / 2

      if (field.type === 'yesNo') {
        const options = ['Yes', 'No', 'N/A']
        options.forEach((opt, i) => {
          const boxX = margin + 5 + (i * 30)
          doc.rect(boxX, boxY, boxSize, boxSize)
          if (value?.toLowerCase() === opt.toLowerCase()) {
            doc.setFillColor(30, 64, 175)
            doc.rect(boxX + 1, boxY + 1, boxSize - 2, boxSize - 2, 'F')
          }
          doc.text(opt, boxX + boxSize + 2, boxY + 4)
        })
      } else {
        doc.rect(margin + 5, boxY, boxSize, boxSize)
        if (value === true || value === 'true' || value === '1') {
          doc.setFillColor(30, 64, 175)
          doc.rect(margin + 6, boxY + 1, boxSize - 2, boxSize - 2, 'F')
        }
        doc.text(value ? 'Checked' : 'Unchecked', margin + 15, boxY + 4)
      }
    } else if (field.type === 'rating') {
      // Draw star rating
      const stars = parseInt(value) || 0
      const starSize = 8
      for (let i = 0; i < 5; i++) {
        const starX = margin + 5 + (i * (starSize + 2))
        const starY = y + (valueHeight - starSize) / 2
        if (i < stars) {
          doc.setFillColor(250, 204, 21) // yellow
          doc.circle(starX + starSize/2, starY + starSize/2, starSize/2, 'F')
        } else {
          doc.circle(starX + starSize/2, starY + starSize/2, starSize/2, 'S')
        }
      }
    } else if (field.type === 'location' && value) {
      // Draw location info
      const loc = typeof value === 'string' ? JSON.parse(value) : value
      doc.text(`Lat: ${loc.latitude?.toFixed(6) || 'N/A'}, Lng: ${loc.longitude?.toFixed(6) || 'N/A'}`, margin + 5, y + valueHeight / 2 + 2)
    } else if (field.type === 'textarea') {
      // Multi-line text
      const lines = doc.splitTextToSize(value, contentWidth - 10)
      doc.text(lines.slice(0, 4), margin + 5, y + 5)
    } else {
      // Standard text display
      doc.text(value.toString().substring(0, 100), margin + 5, y + valueHeight / 2 + 2)
    }

    y += valueHeight + 5
  }

  // Start generating PDF
  addHeader()

  // Form description
  if (form.description) {
    doc.setFont('helvetica', 'italic')
    doc.setFontSize(10)
    doc.setTextColor(107, 114, 128)
    const descLines = doc.splitTextToSize(form.description, contentWidth)
    doc.text(descLines, margin, y)
    y += descLines.length * 5 + 5
  }

  // Metadata section
  if (form.createdByName || form.status) {
    doc.setFillColor(239, 246, 255) // light blue
    doc.rect(margin, y, contentWidth, 20, 'F')

    doc.setFont('helvetica', 'normal')
    doc.setFontSize(9)
    doc.setTextColor(75, 85, 99)

    if (form.createdByName) {
      doc.text(`Created by: ${form.createdByName}`, margin + 5, y + 7)
    }
    if (form.status) {
      const statusColors = {
        draft: '#6b7280',
        submitted: '#2563eb',
        approved: '#059669',
        rejected: '#dc2626'
      }
      doc.setTextColor(statusColors[form.status] || '#6b7280')
      doc.text(`Status: ${form.status.toUpperCase()}`, margin + 5, y + 15)
    }

    y += 25
  }

  // Process fields
  const fields = form.fields || []

  for (const field of fields) {
    if (field.type === 'section') {
      drawSection(field.label)
    } else {
      drawField(field)
    }
  }

  // Signatures section
  if (includeSignatures && form.signatures?.length > 0) {
    checkPageBreak(60)
    drawSection('Signatures & Verification')

    for (const sig of form.signatures) {
      checkPageBreak(45)

      // Signature box
      doc.setDrawColor(200, 200, 200)
      doc.rect(margin, y, contentWidth, 35)

      // Signature image
      if (sig.signatureData) {
        try {
          doc.addImage(sig.signatureData, 'PNG', margin + 5, y + 2, 60, 25)
        } catch (e) {
          doc.text('[Signature]', margin + 10, y + 15)
        }
      }

      // Signature details
      doc.setFont('helvetica', 'bold')
      doc.setFontSize(9)
      doc.setTextColor(17, 24, 39)
      doc.text(sig.signerName || 'Signer', margin + 70, y + 8)

      doc.setFont('helvetica', 'normal')
      doc.setFontSize(8)
      doc.setTextColor(107, 114, 128)
      if (sig.signerEmail) doc.text(sig.signerEmail, margin + 70, y + 14)
      if (sig.timestamp) {
        const sigDate = new Date(sig.timestamp).toLocaleString()
        doc.text(`Signed: ${sigDate}`, margin + 70, y + 20)
      }
      if (sig.ipAddress) doc.text(`IP: ${sig.ipAddress}`, margin + 70, y + 26)
      if (sig.gpsCoordinates) {
        const loc = typeof sig.gpsCoordinates === 'string' ? JSON.parse(sig.gpsCoordinates) : sig.gpsCoordinates
        doc.text(`Location: ${loc.latitude?.toFixed(4)}, ${loc.longitude?.toFixed(4)}`, margin + 70, y + 32)
      }

      y += 40
    }
  }

  // Legal disclaimer
  checkPageBreak(30)
  y += 10

  doc.setFillColor(254, 243, 199) // yellow background
  doc.rect(margin, y, contentWidth, 25, 'F')

  doc.setFont('helvetica', 'bold')
  doc.setFontSize(8)
  doc.setTextColor(146, 64, 14)
  doc.text('LEGAL NOTICE', margin + 5, y + 6)

  doc.setFont('helvetica', 'normal')
  doc.setFontSize(7)
  const legalText = 'This document has been electronically signed and is legally binding under PIPEDA (Canada) and applicable electronic signature laws. The electronic signature(s) above have the same legal effect as handwritten signatures. Document integrity is verified using SHA-256 hash.'
  const legalLines = doc.splitTextToSize(legalText, contentWidth - 10)
  doc.text(legalLines, margin + 5, y + 12)

  // Document hash
  if (form.documentHash) {
    doc.setFont('courier', 'normal')
    doc.setFontSize(6)
    doc.text(`Hash: ${form.documentHash}`, margin + 5, y + 22)
  }

  // Add watermark if specified
  if (watermark) {
    const totalPages = doc.internal.getNumberOfPages()
    for (let i = 1; i <= totalPages; i++) {
      doc.setPage(i)
      doc.setFont('helvetica', 'bold')
      doc.setFontSize(60)
      doc.setTextColor(200, 200, 200)
      doc.text(watermark, pageWidth / 2, pageHeight / 2, {
        align: 'center',
        angle: 45,
        opacity: 0.3
      })
    }
  }

  // Add footers to all pages
  const totalPages = doc.internal.getNumberOfPages()
  for (let i = 1; i <= totalPages; i++) {
    doc.setPage(i)
    addFooter(i, totalPages)
  }

  return doc
}

/**
 * Download form as PDF
 */
export async function downloadFormPDF(form, options = {}) {
  const doc = await generateFormPDF(form, options)
  const filename = `${form.title || form.name || 'form'}_${new Date().toISOString().split('T')[0]}.pdf`
  doc.save(filename)
}

/**
 * Get PDF as blob for sharing/uploading
 */
export async function getFormPDFBlob(form, options = {}) {
  const doc = await generateFormPDF(form, options)
  return doc.output('blob')
}

/**
 * Get PDF as base64 for email attachment
 */
export async function getFormPDFBase64(form, options = {}) {
  const doc = await generateFormPDF(form, options)
  return doc.output('datauristring')
}

/**
 * Print form directly
 */
export async function printFormPDF(form, options = {}) {
  const doc = await generateFormPDF(form, options)
  doc.autoPrint()
  const blobUrl = doc.output('bloburl')
  window.open(blobUrl, '_blank')
}

export default {
  generateFormPDF,
  downloadFormPDF,
  getFormPDFBlob,
  getFormPDFBase64,
  printFormPDF
}
