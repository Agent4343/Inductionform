/**
 * DataController.swift
 * Core Data Stack & Local Storage
 *
 * Manages local data persistence with Core Data
 */

import Foundation
import CoreData

class DataController: ObservableObject {
    static let shared = DataController()

    let container: NSPersistentContainer

    @Published var savedForms: [LocalForm] = []
    @Published var savedTemplates: [LocalTemplate] = []

    private init() {
        container = NSPersistentContainer(name: "DigitalFormsApp")

        container.loadPersistentStores { description, error in
            if let error = error {
                print("Core Data failed to load: \(error.localizedDescription)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // MARK: - Context Management

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

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

    func newBackgroundContext() -> NSManagedObjectContext {
        container.newBackgroundContext()
    }

    // MARK: - Form Operations

    func createForm(title: String, templateId: UUID? = nil, fields: [FormFieldData]) -> LocalForm {
        let form = LocalForm(context: viewContext)
        form.id = UUID()
        form.title = title
        form.templateId = templateId
        form.status = "draft"
        form.createdAt = Date()
        form.updatedAt = Date()

        // Store fields as JSON
        if let fieldsData = try? JSONEncoder().encode(fields) {
            form.fieldsData = fieldsData
        }

        save()
        return form
    }

    func updateForm(_ form: LocalForm, fields: [FormFieldData]) {
        if let fieldsData = try? JSONEncoder().encode(fields) {
            form.fieldsData = fieldsData
        }
        form.updatedAt = Date()
        save()
    }

    func deleteForm(_ form: LocalForm) {
        viewContext.delete(form)
        save()
    }

    func fetchForms(status: String? = nil) -> [LocalForm] {
        let request = LocalForm.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \LocalForm.updatedAt, ascending: false)]

        if let status = status {
            request.predicate = NSPredicate(format: "status == %@", status)
        }

        do {
            return try viewContext.fetch(request)
        } catch {
            print("Failed to fetch forms: \(error)")
            return []
        }
    }

    func fetchForm(id: UUID) -> LocalForm? {
        let request = LocalForm.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        do {
            return try viewContext.fetch(request).first
        } catch {
            print("Failed to fetch form: \(error)")
            return nil
        }
    }

    // MARK: - Template Operations

    func saveTemplate(_ template: APIService.TemplateResponse) {
        let localTemplate = LocalTemplate(context: viewContext)
        localTemplate.id = UUID(uuidString: template.id) ?? UUID()
        localTemplate.name = template.name
        localTemplate.templateDescription = template.description
        localTemplate.category = template.category

        if let fieldsData = try? JSONEncoder().encode(template.fields) {
            localTemplate.fieldsData = fieldsData
        }

        localTemplate.syncedAt = Date()
        save()
    }

    func fetchTemplates(category: String? = nil) -> [LocalTemplate] {
        let request = LocalTemplate.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \LocalTemplate.name, ascending: true)]

        if let category = category {
            request.predicate = NSPredicate(format: "category == %@", category)
        }

        do {
            return try viewContext.fetch(request)
        } catch {
            print("Failed to fetch templates: \(error)")
            return []
        }
    }

    // MARK: - Sync Status

    func markFormAsSynced(_ form: LocalForm, remoteId: String) {
        form.remoteId = remoteId
        form.syncedAt = Date()
        form.needsSync = false
        save()
    }

    func getUnsyncedForms() -> [LocalForm] {
        let request = LocalForm.fetchRequest()
        request.predicate = NSPredicate(format: "needsSync == YES OR remoteId == nil")

        do {
            return try viewContext.fetch(request)
        } catch {
            print("Failed to fetch unsynced forms: \(error)")
            return []
        }
    }
}

// MARK: - Form Field Data (Codable)

struct FormFieldData: Codable, Identifiable {
    var id: String
    var type: String
    var label: String
    var value: String?
    var required: Bool
    var options: [String]?
    var placeholder: String?
    var order: Int

    init(id: String = UUID().uuidString, type: String, label: String, value: String? = nil, required: Bool = false, options: [String]? = nil, placeholder: String? = nil, order: Int = 0) {
        self.id = id
        self.type = type
        self.label = label
        self.value = value
        self.required = required
        self.options = options
        self.placeholder = placeholder
        self.order = order
    }
}

// MARK: - Core Data Extensions

extension LocalForm {
    var fields: [FormFieldData] {
        get {
            guard let data = fieldsData else { return [] }
            return (try? JSONDecoder().decode([FormFieldData].self, from: data)) ?? []
        }
        set {
            fieldsData = try? JSONEncoder().encode(newValue)
        }
    }

    var statusEnum: FormStatus {
        get { FormStatus(rawValue: status ?? "draft") ?? .draft }
        set { status = newValue.rawValue }
    }
}

extension LocalTemplate {
    var fields: [FormFieldData] {
        get {
            guard let data = fieldsData else { return [] }
            return (try? JSONDecoder().decode([FormFieldData].self, from: data)) ?? []
        }
        set {
            fieldsData = try? JSONEncoder().encode(newValue)
        }
    }
}

enum FormStatus: String, CaseIterable {
    case draft = "draft"
    case submitted = "submitted"
    case approved = "approved"
    case rejected = "rejected"

    var displayName: String {
        switch self {
        case .draft: return "Draft"
        case .submitted: return "Submitted"
        case .approved: return "Approved"
        case .rejected: return "Rejected"
        }
    }

    var color: String {
        switch self {
        case .draft: return "gray"
        case .submitted: return "blue"
        case .approved: return "green"
        case .rejected: return "red"
        }
    }
}
