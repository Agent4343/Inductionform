//
//  DigitalFormsApp_Improved.swift
//  DigitalFormsApp
//
//  Improved digital forms app with:
//  - Document Scanner (VisionKit) to copy paper forms
//  - Drag-and-drop form builder
//  - Working PDF export with share sheet
//  - Working email with attachments
//

import SwiftUI
import CoreData
import PencilKit
import PhotosUI
import CoreLocation
import PDFKit
import Network
import Security
import Combine
import UIKit
import VisionKit
import Vision
import MessageUI
import UniformTypeIdentifiers

// MARK: - APP ENTRY POINT

@main
struct DigitalFormsAppMain: App {
    @StateObject private var dataController = DataController.shared
    @StateObject private var syncManager = SyncManager.shared
    @StateObject private var authManager = AuthManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, dataController.container.viewContext)
                .environmentObject(dataController)
                .environmentObject(syncManager)
                .environmentObject(authManager)
        }
    }
}

// MARK: - DATA CONTROLLER

class DataController: ObservableObject {
    static let shared = DataController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "DigitalFormsApp")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        let description = container.persistentStoreDescriptions.first
        description?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // MARK: - Form Operations

    func createForm(from template: FormTemplate, createdBy user: User) -> FormEntity {
        let context = container.viewContext
        let form = FormEntity(context: context)
        form.id = UUID()
        form.templateId = template.id
        form.title = template.name
        form.createdAt = Date()
        form.updatedAt = Date()
        form.status = FormStatus.draft.rawValue
        form.createdById = user.id
        form.syncStatus = SyncStatus.pending.rawValue

        if let templateFields = template.fields?.allObjects as? [TemplateField] {
            for templateField in templateFields.sorted(by: { $0.order < $1.order }) {
                let field = FormField(context: context)
                field.id = UUID()
                field.fieldId = templateField.id
                field.label = templateField.label
                field.type = templateField.type
                field.isRequired = templateField.isRequired
                field.order = templateField.order
                field.options = templateField.options
                field.form = form
            }
        }

        save()
        return form
    }

    func saveSignature(_ signatureData: Data, for form: FormEntity, signedBy user: User, role: String) -> Signature {
        let context = container.viewContext
        let signature = Signature(context: context)
        signature.id = UUID()
        signature.imageData = signatureData
        signature.signedAt = Date()
        signature.signedById = user.id
        signature.signerName = user.name
        signature.signerRole = role
        signature.form = form

        form.updatedAt = Date()
        form.syncStatus = SyncStatus.pending.rawValue

        save()
        return signature
    }

    func addAttachment(_ imageData: Data, to form: FormEntity, caption: String?, location: LocationData?) -> Attachment {
        let context = container.viewContext
        let attachment = Attachment(context: context)
        attachment.id = UUID()
        attachment.imageData = imageData
        attachment.caption = caption
        attachment.capturedAt = Date()
        attachment.form = form

        if let location = location {
            attachment.latitude = location.latitude
            attachment.longitude = location.longitude
        }

        form.updatedAt = Date()
        form.syncStatus = SyncStatus.pending.rawValue

        save()
        return attachment
    }

    func updateFormStatus(_ form: FormEntity, to status: FormStatus) {
        form.status = status.rawValue
        form.updatedAt = Date()
        form.syncStatus = SyncStatus.pending.rawValue
        save()
    }

    func submitForm(_ form: FormEntity) {
        form.status = FormStatus.submitted.rawValue
        form.submittedAt = Date()
        form.updatedAt = Date()
        form.syncStatus = SyncStatus.pending.rawValue
        save()
    }

    func approveForm(_ form: FormEntity, by user: User, comments: String?) {
        let context = container.viewContext
        let approval = Approval(context: context)
        approval.id = UUID()
        approval.approvedAt = Date()
        approval.approvedById = user.id
        approval.approverName = user.name
        approval.comments = comments
        approval.decision = ApprovalDecision.approved.rawValue
        approval.form = form

        form.status = FormStatus.approved.rawValue
        form.updatedAt = Date()
        form.syncStatus = SyncStatus.pending.rawValue

        save()
    }

    func rejectForm(_ form: FormEntity, by user: User, reason: String) {
        let context = container.viewContext
        let approval = Approval(context: context)
        approval.id = UUID()
        approval.approvedAt = Date()
        approval.approvedById = user.id
        approval.approverName = user.name
        approval.comments = reason
        approval.decision = ApprovalDecision.rejected.rawValue
        approval.form = form

        form.status = FormStatus.rejected.rawValue
        form.updatedAt = Date()
        form.syncStatus = SyncStatus.pending.rawValue

        save()
    }

    // MARK: - Template Operations

    func createTemplate(name: String, description: String?, category: String, fields: [TemplateFieldData]) -> FormTemplate {
        let context = container.viewContext
        let template = FormTemplate(context: context)
        template.id = UUID()
        template.name = name
        template.templateDescription = description
        template.category = category
        template.createdAt = Date()
        template.isActive = true
        template.version = 1

        for (index, fieldData) in fields.enumerated() {
            let field = TemplateField(context: context)
            field.id = UUID()
            field.label = fieldData.label
            field.type = fieldData.type.rawValue
            field.isRequired = fieldData.isRequired
            field.order = Int16(index)
            field.options = fieldData.options
            field.template = template
        }

        save()
        return template
    }

    // MARK: - Fetch Operations

    func fetchForms(with status: FormStatus? = nil) -> [FormEntity] {
        let request: NSFetchRequest<FormEntity> = FormEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FormEntity.updatedAt, ascending: false)]

        if let status = status {
            request.predicate = NSPredicate(format: "status == %@", status.rawValue)
        }

        do {
            return try container.viewContext.fetch(request)
        } catch {
            print("Failed to fetch forms: \(error)")
            return []
        }
    }

    func fetchPendingApprovals() -> [FormEntity] {
        let request: NSFetchRequest<FormEntity> = FormEntity.fetchRequest()
        request.predicate = NSPredicate(format: "status == %@", FormStatus.submitted.rawValue)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FormEntity.submittedAt, ascending: true)]

        do {
            return try container.viewContext.fetch(request)
        } catch {
            print("Failed to fetch pending approvals: \(error)")
            return []
        }
    }

    func fetchTemplates(category: String? = nil) -> [FormTemplate] {
        let request: NSFetchRequest<FormTemplate> = FormTemplate.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FormTemplate.name, ascending: true)]

        if let category = category {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                request.predicate!,
                NSPredicate(format: "category == %@", category)
            ])
        }

        do {
            return try container.viewContext.fetch(request)
        } catch {
            print("Failed to fetch templates: \(error)")
            return []
        }
    }

    func fetchUnsyncedForms() -> [FormEntity] {
        let request: NSFetchRequest<FormEntity> = FormEntity.fetchRequest()
        request.predicate = NSPredicate(format: "syncStatus == %@", SyncStatus.pending.rawValue)

        do {
            return try container.viewContext.fetch(request)
        } catch {
            print("Failed to fetch unsynced forms: \(error)")
            return []
        }
    }

    // MARK: - Save

    func save() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Failed to save context: \(error)")
            }
        }
    }
}

// MARK: - DATA MODELS

struct TemplateFieldData {
    let label: String
    let type: FieldType
    let isRequired: Bool
    let options: String?
}

struct LocationData {
    let latitude: Double
    let longitude: Double
}

enum FormStatus: String {
    case draft = "draft"
    case submitted = "submitted"
    case approved = "approved"
    case rejected = "rejected"
}

enum SyncStatus: String {
    case synced = "synced"
    case pending = "pending"
    case failed = "failed"
}

enum FieldType: String, CaseIterable {
    case text = "text"
    case number = "number"
    case date = "date"
    case time = "time"
    case checkbox = "checkbox"
    case dropdown = "dropdown"
    case multiSelect = "multiSelect"
    case signature = "signature"
    case photo = "photo"
    case location = "location"
    case textarea = "textarea"
    case yesNo = "yesNo"
    case email = "email"
    case phone = "phone"
    case currency = "currency"
    case rating = "rating"
    case slider = "slider"
    case section = "section"

    var displayName: String {
        switch self {
        case .text: return "Text Field"
        case .number: return "Number"
        case .date: return "Date Picker"
        case .time: return "Time Picker"
        case .checkbox: return "Checkbox"
        case .dropdown: return "Dropdown"
        case .multiSelect: return "Multi-Select"
        case .signature: return "Signature"
        case .photo: return "Photo"
        case .location: return "Location"
        case .textarea: return "Text Area"
        case .yesNo: return "Yes/No/NA"
        case .email: return "Email"
        case .phone: return "Phone"
        case .currency: return "Currency"
        case .rating: return "Star Rating"
        case .slider: return "Slider"
        case .section: return "Section Header"
        }
    }

    var icon: String {
        switch self {
        case .text: return "textformat"
        case .number: return "number"
        case .date: return "calendar"
        case .time: return "clock"
        case .checkbox: return "checkmark.square"
        case .dropdown: return "list.bullet"
        case .multiSelect: return "checklist"
        case .signature: return "signature"
        case .photo: return "camera"
        case .location: return "location"
        case .textarea: return "text.alignleft"
        case .yesNo: return "hand.thumbsup"
        case .email: return "envelope"
        case .phone: return "phone"
        case .currency: return "dollarsign.circle"
        case .rating: return "star"
        case .slider: return "slider.horizontal.3"
        case .section: return "rectangle.split.3x1"
        }
    }
}

enum ApprovalDecision: String {
    case approved = "approved"
    case rejected = "rejected"
}

// MARK: - AUTH MANAGER

class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var error: AuthError?

    private let keychainService = "com.digitalforms.auth"

    init() {
        checkExistingSession()
    }

    func login(email: String, password: String) async throws {
        await MainActor.run { isLoading = true }

        defer {
            Task { @MainActor in
                isLoading = false
            }
        }

        try await Task.sleep(nanoseconds: 1_000_000_000)

        guard isValidEmail(email) else {
            throw AuthError.invalidEmail
        }

        guard password.count >= 6 else {
            throw AuthError.invalidPassword
        }

        let user = createMockUser(email: email)
        let token = generateToken()
        try saveToKeychain(token: token)

        await MainActor.run {
            self.currentUser = user
            self.isAuthenticated = true
        }
    }

    func loginOffline(pin: String) throws {
        guard let storedPinHash = UserDefaults.standard.string(forKey: "offlinePinHash") else {
            throw AuthError.noPinSet
        }

        guard hashPin(pin) == storedPinHash else {
            throw AuthError.invalidPin
        }

        if let userData = UserDefaults.standard.data(forKey: "cachedUser"),
           let user = try? JSONDecoder().decode(CachedUser.self, from: userData) {
            currentUser = createUserFromCache(user)
            isAuthenticated = true
        } else {
            throw AuthError.noOfflineData
        }
    }

    func setOfflinePin(_ pin: String) {
        let pinHash = hashPin(pin)
        UserDefaults.standard.set(pinHash, forKey: "offlinePinHash")

        if let user = currentUser {
            let cachedUser = CachedUser(
                id: user.id?.uuidString ?? "",
                name: user.name ?? "",
                email: user.email ?? "",
                role: user.role ?? ""
            )
            if let data = try? JSONEncoder().encode(cachedUser) {
                UserDefaults.standard.set(data, forKey: "cachedUser")
            }
        }
    }

    func logout() {
        deleteFromKeychain()
        currentUser = nil
        isAuthenticated = false
    }

    private func checkExistingSession() {
        if let _ = getTokenFromKeychain() {
            if let userData = UserDefaults.standard.data(forKey: "cachedUser"),
               let user = try? JSONDecoder().decode(CachedUser.self, from: userData) {
                currentUser = createUserFromCache(user)
                isAuthenticated = true
            }
        }
    }

    private func saveToKeychain(token: String) throws {
        let data = token.data(using: .utf8)!

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "authToken",
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AuthError.keychainError
        }
    }

    private func getTokenFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "authToken",
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }

        return token
    }

    private func deleteFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "authToken"
        ]

        SecItemDelete(query as CFDictionary)
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    private func generateToken() -> String {
        UUID().uuidString + "-" + String(Date().timeIntervalSince1970)
    }

    private func hashPin(_ pin: String) -> String {
        var hash = 0
        for char in pin.unicodeScalars {
            hash = 31 &* hash &+ Int(char.value)
        }
        return String(hash)
    }

    private func createMockUser(email: String) -> User {
        let context = DataController.shared.container.viewContext
        let user = User(context: context)
        user.id = UUID()
        user.email = email
        user.name = email.components(separatedBy: "@").first?.capitalized ?? "User"
        user.role = "Operator"
        return user
    }

    private func createUserFromCache(_ cached: CachedUser) -> User {
        let context = DataController.shared.container.viewContext
        let user = User(context: context)
        user.id = UUID(uuidString: cached.id)
        user.email = cached.email
        user.name = cached.name
        user.role = cached.role
        return user
    }
}

enum AuthError: LocalizedError {
    case invalidEmail
    case invalidPassword
    case invalidCredentials
    case networkError
    case keychainError
    case noPinSet
    case invalidPin
    case noOfflineData

    var errorDescription: String? {
        switch self {
        case .invalidEmail: return "Please enter a valid email address"
        case .invalidPassword: return "Password must be at least 6 characters"
        case .invalidCredentials: return "Invalid email or password"
        case .networkError: return "Network error. Please try again"
        case .keychainError: return "Failed to save credentials securely"
        case .noPinSet: return "No offline PIN has been set"
        case .invalidPin: return "Invalid PIN"
        case .noOfflineData: return "No offline data available"
        }
    }
}

struct CachedUser: Codable {
    let id: String
    let name: String
    let email: String
    let role: String
}

// MARK: - SYNC MANAGER

class SyncManager: ObservableObject {
    static let shared = SyncManager()

    @Published var isOnline = true
    @Published var isSyncing = false
    @Published var pendingSyncCount = 0
    @Published var lastSyncDate: Date?
    @Published var syncError: SyncError?

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    private var cancellables = Set<AnyCancellable>()

    private let baseURL = "https://api.yourbackend.com/v1"

    init() {
        updatePendingCount()
    }

    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOnline = path.status == .satisfied

                if path.status == .satisfied {
                    Task {
                        await self?.syncAll()
                    }
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }

    func stopMonitoring() {
        monitor.cancel()
    }

    func syncAll() async {
        guard isOnline else {
            await MainActor.run {
                syncError = .offline
            }
            return
        }

        await MainActor.run {
            isSyncing = true
            syncError = nil
        }

        defer {
            Task { @MainActor in
                isSyncing = false
                updatePendingCount()
            }
        }

        do {
            let unsyncedForms = DataController.shared.fetchUnsyncedForms()

            for form in unsyncedForms {
                try await syncForm(form)
            }

            try await fetchRemoteUpdates()

            await MainActor.run {
                lastSyncDate = Date()
                UserDefaults.standard.set(lastSyncDate, forKey: "lastSyncDate")
            }

        } catch {
            await MainActor.run {
                syncError = .syncFailed(error.localizedDescription)
            }
        }
    }

    private func syncForm(_ form: FormEntity) async throws {
        let formData = FormSyncData(from: form)
        let jsonData = try JSONEncoder().encode(formData)

        var request = URLRequest(url: URL(string: "\(baseURL)/forms")!)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(getAuthToken(), forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SyncError.serverError
        }

        await MainActor.run {
            form.syncStatus = SyncStatus.synced.rawValue
            DataController.shared.save()
        }
    }

    private func fetchRemoteUpdates() async throws {
        var request = URLRequest(url: URL(string: "\(baseURL)/templates")!)
        request.setValue(getAuthToken(), forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SyncError.serverError
        }

        let templates = try JSONDecoder().decode([TemplateSyncData].self, from: data)
        await MainActor.run {
            for templateData in templates {
                saveTemplateFromRemote(templateData)
            }
        }
    }

    private func saveTemplateFromRemote(_ data: TemplateSyncData) {
        // Implementation for saving remote templates
    }

    private func getAuthToken() -> String {
        return "Bearer \(UserDefaults.standard.string(forKey: "authToken") ?? "")"
    }

    private func updatePendingCount() {
        pendingSyncCount = DataController.shared.fetchUnsyncedForms().count
    }
}

enum SyncError: LocalizedError {
    case offline
    case serverError
    case syncFailed(String)
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .offline: return "No internet connection. Changes saved locally."
        case .serverError: return "Server error. Please try again later."
        case .syncFailed(let message): return "Sync failed: \(message)"
        case .exportFailed: return "Failed to export form"
        }
    }
}

struct FormSyncData: Codable {
    let id: String
    let templateId: String
    let title: String
    let status: String
    let createdAt: Date
    let updatedAt: Date
    let submittedAt: Date?
    let latitude: Double?
    let longitude: Double?
    let fields: [FieldSyncData]
    let signatures: [SignatureSyncData]
    let attachments: [AttachmentSyncData]

    init(from form: FormEntity) {
        self.id = form.id?.uuidString ?? ""
        self.templateId = form.templateId?.uuidString ?? ""
        self.title = form.title ?? ""
        self.status = form.status ?? ""
        self.createdAt = form.createdAt ?? Date()
        self.updatedAt = form.updatedAt ?? Date()
        self.submittedAt = form.submittedAt
        self.latitude = form.latitude
        self.longitude = form.longitude

        self.fields = (form.fields?.allObjects as? [FormField] ?? []).map { FieldSyncData(from: $0) }
        self.signatures = (form.signatures?.allObjects as? [Signature] ?? []).map { SignatureSyncData(from: $0) }
        self.attachments = (form.attachments?.allObjects as? [Attachment] ?? []).map { AttachmentSyncData(from: $0) }
    }
}

struct FieldSyncData: Codable {
    let id: String
    let label: String
    let type: String
    let value: String?
    let order: Int

    init(from field: FormField) {
        self.id = field.id?.uuidString ?? ""
        self.label = field.label ?? ""
        self.type = field.type ?? ""
        self.value = field.value
        self.order = Int(field.order)
    }
}

struct SignatureSyncData: Codable {
    let id: String
    let signerName: String
    let signerRole: String
    let signedAt: Date
    let imageBase64: String

    init(from signature: Signature) {
        self.id = signature.id?.uuidString ?? ""
        self.signerName = signature.signerName ?? ""
        self.signerRole = signature.signerRole ?? ""
        self.signedAt = signature.signedAt ?? Date()
        self.imageBase64 = signature.imageData?.base64EncodedString() ?? ""
    }
}

struct AttachmentSyncData: Codable {
    let id: String
    let caption: String?
    let capturedAt: Date
    let latitude: Double?
    let longitude: Double?
    let imageBase64: String

    init(from attachment: Attachment) {
        self.id = attachment.id?.uuidString ?? ""
        self.caption = attachment.caption
        self.capturedAt = attachment.capturedAt ?? Date()
        self.latitude = attachment.latitude
        self.longitude = attachment.longitude
        self.imageBase64 = attachment.imageData?.base64EncodedString() ?? ""
    }
}

struct TemplateSyncData: Codable {
    let id: String
    let name: String
    let description: String?
    let category: String
    let version: Int
    let fields: [TemplateFieldSyncData]
}

struct TemplateFieldSyncData: Codable {
    let id: String
    let label: String
    let type: String
    let isRequired: Bool
    let order: Int
    let options: String?
}

// MARK: - IMPROVED PDF GENERATOR

class PDFGenerator {

    func generatePDF(for form: FormEntity) -> Data? {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50
        let contentWidth = pageWidth - (margin * 2)

        let pdfMetaData = [
            kCGPDFContextCreator: "Digital Forms App",
            kCGPDFContextAuthor: "Digital Forms",
            kCGPDFContextTitle: form.title ?? "Form"
        ]

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { context in
            var currentPage = 1
            context.beginPage()
            var y: CGFloat = margin

            // Helper function to check page break
            func checkPageBreak(neededHeight: CGFloat) {
                if y + neededHeight > pageHeight - margin {
                    // Add page number to current page
                    drawPageNumber(currentPage, in: context, pageRect: pageRect, margin: margin)
                    context.beginPage()
                    currentPage += 1
                    y = margin
                }
            }

            // Title
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24),
                .foregroundColor: UIColor.black
            ]
            let title = form.title ?? "Form"
            checkPageBreak(neededHeight: 40)
            title.draw(in: CGRect(x: margin, y: y, width: contentWidth, height: 30), withAttributes: titleAttrs)
            y += 40

            // Status badge
            let statusAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: statusColor(for: form.status ?? "draft")
            ]
            let status = "Status: \(form.status?.uppercased() ?? "DRAFT")"
            status.draw(at: CGPoint(x: margin, y: y), withAttributes: statusAttrs)
            y += 25

            // Divider line
            drawDivider(at: y, margin: margin, width: contentWidth)
            y += 15

            // Timestamps section
            let infoAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.darkGray
            ]
            let df = DateFormatter()
            df.dateStyle = .medium
            df.timeStyle = .short

            if let created = form.createdAt {
                "Created: \(df.string(from: created))".draw(at: CGPoint(x: margin, y: y), withAttributes: infoAttrs)
                y += 14
            }
            if let submitted = form.submittedAt {
                "Submitted: \(df.string(from: submitted))".draw(at: CGPoint(x: margin, y: y), withAttributes: infoAttrs)
                y += 14
            }
            if form.latitude != 0 || form.longitude != 0 {
                let loc = String(format: "Location: %.6f, %.6f", form.latitude, form.longitude)
                loc.draw(at: CGPoint(x: margin, y: y), withAttributes: infoAttrs)
                y += 14
            }
            y += 20

            // Form Fields Section
            let sectionHeaderAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 14),
                .foregroundColor: UIColor.black
            ]

            checkPageBreak(neededHeight: 30)
            "FORM DATA".draw(at: CGPoint(x: margin, y: y), withAttributes: sectionHeaderAttrs)
            y += 25

            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .medium),
                .foregroundColor: UIColor.gray
            ]
            let valueAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11),
                .foregroundColor: UIColor.black
            ]

            if let fields = form.fields?.allObjects as? [FormField] {
                for field in fields.sorted(by: { $0.order < $1.order }) {
                    let label = (field.label ?? "Field") + (field.isRequired ? " *" : "")
                    let value = field.value?.isEmpty == false ? field.value! : "Not provided"

                    let valueSize = value.boundingRect(
                        with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                        options: .usesLineFragmentOrigin,
                        attributes: valueAttrs,
                        context: nil
                    )

                    checkPageBreak(neededHeight: 14 + max(valueSize.height, 16) + 15)

                    // Draw field background
                    let fieldRect = CGRect(x: margin - 5, y: y - 3, width: contentWidth + 10, height: 14 + max(valueSize.height, 16) + 10)
                    UIColor.systemGray6.setFill()
                    UIBezierPath(roundedRect: fieldRect, cornerRadius: 4).fill()

                    label.draw(at: CGPoint(x: margin, y: y), withAttributes: labelAttrs)
                    y += 14

                    let valueRect = CGRect(x: margin, y: y, width: contentWidth, height: 60)
                    value.draw(in: valueRect, withAttributes: valueAttrs)

                    y += max(valueSize.height, 16) + 15
                }
            }

            // Attachments Section
            if let attachments = form.attachments?.allObjects as? [Attachment], !attachments.isEmpty {
                y += 10
                checkPageBreak(neededHeight: 130)

                "PHOTO ATTACHMENTS (\(attachments.count))".draw(at: CGPoint(x: margin, y: y), withAttributes: sectionHeaderAttrs)
                y += 25

                let thumbSize: CGFloat = 100
                let thumbSpacing: CGFloat = 10
                var xOffset = margin

                for attachment in attachments {
                    if xOffset + thumbSize > margin + contentWidth {
                        xOffset = margin
                        y += thumbSize + thumbSpacing + 20
                        checkPageBreak(neededHeight: thumbSize + 30)
                    }

                    if let imgData = attachment.imageData, let img = UIImage(data: imgData) {
                        let thumbRect = CGRect(x: xOffset, y: y, width: thumbSize, height: thumbSize)

                        // Draw border
                        UIColor.lightGray.setStroke()
                        let borderPath = UIBezierPath(roundedRect: thumbRect, cornerRadius: 4)
                        borderPath.lineWidth = 0.5
                        borderPath.stroke()

                        // Draw image
                        img.draw(in: thumbRect.insetBy(dx: 2, dy: 2))

                        // Draw caption if exists
                        if let caption = attachment.caption {
                            let captionAttrs: [NSAttributedString.Key: Any] = [
                                .font: UIFont.systemFont(ofSize: 8),
                                .foregroundColor: UIColor.darkGray
                            ]
                            caption.draw(at: CGPoint(x: xOffset, y: y + thumbSize + 2), withAttributes: captionAttrs)
                        }
                    }

                    xOffset += thumbSize + thumbSpacing
                }
                y += thumbSize + 30
            }

            // Signatures Section
            if let sigs = form.signatures?.allObjects as? [Signature], !sigs.isEmpty {
                y += 10
                checkPageBreak(neededHeight: 120)

                "SIGNATURES (\(sigs.count))".draw(at: CGPoint(x: margin, y: y), withAttributes: sectionHeaderAttrs)
                y += 25

                for sig in sigs {
                    checkPageBreak(neededHeight: 90)

                    // Signature box
                    let sigBoxRect = CGRect(x: margin, y: y, width: 200, height: 70)
                    UIColor.white.setFill()
                    UIBezierPath(roundedRect: sigBoxRect, cornerRadius: 4).fill()
                    UIColor.lightGray.setStroke()
                    UIBezierPath(roundedRect: sigBoxRect, cornerRadius: 4).stroke()

                    if let imgData = sig.imageData, let img = UIImage(data: imgData) {
                        img.draw(in: sigBoxRect.insetBy(dx: 10, dy: 10))
                    }

                    // Signer info
                    let sigInfoX = margin + 210
                    let sigNameAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 11, weight: .medium),
                        .foregroundColor: UIColor.black
                    ]
                    (sig.signerName ?? "Unknown").draw(at: CGPoint(x: sigInfoX, y: y + 10), withAttributes: sigNameAttrs)
                    (sig.signerRole ?? "").draw(at: CGPoint(x: sigInfoX, y: y + 25), withAttributes: infoAttrs)

                    if let date = sig.signedAt {
                        df.string(from: date).draw(at: CGPoint(x: sigInfoX, y: y + 40), withAttributes: infoAttrs)
                    }

                    y += 80
                }
            }

            // Final page number
            drawPageNumber(currentPage, in: context, pageRect: pageRect, margin: margin)

            // Footer
            let footerY = pageHeight - 30
            let footerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8),
                .foregroundColor: UIColor.gray
            ]
            "Generated by Digital Forms App - \(df.string(from: Date()))".draw(at: CGPoint(x: margin, y: footerY), withAttributes: footerAttrs)

            if let fid = form.id?.uuidString {
                "Form ID: \(fid)".draw(at: CGPoint(x: margin, y: footerY - 12), withAttributes: footerAttrs)
            }
        }

        return data
    }

    private func drawDivider(at y: CGFloat, margin: CGFloat, width: CGFloat) {
        let divider = UIBezierPath()
        divider.move(to: CGPoint(x: margin, y: y))
        divider.addLine(to: CGPoint(x: margin + width, y: y))
        UIColor.lightGray.setStroke()
        divider.lineWidth = 0.5
        divider.stroke()
    }

    private func drawPageNumber(_ page: Int, in context: UIGraphicsPDFRendererContext, pageRect: CGRect, margin: CGFloat) {
        let pageNumAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.gray
        ]
        let pageNumText = "Page \(page)"
        let textSize = pageNumText.size(withAttributes: pageNumAttrs)
        pageNumText.draw(at: CGPoint(x: pageRect.width - margin - textSize.width, y: pageRect.height - 30), withAttributes: pageNumAttrs)
    }

    private func statusColor(for status: String) -> UIColor {
        switch status {
        case FormStatus.draft.rawValue: return .systemBlue
        case FormStatus.submitted.rawValue: return .systemOrange
        case FormStatus.approved.rawValue: return .systemGreen
        case FormStatus.rejected.rawValue: return .systemRed
        default: return .gray
        }
    }

    func previewPDF(for form: FormEntity) -> PDFDocument? {
        guard let data = generatePDF(for: form) else { return nil }
        return PDFDocument(data: data)
    }

    /// Save PDF to temporary file and return URL
    func savePDFToTemp(for form: FormEntity) -> URL? {
        guard let data = generatePDF(for: form) else { return nil }

        let fileName = "\(form.title ?? "Form")_\(Date().timeIntervalSince1970).pdf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            print("Failed to save PDF: \(error)")
            return nil
        }
    }
}

// MARK: - EMAIL COMPOSER

struct MailComposeView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss

    let recipients: [String]
    let subject: String
    let body: String
    let attachmentData: Data?
    let attachmentMimeType: String
    let attachmentFileName: String

    var onResult: ((MFMailComposeResult) -> Void)?

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setToRecipients(recipients)
        composer.setSubject(subject)
        composer.setMessageBody(body, isHTML: false)

        if let data = attachmentData {
            composer.addAttachmentData(data, mimeType: attachmentMimeType, fileName: attachmentFileName)
        }

        return composer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposeView

        init(_ parent: MailComposeView) {
            self.parent = parent
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.onResult?(result)
            parent.dismiss()
        }
    }
}

/// Check if device can send email
func canSendEmail() -> Bool {
    MFMailComposeViewController.canSendMail()
}

// MARK: - SHARE SHEET

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - DOCUMENT SCANNER

@available(iOS 13.0, *)
struct DocumentScannerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onScanComplete: ([UIImage]) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScannerView

        init(_ parent: DocumentScannerView) {
            self.parent = parent
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var images: [UIImage] = []
            for i in 0..<scan.pageCount {
                images.append(scan.imageOfPage(at: i))
            }
            parent.onScanComplete(images)
            parent.dismiss()
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.dismiss()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            print("Document scan failed: \(error)")
            parent.dismiss()
        }
    }
}

// MARK: - OCR TEXT RECOGNITION

class DocumentTextRecognizer: ObservableObject {
    @Published var recognizedFields: [RecognizedField] = []
    @Published var isProcessing = false
    @Published var error: String?

    struct RecognizedField: Identifiable {
        let id = UUID()
        var label: String
        var suggestedType: FieldType
        var boundingBox: CGRect
        var confidence: Float
    }

    func processImage(_ image: UIImage) async {
        await MainActor.run {
            isProcessing = true
            error = nil
            recognizedFields = []
        }

        guard let cgImage = image.cgImage else {
            await MainActor.run {
                error = "Invalid image"
                isProcessing = false
            }
            return
        }

        let request = VNRecognizeTextRequest { [weak self] request, error in
            if let error = error {
                Task { @MainActor in
                    self?.error = error.localizedDescription
                    self?.isProcessing = false
                }
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                Task { @MainActor in
                    self?.isProcessing = false
                }
                return
            }

            var fields: [RecognizedField] = []

            for observation in observations {
                guard let topCandidate = observation.topCandidates(1).first else { continue }

                let text = topCandidate.string.trimmingCharacters(in: .whitespacesAndNewlines)

                // Skip very short text
                guard text.count >= 2 else { continue }

                // Detect field type based on text content
                let fieldType = self?.detectFieldType(from: text) ?? .text

                // Check if this looks like a field label (ends with : or is followed by _____)
                let isLabel = text.hasSuffix(":") ||
                              text.contains("____") ||
                              text.uppercased() == text ||
                              self?.isCommonFieldLabel(text) == true

                if isLabel {
                    let cleanLabel = text.replacingOccurrences(of: ":", with: "")
                                        .replacingOccurrences(of: "_", with: "")
                                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    if !cleanLabel.isEmpty {
                        fields.append(RecognizedField(
                            label: cleanLabel,
                            suggestedType: fieldType,
                            boundingBox: observation.boundingBox,
                            confidence: topCandidate.confidence
                        ))
                    }
                }
            }

            Task { @MainActor in
                self?.recognizedFields = fields.sorted { $0.boundingBox.origin.y > $1.boundingBox.origin.y }
                self?.isProcessing = false
            }
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isProcessing = false
            }
        }
    }

    private func detectFieldType(from text: String) -> FieldType {
        let lowercased = text.lowercased()

        // Date patterns
        if lowercased.contains("date") || lowercased.contains("dob") || lowercased.contains("birth") {
            return .date
        }

        // Time patterns
        if lowercased.contains("time") {
            return .time
        }

        // Email patterns
        if lowercased.contains("email") || lowercased.contains("e-mail") {
            return .email
        }

        // Phone patterns
        if lowercased.contains("phone") || lowercased.contains("tel") || lowercased.contains("mobile") || lowercased.contains("cell") {
            return .phone
        }

        // Signature patterns
        if lowercased.contains("signature") || lowercased.contains("sign here") {
            return .signature
        }

        // Yes/No patterns
        if lowercased.contains("yes") && lowercased.contains("no") {
            return .yesNo
        }

        // Checkbox patterns
        if lowercased.contains("[ ]") || lowercased.contains("[x]") || lowercased.contains("check") {
            return .checkbox
        }

        // Number patterns
        if lowercased.contains("number") || lowercased.contains("amount") || lowercased.contains("qty") || lowercased.contains("quantity") {
            return .number
        }

        // Currency patterns
        if lowercased.contains("$") || lowercased.contains("price") || lowercased.contains("cost") || lowercased.contains("total") {
            return .currency
        }

        // Address/long text patterns
        if lowercased.contains("address") || lowercased.contains("description") || lowercased.contains("comments") || lowercased.contains("notes") {
            return .textarea
        }

        return .text
    }

    private func isCommonFieldLabel(_ text: String) -> Bool {
        let commonLabels = [
            "name", "first name", "last name", "full name",
            "date", "time", "email", "phone", "address",
            "city", "state", "zip", "country",
            "company", "organization", "department",
            "title", "position", "role",
            "signature", "sign", "initials",
            "comments", "notes", "description",
            "yes", "no", "n/a",
            "total", "amount", "quantity", "qty"
        ]

        let lowercased = text.lowercased().trimmingCharacters(in: .punctuationCharacters)
        return commonLabels.contains { lowercased.contains($0) }
    }
}

// MARK: - SCAN TO FORM VIEW

struct ScanToFormView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var textRecognizer = DocumentTextRecognizer()

    @State private var showScanner = false
    @State private var scannedImages: [UIImage] = []
    @State private var selectedImageIndex = 0
    @State private var formName = ""
    @State private var formCategory = "General"
    @State private var showCreateConfirmation = false

    let categories = ["General", "Safety", "Permits", "Inspections", "Meetings", "Maintenance", "Quality", "HR"]

    let onTemplateCreated: (FormTemplate) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if scannedImages.isEmpty {
                    // Empty state - prompt to scan
                    emptyStateView
                } else {
                    // Show scanned document and recognized fields
                    ScrollView {
                        VStack(spacing: 20) {
                            // Scanned image preview
                            scannedImageSection

                            // Form details
                            formDetailsSection

                            // Recognized fields
                            recognizedFieldsSection

                            // Create button
                            createButtonSection
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Scan Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                if !scannedImages.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Rescan") {
                            showScanner = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showScanner) {
                DocumentScannerView { images in
                    scannedImages = images
                    if let firstImage = images.first {
                        Task {
                            await textRecognizer.processImage(firstImage)
                        }
                    }
                }
            }
            .alert("Template Created", isPresented: $showCreateConfirmation) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your form template '\(formName)' has been created with \(textRecognizer.recognizedFields.count) fields.")
            }
            .onAppear {
                showScanner = true
            }
        }
    }

    // MARK: - Views

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "doc.viewfinder")
                .font(.system(size: 64))
                .foregroundColor(.blue)

            Text("Scan a Paper Form")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Point your camera at a paper form and we'll automatically detect the fields and create a digital template.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: { showScanner = true }) {
                Label("Start Scanning", systemImage: "camera.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
        }
        .frame(maxHeight: .infinity)
    }

    private var scannedImageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scanned Document")
                .font(.headline)

            if scannedImages.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(scannedImages.enumerated()), id: \.offset) { index, image in
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 140)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(selectedImageIndex == index ? Color.blue : Color.clear, lineWidth: 3)
                                )
                                .onTapGesture {
                                    selectedImageIndex = index
                                    Task {
                                        await textRecognizer.processImage(image)
                                    }
                                }
                        }
                    }
                }
            } else if let image = scannedImages.first {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    private var formDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Form Details")
                .font(.headline)

            TextField("Form Name", text: $formName)
                .textFieldStyle(.roundedBorder)

            Picker("Category", selection: $formCategory) {
                ForEach(categories, id: \.self) { category in
                    Text(category).tag(category)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    private var recognizedFieldsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Detected Fields")
                    .font(.headline)

                Spacer()

                if textRecognizer.isProcessing {
                    ProgressView()
                } else {
                    Text("\(textRecognizer.recognizedFields.count) fields")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if textRecognizer.isProcessing {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("Analyzing document...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding()
            } else if let error = textRecognizer.error {
                Text("Error: \(error)")
                    .font(.caption)
                    .foregroundColor(.red)
            } else if textRecognizer.recognizedFields.isEmpty {
                Text("No fields detected. Try scanning a clearer image or add fields manually.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(textRecognizer.recognizedFields.enumerated()), id: \.element.id) { index, field in
                    RecognizedFieldRow(
                        field: field,
                        onUpdate: { updated in
                            textRecognizer.recognizedFields[index] = updated
                        },
                        onDelete: {
                            textRecognizer.recognizedFields.remove(at: index)
                        }
                    )
                }

                // Add field manually button
                Button(action: addManualField) {
                    Label("Add Field Manually", systemImage: "plus.circle")
                        .font(.subheadline)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    private var createButtonSection: some View {
        Button(action: createTemplate) {
            HStack {
                Image(systemName: "doc.badge.plus")
                Text("Create Template")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(canCreate ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!canCreate)
    }

    // MARK: - Helpers

    private var canCreate: Bool {
        !formName.isEmpty && !textRecognizer.recognizedFields.isEmpty && !textRecognizer.isProcessing
    }

    private func addManualField() {
        let newField = DocumentTextRecognizer.RecognizedField(
            label: "New Field",
            suggestedType: .text,
            boundingBox: .zero,
            confidence: 1.0
        )
        textRecognizer.recognizedFields.append(newField)
    }

    private func createTemplate() {
        let fields = textRecognizer.recognizedFields.enumerated().map { index, field in
            TemplateFieldData(
                label: field.label,
                type: field.suggestedType,
                isRequired: false,
                options: nil
            )
        }

        let template = DataController.shared.createTemplate(
            name: formName,
            description: "Created from scanned document",
            category: formCategory,
            fields: fields
        )

        onTemplateCreated(template)
        showCreateConfirmation = true
    }
}

struct RecognizedFieldRow: View {
    let field: DocumentTextRecognizer.RecognizedField
    let onUpdate: (DocumentTextRecognizer.RecognizedField) -> Void
    let onDelete: () -> Void

    @State private var label: String
    @State private var fieldType: FieldType
    @State private var isEditing = false

    init(field: DocumentTextRecognizer.RecognizedField, onUpdate: @escaping (DocumentTextRecognizer.RecognizedField) -> Void, onDelete: @escaping () -> Void) {
        self.field = field
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        _label = State(initialValue: field.label)
        _fieldType = State(initialValue: field.suggestedType)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: fieldType.icon)
                .foregroundColor(.blue)
                .frame(width: 24)

            if isEditing {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Label", text: $label)
                        .textFieldStyle(.roundedBorder)
                        .font(.subheadline)

                    Picker("Type", selection: $fieldType) {
                        ForEach(FieldType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.subheadline)
                    Text(fieldType.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if isEditing {
                Button("Done") {
                    var updated = field
                    updated.label = label
                    updated.suggestedType = fieldType
                    onUpdate(updated)
                    isEditing = false
                }
                .font(.caption)
            } else {
                Menu {
                    Button("Edit", action: { isEditing = true })
                    Button("Delete", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - IMPROVED FORM BUILDER VIEW

struct ImprovedFormBuilderView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var formName = ""
    @State private var formDescription = ""
    @State private var selectedCategory = "General"
    @State private var fields: [BuilderField] = []
    @State private var showAddFieldSheet = false
    @State private var showFieldPalette = false
    @State private var editingField: BuilderField?
    @State private var showSaveConfirmation = false
    @State private var showScanDocument = false
    @State private var draggedField: BuilderField?

    let categories = ["General", "Safety", "Permits", "Inspections", "Meetings", "Maintenance", "Quality", "HR"]

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                // Field Palette (iPad sidebar or bottom sheet on iPhone)
                if showFieldPalette {
                    fieldPaletteView
                        .frame(width: 200)
                        .background(Color(.systemGray6))
                }

                // Main form builder area
                ScrollView {
                    VStack(spacing: 16) {
                        // Form details card
                        formDetailsCard

                        // Quick actions
                        quickActionsRow

                        // Fields list
                        fieldsListSection

                        // Add field button
                        addFieldButton
                    }
                    .padding()
                }
            }
            .navigationTitle("Form Builder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    HStack {
                        Button(action: { showFieldPalette.toggle() }) {
                            Image(systemName: "sidebar.right")
                        }

                        Button("Save") {
                            saveTemplate()
                        }
                        .disabled(formName.isEmpty || fields.isEmpty)
                    }
                }
            }
            .sheet(isPresented: $showAddFieldSheet) {
                AddFieldSheet { newField in
                    fields.append(newField)
                }
            }
            .sheet(item: $editingField) { field in
                EditFieldSheet(field: field) { updatedField in
                    if let index = fields.firstIndex(where: { $0.id == field.id }) {
                        fields[index] = updatedField
                    }
                }
            }
            .sheet(isPresented: $showScanDocument) {
                ScanToFormView { template in
                    // Convert template fields to builder fields
                    if let templateFields = template.fields?.allObjects as? [TemplateField] {
                        fields = templateFields.map { tf in
                            BuilderField(
                                label: tf.label ?? "",
                                type: FieldType(rawValue: tf.type ?? "text") ?? .text,
                                isRequired: tf.isRequired,
                                options: tf.options,
                                placeholder: nil
                            )
                        }
                        formName = template.name ?? ""
                        selectedCategory = template.category ?? "General"
                    }
                }
            }
            .alert("Template Saved", isPresented: $showSaveConfirmation) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your form template has been created successfully.")
            }
        }
    }

    // MARK: - Views

    private var formDetailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Form Details")
                .font(.headline)

            TextField("Form Name *", text: $formName)
                .textFieldStyle(.roundedBorder)

            TextField("Description (optional)", text: $formDescription)
                .textFieldStyle(.roundedBorder)

            Picker("Category", selection: $selectedCategory) {
                ForEach(categories, id: \.self) { category in
                    Text(category).tag(category)
                }
            }
            .pickerStyle(.menu)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }

    private var quickActionsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                QuickActionButton(
                    title: "Scan Document",
                    icon: "doc.viewfinder",
                    color: .blue
                ) {
                    showScanDocument = true
                }

                QuickActionButton(
                    title: "Add Text Field",
                    icon: "textformat",
                    color: .green
                ) {
                    addQuickField(.text)
                }

                QuickActionButton(
                    title: "Add Signature",
                    icon: "signature",
                    color: .purple
                ) {
                    addQuickField(.signature)
                }

                QuickActionButton(
                    title: "Add Photo",
                    icon: "camera",
                    color: .orange
                ) {
                    addQuickField(.photo)
                }

                QuickActionButton(
                    title: "Add Yes/No",
                    icon: "hand.thumbsup",
                    color: .teal
                ) {
                    addQuickField(.yesNo)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private var fieldsListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Form Fields")
                    .font(.headline)
                Spacer()
                if !fields.isEmpty {
                    Text("\(fields.count) field\(fields.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if fields.isEmpty {
                emptyFieldsView
            } else {
                ForEach(Array(fields.enumerated()), id: \.element.id) { index, field in
                    DraggableFieldRow(
                        field: field,
                        index: index,
                        onEdit: { editingField = field },
                        onDelete: { fields.remove(at: index) },
                        onMove: { from, to in
                            fields.move(fromOffsets: IndexSet(integer: from), toOffset: to)
                        }
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }

    private var emptyFieldsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("No fields yet")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Scan a document, drag fields from the palette, or tap + to add fields")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var addFieldButton: some View {
        Button(action: { showAddFieldSheet = true }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Add Field")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue.opacity(0.1))
            .foregroundColor(.blue)
            .cornerRadius(12)
        }
    }

    private var fieldPaletteView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Field Types")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(FieldType.allCases, id: \.self) { type in
                        PaletteFieldItem(type: type) {
                            addQuickField(type)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Helpers

    private func addQuickField(_ type: FieldType) {
        let field = BuilderField(
            label: type.displayName,
            type: type,
            isRequired: false,
            options: nil,
            placeholder: nil
        )
        fields.append(field)
    }

    private func saveTemplate() {
        let templateFields = fields.map { field in
            TemplateFieldData(
                label: field.label,
                type: field.type,
                isRequired: field.isRequired,
                options: field.options
            )
        }

        _ = DataController.shared.createTemplate(
            name: formName,
            description: formDescription.isEmpty ? nil : formDescription,
            category: selectedCategory,
            fields: templateFields
        )

        showSaveConfirmation = true
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.primary)
            }
            .frame(width: 80, height: 70)
            .background(color.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct PaletteFieldItem: View {
    let type: FieldType
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: type.icon)
                    .foregroundColor(.blue)
                    .frame(width: 24)

                Text(type.displayName)
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "plus.circle")
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(Color(.systemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct DraggableFieldRow: View {
    let field: BuilderField
    let index: Int
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onMove: (Int, Int) -> Void

    @State private var isDragging = false

    var body: some View {
        HStack(spacing: 12) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .foregroundColor(.secondary)
                .font(.caption)

            // Field icon
            Image(systemName: field.type.icon)
                .foregroundColor(.blue)
                .frame(width: 24)

            // Field info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(field.label)
                        .font(.subheadline)
                    if field.isRequired {
                        Text("*")
                            .foregroundColor(.red)
                    }
                }
                Text(field.type.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Actions
            Menu {
                Button("Edit", action: onEdit)
                Button("Duplicate") {
                    // Could implement duplicate
                }
                Divider()
                Button("Delete", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(isDragging ? Color.blue.opacity(0.1) : Color(.systemGray6))
        .cornerRadius(8)
        .opacity(isDragging ? 0.8 : 1)
        .onDrag {
            isDragging = true
            return NSItemProvider(object: String(index) as NSString)
        }
        .onDrop(of: [.text], delegate: FieldDropDelegate(
            targetIndex: index,
            onMove: onMove,
            onDragEnd: { isDragging = false }
        ))
    }
}

struct FieldDropDelegate: DropDelegate {
    let targetIndex: Int
    let onMove: (Int, Int) -> Void
    let onDragEnd: () -> Void

    func performDrop(info: DropInfo) -> Bool {
        onDragEnd()
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let item = info.itemProviders(for: [.text]).first else { return }

        item.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { data, _ in
            if let data = data as? Data,
               let sourceIndexString = String(data: data, encoding: .utf8),
               let sourceIndex = Int(sourceIndexString),
               sourceIndex != targetIndex {
                DispatchQueue.main.async {
                    onMove(sourceIndex, targetIndex > sourceIndex ? targetIndex + 1 : targetIndex)
                }
            }
        }
    }
}

// MARK: - BUILDER FIELD MODEL

struct BuilderField: Identifiable, Equatable {
    let id = UUID()
    var label: String
    var type: FieldType
    var isRequired: Bool
    var options: String?
    var placeholder: String?

    static func == (lhs: BuilderField, rhs: BuilderField) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - ADD FIELD SHEET

struct AddFieldSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (BuilderField) -> Void

    @State private var label = ""
    @State private var selectedType: FieldType = .text
    @State private var isRequired = false
    @State private var options = ""
    @State private var placeholder = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Field Details") {
                    TextField("Field Label", text: $label)

                    Picker("Field Type", selection: $selectedType) {
                        ForEach(FieldType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon).tag(type)
                        }
                    }

                    Toggle("Required", isOn: $isRequired)
                }

                if selectedType == .dropdown || selectedType == .multiSelect {
                    Section("Options") {
                        TextField("Options (comma separated)", text: $options)
                        Text("Example: Option 1, Option 2, Option 3")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if selectedType == .text || selectedType == .number || selectedType == .textarea {
                    Section("Optional") {
                        TextField("Placeholder text", text: $placeholder)
                    }
                }

                // Preview section
                Section("Preview") {
                    FieldPreview(type: selectedType, label: label.isEmpty ? "Field Label" : label)
                }
            }
            .navigationTitle("Add Field")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Add") {
                        let field = BuilderField(
                            label: label,
                            type: selectedType,
                            isRequired: isRequired,
                            options: options.isEmpty ? nil : options,
                            placeholder: placeholder.isEmpty ? nil : placeholder
                        )
                        onAdd(field)
                        dismiss()
                    }
                    .disabled(label.isEmpty)
                }
            }
        }
    }
}

struct FieldPreview: View {
    let type: FieldType
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            previewContent
        }
    }

    @ViewBuilder
    private var previewContent: some View {
        switch type {
        case .text, .email, .phone:
            TextField("Enter text...", text: .constant(""))
                .textFieldStyle(.roundedBorder)
                .disabled(true)

        case .number, .currency:
            TextField("0", text: .constant(""))
                .textFieldStyle(.roundedBorder)
                .disabled(true)

        case .textarea:
            TextEditor(text: .constant(""))
                .frame(height: 60)
                .border(Color.gray.opacity(0.3))
                .disabled(true)

        case .date:
            DatePicker("", selection: .constant(Date()), displayedComponents: .date)
                .labelsHidden()
                .disabled(true)

        case .time:
            DatePicker("", selection: .constant(Date()), displayedComponents: .hourAndMinute)
                .labelsHidden()
                .disabled(true)

        case .checkbox:
            Toggle("", isOn: .constant(false))
                .labelsHidden()
                .disabled(true)

        case .yesNo:
            HStack {
                ForEach(["Yes", "No", "N/A"], id: \.self) { option in
                    Text(option)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }
            }

        case .dropdown, .multiSelect:
            HStack {
                Text("Select...")
                    .foregroundColor(.gray)
                Spacer()
                Image(systemName: "chevron.down")
            }
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(6)

        case .signature:
            RoundedRectangle(cornerRadius: 6)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                .foregroundColor(.gray)
                .frame(height: 50)
                .overlay(
                    Text("Sign here")
                        .font(.caption)
                        .foregroundColor(.gray)
                )

        case .photo:
            RoundedRectangle(cornerRadius: 6)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                .foregroundColor(.gray)
                .frame(height: 50)
                .overlay(
                    Label("Add photo", systemImage: "camera")
                        .font(.caption)
                        .foregroundColor(.gray)
                )

        case .location:
            HStack {
                Image(systemName: "location")
                    .foregroundColor(.blue)
                Text("Capture location")
                    .foregroundColor(.gray)
            }

        case .rating:
            HStack {
                ForEach(1...5, id: \.self) { _ in
                    Image(systemName: "star")
                        .foregroundColor(.gray)
                }
            }

        case .slider:
            Slider(value: .constant(0.5))
                .disabled(true)

        case .section:
            Text("Section Header")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - EDIT FIELD SHEET

struct EditFieldSheet: View {
    @Environment(\.dismiss) private var dismiss
    let field: BuilderField
    let onSave: (BuilderField) -> Void

    @State private var label: String
    @State private var selectedType: FieldType
    @State private var isRequired: Bool
    @State private var options: String
    @State private var placeholder: String

    init(field: BuilderField, onSave: @escaping (BuilderField) -> Void) {
        self.field = field
        self.onSave = onSave
        _label = State(initialValue: field.label)
        _selectedType = State(initialValue: field.type)
        _isRequired = State(initialValue: field.isRequired)
        _options = State(initialValue: field.options ?? "")
        _placeholder = State(initialValue: field.placeholder ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Field Details") {
                    TextField("Field Label", text: $label)

                    Picker("Field Type", selection: $selectedType) {
                        ForEach(FieldType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon).tag(type)
                        }
                    }

                    Toggle("Required", isOn: $isRequired)
                }

                if selectedType == .dropdown || selectedType == .multiSelect {
                    Section("Options") {
                        TextField("Options (comma separated)", text: $options)
                    }
                }

                if selectedType == .text || selectedType == .number || selectedType == .textarea {
                    Section("Optional") {
                        TextField("Placeholder text", text: $placeholder)
                    }
                }
            }
            .navigationTitle("Edit Field")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Save") {
                        var updatedField = field
                        updatedField.label = label
                        updatedField.type = selectedType
                        updatedField.isRequired = isRequired
                        updatedField.options = options.isEmpty ? nil : options
                        updatedField.placeholder = placeholder.isEmpty ? nil : placeholder
                        onSave(updatedField)
                        dismiss()
                    }
                    .disabled(label.isEmpty)
                }
            }
        }
    }
}

// MARK: - IMPROVED EXPORT OPTIONS VIEW

struct ImprovedExportOptionsView: View {
    let form: FormEntity
    @Environment(\.dismiss) private var dismiss

    @State private var showShareSheet = false
    @State private var showMailComposer = false
    @State private var emailRecipient = ""
    @State private var pdfData: Data?
    @State private var pdfURL: URL?
    @State private var isGenerating = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            List {
                // PDF Preview Section
                Section {
                    if isGenerating {
                        HStack {
                            Spacer()
                            ProgressView("Generating PDF...")
                            Spacer()
                        }
                        .padding()
                    } else if let data = pdfData, let doc = PDFDocument(data: data) {
                        PDFPreviewView(document: doc)
                            .frame(height: 300)
                            .cornerRadius(8)
                    }
                } header: {
                    Text("Preview")
                }

                // Share Options
                Section("Share") {
                    Button(action: sharePDF) {
                        Label("Share PDF", systemImage: "square.and.arrow.up")
                    }
                    .disabled(pdfData == nil)

                    Button(action: { showMailComposer = true }) {
                        Label("Email PDF", systemImage: "envelope")
                    }
                    .disabled(pdfData == nil || !canSendEmail())

                    Button(action: saveToPDF) {
                        Label("Save to Files", systemImage: "folder")
                    }
                    .disabled(pdfData == nil)
                }

                // Export Formats
                Section("Export Format") {
                    Button(action: exportAsJSON) {
                        Label("Export as JSON", systemImage: "doc.text")
                    }

                    Button(action: exportAsCSV) {
                        Label("Export as CSV", systemImage: "tablecells")
                    }
                }

                // Print
                Section {
                    Button(action: printPDF) {
                        Label("Print", systemImage: "printer")
                    }
                    .disabled(pdfData == nil)
                }
            }
            .navigationTitle("Export Form")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                generatePDF()
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = pdfURL {
                    ShareSheet(items: [url])
                }
            }
            .sheet(isPresented: $showMailComposer) {
                if canSendEmail(), let data = pdfData {
                    MailComposeView(
                        recipients: [],
                        subject: "Form: \(form.title ?? "Untitled")",
                        body: "Please find the attached form.\n\nForm: \(form.title ?? "Untitled")\nStatus: \(form.status ?? "Draft")\nDate: \(Date().formatted())",
                        attachmentData: data,
                        attachmentMimeType: "application/pdf",
                        attachmentFileName: "\(form.title ?? "Form").pdf"
                    )
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Actions

    private func generatePDF() {
        isGenerating = true

        DispatchQueue.global(qos: .userInitiated).async {
            let generator = PDFGenerator()
            let data = generator.generatePDF(for: form)
            let url = generator.savePDFToTemp(for: form)

            DispatchQueue.main.async {
                pdfData = data
                pdfURL = url
                isGenerating = false
            }
        }
    }

    private func sharePDF() {
        guard pdfURL != nil else { return }
        showShareSheet = true
    }

    private func saveToPDF() {
        guard let data = pdfData else { return }

        let fileName = "\(form.title ?? "Form")_\(Date().formatted(date: .numeric, time: .omitted)).pdf"

        // Use document picker to save
        if let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = url.appendingPathComponent(fileName)
            do {
                try data.write(to: fileURL)
                // Could show success message
            } catch {
                errorMessage = "Failed to save PDF: \(error.localizedDescription)"
                showError = true
            }
        }
    }

    private func exportAsJSON() {
        let formData = FormSyncData(from: form)

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try encoder.encode(formData)

            let fileName = "\(form.title ?? "Form").json"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try jsonData.write(to: tempURL)

            pdfURL = tempURL
            showShareSheet = true
        } catch {
            errorMessage = "Failed to export JSON: \(error.localizedDescription)"
            showError = true
        }
    }

    private func exportAsCSV() {
        var csv = "Field,Value,Type,Required\n"

        if let fields = form.fields?.allObjects as? [FormField] {
            for field in fields.sorted(by: { $0.order < $1.order }) {
                let label = (field.label ?? "").replacingOccurrences(of: ",", with: ";")
                let value = (field.value ?? "").replacingOccurrences(of: ",", with: ";")
                let type = field.type ?? "text"
                let required = field.isRequired ? "Yes" : "No"
                csv += "\"\(label)\",\"\(value)\",\"\(type)\",\"\(required)\"\n"
            }
        }

        let fileName = "\(form.title ?? "Form").csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try csv.write(to: tempURL, atomically: true, encoding: .utf8)
            pdfURL = tempURL
            showShareSheet = true
        } catch {
            errorMessage = "Failed to export CSV: \(error.localizedDescription)"
            showError = true
        }
    }

    private func printPDF() {
        guard let data = pdfData else { return }

        let printController = UIPrintInteractionController.shared
        printController.printingItem = data
        printController.present(animated: true)
    }
}

struct PDFPreviewView: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = document
    }
}

// MARK: - CONTENT VIEW

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var syncManager: SyncManager

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .onAppear {
            syncManager.startMonitoring()
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            FormsListView()
                .tabItem {
                    Label("Forms", systemImage: "doc.text.fill")
                }
                .tag(0)

            TemplatesView()
                .tabItem {
                    Label("Templates", systemImage: "square.stack.fill")
                }
                .tag(1)

            PendingApprovalsView()
                .tabItem {
                    Label("Approvals", systemImage: "checkmark.seal.fill")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
    }
}

// MARK: - PLACEHOLDER VIEWS (Keep existing implementations)

// Note: The following views should use the existing implementations from the original file:
// - LoginView
// - FormsListView
// - FormDetailView
// - TemplatesView
// - PendingApprovalsView
// - SettingsView
// - SignatureView
// - All other supporting views

// For brevity, I'm including placeholders - in the actual implementation,
// merge these with the improved features above

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var syncManager: SyncManager

    @State private var email = ""
    @State private var password = ""
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.blue.gradient)

                    Text("Digital Forms")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                .padding(.top, 60)

                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)

                    SecureField("Password", text: $password)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)

                    Button(action: login) {
                        HStack {
                            if authManager.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Sign In")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(email.isEmpty || password.isEmpty || authManager.isLoading)
                }
                .padding(.horizontal)

                Spacer()
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func login() {
        Task {
            do {
                try await authManager.login(email: email, password: password)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

struct FormsListView: View {
    @EnvironmentObject var syncManager: SyncManager
    @State private var showNewFormSheet = false

    var body: some View {
        NavigationStack {
            List {
                Text("Forms will appear here")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Forms")
            .toolbar {
                Button(action: { showNewFormSheet = true }) {
                    Image(systemName: "plus.circle.fill")
                }
            }
            .sheet(isPresented: $showNewFormSheet) {
                NewFormView()
            }
        }
    }
}

struct NewFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showFormBuilder = false
    @State private var showScanDocument = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(action: { showScanDocument = true }) {
                        Label("Scan Paper Form", systemImage: "doc.viewfinder")
                    }

                    Button(action: { showFormBuilder = true }) {
                        Label("Build Custom Form", systemImage: "plus.rectangle.on.rectangle")
                    }
                }

                Section("Templates") {
                    Text("Select a template to create a new form")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("New Form")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showFormBuilder) {
                ImprovedFormBuilderView()
            }
            .sheet(isPresented: $showScanDocument) {
                ScanToFormView { _ in }
            }
        }
    }
}

struct TemplatesView: View {
    @State private var showFormBuilder = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(action: { showFormBuilder = true }) {
                        Label("Create Template", systemImage: "plus.rectangle.on.rectangle")
                    }
                }
            }
            .navigationTitle("Templates")
            .sheet(isPresented: $showFormBuilder) {
                ImprovedFormBuilderView()
            }
        }
    }
}

struct PendingApprovalsView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Image(systemName: "checkmark.seal")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
                Text("No pending approvals")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Approvals")
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text(authManager.currentUser?.name ?? "User")
                                .font(.headline)
                            Text(authManager.currentUser?.email ?? "")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        authManager.logout()
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthManager.shared)
        .environmentObject(SyncManager.shared)
        .environmentObject(DataController.shared)
}
