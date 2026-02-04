/**
 * DashboardView.swift
 * Analytics & Statistics Dashboard
 */

import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var dataController: DataController
    @EnvironmentObject var syncManager: SyncManager

    @State private var stats = DashboardStats()
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Summary Cards
                    summaryCards

                    // Status Chart
                    statusChart

                    // Recent Activity
                    recentActivity

                    // Sync Status
                    syncStatus
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .refreshable {
                await loadStats()
            }
            .onAppear {
                Task { await loadStats() }
            }
        }
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatCard(
                title: "Total Forms",
                value: "\(stats.totalForms)",
                icon: "doc.text.fill",
                color: .blue
            )

            StatCard(
                title: "Pending",
                value: "\(stats.pendingForms)",
                icon: "clock.fill",
                color: .orange
            )

            StatCard(
                title: "Approved",
                value: "\(stats.approvedForms)",
                icon: "checkmark.circle.fill",
                color: .green
            )

            StatCard(
                title: "This Week",
                value: "\(stats.formsThisWeek)",
                icon: "calendar",
                color: .purple
            )
        }
    }

    // MARK: - Status Chart

    private var statusChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Forms by Status")
                .font(.headline)

            if #available(iOS 16.0, *) {
                Chart {
                    ForEach(stats.statusBreakdown, id: \.status) { item in
                        SectorMark(
                            angle: .value("Count", item.count),
                            innerRadius: .ratio(0.5),
                            angularInset: 1.5
                        )
                        .foregroundStyle(by: .value("Status", item.status))
                        .cornerRadius(4)
                    }
                }
                .frame(height: 200)
                .chartLegend(position: .bottom)
            } else {
                // Fallback for iOS 15
                HStack(spacing: 20) {
                    ForEach(stats.statusBreakdown, id: \.status) { item in
                        VStack {
                            Text("\(item.count)")
                                .font(.title)
                                .fontWeight(.bold)
                            Text(item.status)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }

    // MARK: - Recent Activity

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)

            if stats.recentForms.isEmpty {
                Text("No recent activity")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(stats.recentForms, id: \.id) { form in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(form.title ?? "Untitled")
                                .font(.subheadline)
                            Text(form.updatedAt ?? Date(), style: .relative)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        StatusBadge(status: form.statusEnum)
                    }
                    .padding(.vertical, 4)

                    if form.id != stats.recentForms.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }

    // MARK: - Sync Status

    private var syncStatus: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sync Status")
                .font(.headline)

            HStack {
                Image(systemName: syncManager.isOnline ? "wifi" : "wifi.slash")
                    .foregroundColor(syncManager.isOnline ? .green : .red)

                Text(syncManager.isOnline ? "Online" : "Offline")

                Spacer()

                if syncManager.pendingSyncCount > 0 {
                    Text("\(syncManager.pendingSyncCount) pending")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            if let lastSync = syncManager.lastSyncDate {
                Text("Last sync: \(lastSync, style: .relative)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button {
                Task { await syncManager.syncAll() }
            } label: {
                Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(syncManager.isSyncing || !syncManager.isOnline)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }

    // MARK: - Load Stats

    private func loadStats() async {
        isLoading = true

        let forms = dataController.fetchForms()

        let drafts = forms.filter { $0.statusEnum == .draft }.count
        let submitted = forms.filter { $0.statusEnum == .submitted }.count
        let approved = forms.filter { $0.statusEnum == .approved }.count
        let rejected = forms.filter { $0.statusEnum == .rejected }.count

        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let thisWeek = forms.filter { ($0.createdAt ?? Date()) > weekAgo }.count

        await MainActor.run {
            stats = DashboardStats(
                totalForms: forms.count,
                pendingForms: submitted,
                approvedForms: approved,
                formsThisWeek: thisWeek,
                statusBreakdown: [
                    StatusCount(status: "Draft", count: drafts),
                    StatusCount(status: "Submitted", count: submitted),
                    StatusCount(status: "Approved", count: approved),
                    StatusCount(status: "Rejected", count: rejected)
                ],
                recentForms: Array(forms.prefix(5))
            )
            isLoading = false
        }
    }
}

// MARK: - Dashboard Stats

struct DashboardStats {
    var totalForms = 0
    var pendingForms = 0
    var approvedForms = 0
    var formsThisWeek = 0
    var statusBreakdown: [StatusCount] = []
    var recentForms: [LocalForm] = []
}

struct StatusCount {
    let status: String
    let count: Int
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }

            Text(value)
                .font(.title)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
}

#Preview {
    DashboardView()
        .environmentObject(DataController.shared)
        .environmentObject(SyncManager.shared)
}
