/**
 * APIService.swift
 * Railway Backend API Integration
 *
 * Handles all communication with the backend server
 */

import Foundation

// MARK: - API Configuration

struct APIConfig {
    // Change this to your Railway URL after deployment
    #if DEBUG
    static let baseURL = "http://localhost:3000/api"
    #else
    static let baseURL = "https://your-app.railway.app/api"
    #endif

    static let timeout: TimeInterval = 30
}

// MARK: - API Error

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case validationError([String])
    case serverError(String)
    case networkError(Error)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .unauthorized:
            return "Please sign in again"
        case .forbidden:
            return "You don't have permission to do this"
        case .notFound:
            return "Resource not found"
        case .validationError(let errors):
            return errors.joined(separator: "\n")
        case .serverError(let message):
            return message
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Data error: \(error.localizedDescription)"
        }
    }
}

// MARK: - API Service

class APIService {
    static let shared = APIService()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = APIConfig.timeout
        config.timeoutIntervalForResource = APIConfig.timeout * 2
        session = URLSession(configuration: config)

        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Generic Request

    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        body: Encodable? = nil,
        requiresAuth: Bool = true
    ) async throws -> T {
        guard let url = URL(string: APIConfig.baseURL + endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add auth token if required
        if requiresAuth, let token = AuthManager.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Add body if present
        if let body = body {
            request.httpBody = try encoder.encode(body)
        }

        // Make request
        let (data, response) = try await session.data(for: request)

        // Handle response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decodingError(error)
            }

        case 401:
            // Try to refresh token
            if requiresAuth {
                try await AuthManager.shared.refreshTokens()
                // Retry request
                return try await self.request(endpoint: endpoint, method: method, body: body, requiresAuth: requiresAuth)
            }
            throw APIError.unauthorized

        case 403:
            throw APIError.forbidden

        case 404:
            throw APIError.notFound

        case 400:
            // Parse validation errors
            if let errorResponse = try? decoder.decode(ValidationErrorResponse.self, from: data) {
                throw APIError.validationError(errorResponse.errors.map { $0.msg })
            }
            throw APIError.serverError("Bad request")

        default:
            if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(errorResponse.error)
            }
            throw APIError.serverError("Server error (\(httpResponse.statusCode))")
        }
    }

    // MARK: - Upload Request

    func upload(
        endpoint: String,
        fileData: Data,
        fileName: String,
        mimeType: String,
        fieldName: String = "file",
        additionalFields: [String: String] = [:]
    ) async throws -> UploadResponse {
        guard let url = URL(string: APIConfig.baseURL + endpoint) else {
            throw APIError.invalidURL
        }

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let token = AuthManager.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Build multipart body
        var body = Data()

        // Add file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)

        // Add additional fields
        for (key, value) in additionalFields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

        return try decoder.decode(UploadResponse.self, from: data)
    }

    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
    }
}

// MARK: - API Response Types

struct ErrorResponse: Decodable {
    let error: String
}

struct ValidationErrorResponse: Decodable {
    let errors: [ValidationError]

    struct ValidationError: Decodable {
        let msg: String
        let param: String?
    }
}

struct UploadResponse: Decodable {
    let message: String
    let url: String
    let thumbnailUrl: String?
    let size: Int?
}

// MARK: - Auth API

extension APIService {
    struct LoginRequest: Encodable {
        let email: String
        let password: String
    }

    struct RegisterRequest: Encodable {
        let email: String
        let password: String
        let name: String
    }

    struct AuthResponse: Decodable {
        let accessToken: String
        let refreshToken: String
        let user: UserResponse
    }

    struct UserResponse: Decodable {
        let id: String
        let email: String
        let name: String
        let role: String
        let organizationId: String?
    }

    struct RefreshRequest: Encodable {
        let refreshToken: String
    }

    struct RefreshResponse: Decodable {
        let accessToken: String
        let refreshToken: String
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        return try await request(
            endpoint: "/auth/login",
            method: .post,
            body: LoginRequest(email: email, password: password),
            requiresAuth: false
        )
    }

    func register(email: String, password: String, name: String) async throws -> AuthResponse {
        return try await request(
            endpoint: "/auth/register",
            method: .post,
            body: RegisterRequest(email: email, password: password, name: name),
            requiresAuth: false
        )
    }

    func refreshToken(_ token: String) async throws -> RefreshResponse {
        return try await request(
            endpoint: "/auth/refresh",
            method: .post,
            body: RefreshRequest(refreshToken: token),
            requiresAuth: false
        )
    }

    func logout() async throws {
        let _: EmptyResponse = try await request(endpoint: "/auth/logout", method: .delete)
    }
}

// MARK: - Forms API

extension APIService {
    struct FormsListResponse: Decodable {
        let forms: [FormResponse]
        let total: Int
        let limit: Int
        let offset: Int
    }

    struct FormResponse: Decodable {
        let id: String
        let templateId: String?
        let title: String
        let status: String
        let fields: [FormFieldData]
        let createdBy: String?
        let createdByName: String?
        let latitude: Double?
        let longitude: Double?
        let submittedAt: Date?
        let createdAt: Date
        let updatedAt: Date
        let signatureCount: Int?
        let attachmentCount: Int?
    }

    struct FormFieldData: Codable {
        let id: String
        let type: String
        let label: String
        let value: String?
        let required: Bool?
        let options: [String]?
        let placeholder: String?
    }

    struct CreateFormRequest: Encodable {
        let title: String
        let templateId: String?
        let fields: [FormFieldData]
        let latitude: Double?
        let longitude: Double?
    }

    struct FormDetailResponse: Decodable {
        let form: FormResponse
        let signatures: [SignatureResponse]
        let attachments: [AttachmentResponse]
        let approvals: [ApprovalResponse]
    }

    struct SignatureResponse: Decodable {
        let id: String
        let signerName: String
        let signerEmail: String?
        let signerRole: String?
        let signatureType: String
        let signedAt: Date
        let documentHash: String?
        let consentGiven: Bool?
    }

    struct AttachmentResponse: Decodable {
        let id: String
        let fileName: String
        let fileType: String?
        let fileUrl: String
        let thumbnailUrl: String?
        let createdAt: Date
    }

    struct ApprovalResponse: Decodable {
        let id: String
        let decision: String
        let comments: String?
        let approverName: String?
        let decidedAt: Date
    }

    func getForms(status: String? = nil, limit: Int = 50, offset: Int = 0) async throws -> FormsListResponse {
        var endpoint = "/forms?limit=\(limit)&offset=\(offset)"
        if let status = status {
            endpoint += "&status=\(status)"
        }
        return try await request(endpoint: endpoint)
    }

    func getForm(id: String) async throws -> FormDetailResponse {
        return try await request(endpoint: "/forms/\(id)")
    }

    func createForm(_ form: CreateFormRequest) async throws -> FormResponse {
        struct CreateResponse: Decodable { let form: FormResponse }
        let response: CreateResponse = try await request(endpoint: "/forms", method: .post, body: form)
        return response.form
    }

    func updateForm(id: String, fields: [FormFieldData]) async throws -> FormResponse {
        struct UpdateRequest: Encodable { let fields: [FormFieldData] }
        struct UpdateResponse: Decodable { let form: FormResponse }
        let response: UpdateResponse = try await request(
            endpoint: "/forms/\(id)",
            method: .put,
            body: UpdateRequest(fields: fields)
        )
        return response.form
    }

    func submitForm(id: String) async throws -> FormResponse {
        struct SubmitResponse: Decodable { let form: FormResponse }
        let response: SubmitResponse = try await request(endpoint: "/forms/\(id)/submit", method: .post)
        return response.form
    }

    func deleteForm(id: String) async throws {
        let _: EmptyResponse = try await request(endpoint: "/forms/\(id)", method: .delete)
    }
}

// MARK: - Signatures API

extension APIService {
    struct AddSignatureRequest: Encodable {
        let signerName: String
        let signerEmail: String
        let signerRole: String?
        let signatureType: String
        let signatureData: String
        let consentGiven: Bool
        let consentText: String?
        let witnessName: String?
        let witnessEmail: String?
        let deviceId: String?
        let latitude: Double?
        let longitude: Double?
    }

    struct AddSignatureResponse: Decodable {
        let signature: SignatureResponse
        let legalNotice: String?
        let documentHash: String
    }

    func addSignature(formId: String, signature: AddSignatureRequest) async throws -> AddSignatureResponse {
        return try await request(
            endpoint: "/forms/\(formId)/signatures",
            method: .post,
            body: signature
        )
    }

    func getSignatureCertificate(formId: String) async throws -> SignatureCertificate {
        return try await request(endpoint: "/forms/\(formId)/signature-certificate")
    }

    struct SignatureCertificate: Decodable {
        let document: DocumentInfo
        let signatures: [SignatureInfo]
        let verification: VerificationInfo

        struct DocumentInfo: Decodable {
            let id: String
            let title: String
            let createdAt: Date
            let status: String
        }

        struct SignatureInfo: Decodable {
            let signerName: String
            let signerEmail: String?
            let signerRole: String?
            let signedAt: Date
            let documentHash: String?
            let consentGiven: Bool?
        }

        struct VerificationInfo: Decodable {
            let generatedAt: String
            let legalFramework: String
            let verificationStatement: String
        }
    }
}

// MARK: - Templates API

extension APIService {
    struct TemplatesListResponse: Decodable {
        let templates: [TemplateResponse]
        let pagination: Pagination

        struct Pagination: Decodable {
            let page: Int
            let limit: Int
            let total: Int
            let pages: Int
        }
    }

    struct TemplateResponse: Decodable {
        let id: String
        let name: String
        let description: String?
        let category: String?
        let fields: [FormFieldData]
        let isPublic: Bool
        let version: Int
        let createdAt: Date
        let createdByName: String?
    }

    func getTemplates(category: String? = nil, page: Int = 1) async throws -> TemplatesListResponse {
        var endpoint = "/templates?page=\(page)"
        if let category = category {
            endpoint += "&category=\(category)"
        }
        return try await request(endpoint: endpoint)
    }

    func getTemplate(id: String) async throws -> TemplateResponse {
        return try await request(endpoint: "/templates/\(id)")
    }

    func duplicateTemplate(id: String) async throws -> TemplateResponse {
        return try await request(endpoint: "/templates/\(id)/duplicate", method: .post)
    }
}

// MARK: - User API

extension APIService {
    struct ProfileResponse: Decodable {
        let id: String
        let email: String
        let name: String
        let role: String
        let organizationId: String?
        let organizationName: String?
    }

    struct NotificationsResponse: Decodable {
        let notifications: [NotificationItem]
        let unreadCount: Int
    }

    struct NotificationItem: Decodable, Identifiable {
        let id: String
        let type: String
        let title: String
        let message: String?
        let readAt: Date?
        let createdAt: Date
    }

    func getProfile() async throws -> ProfileResponse {
        return try await request(endpoint: "/users/me")
    }

    func getNotifications(unreadOnly: Bool = false) async throws -> NotificationsResponse {
        return try await request(endpoint: "/users/me/notifications?unreadOnly=\(unreadOnly)")
    }

    func markNotificationRead(id: String) async throws {
        let _: EmptyResponse = try await request(
            endpoint: "/users/me/notifications/\(id)/read",
            method: .put
        )
    }
}

// MARK: - Empty Response

struct EmptyResponse: Decodable {
    let message: String?

    init(from decoder: Decoder) throws {
        let container = try? decoder.container(keyedBy: CodingKeys.self)
        message = try? container?.decode(String.self, forKey: .message)
    }

    enum CodingKeys: String, CodingKey {
        case message
    }
}
