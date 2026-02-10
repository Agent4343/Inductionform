/**
 * FormBuilderView.swift
 * Enhanced Form Builder with Presets and Duplication
 *
 * Features:
 * - Field template presets
 * - Drag-and-drop reordering
 * - Field/section duplication
 * - Real-time preview
 * - Advanced field configuration
 */

import SwiftUI

struct FormBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataController: DataController
    
    @State private var formTitle: String = ""
    @State private var formDescription: String = ""
    @State private var fields: [FormFieldData] = []
    @State private var selectedFieldIndex: Int?
    @State private var showingFieldPresets = false
    @State private var showingFieldTypes = false
    @State private var showingPreview = false
    @State private var editingField: FormFieldData?
    
    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                // Left Panel: Builder
                builderPanel
                    .frame(maxWidth: showingPreview ? .infinity : nil)
                
                // Right Panel: Preview
                if showingPreview {
                    Divider()
                    previewPanel
                        .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Form Builder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("Save Form") {
                        saveTemplate()
                    }
                    .disabled(formTitle.isEmpty || fields.isEmpty)
                    .fontWeight(.semibold)
                }
                
                ToolbarItem(placement: .automatic) {
                    Button {
                        showingPreview.toggle()
                    } label: {
                        Label("Preview", systemImage: showingPreview ? "eye.slash" : "eye")
                    }
                }
            }
            .sheet(isPresented: $showingFieldPresets) {
                FieldPresetsSheet { preset in
                    insertPreset(preset)
                }
            }
            .sheet(isPresented: $showingFieldTypes) {
                FieldTypesSheet { fieldType in
                    addField(type: fieldType)
                }
            }
            .sheet(item: $editingField) { field in
                FieldConfigurationView(field: binding(for: field))
            }
        }
    }
    
    // MARK: - Builder Panel
    
    private var builderPanel: some View {
        Form {
            Section("Form Information") {
                TextField("Form Title", text: $formTitle)
                    .font(.headline)
                
                TextField("Description (Optional)", text: $formDescription, axis: .vertical)
                    .lineLimit(3...6)
            }
            
            Section {
                if fields.isEmpty {
                    ContentUnavailableView {
                        Label("No Fields Yet", systemImage: "square.stack.3d.up.slash")
                    } description: {
                        Text("Add fields or field presets to build your form")
                    } actions: {
                        Button {
                            showingFieldPresets = true
                        } label: {
                            Label("Browse Presets", systemImage: "rectangle.stack.badge.plus")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    ForEach(fields.indices, id: \.self) { index in
                        FieldBuilderRow(
                            field: $fields[index],
                            isSelected: selectedFieldIndex == index
                        )
                        .onTapGesture {
                            selectedFieldIndex = index
                        }
                        .contextMenu {
                            fieldContextMenu(for: index)
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                duplicateField(at: index)
                            } label: {
                                Label("Duplicate", systemImage: "doc.on.doc")
                            }
                            .tint(.blue)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deleteField(at: index)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onMove { source, destination in
                        moveFields(from: source, to: destination)
                    }
                }
            } header: {
                HStack {
                    Text("Form Fields")
                    Spacer()
                    Text("\(fields.count) field\(fields.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section {
                Button {
                    showingFieldTypes = true
                } label: {
                    Label("Add Field", systemImage: "plus.circle.fill")
                }
                
                Button {
                    showingFieldPresets = true
                } label: {
                    Label("Insert Preset", systemImage: "rectangle.stack.badge.plus")
                }
                
                if let selectedIndex = selectedFieldIndex {
                    Button {
                        duplicateField(at: selectedIndex)
                    } label: {
                        Label("Duplicate Selected Field", systemImage: "doc.on.doc")
                    }
                    
                    Button {
                        editingField = fields[selectedIndex]
                    } label: {
                        Label("Configure Field", systemImage: "slider.horizontal.3")
                    }
                }
            }
        }
    }
    
    // MARK: - Preview Panel
    
    private var previewPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Form Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(formTitle.isEmpty ? "Untitled Form" : formTitle)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if !formDescription.isEmpty {
                        Text(formDescription)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground))
                
                Divider()
                
                // Fields Preview
                ForEach(fields) { field in
                    FormFieldPreview(field: field)
                        .padding(.horizontal)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private func fieldContextMenu(for index: Int) -> some View {
        Button {
            editingField = fields[index]
        } label: {
            Label("Configure", systemImage: "slider.horizontal.3")
        }
        
        Button {
            duplicateField(at: index)
        } label: {
            Label("Duplicate", systemImage: "doc.on.doc")
        }
        
        Button {
            duplicateFieldAsSection(at: index)
        } label: {
            Label("Duplicate as Section", systemImage: "rectangle.stack")
        }
        
        Divider()
        
        Button {
            toggleFieldRequired(at: index)
        } label: {
            Label(
                fields[index].required ? "Make Optional" : "Make Required",
                systemImage: fields[index].required ? "asterisk.circle.fill" : "asterisk.circle"
            )
        }
        
        Divider()
        
        Button(role: .destructive) {
            deleteField(at: index)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
    
    // MARK: - Actions
    
    private func addField(type: FieldType) {
        let field = FormFieldData(
            id: UUID().uuidString,
            type: type.rawValue,
            label: type.displayName,
            required: false,
            order: fields.count
        )
        fields.append(field)
        selectedFieldIndex = fields.count - 1
        showingFieldTypes = false
    }
    
    private func insertPreset(_ preset: FieldPreset) {
        let newFields = preset.toFormFieldData(startingOrder: fields.count)
        fields.append(contentsOf: newFields)
        showingFieldPresets = false
    }
    
    private func duplicateField(at index: Int) {
        var duplicatedField = fields[index]
        duplicatedField.id = UUID().uuidString
        duplicatedField.label = duplicatedField.label + " (Copy)"
        duplicatedField.order = fields.count
        fields.insert(duplicatedField, at: index + 1)
        updateFieldOrders()
        selectedFieldIndex = index + 1
    }
    
    private func duplicateFieldAsSection(at index: Int) {
        // Create a section header
        let sectionField = FormFieldData(
            id: UUID().uuidString,
            type: "section",
            label: "Section",
            required: false,
            order: fields.count
        )
        
        // Duplicate the original field
        var duplicatedField = fields[index]
        duplicatedField.id = UUID().uuidString
        duplicatedField.order = fields.count + 1
        
        fields.insert(sectionField, at: index + 1)
        fields.insert(duplicatedField, at: index + 2)
        updateFieldOrders()
    }
    
    private func deleteField(at index: Int) {
        fields.remove(at: index)
        updateFieldOrders()
        if selectedFieldIndex == index {
            selectedFieldIndex = nil
        }
    }
    
    private func moveFields(from source: IndexSet, to destination: Int) {
        fields.move(fromOffsets: source, toOffset: destination)
        updateFieldOrders()
    }
    
    private func toggleFieldRequired(at index: Int) {
        fields[index].required.toggle()
    }
    
    private func updateFieldOrders() {
        for (index, _) in fields.enumerated() {
            fields[index].order = index
        }
    }
    
    private func binding(for field: FormFieldData) -> Binding<FormFieldData> {
        guard let index = fields.firstIndex(where: { $0.id == field.id }) else {
            return .constant(field)
        }
        return $fields[index]
    }
    
    private func saveTemplate() {
        // Save as a custom template
        // Implementation depends on template storage system
        dismiss()
    }
}

// MARK: - Field Builder Row

struct FieldBuilderRow: View {
    @Binding var field: FormFieldData
    let isSelected: Bool
    
    private var fieldType: FieldType {
        FieldType(rawValue: field.type) ?? .text
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Drag Handle
            Image(systemName: "line.3.horizontal")
                .foregroundColor(.secondary)
                .font(.caption)
            
            // Field Icon
            Image(systemName: fieldType.icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            
            // Field Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(field.label)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if field.required {
                        Text("*")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                HStack(spacing: 8) {
                    Text(fieldType.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let options = field.options, !options.isEmpty {
                        Text("• \(options.count) options")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Selection Indicator
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
}

// MARK: - Field Preview

struct FormFieldPreview: View {
    let field: FormFieldData
    
    private var fieldType: FieldType {
        FieldType(rawValue: field.type) ?? .text
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Label
            if fieldType != .section {
                HStack {
                    Text(field.label)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if field.required {
                        Text("*")
                            .foregroundColor(.red)
                    }
                }
            }
            
            // Input Preview
            Group {
                switch fieldType {
                case .section:
                    Text(field.label)
                        .font(.headline)
                        .padding(.top, 8)
                    
                case .text, .email, .phone:
                    TextField(field.placeholder ?? "Enter value", text: .constant(""))
                        .textFieldStyle(.roundedBorder)
                        .disabled(true)
                    
                case .textarea:
                    TextEditor(text: .constant(""))
                        .frame(height: 80)
                        .disabled(true)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.3))
                        )
                    
                case .number, .currency:
                    TextField("0", text: .constant(""))
                        .textFieldStyle(.roundedBorder)
                        .disabled(true)
                    
                case .date:
                    HStack {
                        Image(systemName: "calendar")
                        Text("Select date")
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3))
                    )
                    
                case .time:
                    HStack {
                        Image(systemName: "clock")
                        Text("Select time")
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3))
                    )
                    
                case .checkbox:
                    Toggle("", isOn: .constant(false))
                        .labelsHidden()
                        .disabled(true)
                    
                case .yesNo:
                    Picker("", selection: .constant("")) {
                        Text("Yes").tag("yes")
                        Text("No").tag("no")
                        Text("N/A").tag("na")
                    }
                    .pickerStyle(.segmented)
                    .disabled(true)
                    
                case .dropdown:
                    Menu {
                        ForEach(field.options ?? ["Option 1", "Option 2"], id: \.self) { option in
                            Button(option) { }
                        }
                    } label: {
                        HStack {
                            Text("Select option")
                                .foregroundColor(.secondary)
                            Spacer()
                            Image(systemName: "chevron.down")
                        }
                        .padding(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.3))
                        )
                    }
                    .disabled(true)
                    
                case .signature:
                    HStack {
                        Image(systemName: "signature")
                        Text("Tap to sign")
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 60)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
                    )
                    
                case .photo:
                    HStack {
                        Image(systemName: "camera")
                        Text("Add photo")
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 60)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
                    )
                    
                case .rating:
                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { _ in
                            Image(systemName: "star")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                case .slider:
                    Slider(value: .constant(0.5))
                        .disabled(true)
                    
                default:
                    Text("Field preview")
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Supporting Views

struct FieldPresetsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (FieldPreset) -> Void
    
    var body: some View {
        NavigationStack {
            List(FieldTemplatePresets.all) { preset in
                Button {
                    onSelect(preset)
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: preset.icon)
                            .foregroundColor(.accentColor)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading) {
                            Text(preset.name)
                                .font(.headline)
                            Text("\(preset.fields.count) fields")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Field Presets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct FieldTypesSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (FieldType) -> Void
    
    private let fieldGroups: [(String, [FieldType])] = [
        ("Text Input", [.text, .textarea, .email, .phone, .number, .currency]),
        ("Selection", [.dropdown, .multiSelect, .checkbox, .yesNo, .rating, .slider]),
        ("Date & Time", [.date, .time]),
        ("Media & Location", [.photo, .signature, .location]),
        ("Layout", [.section])
    ]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(fieldGroups, id: \.0) { groupName, types in
                    Section(groupName) {
                        ForEach(types, id: \.self) { type in
                            Button {
                                onSelect(type)
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: type.icon)
                                        .foregroundColor(.accentColor)
                                        .frame(width: 30)
                                    Text(type.displayName)
                                    Spacer()
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Field")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct FieldConfigurationView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var field: FormFieldData
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Information") {
                    TextField("Field Label", text: $field.label)
                    TextField("Placeholder (Optional)", text: Binding(
                        get: { field.placeholder ?? "" },
                        set: { field.placeholder = $0.isEmpty ? nil : $0 }
                    ))
                    Toggle("Required Field", isOn: $field.required)
                }
                
                if FieldType(rawValue: field.type) == .dropdown || FieldType(rawValue: field.type) == .multiSelect {
                    Section("Options") {
                        ForEach(field.options ?? [], id: \.self) { option in
                            Text(option)
                        }
                        // Add option editing UI here
                    }
                }
            }
            .navigationTitle("Configure Field")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    FormBuilderView()
        .environmentObject(DataController.shared)
}
