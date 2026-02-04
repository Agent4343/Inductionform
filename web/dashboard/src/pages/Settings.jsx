import { useState } from 'react'
import { useAuth } from '../App'
import {
  User,
  Mail,
  Building,
  Bell,
  Shield,
  CreditCard,
  Globe,
  Moon,
  Smartphone,
  Key,
  Save,
  CheckCircle
} from 'lucide-react'

function Settings() {
  const { user } = useAuth()
  const [activeTab, setActiveTab] = useState('profile')
  const [isSaving, setIsSaving] = useState(false)
  const [showSaved, setShowSaved] = useState(false)

  // Profile state
  const [profile, setProfile] = useState({
    name: user?.name || '',
    email: user?.email || '',
    company: user?.company || '',
    phone: user?.phone || '',
    timezone: 'America/Toronto'
  })

  // Notification settings
  const [notifications, setNotifications] = useState({
    emailNewForm: true,
    emailApproval: true,
    emailWeekly: false,
    pushNewForm: true,
    pushApproval: true
  })

  // Security settings
  const [security, setSecurity] = useState({
    twoFactor: false,
    sessionTimeout: '30'
  })

  const handleSave = async () => {
    setIsSaving(true)
    // Simulate API call
    await new Promise((resolve) => setTimeout(resolve, 1000))
    setIsSaving(false)
    setShowSaved(true)
    setTimeout(() => setShowSaved(false), 3000)
  }

  const tabs = [
    { id: 'profile', name: 'Profile', icon: User },
    { id: 'notifications', name: 'Notifications', icon: Bell },
    { id: 'security', name: 'Security', icon: Shield },
    { id: 'billing', name: 'Billing', icon: CreditCard }
  ]

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Settings</h1>
        <p className="text-gray-500">Manage your account and preferences</p>
      </div>

      <div className="flex flex-col lg:flex-row gap-6">
        {/* Sidebar */}
        <div className="lg:w-64 flex-shrink-0">
          <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-2">
            {tabs.map((tab) => {
              const Icon = tab.icon
              return (
                <button
                  key={tab.id}
                  onClick={() => setActiveTab(tab.id)}
                  className={`w-full flex items-center gap-3 px-4 py-3 rounded-lg text-left transition-colors ${
                    activeTab === tab.id
                      ? 'bg-primary-50 text-primary-600'
                      : 'text-gray-600 hover:bg-gray-50'
                  }`}
                >
                  <Icon size={18} />
                  <span className="font-medium">{tab.name}</span>
                </button>
              )
            })}
          </div>
        </div>

        {/* Content */}
        <div className="flex-1">
          {/* Profile Tab */}
          {activeTab === 'profile' && (
            <div className="bg-white rounded-xl shadow-sm border border-gray-100">
              <div className="p-5 border-b border-gray-100">
                <h2 className="font-semibold text-gray-900">Profile Information</h2>
                <p className="text-sm text-gray-500">Update your personal details</p>
              </div>
              <div className="p-5 space-y-5">
                {/* Avatar */}
                <div className="flex items-center gap-4">
                  <div className="w-16 h-16 bg-primary-100 rounded-full flex items-center justify-center text-primary-600 text-xl font-bold">
                    {profile.name?.charAt(0) || 'U'}
                  </div>
                  <div>
                    <button className="btn btn-secondary text-sm">Change Photo</button>
                    <p className="text-xs text-gray-500 mt-1">JPG, PNG. Max 2MB</p>
                  </div>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-5">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Full Name
                    </label>
                    <div className="relative">
                      <User size={18} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
                      <input
                        type="text"
                        value={profile.name}
                        onChange={(e) => setProfile({ ...profile, name: e.target.value })}
                        className="input pl-10 w-full"
                      />
                    </div>
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Email Address
                    </label>
                    <div className="relative">
                      <Mail size={18} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
                      <input
                        type="email"
                        value={profile.email}
                        onChange={(e) => setProfile({ ...profile, email: e.target.value })}
                        className="input pl-10 w-full"
                      />
                    </div>
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Company
                    </label>
                    <div className="relative">
                      <Building size={18} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
                      <input
                        type="text"
                        value={profile.company}
                        onChange={(e) => setProfile({ ...profile, company: e.target.value })}
                        className="input pl-10 w-full"
                        placeholder="Your company name"
                      />
                    </div>
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Phone Number
                    </label>
                    <div className="relative">
                      <Smartphone size={18} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
                      <input
                        type="tel"
                        value={profile.phone}
                        onChange={(e) => setProfile({ ...profile, phone: e.target.value })}
                        className="input pl-10 w-full"
                        placeholder="+1 (555) 000-0000"
                      />
                    </div>
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Timezone
                    </label>
                    <div className="relative">
                      <Globe size={18} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
                      <select
                        value={profile.timezone}
                        onChange={(e) => setProfile({ ...profile, timezone: e.target.value })}
                        className="input pl-10 w-full"
                      >
                        <option value="America/Toronto">Eastern Time (Toronto)</option>
                        <option value="America/Vancouver">Pacific Time (Vancouver)</option>
                        <option value="America/Chicago">Central Time (Chicago)</option>
                        <option value="America/Denver">Mountain Time (Denver)</option>
                        <option value="UTC">UTC</option>
                      </select>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* Notifications Tab */}
          {activeTab === 'notifications' && (
            <div className="bg-white rounded-xl shadow-sm border border-gray-100">
              <div className="p-5 border-b border-gray-100">
                <h2 className="font-semibold text-gray-900">Notification Preferences</h2>
                <p className="text-sm text-gray-500">Choose how you want to be notified</p>
              </div>
              <div className="p-5 space-y-6">
                {/* Email Notifications */}
                <div>
                  <h3 className="text-sm font-medium text-gray-900 mb-4 flex items-center gap-2">
                    <Mail size={16} />
                    Email Notifications
                  </h3>
                  <div className="space-y-4">
                    <label className="flex items-center justify-between">
                      <div>
                        <p className="text-gray-700">New form submissions</p>
                        <p className="text-sm text-gray-500">Get notified when a new form is submitted</p>
                      </div>
                      <input
                        type="checkbox"
                        checked={notifications.emailNewForm}
                        onChange={(e) => setNotifications({ ...notifications, emailNewForm: e.target.checked })}
                        className="h-5 w-5 text-primary-500 rounded border-gray-300 focus:ring-primary-500"
                      />
                    </label>
                    <label className="flex items-center justify-between">
                      <div>
                        <p className="text-gray-700">Approval requests</p>
                        <p className="text-sm text-gray-500">Get notified when forms need your approval</p>
                      </div>
                      <input
                        type="checkbox"
                        checked={notifications.emailApproval}
                        onChange={(e) => setNotifications({ ...notifications, emailApproval: e.target.checked })}
                        className="h-5 w-5 text-primary-500 rounded border-gray-300 focus:ring-primary-500"
                      />
                    </label>
                    <label className="flex items-center justify-between">
                      <div>
                        <p className="text-gray-700">Weekly summary</p>
                        <p className="text-sm text-gray-500">Receive a weekly digest of activity</p>
                      </div>
                      <input
                        type="checkbox"
                        checked={notifications.emailWeekly}
                        onChange={(e) => setNotifications({ ...notifications, emailWeekly: e.target.checked })}
                        className="h-5 w-5 text-primary-500 rounded border-gray-300 focus:ring-primary-500"
                      />
                    </label>
                  </div>
                </div>

                {/* Push Notifications */}
                <div className="pt-6 border-t border-gray-100">
                  <h3 className="text-sm font-medium text-gray-900 mb-4 flex items-center gap-2">
                    <Bell size={16} />
                    Push Notifications
                  </h3>
                  <div className="space-y-4">
                    <label className="flex items-center justify-between">
                      <div>
                        <p className="text-gray-700">New form submissions</p>
                        <p className="text-sm text-gray-500">Push notification for new forms</p>
                      </div>
                      <input
                        type="checkbox"
                        checked={notifications.pushNewForm}
                        onChange={(e) => setNotifications({ ...notifications, pushNewForm: e.target.checked })}
                        className="h-5 w-5 text-primary-500 rounded border-gray-300 focus:ring-primary-500"
                      />
                    </label>
                    <label className="flex items-center justify-between">
                      <div>
                        <p className="text-gray-700">Approval requests</p>
                        <p className="text-sm text-gray-500">Push notification for approvals</p>
                      </div>
                      <input
                        type="checkbox"
                        checked={notifications.pushApproval}
                        onChange={(e) => setNotifications({ ...notifications, pushApproval: e.target.checked })}
                        className="h-5 w-5 text-primary-500 rounded border-gray-300 focus:ring-primary-500"
                      />
                    </label>
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* Security Tab */}
          {activeTab === 'security' && (
            <div className="space-y-6">
              <div className="bg-white rounded-xl shadow-sm border border-gray-100">
                <div className="p-5 border-b border-gray-100">
                  <h2 className="font-semibold text-gray-900">Security Settings</h2>
                  <p className="text-sm text-gray-500">Manage your security preferences</p>
                </div>
                <div className="p-5 space-y-6">
                  {/* Password */}
                  <div>
                    <h3 className="text-sm font-medium text-gray-900 mb-4 flex items-center gap-2">
                      <Key size={16} />
                      Password
                    </h3>
                    <button className="btn btn-secondary">Change Password</button>
                  </div>

                  {/* Two Factor */}
                  <div className="pt-6 border-t border-gray-100">
                    <div className="flex items-center justify-between">
                      <div>
                        <h3 className="text-sm font-medium text-gray-900 flex items-center gap-2">
                          <Shield size={16} />
                          Two-Factor Authentication
                        </h3>
                        <p className="text-sm text-gray-500 mt-1">
                          Add an extra layer of security to your account
                        </p>
                      </div>
                      <input
                        type="checkbox"
                        checked={security.twoFactor}
                        onChange={(e) => setSecurity({ ...security, twoFactor: e.target.checked })}
                        className="h-5 w-5 text-primary-500 rounded border-gray-300 focus:ring-primary-500"
                      />
                    </div>
                  </div>

                  {/* Session Timeout */}
                  <div className="pt-6 border-t border-gray-100">
                    <h3 className="text-sm font-medium text-gray-900 mb-3">Session Timeout</h3>
                    <select
                      value={security.sessionTimeout}
                      onChange={(e) => setSecurity({ ...security, sessionTimeout: e.target.value })}
                      className="input"
                    >
                      <option value="15">15 minutes</option>
                      <option value="30">30 minutes</option>
                      <option value="60">1 hour</option>
                      <option value="240">4 hours</option>
                    </select>
                  </div>
                </div>
              </div>

              {/* Active Sessions */}
              <div className="bg-white rounded-xl shadow-sm border border-gray-100">
                <div className="p-5 border-b border-gray-100">
                  <h2 className="font-semibold text-gray-900">Active Sessions</h2>
                </div>
                <div className="p-5">
                  <div className="flex items-center justify-between py-3 border-b border-gray-100">
                    <div className="flex items-center gap-3">
                      <div className="w-10 h-10 bg-green-100 rounded-lg flex items-center justify-center">
                        <Globe size={18} className="text-green-600" />
                      </div>
                      <div>
                        <p className="font-medium text-gray-900">Current Session</p>
                        <p className="text-sm text-gray-500">Chrome on macOS • Toronto, Canada</p>
                      </div>
                    </div>
                    <span className="text-green-600 text-sm font-medium">Active now</span>
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* Billing Tab */}
          {activeTab === 'billing' && (
            <div className="space-y-6">
              {/* Current Plan */}
              <div className="bg-white rounded-xl shadow-sm border border-gray-100">
                <div className="p-5 border-b border-gray-100">
                  <h2 className="font-semibold text-gray-900">Current Plan</h2>
                </div>
                <div className="p-5">
                  <div className="flex items-center justify-between">
                    <div>
                      <div className="flex items-center gap-2">
                        <h3 className="text-lg font-semibold text-gray-900">
                          {user?.isDemo ? 'Demo Account' : 'Professional'}
                        </h3>
                        {!user?.isDemo && (
                          <span className="px-2 py-0.5 bg-primary-100 text-primary-700 text-xs font-medium rounded-full">
                            Current
                          </span>
                        )}
                      </div>
                      <p className="text-gray-500 mt-1">
                        {user?.isDemo
                          ? 'Explore all features with sample data'
                          : '$29/month • Unlimited forms • 5 team members'}
                      </p>
                    </div>
                    {!user?.isDemo && (
                      <button className="btn btn-secondary">Upgrade Plan</button>
                    )}
                  </div>
                </div>
              </div>

              {/* Payment Method */}
              {!user?.isDemo && (
                <div className="bg-white rounded-xl shadow-sm border border-gray-100">
                  <div className="p-5 border-b border-gray-100">
                    <h2 className="font-semibold text-gray-900">Payment Method</h2>
                  </div>
                  <div className="p-5">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-3">
                        <div className="w-12 h-8 bg-gray-100 rounded flex items-center justify-center">
                          <CreditCard size={18} className="text-gray-600" />
                        </div>
                        <div>
                          <p className="font-medium text-gray-900">•••• •••• •••• 4242</p>
                          <p className="text-sm text-gray-500">Expires 12/25</p>
                        </div>
                      </div>
                      <button className="text-primary-500 hover:text-primary-600 text-sm font-medium">
                        Update
                      </button>
                    </div>
                  </div>
                </div>
              )}

              {/* Billing History */}
              {!user?.isDemo && (
                <div className="bg-white rounded-xl shadow-sm border border-gray-100">
                  <div className="p-5 border-b border-gray-100">
                    <h2 className="font-semibold text-gray-900">Billing History</h2>
                  </div>
                  <div className="p-5">
                    <p className="text-gray-500 text-center py-4">No billing history yet</p>
                  </div>
                </div>
              )}
            </div>
          )}

          {/* Save Button */}
          {(activeTab === 'profile' || activeTab === 'notifications' || activeTab === 'security') && (
            <div className="mt-6 flex items-center justify-end gap-4">
              {showSaved && (
                <span className="flex items-center gap-2 text-green-600">
                  <CheckCircle size={16} />
                  Saved successfully
                </span>
              )}
              <button
                onClick={handleSave}
                disabled={isSaving}
                className="btn btn-primary flex items-center gap-2"
              >
                {isSaving ? (
                  <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white" />
                ) : (
                  <Save size={16} />
                )}
                {isSaving ? 'Saving...' : 'Save Changes'}
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

export default Settings
