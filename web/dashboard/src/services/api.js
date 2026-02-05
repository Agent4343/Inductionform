// API Service - Connects to Railway backend

const API_BASE = import.meta.env.VITE_API_URL || '/api'

class ApiService {
  constructor() {
    this.token = null
  }

  setToken(token) {
    this.token = token
  }

  async request(endpoint, options = {}) {
    const headers = {
      'Content-Type': 'application/json',
      ...options.headers,
    }

    if (this.token) {
      headers['Authorization'] = `Bearer ${this.token}`
    }

    const response = await fetch(`${API_BASE}${endpoint}`, {
      ...options,
      headers,
    })

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
    }

    if (!response.ok) {
      const error = await response.json().catch(() => ({ error: 'Request failed' }))
      throw new Error(error.error || 'Request failed')
    }

    return response.json()
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
    return this.request('/auth/login', {
      method: 'POST',
      body: JSON.stringify({ email, password }),
    })
  }

  async register(name, email, password) {
    return this.request('/auth/register', {
      method: 'POST',
      body: JSON.stringify({ name, email, password }),
    })
  }

  // Forms
  async getForms(params = {}) {
    const query = new URLSearchParams(params).toString()
    return this.request(`/forms${query ? `?${query}` : ''}`)
  }

  async getForm(id) {
    return this.request(`/forms/${id}`)
  }

  async createForm(data) {
    return this.request('/forms', {
      method: 'POST',
      body: JSON.stringify(data),
    })
  }

  async updateForm(id, data) {
    return this.request(`/forms/${id}`, {
      method: 'PUT',
      body: JSON.stringify(data),
    })
  }

  async deleteForm(id) {
    return this.request(`/forms/${id}`, { method: 'DELETE' })
  }

  async submitForm(id) {
    return this.request(`/forms/${id}/submit`, { method: 'POST' })
  }

  async approveForm(id, comments) {
    return this.request(`/forms/${id}/approve`, {
      method: 'POST',
      body: JSON.stringify({ comments }),
    })
  }

  async rejectForm(id, reason) {
    return this.request(`/forms/${id}/reject`, {
      method: 'POST',
      body: JSON.stringify({ reason }),
    })
  }

  // Templates
  async getTemplates(params = {}) {
    const query = new URLSearchParams(params).toString()
    return this.request(`/templates${query ? `?${query}` : ''}`)
  }

  async getTemplate(id) {
    return this.request(`/templates/${id}`)
  }

  async createTemplate(data) {
    return this.request('/templates', {
      method: 'POST',
      body: JSON.stringify(data),
    })
  }

  // User
  async getProfile() {
    return this.request('/users/me')
  }

  async updateProfile(data) {
    return this.request('/users/me', {
      method: 'PUT',
      body: JSON.stringify(data),
    })
  }

  async getNotifications() {
    return this.request('/users/me/notifications')
  }

  // Stats/Dashboard
  async getStats() {
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
