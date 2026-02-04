/**
 * DigitalFormsApp.swift
 * Main App Entry Point
 *
 * Professional iOS/iPadOS application for digital forms
 */

import SwiftUI

@main
struct DigitalFormsApp: App {
    @StateObject private var dataController = DataController.shared
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var syncManager = SyncManager.shared
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, dataController.container.viewContext)
                .environmentObject(dataController)
                .environmentObject(authManager)
                .environmentObject(syncManager)
                .environmentObject(appState)
                .onAppear {
                    setupAppearance()
                }
        }
    }

    private func setupAppearance() {
        // Configure navigation bar
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - App State

class AppState: ObservableObject {
    @Published var isLoading = false
    @Published var showingError = false
    @Published var errorMessage = ""
    @Published var selectedTab: Tab = .forms

    enum Tab: Int {
        case forms = 0
        case templates = 1
        case scanner = 2
        case dashboard = 3
        case settings = 4
    }

    func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}

// MARK: - Content View

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .alert("Error", isPresented: $appState.showingError) {
            Button("OK") { }
        } message: {
            Text(appState.errorMessage)
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            FormsListView()
                .tabItem {
                    Label("Forms", systemImage: "doc.text.fill")
                }
                .tag(AppState.Tab.forms)

            TemplatesListView()
                .tabItem {
                    Label("Templates", systemImage: "square.stack.fill")
                }
                .tag(AppState.Tab.templates)

            DocumentScannerLauncherView()
                .tabItem {
                    Label("Scan", systemImage: "doc.text.viewfinder")
                }
                .tag(AppState.Tab.scanner)

            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }
                .tag(AppState.Tab.dashboard)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(AppState.Tab.settings)
        }
    }
}

// MARK: - Login View

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showingRegister = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Logo
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)

                Text("DigitalForms")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Professional Form Management")
                    .foregroundColor(.secondary)

                Spacer().frame(height: 20)

                // Login Form
                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)

                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.password)

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }

                    Button(action: login) {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Sign In")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading || email.isEmpty || password.isEmpty)

                    Button("Create Account") {
                        showingRegister = true
                    }
                    .foregroundColor(.accentColor)
                }
                .padding(.horizontal, 32)

                Spacer()

                // Demo mode
                Button("Continue in Demo Mode") {
                    authManager.loginDemo()
                }
                .foregroundColor(.secondary)
                .padding(.bottom)
            }
            .padding()
            .sheet(isPresented: $showingRegister) {
                RegisterView()
            }
        }
    }

    private func login() {
        isLoading = true
        errorMessage = ""

        Task {
            do {
                try await authManager.login(email: email, password: password)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - Register View

struct RegisterView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Account Information") {
                    TextField("Full Name", text: $name)
                        .textContentType(.name)

                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }

                Section("Password") {
                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)

                    SecureField("Confirm Password", text: $confirmPassword)
                        .textContentType(.newPassword)

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                Section {
                    Button(action: register) {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Create Account")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isLoading || !isFormValid)
                }
            }
            .navigationTitle("Create Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var isFormValid: Bool {
        !name.isEmpty &&
        !email.isEmpty &&
        password.count >= 8 &&
        password == confirmPassword
    }

    private func register() {
        isLoading = true
        errorMessage = ""

        Task {
            do {
                try await authManager.register(name: name, email: email, password: password)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthManager.shared)
        .environmentObject(AppState())
}
