/**
 * FormsListView.swift
 * Forms List & Management
 */

import SwiftUI

struct FormsListView: View {
    @EnvironmentObject var dataController: DataController
    @EnvironmentObject var syncManager: SyncManager

    @State private var forms: [LocalForm] = []
    @State private var selectedStatus: FormStatus?
    @State private var searchText = ""
    @State private var showingNewForm = false
    @State private var showingTemplates = false
    @State private var isRefreshing = false

    var filteredForms: [LocalForm] {
        var result = forms

        if let status = selectedStatus {
            result = result.filter { $0.statusEnum == status }
        }

        if !searchText.isEmpty {
            result = result.filter {
                ($0.title ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Status Filter
                statusFilterBar

                // Forms List
                if filteredForms.isEmpty {
                    emptyState
                } else {
                    formsList
                }
            }
            .navigationTitle("Forms")
            .searchable(text: $searchText, prompt: "Search forms")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingTemplates = true
                        } label: {
                            Label("From Template", systemImage: "square.stack")
                        }

                        Button {
                            showingNewForm = true
                        } label: {
                            Label("Blank Form", systemImage: "doc.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }

                ToolbarItem(placement: .topBarLeading) {
                    if syncManager.isSyncing {
                        ProgressView()
                    } else if syncManager.pendingSyncCount > 0 {
                        Button {
                            Task { await syncManager.syncAll() }
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .overlay(Badge(count: syncManager.pendingSyncCount))
                        }
                    }
                }
            }
            .refreshable {
                await refresh()
            }
            .sheet(isPresented: $showingNewForm) {
                FormEditorView(form: nil)
            }
            .sheet(isPresented: $showingTemplates) {
                TemplatePickerView { template in
                    createFormFromTemplate(template)
                }
            }
            .onAppear {
                loadForms()
            }
        }
    }

    // MARK: - Subviews

    private var statusFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "All",
                    isSelected: selectedStatus == nil
                ) {
                    selectedStatus = nil
                }

                ForEach(FormStatus.allCases, id: \.self) { status in
                    FilterChip(
                        title: status.displayName,
                        isSelected: selectedStatus == status
                    ) {
                        selectedStatus = status
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var formsList: some View {
        List {
            ForEach(filteredForms, id: \.id) { form in
                NavigationLink {
                    FormEditorView(form: form)
                } label: {
                    FormRowView(form: form)
                }
            }
            .onDelete(perform: deleteForms)
        }
        .listStyle(.plain)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Forms", systemImage: "doc.text")
        } description: {
            Text("Create a new form to get started")
        } actions: {
            Button("Create Form") {
                showingNewForm = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Actions

    private func loadForms() {
        forms = dataController.fetchForms()
    }

    private func refresh() async {
        isRefreshing = true
        await syncManager.syncAll()
        loadForms()
        isRefreshing = false
    }

    private func deleteForms(at offsets: IndexSet) {
        for index in offsets {
            let form = filteredForms[index]
            dataController.deleteForm(form)
        }
        loadForms()
    }

    private func createFormFromTemplate(_ template: LocalTemplate) {
        let form = dataController.createForm(
            title: template.name ?? "New Form",
            templateId: template.id,
            fields: template.fields
        )
        forms.insert(form, at: 0)
        showingTemplates = false
    }
}

// MARK: - Form Row View

struct FormRowView: View {
    let form: LocalForm

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(form.title ?? "Untitled")
                    .font(.headline)

                Spacer()

                StatusBadge(status: form.statusEnum)
            }

            HStack {
                if let date = form.updatedAt {
                    Text(date, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if form.needsSync {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: FormStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .foregroundColor(.white)
            .cornerRadius(4)
    }

    private var backgroundColor: Color {
        switch status {
        case .draft: return .gray
        case .submitted: return .blue
        case .approved: return .green
        case .rejected: return .red
        }
    }
}

// MARK: - Badge

struct Badge: View {
    let count: Int

    var body: some View {
        if count > 0 {
            Text("\(count)")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(4)
                .background(Color.red)
                .clipShape(Circle())
                .offset(x: 8, y: -8)
        }
    }
}

// MARK: - Template Picker

struct TemplatePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataController: DataController

    let onSelect: (LocalTemplate) -> Void

    @State private var templates: [LocalTemplate] = []
    @State private var searchText = ""

    var filteredTemplates: [LocalTemplate] {
        if searchText.isEmpty {
            return templates
        }
        return templates.filter {
            ($0.name ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredTemplates, id: \.id) { template in
                Button {
                    onSelect(template)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(template.name ?? "Untitled")
                            .font(.headline)
                            .foregroundColor(.primary)

                        if let description = template.templateDescription {
                            Text(description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }

                        if let category = template.category {
                            Text(category)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.1))
                                .foregroundColor(.accentColor)
                                .cornerRadius(4)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Choose Template")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search templates")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                templates = dataController.fetchTemplates()
            }
        }
    }
}

#Preview {
    FormsListView()
        .environmentObject(DataController.shared)
        .environmentObject(SyncManager.shared)
}
