import SwiftUI
import Charts

struct AppleDataView: View {
    @EnvironmentObject var api: APIService
    @Binding var filter: DateRangeFilter
    @Binding var selectedApp: String?
    @Binding var apps: [AppInfo]

    @State private var data: DownloadsResponse?
    @State private var isLoading = false
    @State private var error: String?

    /// Filters supported by Apple Data (max 90 days)
    private static let supportedFilters: [DateRangeFilter] = [.thisMonth, .lastMonth]

    /// Clamp to a supported filter if the shared filter is unsupported
    private var effectiveFilter: DateRangeFilter {
        Self.supportedFilters.contains(filter) ? filter : .thisMonth
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && data == nil {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error, data == nil {
                    LoadingOrError(isLoading: false, error: error, retry: load)
                } else if let data {
                    if data.configured {
                        content(data)
                    } else {
                        ContentUnavailableView {
                            Label("Not Configured", systemImage: "gear")
                        } description: {
                            Text(data.message ?? "App Store Connect API not configured")
                        }
                    }
                }
            }
            .navigationTitle("Apple Data")
        }
        .task {
            clampFilterIfNeeded()
            load()
        }
        .onChange(of: filter) { load() }
        .onChange(of: selectedApp) { load() }
    }

    private func clampFilterIfNeeded() {
        if !Self.supportedFilters.contains(filter) {
            filter = .thisMonth
        }
    }

    @ViewBuilder
    private func content(_ data: DownloadsResponse) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                AppPicker(selectedApp: $selectedApp, apps: apps)

                // Only show supported filters (no All Time / This Year)
                Picker("Period", selection: $filter) {
                    ForEach(Self.supportedFilters, id: \.self) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 4)
                }

                // KPI Cards
                LazyVGrid(columns: [.init(), .init()], spacing: 12) {
                    MetricCard("Downloads", value: "\(data.totalDownloads ?? 0)", color: .green)
                    MetricCard("Updates", value: "\(data.totalUpdates ?? 0)", color: .blue)
                    MetricCard("Redownloads", value: "\(data.totalRedownloads ?? 0)", color: .orange)
                }
                .padding(.horizontal)

                // Daily downloads chart
                if let daily = data.daily, !daily.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Daily Downloads")
                            .font(.headline)
                            .padding(.horizontal)

                        let recentDays = Array(daily.suffix(31))
                        Chart(Array(recentDays.enumerated()), id: \.element.id) { index, day in
                            BarMark(
                                x: .value("Day", dayNumber(from: day.date)),
                                y: .value("Downloads", day.downloads)
                            )
                            .foregroundStyle(.green)
                        }
                        .frame(height: 200)
                        .padding(.horizontal)
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 7))
                        }
                    }
                    .padding(.vertical, 12)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }

                // Top countries
                if let countries = data.countries, !countries.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("By Country")
                            .font(.headline)
                            .padding(.horizontal)

                        Chart(countries.prefix(10)) { c in
                            BarMark(
                                x: .value("Units", c.units),
                                y: .value("Country", c.country)
                            )
                            .foregroundStyle(.green)
                        }
                        .frame(height: CGFloat(min(countries.count, 10) * 32 + 20))
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 12)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }

                // Top devices
                if let devices = data.devices, !devices.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("By Device")
                            .font(.headline)
                            .padding(.horizontal)

                        Chart(devices.prefix(10)) { d in
                            BarMark(
                                x: .value("Units", d.units),
                                y: .value("Device", d.device)
                            )
                            .foregroundStyle(.blue)
                        }
                        .frame(height: CGFloat(min(devices.count, 10) * 32 + 20))
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

    /// Extract day-of-month number from a date string like "2026-03-10"
    private func dayNumber(from dateString: String) -> Int {
        let parts = dateString.split(separator: "-")
        if parts.count == 3, let day = Int(parts[2]) {
            return day
        }
        return 0
    }

    private func load() {
        clampFilterIfNeeded()
        isLoading = true
        error = nil
        Task {
            do {
                data = try await api.fetchDownloads(filter: effectiveFilter, app: selectedApp)
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }
}
