/**
 * TwoFactorAuthManager.swift
 * Two-Factor Authentication Support
 */

import Foundation
import LocalAuthentication

class TwoFactorAuthManager: ObservableObject {
    static let shared = TwoFactorAuthManager()
    
    @Published var isTwoFactorEnabled: Bool = false
    @Published var requiresBiometrics: Bool = false
    
    private init() {
        loadSettings()
    }
    
    func authenticateWithBiometrics(completion: @escaping (Bool, Error?) -> Void) {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            completion(false, error)
            return
        }
        
        let reason = "Authenticate to access your forms"
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                completion(success, error)
            }
        }
    }
    
    func enable2FA() {
        isTwoFactorEnabled = true
        saveSettings()
    }
    
    func disable2FA() {
        isTwoFactorEnabled = false
        saveSettings()
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(isTwoFactorEnabled, forKey: "twoFactorEnabled")
        UserDefaults.standard.set(requiresBiometrics, forKey: "requiresBiometrics")
    }
    
    private func loadSettings() {
        isTwoFactorEnabled = UserDefaults.standard.bool(forKey: "twoFactorEnabled")
        requiresBiometrics = UserDefaults.standard.bool(forKey: "requiresBiometrics")
    }
}
