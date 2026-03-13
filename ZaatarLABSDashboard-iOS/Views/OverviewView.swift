import SwiftUI
import Charts

struct OverviewView: View {
    @EnvironmentObject var api: APIService
    @Binding var filter: DateRangeFilter
    @Binding var selectedApp: String?
    @Binding var apps: [AppInfo]

    @State private var overview: OverviewResponse?
    @State private var plans: PlansResponse?
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && overview == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error, overview == nil {
                    LoadingOrError(isLoading: false, error: error, retry: load)
                } else if let overview {
                    content(overview)
                }
            }
            .navigationTitle("Overview")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { try? await api.refresh(); load() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Logout") { api.logout() }
                        .foregroundStyle(.red)
                }
            }
        }
        .task { load() }
        .onChange(of: filter) { load() }
        .onChange(of: selectedApp) { load() }
    }

    @ViewBuilder
    private func content(_ data: OverviewResponse) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                AppPicker(selectedApp: $selectedApp, apps: apps)
                FilterPicker(filter: $filter)

                // KPI Grid
                LazyVGrid(columns: [.init(), .init()], spacing: 12) {
                    MetricCard("Active Subscribers", value: "\(data.activeSubscribers)", color: .green)
                    MetricCard("MRR", value: "$\(String(format: "%.2f", data.mrr))", color: .blue)
                    MetricCard("Total Revenue", value: "$\(String(format: "%.2f", data.totalRevenue))")
                    MetricCard("Churn Rate", value: "\(String(format: "%.1f", data.churnRate))%", color: data.churnRate > 10 ? .red : .orange)
                    MetricCard("New", value: "\(data.newInPeriod)", subtitle: "In period", color: .green)
                    MetricCard("Billing Issues", value: "\(data.billingIssues)", color: data.billingIssues > 0 ? .red : .secondary)
                    MetricCard("Expired", value: "\(data.expired)", color: .secondary)
                    MetricCard("Refunded", value: "\(data.refunded)", color: data.refunded > 0 ? .red : .secondary)
                }
                .padding(.horizontal)

                // Plan breakdown
                if let plans, !plans.plans.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Plan Breakdown")
                            .font(.headline)
                            .padding(.horizontal)

                        Chart(plans.plans) { plan in
                            BarMark(
                                x: .value("Count", plan.count),
                                y: .value("Plan", plan.name)
                            )
                            .foregroundStyle(plan.tier == "Pro" ? Color.blue : Color.green)
                        }
                        .frame(height: CGFloat(plans.plans.count * 44 + 20))
                        .padding(.horizontal)

                        // Tier summary
                        HStack(spacing: 16) {
                            ForEach(Array(plans.tiers.sorted(by: { $0.key < $1.key })), id: \.key) { tier, count in
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(tier == "Pro" ? Color.blue : Color.green)
                                        .frame(width: 8, height: 8)
                                    Text("\(tier): \(count)")
                                        .font(.caption)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 12)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .refreshable { load() }
    }

    private func load() {
        isLoading = true
        error = nil
        Task {
            do {
                // Load apps list if not yet loaded
                if apps.isEmpty {
                    apps = (try? await api.fetchApps()) ?? []
                }
                async let o = api.fetchOverview(filter: filter, app: selectedApp)
                async let p = api.fetchPlans(filter: filter, app: selectedApp)
                overview = try await o
                plans = try await p
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }
}
