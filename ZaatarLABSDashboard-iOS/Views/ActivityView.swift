import SwiftUI
import Charts

struct ActivityView: View {
    @EnvironmentObject var api: APIService
    @Binding var filter: DateRangeFilter
    @Binding var selectedApp: String?

    @State private var timeline: TimelineResponse?
    @State private var trends: [TrendMonth]?
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && timeline == nil {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error, timeline == nil {
                    LoadingOrError(isLoading: false, error: error, retry: load)
                } else {
                    content
                }
            }
            .navigationTitle("Activity")
        }
        .task { load() }
        .onChange(of: filter) { load() }
        .onChange(of: selectedApp) { load() }
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(spacing: 16) {
                FilterPicker(filter: $filter)

                // Monthly trends chart
                if let trends, !trends.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Monthly Trends")
                            .font(.headline)
                            .padding(.horizontal)

                        Chart {
                            ForEach(trends) { t in
                                LineMark(
                                    x: .value("Month", t.month),
                                    y: .value("Revenue", t.revenue)
                                )
                                .foregroundStyle(.green)
                                .symbol(.circle)
                            }
                        }
                        .frame(height: 200)
                        .padding(.horizontal)
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 5))
                        }

                        // Summary row
                        Chart {
                            ForEach(trends.suffix(6)) { t in
                                BarMark(
                                    x: .value("Month", t.month),
                                    y: .value("Count", t.subscribed)
                                )
                                .foregroundStyle(.green)
                                .position(by: .value("Type", "Subscribed"))

                                BarMark(
                                    x: .value("Month", t.month),
                                    y: .value("Count", t.expired)
                                )
                                .foregroundStyle(.red.opacity(0.6))
                                .position(by: .value("Type", "Expired"))
                            }
                        }
                        .frame(height: 150)
                        .padding(.horizontal)
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 5))
                        }
                        .chartForegroundStyleScale([
                            "Subscribed": Color.green,
                            "Expired": Color.red.opacity(0.6),
                        ])
                    }
                    .padding(.vertical, 12)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }

                // Recent timeline
                if let timeline, !timeline.timeline.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent Events (\(timeline.total))")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(timeline.timeline.prefix(50)) { event in
                            HStack {
                                eventIcon(event.type)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(event.type)
                                            .font(.caption.bold())
                                        if let sub = event.subtype, !sub.isEmpty {
                                            Text("(\(sub))")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Text(event.productName ?? event.productId ?? "—")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if let date = event.storedAt ?? event.purchaseDate {
                                        Text(date.shortDate)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    if let price = event.price, price > 0 {
                                        Text("$\(String(format: "%.2f", price / 1000))")
                                            .font(.caption.bold())
                                            .foregroundStyle(.green)
                                    }
                                    if let country = event.storefront {
                                        Text(country)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(.horizontal)

                            if event.id != timeline.timeline.prefix(50).last?.id {
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

    @ViewBuilder
    private func eventIcon(_ type: String) -> some View {
        switch type {
        case "SUBSCRIBED":
            Image(systemName: "plus.circle.fill").foregroundStyle(.green)
        case "DID_RENEW":
            Image(systemName: "arrow.triangle.2.circlepath.circle.fill").foregroundStyle(.blue)
        case "EXPIRED", "GRACE_PERIOD_EXPIRED":
            Image(systemName: "clock.badge.xmark").foregroundStyle(.secondary)
        case "REFUND", "REVOKE":
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        case "DID_FAIL_TO_RENEW":
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        case "DID_CHANGE_RENEWAL_STATUS":
            Image(systemName: "arrow.left.arrow.right.circle").foregroundStyle(.yellow)
        default:
            Image(systemName: "circle.fill").foregroundStyle(.secondary)
        }
    }

    private func load() {
        isLoading = true
        error = nil
        Task {
            do {
                async let t = api.fetchTimeline(filter: filter, app: selectedApp)
                async let tr = api.fetchTrends(filter: filter, app: selectedApp)
                timeline = try await t
                trends = try await tr
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }
}
