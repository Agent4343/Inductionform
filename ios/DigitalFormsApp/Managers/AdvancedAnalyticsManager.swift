/**
 * AdvancedAnalyticsManager.swift
 * Enhanced Analytics and Reporting
 *
 * Features:
 * - Average completion time tracking
 * - Incomplete form tracking
 * - Signature collection reports
 * - Activity trends
 * - Field-level analytics
 * - Performance metrics
 */

import Foundation
import Combine

// MARK: - Analytics Models

struct FormAnalytics: Codable {
    var formId: UUID
    var formTitle: String
    var startedAt: Date?
    var completedAt: Date?
    var completionTime: TimeInterval?
    var fieldInteractions: [FieldInteraction]
    var status: FormCompletionStatus
    var lastModified: Date
    
    enum FormCompletionStatus: String, Codable {
        case notStarted = "not_started"
        case inProgress = "in_progress"
        case completed = "completed"
        case abandoned = "abandoned"
    }
}

struct FieldInteraction: Codable, Identifiable {
    let id: UUID
    let fieldId: String
    let fieldLabel: String
    let interactedAt: Date
    var timeSpent: TimeInterval
    var valueChanged: Bool
    
    init(fieldId: String, fieldLabel: String) {
        self.id = UUID()
        self.fieldId = fieldId
        self.fieldLabel = fieldLabel
        self.interactedAt = Date()
        self.timeSpent = 0
        self.valueChanged = false
    }
}

struct SignatureAnalytics: Codable {
    var formId: UUID
    var signatureId: UUID
    var signerName: String
    var signatureType: String
    var capturedAt: Date
    var timeToSign: TimeInterval
    var deviceType: String
    var location: (latitude: Double, longitude: Double)?
}

struct ActivityTrend: Identifiable {
    let id = UUID()
    let date: Date
    let formsCreated: Int
    let formsCompleted: Int
    let formsAbandoned: Int
    let averageCompletionTime: TimeInterval
}

// MARK: - Advanced Analytics Manager

class AdvancedAnalyticsManager: ObservableObject {
    static let shared = AdvancedAnalyticsManager()
    
    @Published var formAnalytics: [UUID: FormAnalytics] = [:]
    @Published var signatureAnalytics: [SignatureAnalytics] = []
    @Published var activityTrends: [ActivityTrend] = []
    
    private let analyticsKey = "FormAnalytics"
    private let signatureAnalyticsKey = "SignatureAnalytics"
    
    private init() {
        loadAnalytics()
    }
    
    // MARK: - Form Analytics
    
    func startFormSession(form: LocalForm) {
        let formId = form.id ?? UUID()
        
        var analytics = formAnalytics[formId] ?? FormAnalytics(
            formId: formId,
            formTitle: form.title ?? "Untitled",
            fieldInteractions: [],
            status: .notStarted,
            lastModified: Date()
        )
        
        if analytics.startedAt == nil {
            analytics.startedAt = Date()
            analytics.status = .inProgress
        }
        
        formAnalytics[formId] = analytics
        saveAnalytics()
    }
    
    func trackFieldInteraction(formId: UUID, fieldId: String, fieldLabel: String, valueChanged: Bool = false) {
        guard var analytics = formAnalytics[formId] else { return }
        
        // Find existing interaction or create new
        if let index = analytics.fieldInteractions.firstIndex(where: { $0.fieldId == fieldId }) {
            analytics.fieldInteractions[index].timeSpent += Date().timeIntervalSince(analytics.fieldInteractions[index].interactedAt)
            analytics.fieldInteractions[index].valueChanged = valueChanged || analytics.fieldInteractions[index].valueChanged
        } else {
            var interaction = FieldInteraction(fieldId: fieldId, fieldLabel: fieldLabel)
            interaction.valueChanged = valueChanged
            analytics.fieldInteractions.append(interaction)
        }
        
        analytics.lastModified = Date()
        formAnalytics[formId] = analytics
        saveAnalytics()
    }
    
    func completeForm(form: LocalForm) {
        let formId = form.id ?? UUID()
        guard var analytics = formAnalytics[formId] else { return }
        
        analytics.completedAt = Date()
        analytics.status = .completed
        
        if let startedAt = analytics.startedAt {
            analytics.completionTime = Date().timeIntervalSince(startedAt)
        }
        
        formAnalytics[formId] = analytics
        saveAnalytics()
        updateActivityTrends()
    }
    
    func abandonForm(formId: UUID) {
        guard var analytics = formAnalytics[formId] else { return }
        
        analytics.status = .abandoned
        analytics.lastModified = Date()
        
        formAnalytics[formId] = analytics
        saveAnalytics()
        updateActivityTrends()
    }
    
    // MARK: - Signature Analytics
    
    func trackSignature(_ signature: LegalSignature, formId: UUID, timeToSign: TimeInterval) {
        let analytics = SignatureAnalytics(
            formId: formId,
            signatureId: signature.id,
            signerName: signature.signerName,
            signatureType: signature.signatureType.rawValue,
            capturedAt: signature.signedAt,
            timeToSign: timeToSign,
            deviceType: UIDevice.current.model,
            location: signature.latitude != nil && signature.longitude != nil
                ? (signature.latitude!, signature.longitude!)
                : nil
        )
        
        signatureAnalytics.append(analytics)
        saveSignatureAnalytics()
    }
    
    // MARK: - Reports
    
    func getCompletionTimeReport() -> CompletionTimeReport {
        let completedForms = formAnalytics.values.filter { $0.status == .completed }
        let completionTimes = completedForms.compactMap { $0.completionTime }
        
        guard !completionTimes.isEmpty else {
            return CompletionTimeReport(
                averageTime: 0,
                medianTime: 0,
                minTime: 0,
                maxTime: 0,
                totalCompleted: 0
            )
        }
        
        let average = completionTimes.reduce(0, +) / Double(completionTimes.count)
        let sorted = completionTimes.sorted()
        let median = sorted.count % 2 == 0
            ? (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2
            : sorted[sorted.count / 2]
        
        return CompletionTimeReport(
            averageTime: average,
            medianTime: median,
            minTime: sorted.first ?? 0,
            maxTime: sorted.last ?? 0,
            totalCompleted: completedForms.count
        )
    }
    
    func getIncompleteForms() -> [IncompleteFormInfo] {
        let incompleteForms = formAnalytics.values.filter {
            $0.status == .inProgress || $0.status == .abandoned
        }
        
        return incompleteForms.map { analytics in
            let progress = calculateProgress(analytics)
            let timeSpent = analytics.fieldInteractions.reduce(0) { $0 + $1.timeSpent }
            
            return IncompleteFormInfo(
                formId: analytics.formId,
                formTitle: analytics.formTitle,
                status: analytics.status,
                progress: progress,
                lastModified: analytics.lastModified,
                timeSpent: timeSpent,
                fieldsCompleted: analytics.fieldInteractions.filter { $0.valueChanged }.count
            )
        }.sorted { $0.lastModified > $1.lastModified }
    }
    
    func getSignatureReport() -> SignatureReport {
        let totalSignatures = signatureAnalytics.count
        
        let byType = Dictionary(grouping: signatureAnalytics, by: { $0.signatureType })
            .mapValues { $0.count }
        
        let avgTimeToSign = signatureAnalytics.isEmpty
            ? 0
            : signatureAnalytics.reduce(0) { $0 + $1.timeToSign } / Double(signatureAnalytics.count)
        
        let recentSignatures = signatureAnalytics
            .sorted { $0.capturedAt > $1.capturedAt }
            .prefix(10)
            .map { RecentSignatureInfo(
                signerName: $0.signerName,
                signatureType: $0.signatureType,
                capturedAt: $0.capturedAt
            )}
        
        return SignatureReport(
            totalSignatures: totalSignatures,
            signaturesByType: byType,
            averageTimeToSign: avgTimeToSign,
            recentSignatures: Array(recentSignatures)
        )
    }
    
    func getFieldAnalytics(formId: UUID) -> [FieldAnalytic] {
        guard let analytics = formAnalytics[formId] else { return [] }
        
        return analytics.fieldInteractions.map { interaction in
            FieldAnalytic(
                fieldLabel: interaction.fieldLabel,
                interactionCount: 1, // Would need to track this better
                averageTimeSpent: interaction.timeSpent,
                completionRate: interaction.valueChanged ? 1.0 : 0.0
            )
        }
    }
    
    // MARK: - Activity Trends
    
    private func updateActivityTrends() {
        let calendar = Calendar.current
        let now = Date()
        let last30Days = calendar.date(byAdding: .day, value: -30, to: now)!
        
        let relevantAnalytics = formAnalytics.values.filter { analytics in
            analytics.lastModified >= last30Days
        }
        
        let groupedByDate = Dictionary(grouping: relevantAnalytics) { analytics in
            calendar.startOfDay(for: analytics.lastModified)
        }
        
        activityTrends = groupedByDate.map { date, analytics in
            let created = analytics.filter { $0.startedAt != nil }.count
            let completed = analytics.filter { $0.status == .completed }.count
            let abandoned = analytics.filter { $0.status == .abandoned }.count
            
            let completionTimes = analytics.compactMap { $0.completionTime }
            let avgTime = completionTimes.isEmpty ? 0 : completionTimes.reduce(0, +) / Double(completionTimes.count)
            
            return ActivityTrend(
                date: date,
                formsCreated: created,
                formsCompleted: completed,
                formsAbandoned: abandoned,
                averageCompletionTime: avgTime
            )
        }.sorted { $0.date < $1.date }
    }
    
    // MARK: - Helper Methods
    
    private func calculateProgress(_ analytics: FormAnalytics) -> Double {
        // Calculate based on fields with values vs total fields
        let fieldsWithValues = analytics.fieldInteractions.filter { $0.valueChanged }.count
        let totalFields = analytics.fieldInteractions.count
        
        guard totalFields > 0 else { return 0 }
        return Double(fieldsWithValues) / Double(totalFields)
    }
    
    // MARK: - Persistence
    
    private func saveAnalytics() {
        if let data = try? JSONEncoder().encode(formAnalytics) {
            UserDefaults.standard.set(data, forKey: analyticsKey)
        }
    }
    
    private func loadAnalytics() {
        if let data = UserDefaults.standard.data(forKey: analyticsKey),
           let analytics = try? JSONDecoder().decode([UUID: FormAnalytics].self, from: data) {
            formAnalytics = analytics
        }
    }
    
    private func saveSignatureAnalytics() {
        if let data = try? JSONEncoder().encode(signatureAnalytics) {
            UserDefaults.standard.set(data, forKey: signatureAnalyticsKey)
        }
    }
    
    private func loadSignatureAnalytics() {
        if let data = UserDefaults.standard.data(forKey: signatureAnalyticsKey),
           let analytics = try? JSONDecoder().decode([SignatureAnalytics].self, from: data) {
            signatureAnalytics = analytics
        }
    }
}

// MARK: - Report Models

struct CompletionTimeReport {
    let averageTime: TimeInterval
    let medianTime: TimeInterval
    let minTime: TimeInterval
    let maxTime: TimeInterval
    let totalCompleted: Int
    
    var averageTimeFormatted: String {
        formatTime(averageTime)
    }
    
    var medianTimeFormatted: String {
        formatTime(medianTime)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct IncompleteFormInfo: Identifiable {
    let id = UUID()
    let formId: UUID
    let formTitle: String
    let status: FormAnalytics.FormCompletionStatus
    let progress: Double
    let lastModified: Date
    let timeSpent: TimeInterval
    let fieldsCompleted: Int
}

struct SignatureReport {
    let totalSignatures: Int
    let signaturesByType: [String: Int]
    let averageTimeToSign: TimeInterval
    let recentSignatures: [RecentSignatureInfo]
}

struct RecentSignatureInfo: Identifiable {
    let id = UUID()
    let signerName: String
    let signatureType: String
    let capturedAt: Date
}

struct FieldAnalytic: Identifiable {
    let id = UUID()
    let fieldLabel: String
    let interactionCount: Int
    let averageTimeSpent: TimeInterval
    let completionRate: Double
}
