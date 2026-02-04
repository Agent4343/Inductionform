/**
 * FormEditorView.swift
 * Form Editing & Field Input
 */

import SwiftUI
import PhotosUI
import CoreLocation

struct FormEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataController: DataController
    @EnvironmentObject var syncManager: SyncManager

    let form: LocalForm?

    @State private var title: String = ""
    @State private var fields: [FormFieldData] = []
    @State private var isEditing = false
    @State private var showingSignature = false
    @State private var showingSubmitConfirm = false
    @State private var showingExport = false
    @State private var isSaving = false

    @StateObject private var locationManager = LocationManager()
    @StateObject private var autoSave = AutoSaveManager()

    private var isNewForm: Bool { form == nil }
    private var canEdit: Bool { form?.statusEnum == .draft || isNewForm }

    var body: some View {
        NavigationStack {
            Form {
                // Title Section
                Section("Form Details") {
                    TextField("Form Title", text: $title)
                        .font(.headline)
                }

                // Fields Section
                Section("Fields") {
                    if fields.isEmpty {
                        Text("No fields yet")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach($fields) { $field in
                            FormFieldView(field: $field, isEditing: canEdit)
                        }
                        .onMove(perform: canEdit ? moveFields : nil)
                    }

                    if canEdit {
                        Menu {
                            ForEach(FieldType.allCases, id: \.self) { type in
                                Button {
                                    addField(type: type)
                                } label: {
                                    Label(type.displayName, systemImage: type.icon)
                                }
                            }
                        } label: {
                            Label("Add Field", systemImage: "plus.circle.fill")
                        }
                    }
                }

                // Location Section
                if let location = locationManager.location {
                    Section("Location") {
                        LabeledContent("Coordinates") {
                            Text(String(format: "%.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude))
                                .font(.caption)
                        }
                    }
                }

                // Signature Section (for submitted forms)
                if !isNewForm && form?.statusEnum != .draft {
                    Section("Signatures") {
                        Button {
                            showingSignature = true
                        } label: {
                            Label("View/Add Signatures", systemImage: "signature")
                        }
                    }
                }
            }
            .navigationTitle(isNewForm ? "New Form" : (form?.title ?? "Form"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        if canEdit {
                            Button {
                                saveForm()
                            } label: {
                                Label("Save Draft", systemImage: "square.and.arrow.down")
                            }

                            Button {
                                showingSubmitConfirm = true
                            } label: {
                                Label("Submit", systemImage: "paperplane")
                            }
                        }

                        Button {
                            showingExport = true
                        } label: {
                            Label("Export PDF", systemImage: "doc.richtext")
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            .onAppear {
                loadForm()
                locationManager.requestLocation()
                if canEdit {
                    autoSave.startAutoSave { saveForm() }
                }
            }
            .onDisappear {
                autoSave.stopAutoSave()
            }
            .sheet(isPresented: $showingSignature) {
                if let form = form {
                    LegalSignatureSheet(form: form)
                }
            }
            .sheet(isPresented: $showingExport) {
                PDFExportView(title: title, fields: fields)
            }
            .alert("Submit Form", isPresented: $showingSubmitConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Submit") { submitForm() }
            } message: {
                Text("Are you sure you want to submit this form? You won't be able to edit it after submission.")
            }
        }
    }

    // MARK: - Actions

    private func loadForm() {
        if let form = form {
            title = form.title ?? ""
            fields = form.fields
        } else {
            title = "New Form"
            fields = []
        }
    }

    private func saveForm() {
        isSaving = true

        if let existingForm = form {
            existingForm.title = title
            dataController.updateForm(existingForm, fields: fields)
        } else {
            _ = dataController.createForm(title: title, fields: fields)
        }

        isSaving = false
    }

    private func submitForm() {
        guard let form = form else { return }

        saveForm()
        form.status = FormStatus.submitted.rawValue
        form.updatedAt = Date()
        dataController.save()

        Task {
            try? await syncManager.syncForm(form)
        }

        dismiss()
    }

    private func addField(type: FieldType) {
        let field = FormFieldData(
            id: UUID().uuidString,
            type: type.rawValue,
            label: type.displayName,
            required: false,
            order: fields.count
        )
        fields.append(field)
    }

    private func moveFields(from source: IndexSet, to destination: Int) {
        fields.move(fromOffsets: source, toOffset: destination)
        // Update order
        for (index, _) in fields.enumerated() {
            fields[index].order = index
        }
    }
}

// MARK: - Form Field View

struct FormFieldView: View {
    @Binding var field: FormFieldData
    let isEditing: Bool

    @State private var showingPhotoPicker = false
    @State private var showingSignature = false
    @State private var selectedPhoto: PhotosPickerItem?

    var fieldType: FieldType {
        FieldType(rawValue: field.type) ?? .text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Label
            HStack {
                Text(field.label)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if field.required {
                    Text("*")
                        .foregroundColor(.red)
                }
            }

            // Input based on type
            fieldInput
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var fieldInput: some View {
        switch fieldType {
        case .text:
            TextField(field.placeholder ?? "Enter text", text: Binding(
                get: { field.value ?? "" },
                set: { field.value = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .disabled(!isEditing)

        case .textarea:
            TextEditor(text: Binding(
                get: { field.value ?? "" },
                set: { field.value = $0 }
            ))
            .frame(height: 100)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
            .disabled(!isEditing)

        case .number:
            TextField(field.placeholder ?? "0", text: Binding(
                get: { field.value ?? "" },
                set: { field.value = $0 }
            ))
            .keyboardType(.decimalPad)
            .textFieldStyle(.roundedBorder)
            .disabled(!isEditing)

        case .email:
            TextField(field.placeholder ?? "email@example.com", text: Binding(
                get: { field.value ?? "" },
                set: { field.value = $0 }
            ))
            .keyboardType(.emailAddress)
            .textContentType(.emailAddress)
            .autocapitalization(.none)
            .textFieldStyle(.roundedBorder)
            .disabled(!isEditing)

        case .phone:
            TextField(field.placeholder ?? "Phone number", text: Binding(
                get: { field.value ?? "" },
                set: { field.value = $0 }
            ))
            .keyboardType(.phonePad)
            .textContentType(.telephoneNumber)
            .textFieldStyle(.roundedBorder)
            .disabled(!isEditing)

        case .date:
            DatePicker(
                "",
                selection: Binding(
                    get: { parseDate(field.value) ?? Date() },
                    set: { field.value = formatDate($0) }
                ),
                displayedComponents: .date
            )
            .labelsHidden()
            .disabled(!isEditing)

        case .time:
            DatePicker(
                "",
                selection: Binding(
                    get: { parseDate(field.value) ?? Date() },
                    set: { field.value = formatTime($0) }
                ),
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .disabled(!isEditing)

        case .checkbox:
            Toggle(isOn: Binding(
                get: { field.value == "true" },
                set: { field.value = $0 ? "true" : "false" }
            )) {
                EmptyView()
            }
            .disabled(!isEditing)

        case .yesNo:
            Picker("", selection: Binding(
                get: { field.value ?? "" },
                set: { field.value = $0 }
            )) {
                Text("Select").tag("")
                Text("Yes").tag("yes")
                Text("No").tag("no")
                Text("N/A").tag("na")
            }
            .pickerStyle(.segmented)
            .disabled(!isEditing)

        case .dropdown:
            Picker("", selection: Binding(
                get: { field.value ?? "" },
                set: { field.value = $0 }
            )) {
                Text("Select...").tag("")
                ForEach(field.options ?? [], id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(.menu)
            .disabled(!isEditing)

        case .rating:
            HStack {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= (Int(field.value ?? "0") ?? 0) ? "star.fill" : "star")
                        .foregroundColor(.yellow)
                        .onTapGesture {
                            if isEditing {
                                field.value = "\(star)"
                            }
                        }
                }
            }

        case .photo:
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                if let value = field.value, !value.isEmpty {
                    Label("Photo attached", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Label("Add Photo", systemImage: "camera")
                }
            }
            .disabled(!isEditing)

        case .signature:
            Button {
                showingSignature = true
            } label: {
                if let value = field.value, !value.isEmpty {
                    Label("Signature captured", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Label("Add Signature", systemImage: "signature")
                }
            }
            .disabled(!isEditing)
            .sheet(isPresented: $showingSignature) {
                QuickSignatureView { signatureData in
                    field.value = signatureData
                }
            }

        case .location:
            LocationFieldView(value: $field.value, isEditing: isEditing)

        case .section:
            Divider()

        default:
            TextField("Enter value", text: Binding(
                get: { field.value ?? "" },
                set: { field.value = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .disabled(!isEditing)
        }
    }

    // MARK: - Helpers

    private func parseDate(_ string: String?) -> Date? {
        guard let string = string else { return nil }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: string)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Location Field

struct LocationFieldView: View {
    @Binding var value: String?
    let isEditing: Bool

    @StateObject private var locationManager = LocationManager()

    var body: some View {
        HStack {
            if let value = value, !value.isEmpty {
                Text(value)
                    .font(.caption)
            } else {
                Text("No location")
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isEditing {
                Button {
                    captureLocation()
                } label: {
                    Image(systemName: "location.fill")
                }
            }
        }
    }

    private func captureLocation() {
        locationManager.requestLocation()
        if let location = locationManager.location {
            value = String(format: "%.6f, %.6f", location.coordinate.latitude, location.coordinate.longitude)
        }
    }
}

// MARK: - Quick Signature View

struct QuickSignatureView: View {
    @Environment(\.dismiss) private var dismiss
    let onSign: (String) -> Void

    @State private var canvasView = PKCanvasView()

    var body: some View {
        NavigationStack {
            VStack {
                SignatureCanvasView(canvasView: $canvasView)
                    .frame(height: 200)
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.3)))
                    .padding()

                Button("Clear") {
                    canvasView.drawing = PKDrawing()
                }

                Spacer()
            }
            .navigationTitle("Sign")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let image = canvasView.drawing.image(from: canvasView.drawing.bounds, scale: 2.0)
                        if let data = image.pngData() {
                            onSign("data:image/png;base64," + data.base64EncodedString())
                        }
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Location Manager

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var location: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocation() {
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.first
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
    }
}

// MARK: - Legal Signature Sheet

struct LegalSignatureSheet: View {
    @Environment(\.dismiss) private var dismiss
    let form: LocalForm

    var body: some View {
        LegalSignatureView(
            formId: form.id ?? UUID(),
            formTitle: form.title ?? "Form",
            formFields: [],
            formCreatedAt: form.createdAt ?? Date()
        ) { signature in
            // Handle signature
            Task {
                try? await submitSignature(signature)
            }
            dismiss()
        }
    }

    private func submitSignature(_ signature: LegalSignature) async throws {
        guard let formId = form.remoteId else { return }

        let request = APIService.AddSignatureRequest(
            signerName: signature.signerName,
            signerEmail: signature.signerEmail,
            signerRole: signature.signerRole,
            signatureType: signature.signatureType.rawValue,
            signatureData: signature.signatureData,
            consentGiven: signature.consentGiven,
            consentText: signature.consentText,
            witnessName: signature.witnessName,
            witnessEmail: signature.witnessEmail,
            deviceId: signature.deviceId,
            latitude: signature.latitude,
            longitude: signature.longitude
        )

        _ = try await APIService.shared.addSignature(formId: formId, signature: request)
    }
}

import PencilKit

#Preview {
    FormEditorView(form: nil)
        .environmentObject(DataController.shared)
        .environmentObject(SyncManager.shared)
}
