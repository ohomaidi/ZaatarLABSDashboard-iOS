import SwiftUI

struct RetentionView: View {
    @EnvironmentObject var api: APIService
    @Binding var filter: DateRangeFilter
    @Binding var selectedApp: String?
    @Binding var apps: [AppInfo]

    @State private var cohorts: [RetentionCohort]?
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && cohorts == nil {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error, cohorts == nil {
                    LoadingOrError(isLoading: false, error: error, retry: load)
                } else if let cohorts {
                    content(cohorts)
                }
            }
            .navigationTitle("Retention")
        }
        .task { load() }
        .onChange(of: filter) { load() }
        .onChange(of: selectedApp) { load() }
    }

    @ViewBuilder
    private func content(_ cohorts: [RetentionCohort]) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                AppPicker(selectedApp: $selectedApp, apps: apps)
                FilterPicker(filter: $filter)

                if cohorts.isEmpty {
                    ContentUnavailableView {
                        Label("No Data", systemImage: "chart.bar.xaxis")
                    } description: {
                        Text("Not enough data for retention analysis")
                    }
                } else {
                    // Retention grid
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Cohort Retention")
                            .font(.headline)
                            .padding()

                        // Each cohort row
                        ForEach(cohorts) { cohort in
                            cohortRow(cohort)
                            Divider()
                        }
                    }
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    // Legend
                    HStack(spacing: 16) {
                        legendItem(color: retentionColor(100), text: "90-100%")
                        legendItem(color: retentionColor(70), text: "50-89%")
                        legendItem(color: retentionColor(30), text: "< 50%")
                    }
                    .font(.caption)
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .refreshable { load() }
    }

    @ViewBuilder
    private func cohortRow(_ cohort: RetentionCohort) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(cohort.month)
                    .font(.caption.bold())
                    .frame(width: 70, alignment: .leading)
                Text("\(cohort.total) users")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    let maxMonth = cohort.retention.keys
                        .compactMap { Int($0) }
                        .max() ?? 0

                    ForEach(0...maxMonth, id: \.self) { m in
                        let key = String(m)
                        let pct = cohort.retention[key] ?? 0

                        VStack(spacing: 2) {
                            Text("M\(m)")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                            Text("\(Int(pct))%")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 28)
                                .background(retentionColor(pct))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
    }

    private func retentionColor(_ pct: Double) -> Color {
        if pct >= 90 { return .green }
        if pct >= 70 { return .green.opacity(0.7) }
        if pct >= 50 { return .orange }
        if pct >= 30 { return .orange.opacity(0.7) }
        return .red.opacity(0.6)
    }

    @ViewBuilder
    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 12, height: 12)
            Text(text)
        }
    }

    private func load() {
        isLoading = true
        error = nil
        Task {
            do {
                cohorts = try await api.fetchRetention(filter: filter, app: selectedApp)
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }
}
