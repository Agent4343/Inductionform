/**
 * RBACManager.swift
 * Role-Based Access Control System
 */

import Foundation
import SwiftUI

enum UserRole: String, Codable, CaseIterable {
    case admin, manager, user, guest
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var level: Int {
        switch self {
        case .admin: return 4
        case .manager: return 3
        case .user: return 2
        case .guest: return 1
        }
    }
}

enum Permission: String, CaseIterable {
    case createForm, editForm, deleteForm, viewForm, submitForm, approveForm
    case createTemplate, editTemplate, deleteTemplate, viewTemplate
    case manageUsers, viewAnalytics, manageSettings
}

class RBACManager: ObservableObject {
    static let shared = RBACManager()
    @Published var currentUserRole: UserRole = .user
    
    private init() {}
    
    func hasPermission(_ permission: Permission) -> Bool {
        let permissions: [UserRole: Set<Permission>] = [
            .admin: Set(Permission.allCases),
            .manager: [.createForm, .editForm, .deleteForm, .viewForm, .submitForm, .approveForm, .viewTemplate, .viewAnalytics],
            .user: [.createForm, .editForm, .viewForm, .submitForm, .viewTemplate],
            .guest: [.viewForm, .viewTemplate]
        ]
        return permissions[currentUserRole]?.contains(permission) ?? false
    }
}
