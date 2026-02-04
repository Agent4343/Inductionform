/**
 * SyncManager.swift
 * Offline-First Sync Management
 *
 * Handles data synchronization between local storage and Railway backend
 */

import Foundation
import Network
import Combine

class SyncManager: ObservableObject {
    static let shared = SyncManager()

    @Published var isOnline = true
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var pendingSyncCount = 0

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "SyncManager")
    private var cancellables = Set<AnyCancellable>()

    private let dataController = DataController.shared
    private let api = APIService.shared

    private init() {
        setupNetworkMonitor()
        loadLastSyncDate()
    }

    // MARK: - Network Monitoring

    private func setupNetworkMonitor() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasOffline = !(self?.isOnline ?? true)
                self?.isOnline = path.status == .satisfied

                // Auto-sync when coming back online
                if wasOffline && path.status == .satisfied {
                    Task {
                        await self?.syncAll()
                    }
                }
            }
        }
        monitor.start(queue: queue)
    }

    // MARK: - Sync Operations

    func syncAll() async {
        guard isOnline, !isSyncing else { return }

        await MainActor.run {
            isSyncing = true
        }

        defer {
            Task { @MainActor in
                isSyncing = false
                lastSyncDate = Date()
                saveLastSyncDate()
                updatePendingCount()
            }
        }

        // Upload local changes
        await uploadLocalChanges()

        // Download remote changes
        await downloadRemoteChanges()
    }

    func syncForm(_ form: LocalForm) async throws {
        guard isOnline else {
            form.needsSync = true
            dataController.save()
            updatePendingCount()
            return
        }

        let fields = form.fields.map { field in
            APIService.FormFieldData(
                id: field.id,
                type: field.type,
                label: field.label,
                value: field.value,
                required: field.required,
                options: field.options,
                placeholder: field.placeholder
            )
        }

        if let remoteId = form.remoteId {
            // Update existing
            _ = try await api.updateForm(id: remoteId, fields: fields)
        } else {
            // Create new
            let request = APIService.CreateFormRequest(
                title: form.title ?? "Untitled",
                templateId: form.templateId?.uuidString,
                fields: fields,
                latitude: form.latitude != 0 ? form.latitude : nil,
                longitude: form.longitude != 0 ? form.longitude : nil
            )
            let response = try await api.createForm(request)
            dataController.markFormAsSynced(form, remoteId: response.id)
        }
    }

    // MARK: - Private Sync Methods

    private func uploadLocalChanges() async {
        let unsyncedForms = dataController.getUnsyncedForms()

        for form in unsyncedForms {
            do {
                try await syncForm(form)
            } catch {
                print("Failed to sync form \(form.id?.uuidString ?? "unknown"): \(error)")
            }
        }
    }

    private func downloadRemoteChanges() async {
        do {
            // Fetch templates
            let templatesResponse = try await api.getTemplates()
            for template in templatesResponse.templates {
                dataController.saveTemplate(template)
            }

            // Fetch forms
            let formsResponse = try await api.getForms()
            // Merge with local forms
            for remoteForm in formsResponse.forms {
                await mergeRemoteForm(remoteForm)
            }
        } catch {
            print("Failed to download remote changes: \(error)")
        }
    }

    private func mergeRemoteForm(_ remote: APIService.FormResponse) async {
        let context = dataController.newBackgroundContext()

        await context.perform {
            let request = LocalForm.fetchRequest()
            request.predicate = NSPredicate(format: "remoteId == %@", remote.id)
            request.fetchLimit = 1

            let existing = try? context.fetch(request).first

            let form = existing ?? LocalForm(context: context)
            form.remoteId = remote.id
            form.title = remote.title
            form.status = remote.status
            form.syncedAt = Date()
            form.needsSync = false

            if form.id == nil {
                form.id = UUID()
            }

            if let templateId = remote.templateId {
                form.templateId = UUID(uuidString: templateId)
            }

            // Convert fields
            let fields = remote.fields.map { f in
                FormFieldData(
                    id: f.id,
                    type: f.type,
                    label: f.label,
                    value: f.value,
                    required: f.required ?? false,
                    options: f.options,
                    placeholder: f.placeholder,
                    order: 0
                )
            }
            form.fields = fields

            form.createdAt = remote.createdAt
            form.updatedAt = remote.updatedAt

            if let lat = remote.latitude, let lon = remote.longitude {
                form.latitude = lat
                form.longitude = lon
            }

            try? context.save()
        }
    }

    // MARK: - Persistence

    private func loadLastSyncDate() {
        lastSyncDate = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date
    }

    private func saveLastSyncDate() {
        UserDefaults.standard.set(lastSyncDate, forKey: "lastSyncDate")
    }

    private func updatePendingCount() {
        pendingSyncCount = dataController.getUnsyncedForms().count
    }
}

// MARK: - Auto-Save Manager

class AutoSaveManager: ObservableObject {
    @Published var lastSaveDate: Date?

    private var timer: Timer?
    private let interval: TimeInterval = 30 // 30 seconds

    func startAutoSave(action: @escaping () -> Void) {
        stopAutoSave()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            action()
            self?.lastSaveDate = Date()
        }
    }

    func stopAutoSave() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        stopAutoSave()
    }
}
