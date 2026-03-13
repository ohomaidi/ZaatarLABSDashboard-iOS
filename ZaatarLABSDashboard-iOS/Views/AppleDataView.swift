import SwiftUI
import Charts

struct AppleDataView: View {
    @EnvironmentObject var api: APIService
    @Binding var filter: DateRangeFilter
    @Binding var selectedApp: String?

    @State private var data: DownloadsResponse?
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
        .task { load() }
        .onChange(of: filter) { load() }
        .onChange(of: selectedApp) { load() }
    }

    @ViewBuilder
    private func content(_ data: DownloadsResponse) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                FilterPicker(filter: $filter)

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

                        Chart(daily.suffix(30)) { day in
                            BarMark(
                                x: .value("Date", day.date),
                                y: .value("Downloads", day.downloads)
                            )
                            .foregroundStyle(.green)
                        }
                        .frame(height: 200)
                        .padding(.horizontal)
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 5))
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

    private func load() {
        isLoading = true
        error = nil
        Task {
            do {
                data = try await api.fetchDownloads(filter: filter, app: selectedApp)
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }
}
