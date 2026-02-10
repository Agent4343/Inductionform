// API Service - Connects to Railway backend

const API_BASE = import.meta.env.VITE_API_URL || '/api'

class ApiService {
  constructor() {
    this.token = null
    this.demoMode = false
  }

  setToken(token) {
    this.token = token
  }

  setDemoMode(isDemoMode) {
    this.demoMode = isDemoMode
  }

  async request(endpoint, options = {}) {
    // In demo mode, don't make real API calls
    if (this.demoMode) {
      throw new Error('Demo mode - API calls disabled')
    }

    const headers = {
      'Content-Type': 'application/json',
      ...options.headers,
    }

    if (this.token) {
      headers['Authorization'] = `Bearer ${this.token}`
    }

    try {
      const response = await fetch(`${API_BASE}${endpoint}`, {
        ...options,
        headers,
      })

      // Check if response is HTML (error page) instead of JSON
      const contentType = response.headers.get('content-type')
      if (contentType && contentType.includes('text/html')) {
        throw new Error('Backend server is not available or returned an error page. Please try demo mode or check that the backend is running.')
      }

      if (response.status === 401) {
        // Try to refresh token
        const refreshed = await this.refreshToken()
        if (refreshed) {
          headers['Authorization'] = `Bearer ${this.token}`
          return fetch(`${API_BASE}${endpoint}`, { ...options, headers })
        }
        // Logout if refresh fails
        localStorage.clear()
        window.location.href = '/login'
        throw new Error('Session expired. Please log in again.')
      }

      if (!response.ok) {
        const error = await response.json().catch(() => ({ 
          error: `Server error (${response.status}). The backend may not be running.` 
        }))
        throw new Error(error.error || error.message || `Request failed with status ${response.status}`)
      }

      return response.json()
    } catch (error) {
      // If it's a network error (backend not running)
      if (error.message.includes('Failed to fetch') || error.name === 'TypeError') {
        throw new Error('Unable to connect to backend server. Please try demo mode or check that the backend is running.')
      }
      // Re-throw other errors
      throw error
    }
  }

  async refreshToken() {
    const refreshToken = localStorage.getItem('refreshToken')
    if (!refreshToken) return false

    try {
      const response = await fetch(`${API_BASE}/auth/refresh`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ refreshToken }),
      })

      if (response.ok) {
        const data = await response.json()
        this.token = data.accessToken
        localStorage.setItem('accessToken', data.accessToken)
        localStorage.setItem('refreshToken', data.refreshToken)
        return true
      }
    } catch (e) {
      console.error('Token refresh failed:', e)
    }
    return false
  }

  // Auth
  async login(email, password) {
    try {
      return await this.request('/auth/login', {
        method: 'POST',
        body: JSON.stringify({ email, password }),
      })
    } catch (error) {
      // Provide user-friendly error messages
      if (error.message.includes('Backend server is not available') || 
          error.message.includes('Unable to connect')) {
        throw new Error('Backend server is not available. Try using "Continue with Demo Account" to explore the application.')
      }
      throw error
    }
  }

  async register(name, email, password) {
    return this.request('/auth/register', {
      method: 'POST',
      body: JSON.stringify({ name, email, password }),
    })
  }

  // Forms
  async getForms(params = {}) {
    if (this.demoMode) {
      // Return demo forms in demo mode
      return { forms: demoData.forms, total: demoData.forms.length }
    }
    try {
      const query = new URLSearchParams(params).toString()
      return await this.request(`/forms${query ? `?${query}` : ''}`)
    } catch (e) {
      console.log('Using demo forms data')
      // Return demo forms when API not available
      const demoForms = [
        {
          id: 'demo-1',
          title: 'Safety Inspection - Warehouse A',
          templateName: 'Daily Safety Inspection',
          status: 'approved',
          submittedBy: 'John Smith',
          createdAt: new Date(Date.now() - 86400000).toISOString(),
          signatureCount: 1
        },
        {
          id: 'demo-2',
          title: 'Incident Report - Loading Dock',
          templateName: 'Incident Report',
          status: 'pending',
          submittedBy: 'Jane Doe',
          createdAt: new Date(Date.now() - 172800000).toISOString(),
          signatureCount: 2
        },
        {
          id: 'demo-3',
          title: 'Equipment Check - Forklift #12',
          templateName: 'Equipment Checklist',
          status: 'submitted',
          submittedBy: 'Mike Wilson',
          createdAt: new Date(Date.now() - 259200000).toISOString(),
          signatureCount: 1
        },
        {
          id: 'demo-4',
          title: 'Delivery Receipt - Order #4521',
          templateName: 'Delivery Receipt',
          status: 'approved',
          submittedBy: 'Sarah Johnson',
          createdAt: new Date(Date.now() - 345600000).toISOString(),
          signatureCount: 2
        },
        {
          id: 'demo-5',
          title: 'Hot Work Permit - Welding Bay',
          templateName: 'Hot Work Permit',
          status: 'rejected',
          submittedBy: 'Tom Brown',
          createdAt: new Date(Date.now() - 432000000).toISOString(),
          signatureCount: 0
        }
      ]

      // Filter by status if provided
      let filtered = demoForms
      if (params.status && params.status !== 'all') {
        filtered = demoForms.filter(f => f.status === params.status)
      }

      return { forms: filtered, totalPages: 1 }
    }
  }

  async getForm(id) {
    if (this.demoMode) {
      const form = demoData.forms.find(f => f.id === id)
      if (!form) throw new Error('Form not found')
      return form
    }
    try {
      return await this.request(`/forms/${id}`)
    } catch (e) {
      // Return demo form detail
      return {
        id,
        title: 'Safety Inspection - Warehouse A',
        templateName: 'Daily Safety Inspection',
        status: 'approved',
        submittedBy: 'John Smith',
        createdAt: new Date(Date.now() - 86400000).toISOString(),
        location: { latitude: 43.6532, longitude: -79.3832 },
        fields: [
          { id: '1', type: 'section', label: 'Inspection Details' },
          { id: '2', type: 'date', label: 'Inspection Date', value: new Date().toISOString().split('T')[0], required: true },
          { id: '3', type: 'text', label: 'Inspector Name', value: 'John Smith', required: true },
          { id: '4', type: 'dropdown', label: 'Location', value: 'Warehouse A', required: true },
          { id: '5', type: 'section', label: 'Safety Checks' },
          { id: '6', type: 'yesNo', label: 'PPE Available?', value: 'yes', required: true },
          { id: '7', type: 'yesNo', label: 'Exits Clear?', value: 'yes', required: true },
          { id: '8', type: 'yesNo', label: 'Hazards Found?', value: 'no', required: true },
          { id: '9', type: 'textarea', label: 'Comments', value: 'All areas inspected. No issues found.' },
          { id: '10', type: 'section', label: 'Verification' },
          { id: '11', type: 'signature', label: 'Inspector Signature', value: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==', required: true }
        ],
        signatures: [
          {
            signerName: 'John Smith',
            signerEmail: 'john@example.com',
            timestamp: new Date(Date.now() - 86400000).toISOString(),
            signatureData: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='
          }
        ],
        auditTrail: [
          { action: 'Form created', user: 'John Smith', timestamp: new Date(Date.now() - 90000000).toISOString() },
          { action: 'Form submitted', user: 'John Smith', timestamp: new Date(Date.now() - 86400000).toISOString() },
          { action: 'Form approved', user: 'Manager', timestamp: new Date(Date.now() - 43200000).toISOString() }
        ]
      }
    }
  }

  async createForm(data) {
    if (this.demoMode) {
      // Simulate creating a form
      return { id: 'demo-' + Date.now(), ...data, status: 'draft' }
    }
    return this.request('/forms', {
      method: 'POST',
      body: JSON.stringify(data),
    })
  }

  async updateForm(id, data) {
    if (this.demoMode) {
      return { id, ...data }
    }
    return this.request(`/forms/${id}`, {
      method: 'PUT',
      body: JSON.stringify(data),
    })
  }

  async deleteForm(id) {
    if (this.demoMode) {
      return { success: true }
    }
    return this.request(`/forms/${id}`, { method: 'DELETE' })
  }

  async submitForm(id) {
    if (this.demoMode) {
      return { id, status: 'submitted' }
    }
    return this.request(`/forms/${id}/submit`, { method: 'POST' })
  }

  async approveForm(id, comments) {
    if (this.demoMode) {
      return { id, status: 'approved', comments }
    }
    return this.request(`/forms/${id}/approve`, {
      method: 'POST',
      body: JSON.stringify({ comments }),
    })
  }

  async rejectForm(id, reason) {
    if (this.demoMode) {
      return { id, status: 'rejected', reason }
    }
    return this.request(`/forms/${id}/reject`, {
      method: 'POST',
      body: JSON.stringify({ reason }),
    })
  }

  // Templates
  async getTemplates(params = {}) {
    if (this.demoMode) {
      // Return demo templates
      return { templates: demoData.templates }
    }
    const query = new URLSearchParams(params).toString()
    return this.request(`/templates${query ? `?${query}` : ''}`)
  }

  async getTemplate(id) {
    if (this.demoMode) {
      const template = demoData.templates.find(t => t.id === id)
      if (!template) throw new Error('Template not found')
      return template
    }
    return this.request(`/templates/${id}`)
  }

  async createTemplate(data) {
    if (this.demoMode) {
      return { id: 'demo-template-' + Date.now(), ...data }
    }
    return this.request('/templates', {
      method: 'POST',
      body: JSON.stringify(data),
    })
  }

  async updateTemplate(id, data) {
    return this.request(`/templates/${id}`, {
      method: 'PUT',
      body: JSON.stringify(data),
    })
  }

  async deleteTemplate(id) {
    return this.request(`/templates/${id}`, { method: 'DELETE' })
  }

  // Load shared industrial templates
  async getSharedTemplates() {
    try {
      const response = await fetch('/templates/industrial-templates.json')
      if (response.ok) {
        const data = await response.json()
        // Return the templates array with all fields
        return data.templates || data
      }
    } catch (e) {
      console.log('Could not load shared templates from file')
    }
    // Return built-in templates as fallback (with basic fields)
    return [
      {
        id: 'daily-safety',
        name: 'Daily Safety Inspection',
        category: 'Safety',
        description: 'Standard daily safety walkthrough inspection form',
        fieldCount: 15,
        featured: true,
        fields: [
          { id: 'header', type: 'section', label: 'Inspection Details' },
          { id: 'date', type: 'date', label: 'Inspection Date', required: true },
          { id: 'location', type: 'dropdown', label: 'Work Area', required: true, options: ['Warehouse A', 'Warehouse B', 'Loading Dock', 'Manufacturing Floor', 'Other'] },
          { id: 'inspector', type: 'text', label: 'Inspector Name', required: true },
          { id: 'ppe-section', type: 'section', label: 'PPE Checks' },
          { id: 'ppe-available', type: 'yesNo', label: 'Required PPE available?', required: true },
          { id: 'ppe-worn', type: 'yesNo', label: 'All personnel wearing PPE?', required: true },
          { id: 'housekeeping-section', type: 'section', label: 'Housekeeping' },
          { id: 'floors-clear', type: 'yesNo', label: 'Floors clear?', required: true },
          { id: 'aisles-clear', type: 'yesNo', label: 'Aisles clear?', required: true },
          { id: 'hazards-section', type: 'section', label: 'Hazards' },
          { id: 'hazards-found', type: 'yesNo', label: 'Any hazards found?', required: true },
          { id: 'hazard-description', type: 'textarea', label: 'Describe hazards', required: false },
          { id: 'signature-section', type: 'section', label: 'Verification' },
          { id: 'inspector-signature', type: 'signature', label: 'Inspector Signature', required: true }
        ]
      },
      {
        id: 'incident-report',
        name: 'Incident/Accident Report',
        category: 'Safety',
        description: 'Report workplace incidents and accidents',
        fieldCount: 18,
        featured: true,
        fields: [
          { id: 'header', type: 'section', label: 'Incident Information' },
          { id: 'incident-date', type: 'date', label: 'Date of Incident', required: true },
          { id: 'incident-time', type: 'time', label: 'Time of Incident', required: true },
          { id: 'incident-type', type: 'dropdown', label: 'Type of Incident', required: true, options: ['Injury', 'Near Miss', 'Property Damage', 'Other'] },
          { id: 'location', type: 'text', label: 'Location', required: true },
          { id: 'injured-section', type: 'section', label: 'Injured Person' },
          { id: 'injured-name', type: 'text', label: 'Name', required: false },
          { id: 'description-section', type: 'section', label: 'Description' },
          { id: 'description', type: 'textarea', label: 'What happened?', required: true },
          { id: 'photo', type: 'photo', label: 'Photo of scene', required: false },
          { id: 'actions-section', type: 'section', label: 'Actions' },
          { id: 'immediate-actions', type: 'textarea', label: 'Immediate actions taken', required: true },
          { id: 'signature-section', type: 'section', label: 'Signatures' },
          { id: 'reporter-signature', type: 'signature', label: 'Reporter Signature', required: true },
          { id: 'gps', type: 'location', label: 'GPS Location', required: false }
        ]
      },
      {
        id: 'equipment-checklist',
        name: 'Equipment Pre-Use Checklist',
        category: 'Operations',
        description: 'Pre-operation safety check for equipment',
        fieldCount: 14,
        featured: false,
        fields: [
          { id: 'header', type: 'section', label: 'Equipment Information' },
          { id: 'date', type: 'date', label: 'Date', required: true },
          { id: 'equipment-type', type: 'dropdown', label: 'Equipment Type', required: true, options: ['Forklift', 'Crane', 'Truck', 'Other'] },
          { id: 'equipment-id', type: 'text', label: 'Equipment ID', required: true },
          { id: 'operator', type: 'text', label: 'Operator Name', required: true },
          { id: 'checks-section', type: 'section', label: 'Safety Checks' },
          { id: 'visual-ok', type: 'yesNo', label: 'Visual inspection OK?', required: true },
          { id: 'safety-features', type: 'yesNo', label: 'Safety features working?', required: true },
          { id: 'controls-ok', type: 'yesNo', label: 'Controls functioning?', required: true },
          { id: 'safe-to-operate', type: 'yesNo', label: 'Safe to operate?', required: true },
          { id: 'defects-section', type: 'section', label: 'Defects' },
          { id: 'defects-found', type: 'yesNo', label: 'Any defects?', required: true },
          { id: 'defect-notes', type: 'textarea', label: 'Defect details', required: false },
          { id: 'operator-signature', type: 'signature', label: 'Operator Signature', required: true }
        ]
      },
      {
        id: 'delivery-receipt',
        name: 'Delivery Receipt',
        category: 'Logistics',
        description: 'Confirm receipt of deliveries with signatures',
        fieldCount: 12,
        featured: false,
        fields: [
          { id: 'header', type: 'section', label: 'Delivery Information' },
          { id: 'date', type: 'date', label: 'Delivery Date', required: true },
          { id: 'time', type: 'time', label: 'Delivery Time', required: true },
          { id: 'order-number', type: 'text', label: 'Order Number', required: true },
          { id: 'items-section', type: 'section', label: 'Items' },
          { id: 'items', type: 'textarea', label: 'Items Delivered', required: true },
          { id: 'quantity', type: 'number', label: 'Quantity', required: true },
          { id: 'condition', type: 'dropdown', label: 'Condition', required: true, options: ['Good', 'Minor Damage', 'Damaged'] },
          { id: 'photo', type: 'photo', label: 'Photo of delivery', required: false },
          { id: 'signatures-section', type: 'section', label: 'Signatures' },
          { id: 'receiver-signature', type: 'signature', label: 'Receiver Signature', required: true },
          { id: 'driver-signature', type: 'signature', label: 'Driver Signature', required: true }
        ]
      }
    ]
  }

  // User
  async getProfile() {
    if (this.demoMode) {
      return {
        id: 'demo-user',
        name: 'Demo User',
        email: 'demo@example.com',
        role: 'admin'
      }
    }
    return this.request('/users/me')
  }

  async updateProfile(data) {
    if (this.demoMode) {
      return { ...data }
    }
    return this.request('/users/me', {
      method: 'PUT',
      body: JSON.stringify(data),
    })
  }

  async getNotifications() {
    if (this.demoMode) {
      return []
    }
    return this.request('/users/me/notifications')
  }

  // Stats/Dashboard
  async getStats() {
    if (this.demoMode) {
      // Return demo stats
      return {
        totalForms: 47,
        completedForms: 32,
        pendingForms: 12,
        requiresAction: 3,
        weeklySubmissions: 15,
        weeklyApprovals: 11,
        activeUsers: 8
      }
    }
    try {
      return await this.request('/stats')
    } catch {
      // Return demo stats if API not available
      return {
        totalForms: 47,
        completedForms: 32,
        pendingForms: 12,
        requiresAction: 3,
        weeklySubmissions: 15,
        weeklyApprovals: 11,
        activeUsers: 8
      }
    }
  }

  async updateFormStatus(id, status, reason = null) {
    if (this.demoMode) {
      return { id, status, reason }
    }
    return this.request(`/forms/${id}/status`, {
      method: 'PATCH',
      body: JSON.stringify({ status, reason }),
    })
  }
}

export const api = new ApiService()

// Default export for convenience
export default api

// Demo data for testing without backend
export const demoData = {
  forms: [
    {
      id: '1',
      title: 'Safety Inspection - Warehouse A',
      status: 'approved',
      createdByName: 'John Smith',
      createdAt: '2024-02-01T10:00:00Z',
      updatedAt: '2024-02-01T14:30:00Z',
      signatureCount: 2,
    },
    {
      id: '2',
      title: 'Incident Report - Loading Dock',
      status: 'submitted',
      createdByName: 'Jane Doe',
      createdAt: '2024-02-02T09:00:00Z',
      updatedAt: '2024-02-02T09:45:00Z',
      signatureCount: 1,
    },
    {
      id: '3',
      title: 'Equipment Checklist - Forklift #12',
      status: 'draft',
      createdByName: 'Mike Wilson',
      createdAt: '2024-02-03T08:00:00Z',
      updatedAt: '2024-02-03T08:00:00Z',
      signatureCount: 0,
    },
    {
      id: '4',
      title: 'Visitor Sign-In',
      status: 'approved',
      createdByName: 'Sarah Johnson',
      createdAt: '2024-02-03T11:00:00Z',
      updatedAt: '2024-02-03T11:30:00Z',
      signatureCount: 1,
    },
    {
      id: '5',
      title: 'Work Order - HVAC Repair',
      status: 'rejected',
      createdByName: 'John Smith',
      createdAt: '2024-02-01T15:00:00Z',
      updatedAt: '2024-02-02T10:00:00Z',
      signatureCount: 0,
    },
  ],
  templates: [
    { 
      id: 'daily-safety-inspection', 
      name: 'Daily Safety Inspection', 
      category: 'safety', 
      fieldCount: 30,
      description: 'Comprehensive daily safety inspection checklist',
      estimatedTime: '5-10 min'
    },
    { 
      id: 'incident-report', 
      name: 'Incident / Accident Report', 
      category: 'safety', 
      fieldCount: 30,
      description: 'Detailed incident and accident reporting form',
      estimatedTime: '10-15 min'
    },
    { 
      id: 'equipment-checklist', 
      name: 'Equipment Pre-Use Checklist', 
      category: 'operations', 
      fieldCount: 30,
      description: 'Pre-operational equipment safety checklist',
      estimatedTime: '5 min'
    },
    { 
      id: 'hot-work-permit', 
      name: 'Hot Work Permit', 
      category: 'permits', 
      fieldCount: 26,
      description: 'Hot work authorization and safety permit',
      estimatedTime: '10 min'
    },
    { 
      id: 'delivery-receipt', 
      name: 'Delivery Receipt', 
      category: 'logistics', 
      fieldCount: 21,
      description: 'Goods delivery verification and sign-off',
      estimatedTime: '5 min'
    },
    { 
      id: 'toolbox-talk', 
      name: 'Toolbox Talk / Safety Meeting', 
      category: 'safety', 
      fieldCount: 15,
      description: 'Safety meeting attendance and topic discussion',
      estimatedTime: '5 min'
    },
    { 
      id: 'offshore-induction-hebron', 
      name: 'Offshore Induction Form - Hebron Platform', 
      category: 'safety', 
      fieldCount: 70,
      description: 'Hebron Platform - Green Hat Program (CANE-EC-OFPRO-01-005-4008-00 | 04)',
      estimatedTime: '20-30 min'
    },
  ],
}
