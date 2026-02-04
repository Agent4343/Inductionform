/**
 * TemplatesListView.swift
 * Template Management & Browser
 */

import SwiftUI

struct TemplatesListView: View {
    @EnvironmentObject var dataController: DataController
    @EnvironmentObject var syncManager: SyncManager

    @State private var templates: [LocalTemplate] = []
    @State private var categories: [String] = []
    @State private var selectedCategory: String?
    @State private var searchText = ""
    @State private var showingBuilder = false
    @State private var isLoading = false

    var filteredTemplates: [LocalTemplate] {
        var result = templates

        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        if !searchText.isEmpty {
            result = result.filter {
                ($0.name ?? "").localizedCaseInsensitiveContains(searchText) ||
                ($0.templateDescription ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category Filter
                if !categories.isEmpty {
                    categoryFilter
                }

                // Templates Grid
                if filteredTemplates.isEmpty {
                    emptyState
                } else {
                    templatesGrid
                }
            }
            .navigationTitle("Templates")
            .searchable(text: $searchText, prompt: "Search templates")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingBuilder = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable {
                await loadTemplates()
            }
            .sheet(isPresented: $showingBuilder) {
                FormBuilderView()
            }
            .onAppear {
                Task { await loadTemplates() }
            }
        }
    }

    // MARK: - Subviews

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "All",
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }

                ForEach(categories, id: \.self) { category in
                    FilterChip(
                        title: category,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var templatesGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(filteredTemplates, id: \.id) { template in
                    TemplateCard(template: template)
                }
            }
            .padding()
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Templates", systemImage: "square.stack")
        } description: {
            Text("Create a template to reuse form designs")
        } actions: {
            Button("Create Template") {
                showingBuilder = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Actions

    private func loadTemplates() async {
        isLoading = true

        // Sync from server
        if syncManager.isOnline {
            do {
                let response = try await APIService.shared.getTemplates()
                for template in response.templates {
                    dataController.saveTemplate(template)
                }
            } catch {
                print("Failed to sync templates: \(error)")
            }
        }

        // Load from local
        templates = dataController.fetchTemplates()

        // Extract categories
        let allCategories = templates.compactMap { $0.category }
        categories = Array(Set(allCategories)).sorted()

        isLoading = false
    }
}

// MARK: - Template Card

struct TemplateCard: View {
    let template: LocalTemplate

    @State private var showingDetail = false
    @State private var showingCreateForm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Icon & Name
            HStack {
                Image(systemName: "doc.text.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)

                Spacer()

                Menu {
                    Button {
                        showingCreateForm = true
                    } label: {
                        Label("Use Template", systemImage: "plus.circle")
                    }

                    Button {
                        showingDetail = true
                    } label: {
                        Label("View Details", systemImage: "info.circle")
                    }

                    Button {
                        duplicateTemplate()
                    } label: {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                }
            }

            Text(template.name ?? "Untitled")
                .font(.headline)
                .lineLimit(2)

            if let description = template.templateDescription {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            // Category & Field Count
            HStack {
                if let category = template.category {
                    Text(category)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.1))
                        .foregroundColor(.accentColor)
                        .cornerRadius(4)
                }

                Spacer()

                Text("\(template.fields.count) fields")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(height: 160)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
        .sheet(isPresented: $showingDetail) {
            TemplateDetailView(template: template)
        }
        .sheet(isPresented: $showingCreateForm) {
            CreateFormFromTemplateView(template: template)
        }
    }

    private func duplicateTemplate() {
        guard let templateId = template.id?.uuidString else { return }
        Task {
            do {
                _ = try await APIService.shared.duplicateTemplate(id: templateId)
            } catch {
                print("Failed to duplicate: \(error)")
            }
        }
    }
}

// MARK: - Template Detail View

struct TemplateDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let template: LocalTemplate

    var body: some View {
        NavigationStack {
            List {
                Section("Details") {
                    LabeledContent("Name", value: template.name ?? "Untitled")

                    if let description = template.templateDescription {
                        LabeledContent("Description", value: description)
                    }

                    if let category = template.category {
                        LabeledContent("Category", value: category)
                    }

                    LabeledContent("Fields", value: "\(template.fields.count)")
                }

                Section("Fields") {
                    ForEach(template.fields, id: \.id) { field in
                        HStack {
                            Image(systemName: FieldType(rawValue: field.type)?.icon ?? "questionmark")
                                .foregroundColor(.accentColor)

                            VStack(alignment: .leading) {
                                Text(field.label)
                                    .font(.subheadline)

                                Text(field.type.capitalized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if field.required {
                                Text("Required")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Template Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Create Form from Template

struct CreateFormFromTemplateView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataController: DataController

    let template: LocalTemplate

    @State private var title: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Form Title") {
                    TextField("Enter title", text: $title)
                }

                Section("Template") {
                    LabeledContent("Name", value: template.name ?? "")
                    LabeledContent("Fields", value: "\(template.fields.count)")
                }
            }
            .navigationTitle("New Form")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createForm()
                    }
                    .disabled(title.isEmpty)
                }
            }
            .onAppear {
                title = template.name ?? "New Form"
            }
        }
    }

    private func createForm() {
        _ = dataController.createForm(
            title: title,
            templateId: template.id,
            fields: template.fields
        )
        dismiss()
    }
}

// MARK: - Form Builder View

struct FormBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataController: DataController

    @State private var name = ""
    @State private var description = ""
    @State private var category = ""
    @State private var fields: [FormFieldData] = []
    @State private var showingAddField = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Template Info") {
                    TextField("Template Name", text: $name)
                    TextField("Description", text: $description)
                    TextField("Category", text: $category)
                }

                Section("Fields") {
                    if fields.isEmpty {
                        Text("No fields added yet")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach($fields) { $field in
                            FieldBuilderRow(field: $field)
                        }
                        .onDelete { indexSet in
                            fields.remove(atOffsets: indexSet)
                        }
                        .onMove { source, destination in
                            fields.move(fromOffsets: source, toOffset: destination)
                        }
                    }

                    Button {
                        showingAddField = true
                    } label: {
                        Label("Add Field", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle("Form Builder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTemplate()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .sheet(isPresented: $showingAddField) {
                AddFieldSheet { field in
                    fields.append(field)
                }
            }
        }
    }

    private func saveTemplate() {
        // Save to API
        // For now, dismiss
        dismiss()
    }
}

// MARK: - Field Builder Row

struct FieldBuilderRow: View {
    @Binding var field: FormFieldData

    var body: some View {
        HStack {
            Image(systemName: FieldType(rawValue: field.type)?.icon ?? "questionmark")
                .foregroundColor(.accentColor)

            VStack(alignment: .leading) {
                TextField("Label", text: $field.label)
                    .font(.subheadline)

                Text(field.type.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: $field.required)
                .labelsHidden()
        }
    }
}

// MARK: - Add Field Sheet

struct AddFieldSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (FormFieldData) -> Void

    @State private var label = ""
    @State private var selectedType: FieldType = .text
    @State private var isRequired = false
    @State private var options = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Field Info") {
                    TextField("Label", text: $label)

                    Picker("Type", selection: $selectedType) {
                        ForEach(FieldType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }

                    Toggle("Required", isOn: $isRequired)
                }

                if selectedType == .dropdown || selectedType == .multiSelect {
                    Section("Options (one per line)") {
                        TextEditor(text: $options)
                            .frame(height: 100)
                    }
                }
            }
            .navigationTitle("Add Field")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addField()
                    }
                    .disabled(label.isEmpty)
                }
            }
        }
    }

    private func addField() {
        let optionsArray = options.isEmpty ? nil : options.components(separatedBy: "\n").filter { !$0.isEmpty }

        let field = FormFieldData(
            id: UUID().uuidString,
            type: selectedType.rawValue,
            label: label,
            required: isRequired,
            options: optionsArray,
            order: 0
        )

        onAdd(field)
        dismiss()
    }
}

#Preview {
    TemplatesListView()
        .environmentObject(DataController.shared)
        .environmentObject(SyncManager.shared)
}
