import SwiftUI

struct SubscribersView: View {
    @EnvironmentObject var api: APIService
    @Binding var filter: DateRangeFilter
    @Binding var selectedApp: String?
    @Binding var apps: [AppInfo]

    @State private var data: SubscribersResponse?
    @State private var isLoading = false
    @State private var error: String?
    @State private var selectedSubscriber: Subscriber?
    @State private var statusFilter: String?

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
            .navigationTitle("Subscribers")
            .sheet(item: $selectedSubscriber) { sub in
                SubscriberDetailView(subscriberId: sub.subscriberId)
            }
        }
        .task { load() }
        .onChange(of: filter) { load() }
        .onChange(of: selectedApp) { load() }
    }

    @ViewBuilder
    private func content(_ data: SubscribersResponse) -> some View {
        List {
            Section {
                AppPicker(selectedApp: $selectedApp, apps: apps)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section {
                FilterPicker(filter: $filter)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section {
                HStack {
                    Text("Total: \(data.total)")
                        .font(.subheadline.bold())
                    Spacer()
                    Menu {
                        Button("All") { statusFilter = nil; load() }
                        ForEach(["active", "expired", "cancelling", "billing_issue", "refunded"], id: \.self) { s in
                            Button(s.capitalized) { statusFilter = s; load() }
                        }
                    } label: {
                        Label(statusFilter?.capitalized ?? "Filter", systemImage: "line.3.horizontal.decrease.circle")
                            .font(.subheadline)
                    }
                }
            }

            Section {
                ForEach(data.subscribers) { sub in
                    Button { selectedSubscriber = sub } label: {
                        subscriberRow(sub)
                    }
                    .tint(.primary)
                }
            }
        }
        .refreshable { load() }
    }

    @ViewBuilder
    private func subscriberRow(_ sub: Subscriber) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(sub.productName)
                    .font(.subheadline.bold())
                Spacer()
                StatusBadge(status: sub.status)
            }

            HStack {
                Label(sub.storefront, systemImage: "globe")
                Spacer()
                Text("$\(String(format: "%.2f", sub.totalRevenue))")
                    .font(.subheadline.bold())
                    .foregroundStyle(.green)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack {
                Text("Since \(sub.firstPurchase.shortDateOnly)")
                Spacer()
                if sub.autoRenew {
                    Label("Auto-renew", systemImage: "arrow.triangle.2.circlepath")
                        .foregroundStyle(.green)
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func load() {
        isLoading = true
        error = nil
        Task {
            do {
                data = try await api.fetchSubscribers(filter: filter, app: selectedApp, status: statusFilter)
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: String

    var color: Color {
        switch status {
        case "active": return .green
        case "expired": return .secondary
        case "cancelling": return .orange
        case "billing_issue": return .red
        case "refunded": return .red
        default: return .secondary
        }
    }

    var body: some View {
        Text(status.capitalized)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

// MARK: - Detail View

struct SubscriberDetailView: View {
    @EnvironmentObject var api: APIService
    let subscriberId: String

    @State private var detail: SubscriberDetail?
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error {
                    LoadingOrError(isLoading: false, error: error) { load() }
                } else if let detail {
                    detailContent(detail)
                }
            }
            .navigationTitle("Subscriber")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { load() }
    }

    @ViewBuilder
    private func detailContent(_ d: SubscriberDetail) -> some View {
        List {
            Section("Info") {
                LabeledContent("Plan", value: d.currentProductName ?? "—")
                LabeledContent("Status", value: d.status?.capitalized ?? "—")
                LabeledContent("Tier", value: d.tier ?? "—")
                LabeledContent("Country", value: d.storefront ?? "—")
                LabeledContent("Revenue", value: "$\(String(format: "%.2f", d.totalRevenue ?? 0))")
                if let auto = d.autoRenew {
                    LabeledContent("Auto-Renew", value: auto ? "Yes" : "No")
                }
                if let exp = d.expiresDate {
                    LabeledContent("Expires", value: exp.shortDate)
                }
            }

            Section("Events (\(d.events.count))") {
                ForEach(d.events) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(event.type)
                                .font(.caption.bold())
                            Spacer()
                            if let price = event.price, price > 0 {
                                Text("$\(String(format: "%.2f", price / 1000))")
                                    .font(.caption.bold())
                                    .foregroundStyle(.green)
                            }
                        }
                        if let date = event.storedAt ?? event.purchaseDate {
                            Text(date.shortDate)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if let sub = event.subtype, !sub.isEmpty {
                            Text(sub)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func load() {
        isLoading = true
        Task {
            do {
                detail = try await api.fetchSubscriberDetail(id: subscriberId)
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }
}
