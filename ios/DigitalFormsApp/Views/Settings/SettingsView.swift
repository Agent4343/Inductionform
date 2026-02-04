/**
 * SettingsView.swift
 * App Settings & User Profile
 */

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var syncManager: SyncManager

    @State private var showingLogoutConfirm = false
    @State private var showingDeleteConfirm = false
    @State private var biometricsEnabled = false
    @State private var autoSaveEnabled = true
    @State private var notificationsEnabled = true

    var body: some View {
        NavigationStack {
            List {
                // Profile Section
                Section {
                    if let user = authManager.currentUser {
                        HStack(spacing: 16) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.accentColor)

                            VStack(alignment: .leading) {
                                Text(user.name)
                                    .font(.headline)
                                Text(user.email)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(user.role.capitalized)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    NavigationLink {
                        ProfileEditView()
                    } label: {
                        Label("Edit Profile", systemImage: "pencil")
                    }
                } header: {
                    Text("Account")
                }

                // Sync Section
                Section {
                    HStack {
                        Label("Status", systemImage: syncManager.isOnline ? "wifi" : "wifi.slash")

                        Spacer()

                        Text(syncManager.isOnline ? "Online" : "Offline")
                            .foregroundColor(syncManager.isOnline ? .green : .red)
                    }

                    if let lastSync = syncManager.lastSyncDate {
                        HStack {
                            Label("Last Sync", systemImage: "clock")
                            Spacer()
                            Text(lastSync, style: .relative)
                                .foregroundColor(.secondary)
                        }
                    }

                    if syncManager.pendingSyncCount > 0 {
                        HStack {
                            Label("Pending", systemImage: "arrow.triangle.2.circlepath")
                            Spacer()
                            Text("\(syncManager.pendingSyncCount) items")
                                .foregroundColor(.orange)
                        }
                    }

                    Button {
                        Task { await syncManager.syncAll() }
                    } label: {
                        Label("Sync Now", systemImage: "arrow.clockwise")
                    }
                    .disabled(!syncManager.isOnline || syncManager.isSyncing)
                } header: {
                    Text("Sync")
                }

                // Security Section
                Section {
                    Toggle(isOn: $biometricsEnabled) {
                        Label("Face ID / Touch ID", systemImage: "faceid")
                    }
                    .disabled(!authManager.canUseBiometrics())

                    NavigationLink {
                        ChangePasswordView()
                    } label: {
                        Label("Change Password", systemImage: "key")
                    }
                } header: {
                    Text("Security")
                }

                // Preferences Section
                Section {
                    Toggle(isOn: $autoSaveEnabled) {
                        Label("Auto-Save Drafts", systemImage: "square.and.arrow.down")
                    }

                    Toggle(isOn: $notificationsEnabled) {
                        Label("Push Notifications", systemImage: "bell")
                    }

                    NavigationLink {
                        AppearanceSettingsView()
                    } label: {
                        Label("Appearance", systemImage: "paintbrush")
                    }
                } header: {
                    Text("Preferences")
                }

                // Data Section
                Section {
                    NavigationLink {
                        ExportDataView()
                    } label: {
                        Label("Export Data", systemImage: "square.and.arrow.up")
                    }

                    NavigationLink {
                        StorageView()
                    } label: {
                        Label("Storage", systemImage: "internaldrive")
                    }

                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Label("Delete All Data", systemImage: "trash")
                    }
                } header: {
                    Text("Data")
                }

                // About Section
                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About", systemImage: "info.circle")
                    }

                    NavigationLink {
                        HelpView()
                    } label: {
                        Label("Help & Support", systemImage: "questionmark.circle")
                    }

                    Link(destination: URL(string: "https://example.com/privacy")!) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }

                    Link(destination: URL(string: "https://example.com/terms")!) {
                        Label("Terms of Service", systemImage: "doc.text")
                    }
                } header: {
                    Text("About")
                }

                // Logout Section
                Section {
                    Button(role: .destructive) {
                        showingLogoutConfirm = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }

                // Version
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Sign Out", isPresented: $showingLogoutConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    Task { await authManager.logout() }
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Delete All Data", isPresented: $showingDeleteConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteAllData()
                }
            } message: {
                Text("This will permanently delete all local data. This action cannot be undone.")
            }
        }
    }

    private func deleteAllData() {
        // Delete all local data
        // Implementation would clear Core Data
    }
}

// MARK: - Profile Edit View

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager

    @State private var name = ""
    @State private var email = ""
    @State private var isSaving = false

    var body: some View {
        Form {
            Section("Personal Information") {
                TextField("Name", text: $name)
                    .textContentType(.name)

                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveProfile()
                }
                .disabled(isSaving)
            }
        }
        .onAppear {
            if let user = authManager.currentUser {
                name = user.name
                email = user.email
            }
        }
    }

    private func saveProfile() {
        isSaving = true
        // Save to API
        isSaving = false
        dismiss()
    }
}

// MARK: - Change Password View

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    @State private var isSaving = false

    var isValid: Bool {
        !currentPassword.isEmpty &&
        newPassword.count >= 8 &&
        newPassword == confirmPassword
    }

    var body: some View {
        Form {
            Section {
                SecureField("Current Password", text: $currentPassword)
            }

            Section {
                SecureField("New Password", text: $newPassword)
                SecureField("Confirm Password", text: $confirmPassword)

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            } footer: {
                Text("Password must be at least 8 characters")
            }
        }
        .navigationTitle("Change Password")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    changePassword()
                }
                .disabled(!isValid || isSaving)
            }
        }
    }

    private func changePassword() {
        guard newPassword == confirmPassword else {
            errorMessage = "Passwords don't match"
            return
        }

        isSaving = true
        // Call API
        isSaving = false
        dismiss()
    }
}

// MARK: - Appearance Settings

struct AppearanceSettingsView: View {
    @AppStorage("colorScheme") private var colorScheme = 0

    var body: some View {
        Form {
            Section("Theme") {
                Picker("Appearance", selection: $colorScheme) {
                    Text("System").tag(0)
                    Text("Light").tag(1)
                    Text("Dark").tag(2)
                }
                .pickerStyle(.segmented)
            }
        }
        .navigationTitle("Appearance")
    }
}

// MARK: - Export Data View

struct ExportDataView: View {
    @State private var isExporting = false
    @State private var showingShare = false
    @State private var exportData: Data?

    var body: some View {
        Form {
            Section {
                Button {
                    exportAllData()
                } label: {
                    Label("Export All Forms", systemImage: "doc.zipper")
                }

                Button {
                    exportTemplates()
                } label: {
                    Label("Export Templates", systemImage: "square.stack")
                }
            } footer: {
                Text("Export your data as JSON files that can be imported later.")
            }
        }
        .navigationTitle("Export Data")
        .overlay {
            if isExporting {
                ProcessingOverlay()
            }
        }
        .sheet(isPresented: $showingShare) {
            if let data = exportData {
                ShareSheet(items: [data])
            }
        }
    }

    private func exportAllData() {
        isExporting = true
        // Generate export
        isExporting = false
    }

    private func exportTemplates() {
        isExporting = true
        // Generate export
        isExporting = false
    }
}

// MARK: - Storage View

struct StorageView: View {
    @State private var formsCount = 0
    @State private var templatesCount = 0
    @State private var attachmentsSize: Int64 = 0

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Forms")
                    Spacer()
                    Text("\(formsCount)")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Templates")
                    Spacer()
                    Text("\(templatesCount)")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Attachments")
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: attachmentsSize, countStyle: .file))
                        .foregroundColor(.secondary)
                }
            }

            Section {
                Button(role: .destructive) {
                    clearCache()
                } label: {
                    Label("Clear Cache", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Storage")
        .onAppear {
            loadStorageInfo()
        }
    }

    private func loadStorageInfo() {
        let dataController = DataController.shared
        formsCount = dataController.fetchForms().count
        templatesCount = dataController.fetchTemplates().count
    }

    private func clearCache() {
        // Clear cached data
    }
}

// MARK: - About View

struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.accentColor)

                    Text("DigitalForms")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Professional Form Management")
                        .foregroundColor(.secondary)

                    Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }

            Section("Features") {
                FeatureRow(icon: "doc.text.viewfinder", title: "Document Scanner", description: "Scan paper forms with OCR")
                FeatureRow(icon: "signature", title: "Legal Signatures", description: "Canadian-compliant e-signatures")
                FeatureRow(icon: "icloud", title: "Cloud Sync", description: "Sync across all devices")
                FeatureRow(icon: "lock.shield", title: "Secure", description: "End-to-end encryption")
            }

            Section {
                Link(destination: URL(string: "https://example.com")!) {
                    Label("Website", systemImage: "globe")
                }

                Link(destination: URL(string: "mailto:support@example.com")!) {
                    Label("Contact Support", systemImage: "envelope")
                }
            }
        }
        .navigationTitle("About")
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 30)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.subheadline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Help View

struct HelpView: View {
    var body: some View {
        List {
            Section("Getting Started") {
                NavigationLink("Creating a Form") {
                    HelpDetailView(title: "Creating a Form", content: """
                    1. Tap the + button on the Forms tab
                    2. Choose a template or start blank
                    3. Fill in the form fields
                    4. Save as draft or submit
                    """)
                }

                NavigationLink("Scanning Documents") {
                    HelpDetailView(title: "Scanning Documents", content: """
                    1. Go to the Scan tab
                    2. Position the document in view
                    3. The app will auto-detect edges
                    4. Review and create form from scan
                    """)
                }

                NavigationLink("Adding Signatures") {
                    HelpDetailView(title: "Adding Signatures", content: """
                    1. Open a submitted form
                    2. Tap "Add Signature"
                    3. Draw or type your signature
                    4. Confirm legal acknowledgment
                    """)
                }
            }

            Section("FAQ") {
                NavigationLink("Are signatures legally binding?") {
                    HelpDetailView(title: "Legal Signatures", content: """
                    Yes! Our electronic signatures comply with Canadian PIPEDA and provincial Electronic Transactions Acts.

                    Each signature includes:
                    - Consent acknowledgment
                    - Document hash verification
                    - Timestamp and IP logging
                    - Optional witness support
                    """)
                }
            }
        }
        .navigationTitle("Help")
    }
}

struct HelpDetailView: View {
    let title: String
    let content: String

    var body: some View {
        ScrollView {
            Text(content)
                .padding()
        }
        .navigationTitle(title)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthManager.shared)
        .environmentObject(SyncManager.shared)
}
