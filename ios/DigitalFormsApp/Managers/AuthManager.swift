/**
 * AuthManager.swift
 * Authentication & Session Management
 *
 * Handles login, registration, token storage, and session management
 */

import Foundation
import Security
import LocalAuthentication

class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false

    private(set) var accessToken: String?
    private var refreshToken: String?

    private let keychain = KeychainHelper.shared

    struct User: Codable {
        let id: String
        let email: String
        let name: String
        let role: String
        let organizationId: String?
    }

    private init() {
        loadStoredCredentials()
    }

    // MARK: - Authentication

    func login(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }

        let response = try await APIService.shared.login(email: email, password: password)
        await handleAuthResponse(response)
    }

    func register(name: String, email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }

        let response = try await APIService.shared.register(email: email, password: password, name: name)
        await handleAuthResponse(response)
    }

    func loginDemo() {
        // Demo mode for testing without backend
        let demoUser = User(
            id: UUID().uuidString,
            email: "demo@example.com",
            name: "Demo User",
            role: "user",
            organizationId: nil
        )

        DispatchQueue.main.async {
            self.currentUser = demoUser
            self.isAuthenticated = true
        }
    }

    func logout() async {
        // Try to logout on server
        try? await APIService.shared.logout()

        // Clear local state
        await MainActor.run {
            accessToken = nil
            refreshToken = nil
            currentUser = nil
            isAuthenticated = false
        }

        // Clear keychain
        keychain.delete(key: "accessToken")
        keychain.delete(key: "refreshToken")
        keychain.delete(key: "currentUser")
    }

    // MARK: - Token Management

    func refreshTokens() async throws {
        guard let refresh = refreshToken else {
            throw APIError.unauthorized
        }

        let response = try await APIService.shared.refreshToken(refresh)

        await MainActor.run {
            self.accessToken = response.accessToken
            self.refreshToken = response.refreshToken
        }

        // Store new tokens
        keychain.save(key: "accessToken", value: response.accessToken)
        keychain.save(key: "refreshToken", value: response.refreshToken)
    }

    // MARK: - Biometric Authentication

    func canUseBiometrics() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    func authenticateWithBiometrics() async throws -> Bool {
        let context = LAContext()
        let reason = "Authenticate to access your forms"

        return try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
    }

    // MARK: - Private Helpers

    private func handleAuthResponse(_ response: APIService.AuthResponse) async {
        await MainActor.run {
            self.accessToken = response.accessToken
            self.refreshToken = response.refreshToken
            self.currentUser = User(
                id: response.user.id,
                email: response.user.email,
                name: response.user.name,
                role: response.user.role,
                organizationId: response.user.organizationId
            )
            self.isAuthenticated = true
        }

        // Store credentials
        keychain.save(key: "accessToken", value: response.accessToken)
        keychain.save(key: "refreshToken", value: response.refreshToken)

        if let userData = try? JSONEncoder().encode(currentUser) {
            keychain.save(key: "currentUser", data: userData)
        }
    }

    private func loadStoredCredentials() {
        accessToken = keychain.load(key: "accessToken")
        refreshToken = keychain.load(key: "refreshToken")

        if let userData = keychain.loadData(key: "currentUser"),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            currentUser = user
            isAuthenticated = accessToken != nil
        }
    }
}

// MARK: - Keychain Helper

class KeychainHelper {
    static let shared = KeychainHelper()
    private let service = "com.digitalforms.app"

    func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        save(key: key, data: data)
    }

    func save(key: String, data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    func load(key: String) -> String? {
        guard let data = loadData(key: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func loadData(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}
