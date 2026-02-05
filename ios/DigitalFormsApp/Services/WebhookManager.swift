/**
 * WebhookManager.swift
 * Webhook Integration for Form Submissions
 *
 * Features:
 * - Configure webhook endpoints
 * - Automatic form submission triggers
 * - Retry logic with exponential backoff
 * - Webhook delivery history
 * - Custom headers and payload formatting
 */

import Foundation
import Combine

// MARK: - Webhook Configuration

struct WebhookConfig: Codable, Identifiable {
    let id: UUID
    var name: String
    var url: String
    var isActive: Bool
    var triggers: [WebhookTrigger]
    var headers: [String: String]
    var authType: AuthType
    var authToken: String?
    var retryAttempts: Int
    var retryDelay: TimeInterval
    
    enum AuthType: String, Codable {
        case none = "none"
        case bearer = "bearer"
        case apiKey = "api_key"
        case basic = "basic"
    }
    
    enum WebhookTrigger: String, Codable, CaseIterable {
        case formSubmitted = "form_submitted"
        case formApproved = "form_approved"
        case formRejected = "form_rejected"
        case signatureCaptured = "signature_captured"
        
        var displayName: String {
            switch self {
            case .formSubmitted: return "Form Submitted"
            case .formApproved: return "Form Approved"
            case .formRejected: return "Form Rejected"
            case .signatureCaptured: return "Signature Captured"
            }
        }
    }
    
    init(id: UUID = UUID(), name: String, url: String, isActive: Bool = true, triggers: [WebhookTrigger] = [.formSubmitted], authType: AuthType = .none) {
        self.id = id
        self.name = name
        self.url = url
        self.isActive = isActive
        self.triggers = triggers
        self.headers = [:]
        self.authType = authType
        self.authToken = nil
        self.retryAttempts = 3
        self.retryDelay = 2.0
    }
}

// MARK: - Webhook Delivery

struct WebhookDelivery: Codable, Identifiable {
    let id: UUID
    let webhookId: UUID
    let trigger: WebhookConfig.WebhookTrigger
    let formId: UUID
    let timestamp: Date
    var status: DeliveryStatus
    var attempts: Int
    var lastAttemptAt: Date?
    var responseCode: Int?
    var errorMessage: String?
    
    enum DeliveryStatus: String, Codable {
        case pending = "pending"
        case success = "success"
        case failed = "failed"
        case retrying = "retrying"
    }
    
    init(webhookId: UUID, trigger: WebhookConfig.WebhookTrigger, formId: UUID) {
        self.id = UUID()
        self.webhookId = webhookId
        self.trigger = trigger
        self.formId = formId
        self.timestamp = Date()
        self.status = .pending
        self.attempts = 0
    }
}

// MARK: - Webhook Manager

class WebhookManager: ObservableObject {
    static let shared = WebhookManager()
    
    @Published var webhooks: [WebhookConfig] = []
    @Published var deliveries: [WebhookDelivery] = []
    
    private var cancellables = Set<AnyCancellable>()
    private let userDefaultsKey = "WebhookConfigs"
    private let deliveriesKey = "WebhookDeliveries"
    private let maxDeliveryHistory = 100
    
    private init() {
        loadWebhooks()
        loadDeliveries()
    }
    
    // MARK: - Webhook Configuration
    
    func addWebhook(_ webhook: WebhookConfig) {
        webhooks.append(webhook)
        saveWebhooks()
    }
    
    func updateWebhook(_ webhook: WebhookConfig) {
        if let index = webhooks.firstIndex(where: { $0.id == webhook.id }) {
            webhooks[index] = webhook
            saveWebhooks()
        }
    }
    
    func deleteWebhook(id: UUID) {
        webhooks.removeAll { $0.id == id }
        saveWebhooks()
    }
    
    func toggleWebhook(id: UUID) {
        if let index = webhooks.firstIndex(where: { $0.id == id }) {
            webhooks[index].isActive.toggle()
            saveWebhooks()
        }
    }
    
    // MARK: - Webhook Triggering
    
    func trigger(_ event: WebhookConfig.WebhookTrigger, form: LocalForm, signature: LegalSignature? = nil) {
        let formId = form.id ?? UUID()
        
        // Find webhooks that should be triggered
        let matchingWebhooks = webhooks.filter { webhook in
            webhook.isActive && webhook.triggers.contains(event)
        }
        
        for webhook in matchingWebhooks {
            let delivery = WebhookDelivery(webhookId: webhook.id, trigger: event, formId: formId)
            deliveries.append(delivery)
            
            Task {
                await deliverWebhook(webhook, delivery: delivery, form: form, signature: signature)
            }
        }
        
        saveDeliveries()
    }
    
    // MARK: - Webhook Delivery
    
    private func deliverWebhook(_ webhook: WebhookConfig, delivery: WebhookDelivery, form: LocalForm, signature: LegalSignature?) async {
        var currentDelivery = delivery
        
        for attempt in 1...webhook.retryAttempts {
            currentDelivery.attempts = attempt
            currentDelivery.lastAttemptAt = Date()
            currentDelivery.status = attempt > 1 ? .retrying : .pending
            updateDelivery(currentDelivery)
            
            do {
                let payload = createPayload(form: form, signature: signature, trigger: delivery.trigger)
                let response = try await sendWebhook(webhook: webhook, payload: payload)
                
                currentDelivery.status = .success
                currentDelivery.responseCode = response.statusCode
                updateDelivery(currentDelivery)
                return
                
            } catch {
                currentDelivery.errorMessage = error.localizedDescription
                
                if attempt < webhook.retryAttempts {
                    // Exponential backoff
                    let delay = webhook.retryDelay * pow(2.0, Double(attempt - 1))
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } else {
                    currentDelivery.status = .failed
                    updateDelivery(currentDelivery)
                }
            }
        }
    }
    
    private func sendWebhook(webhook: WebhookConfig, payload: [String: Any]) async throws -> (statusCode: Int, data: Data) {
        guard let url = URL(string: webhook.url) else {
            throw WebhookError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add custom headers
        for (key, value) in webhook.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Add authentication
        switch webhook.authType {
        case .bearer:
            if let token = webhook.authToken {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        case .apiKey:
            if let token = webhook.authToken {
                request.setValue(token, forHTTPHeaderField: "X-API-Key")
            }
        case .basic:
            if let token = webhook.authToken {
                request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
            }
        case .none:
            break
        }
        
        // Set payload
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WebhookError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw WebhookError.httpError(httpResponse.statusCode)
        }
        
        return (httpResponse.statusCode, data)
    }
    
    // MARK: - Payload Creation
    
    private func createPayload(form: LocalForm, signature: LegalSignature?, trigger: WebhookConfig.WebhookTrigger) -> [String: Any] {
        var payload: [String: Any] = [
            "event": trigger.rawValue,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "form": [
                "id": form.id?.uuidString ?? "",
                "title": form.title ?? "",
                "status": form.status ?? "",
                "created_at": ISO8601DateFormatter().string(from: form.createdAt ?? Date()),
                "updated_at": ISO8601DateFormatter().string(from: form.updatedAt ?? Date()),
                "fields": form.fields.map { field in
                    [
                        "id": field.id,
                        "type": field.type,
                        "label": field.label,
                        "value": field.value ?? "",
                        "required": field.required
                    ]
                }
            ]
        ]
        
        if let signature = signature {
            payload["signature"] = [
                "id": signature.id.uuidString,
                "signer_name": signature.signerName,
                "signer_email": signature.signerEmail,
                "signature_type": signature.signatureType.rawValue,
                "signed_at": ISO8601DateFormatter().string(from: signature.signedAt),
                "document_hash": signature.documentHash,
                "device_id": signature.deviceId,
                "latitude": signature.latitude ?? 0,
                "longitude": signature.longitude ?? 0
            ]
        }
        
        return payload
    }
    
    // MARK: - Delivery Management
    
    private func updateDelivery(_ delivery: WebhookDelivery) {
        if let index = deliveries.firstIndex(where: { $0.id == delivery.id }) {
            deliveries[index] = delivery
            saveDeliveries()
        }
    }
    
    func retryDelivery(_ delivery: WebhookDelivery) {
        guard let webhook = webhooks.first(where: { $0.id == delivery.webhookId }),
              let form = DataController.shared.fetchForm(id: delivery.formId) else {
            return
        }
        
        Task {
            await deliverWebhook(webhook, delivery: delivery, form: form, signature: nil)
        }
    }
    
    func clearDeliveryHistory() {
        deliveries.removeAll()
        saveDeliveries()
    }
    
    // MARK: - Persistence
    
    private func saveWebhooks() {
        if let data = try? JSONEncoder().encode(webhooks) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
    
    private func loadWebhooks() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let webhooks = try? JSONDecoder().decode([WebhookConfig].self, from: data) else {
            return
        }
        self.webhooks = webhooks
    }
    
    private func saveDeliveries() {
        // Keep only recent deliveries
        if deliveries.count > maxDeliveryHistory {
            deliveries = Array(deliveries.suffix(maxDeliveryHistory))
        }
        
        if let data = try? JSONEncoder().encode(deliveries) {
            UserDefaults.standard.set(data, forKey: deliveriesKey)
        }
    }
    
    private func loadDeliveries() {
        guard let data = UserDefaults.standard.data(forKey: deliveriesKey),
              let deliveries = try? JSONDecoder().decode([WebhookDelivery].self, from: data) else {
            return
        }
        self.deliveries = deliveries
    }
}

// MARK: - Webhook Error

enum WebhookError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid webhook URL"
        case .invalidResponse:
            return "Invalid response from webhook"
        case .httpError(let code):
            return "HTTP error: \(code)"
        }
    }
}
