/**
 * FormVersionManager.swift
 * Form Version Control & History
 *
 * Features:
 * - Version history tracking
 * - Form snapshots
 * - Rollback capability
 * - Change comparison
 * - Audit trail
 */

import Foundation
import CoreData

// MARK: - Form Version Model

struct FormVersion: Codable, Identifiable {
    let id: UUID
    let formId: UUID
    let versionNumber: Int
    let title: String
    let fields: [FormFieldData]
    let createdAt: Date
    let createdBy: String
    let changeDescription: String?
    let snapshotData: Data
    
    init(id: UUID = UUID(), formId: UUID, versionNumber: Int, title: String, fields: [FormFieldData], createdBy: String, changeDescription: String? = nil) {
        self.id = id
        self.formId = formId
        self.versionNumber = versionNumber
        self.title = title
        self.fields = fields
        self.createdAt = Date()
        self.createdBy = createdBy
        self.changeDescription = changeDescription
        self.snapshotData = (try? JSONEncoder().encode(fields)) ?? Data()
    }
}

// MARK: - Version Manager

class FormVersionManager: ObservableObject {
    static let shared = FormVersionManager()
    
    @Published var versions: [UUID: [FormVersion]] = [:]
    
    private let userDefaultsKey = "FormVersionHistory"
    private let maxVersionsPerForm = 50
    
    private init() {
        loadVersionHistory()
    }
    
    // MARK: - Version Operations
    
    func createVersion(for form: LocalForm, changeDescription: String? = nil) -> FormVersion {
        let formId = form.id ?? UUID()
        let existingVersions = versions[formId] ?? []
        let versionNumber = existingVersions.count + 1
        
        let version = FormVersion(
            formId: formId,
            versionNumber: versionNumber,
            title: form.title ?? "Untitled Form",
            fields: form.fields,
            createdBy: "Current User", // Get from AuthManager
            changeDescription: changeDescription
        )
        
        var updatedVersions = existingVersions
        updatedVersions.append(version)
        
        // Keep only the latest N versions
        if updatedVersions.count > maxVersionsPerForm {
            updatedVersions.removeFirst(updatedVersions.count - maxVersionsPerForm)
        }
        
        versions[formId] = updatedVersions
        saveVersionHistory()
        
        return version
    }
    
    func getVersions(for formId: UUID) -> [FormVersion] {
        return versions[formId]?.sorted(by: { $0.versionNumber > $1.versionNumber }) ?? []
    }
    
    func getVersion(id: UUID, for formId: UUID) -> FormVersion? {
        return versions[formId]?.first(where: { $0.id == id })
    }
    
    func getLatestVersion(for formId: UUID) -> FormVersion? {
        return versions[formId]?.max(by: { $0.versionNumber < $1.versionNumber })
    }
    
    func rollback(to version: FormVersion, form: LocalForm) {
        form.title = version.title
        form.fields = version.fields
        form.updatedAt = Date()
        
        DataController.shared.save()
        
        // Create a new version to track the rollback
        createVersion(for: form, changeDescription: "Rolled back to version \(version.versionNumber)")
    }
    
    func compareVersions(_ version1: FormVersion, _ version2: FormVersion) -> VersionComparison {
        return VersionComparison(oldVersion: version1, newVersion: version2)
    }
    
    func deleteVersionHistory(for formId: UUID) {
        versions.removeValue(forKey: formId)
        saveVersionHistory()
    }
    
    // MARK: - Persistence
    
    private func saveVersionHistory() {
        do {
            let data = try JSONEncoder().encode(versions)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("Failed to save version history: \(error)")
        }
    }
    
    private func loadVersionHistory() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return
        }
        
        do {
            versions = try JSONDecoder().decode([UUID: [FormVersion]].self, from: data)
        } catch {
            print("Failed to load version history: \(error)")
        }
    }
}

// MARK: - Version Comparison

struct VersionComparison {
    let oldVersion: FormVersion
    let newVersion: FormVersion
    let changes: [FieldChange]
    
    init(oldVersion: FormVersion, newVersion: FormVersion) {
        self.oldVersion = oldVersion
        self.newVersion = newVersion
        self.changes = VersionComparison.calculateChanges(
            oldFields: oldVersion.fields,
            newFields: newVersion.fields
        )
    }
    
    private static func calculateChanges(oldFields: [FormFieldData], newFields: [FormFieldData]) -> [FieldChange] {
        var changes: [FieldChange] = []
        
        let oldFieldsDict = Dictionary(uniqueKeysWithValues: oldFields.map { ($0.id, $0) })
        let newFieldsDict = Dictionary(uniqueKeysWithValues: newFields.map { ($0.id, $0) })
        
        // Find added fields
        for field in newFields {
            if oldFieldsDict[field.id] == nil {
                changes.append(FieldChange(type: .added, field: field))
            }
        }
        
        // Find removed fields
        for field in oldFields {
            if newFieldsDict[field.id] == nil {
                changes.append(FieldChange(type: .removed, field: field))
            }
        }
        
        // Find modified fields
        for field in newFields {
            if let oldField = oldFieldsDict[field.id] {
                if field.label != oldField.label ||
                   field.type != oldField.type ||
                   field.required != oldField.required ||
                   field.options != oldField.options {
                    changes.append(FieldChange(type: .modified, field: field, oldField: oldField))
                }
            }
        }
        
        return changes.sorted { $0.field.order < $1.field.order }
    }
    
    var hasChanges: Bool {
        !changes.isEmpty
    }
    
    var addedFieldsCount: Int {
        changes.filter { $0.type == .added }.count
    }
    
    var removedFieldsCount: Int {
        changes.filter { $0.type == .removed }.count
    }
    
    var modifiedFieldsCount: Int {
        changes.filter { $0.type == .modified }.count
    }
}

// MARK: - Field Change

struct FieldChange: Identifiable {
    enum ChangeType {
        case added
        case removed
        case modified
    }
    
    let id = UUID()
    let type: ChangeType
    let field: FormFieldData
    let oldField: FormFieldData?
    
    init(type: ChangeType, field: FormFieldData, oldField: FormFieldData? = nil) {
        self.type = type
        self.field = field
        self.oldField = oldField
    }
    
    var description: String {
        switch type {
        case .added:
            return "Added field: \(field.label)"
        case .removed:
            return "Removed field: \(field.label)"
        case .modified:
            return "Modified field: \(field.label)"
        }
    }
}

// MARK: - SwiftUI View for Version History

import SwiftUI

struct FormVersionHistoryView: View {
    let form: LocalForm
    @StateObject private var versionManager = FormVersionManager.shared
    @State private var selectedVersion: FormVersion?
    @State private var showingComparison = false
    @State private var showingRollbackConfirmation = false
    
    private var formId: UUID {
        form.id ?? UUID()
    }
    
    private var versions: [FormVersion] {
        versionManager.getVersions(for: formId)
    }
    
    var body: some View {
        List {
            if versions.isEmpty {
                ContentUnavailableView {
                    Label("No Version History", systemImage: "clock.arrow.circlepath")
                } description: {
                    Text("Version history will appear here as you make changes to this form")
                }
            } else {
                ForEach(versions) { version in
                    VersionRow(version: version, isLatest: version == versions.first)
                        .onTapGesture {
                            selectedVersion = version
                        }
                        .contextMenu {
                            Button {
                                selectedVersion = version
                                showingRollbackConfirmation = true
                            } label: {
                                Label("Rollback to this version", systemImage: "clock.arrow.counterclockwise")
                            }
                            
                            if let latestVersion = versions.first, version != latestVersion {
                                Button {
                                    selectedVersion = version
                                    showingComparison = true
                                } label: {
                                    Label("Compare with latest", systemImage: "arrow.left.arrow.right")
                                }
                            }
                        }
                }
            }
        }
        .navigationTitle("Version History")
        .sheet(item: $selectedVersion) { version in
            NavigationStack {
                VersionDetailView(version: version, form: form)
            }
        }
        .alert("Rollback to Version \(selectedVersion?.versionNumber ?? 0)?", isPresented: $showingRollbackConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Rollback", role: .destructive) {
                if let version = selectedVersion {
                    rollback(to: version)
                }
            }
        } message: {
            Text("This will restore the form to this version. A new version will be created to track this change.")
        }
    }
    
    private func rollback(to version: FormVersion) {
        versionManager.rollback(to: version, form: form)
    }
}

struct VersionRow: View {
    let version: FormVersion
    let isLatest: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Version \(version.versionNumber)")
                    .font(.headline)
                
                if isLatest {
                    Text("Current")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                Spacer()
                
                Text(version.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let changeDescription = version.changeDescription {
                Text(changeDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Label("\(version.fields.count) fields", systemImage: "list.bullet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("•")
                    .foregroundColor(.secondary)
                
                Text(version.createdAt, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct VersionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let version: FormVersion
    let form: LocalForm
    @StateObject private var versionManager = FormVersionManager.shared
    
    var body: some View {
        List {
            Section("Version Information") {
                LabeledContent("Version Number", value: "\(version.versionNumber)")
                LabeledContent("Created", value: version.createdAt.formatted(date: .long, time: .shortened))
                LabeledContent("Created By", value: version.createdBy)
                LabeledContent("Fields", value: "\(version.fields.count)")
                
                if let changeDescription = version.changeDescription {
                    LabeledContent("Changes") {
                        Text(changeDescription)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section("Fields") {
                ForEach(version.fields.sorted(by: { $0.order < $1.order })) { field in
                    HStack {
                        Image(systemName: FieldType(rawValue: field.type)?.icon ?? "questionmark")
                            .foregroundColor(.accentColor)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading) {
                            Text(field.label)
                                .font(.subheadline)
                            Text(FieldType(rawValue: field.type)?.displayName ?? field.type)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if field.required {
                            Text("Required")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
        }
        .navigationTitle(version.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button("Rollback") {
                    versionManager.rollback(to: version, form: form)
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        FormVersionHistoryView(form: LocalForm())
    }
}
