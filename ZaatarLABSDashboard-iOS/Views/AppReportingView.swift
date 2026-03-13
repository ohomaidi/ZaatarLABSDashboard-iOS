import SwiftUI
import Charts

struct AppReportingView: View {
    @EnvironmentObject var api: APIService
    @Binding var filter: DateRangeFilter
    @Binding var selectedApp: String?
    @Binding var apps: [AppInfo]

    @State private var data: AppLaunchesResponse?
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && data == nil {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error, data == nil {
                    LoadingOrError(isLoading: false, error: error, retry: load)
                } else if let data {
                    content(data)
                }
            }
            .navigationTitle("App Reporting")
        }
        .task { load() }
        .onChange(of: filter) { load() }
        .onChange(of: selectedApp) { load() }
    }

    @ViewBuilder
    private func content(_ data: AppLaunchesResponse) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                AppPicker(selectedApp: $selectedApp, apps: apps)
                FilterPicker(filter: $filter)

                // KPI Cards
                LazyVGrid(columns: [.init(), .init()], spacing: 12) {
                    MetricCard("First Installs", value: "\(data.firstInstalls)", color: .green)
                    MetricCard("Redownloads", value: "\(data.redownloads)", color: .orange)
                    MetricCard("Total", value: "\(data.totalLaunches)")
                }
                .padding(.horizontal)

                // Installs over time (stacked bar)
                if !data.daily.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Installs Over Time")
                            .font(.headline)
                            .padding(.horizontal)

                        Chart {
                            ForEach(data.daily) { day in
                                BarMark(
                                    x: .value("Date", day.date),
                                    y: .value("Count", day.firstInstalls)
                                )
                                .foregroundStyle(.green)
                                .position(by: .value("Type", "New"))

                                if day.redownloads > 0 {
                                    BarMark(
                                        x: .value("Date", day.date),
                                        y: .value("Count", day.redownloads)
                                    )
                                    .foregroundStyle(.orange)
                                    .position(by: .value("Type", "Redownload"))
                                }
                            }
                        }
                        .frame(height: 200)
                        .padding(.horizontal)
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 5))
                        }
                        .chartForegroundStyleScale([
                            "New": Color.green,
                            "Redownload": Color.orange,
                        ])
                    }
                    .padding(.vertical, 12)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }

                // By Platform
                if !data.categories.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("By Platform")
                            .font(.headline)
                            .padding(.horizontal)

                        Chart(data.categories) { cat in
                            SectorMark(
                                angle: .value("Count", cat.count),
                                innerRadius: .ratio(0.5),
                                angularInset: 2
                            )
                            .foregroundStyle(by: .value("Platform", cat.category))
                        }
                        .frame(height: 200)
                        .padding(.horizontal)
                        .chartForegroundStyleScale(domain: data.categories.map(\.category), range: [.green, .blue, .mint, .teal])
                    }
                    .padding(.vertical, 12)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }

                // By Device
                if !data.devices.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("By Device Model")
                            .font(.headline)
                            .padding(.horizontal)

                        Chart(data.devices.prefix(10)) { d in
                            BarMark(
                                x: .value("Count", d.count),
                                y: .value("Device", d.device)
                            )
                            .foregroundStyle(.green)
                        }
                        .frame(height: CGFloat(min(data.devices.count, 10) * 32 + 20))
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 12)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }

                // Recent launches
                if !data.recent.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent First Launches")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(data.recent) { launch in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(launch.deviceModel ?? "Unknown")
                                        .font(.subheadline.bold())
                                    HStack(spacing: 8) {
                                        Text(launch.deviceCategory ?? "—")
                                        Text(launch.osVersion ?? "")
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    Text(launch.launchedAt?.shortDate ?? "")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(launch.isRedownload ? "Redownload" : "New")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(launch.isRedownload ? Color.orange.opacity(0.15) : Color.green.opacity(0.15))
                                    .foregroundStyle(launch.isRedownload ? .orange : .green)
                                    .clipShape(Capsule())
                            }
                            .padding(.horizontal)
                            if launch.id != data.recent.last?.id {
                                Divider().padding(.horizontal)
                            }
                        }
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
                data = try await api.fetchAppLaunches(filter: filter, app: selectedApp)
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }
}
