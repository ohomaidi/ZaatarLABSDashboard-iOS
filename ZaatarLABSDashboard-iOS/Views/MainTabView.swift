import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var api: APIService
    @State var selectedFilter: DateRangeFilter = .allTime
    @State var selectedApp: String? = nil
    @State var apps: [AppInfo] = []

    var body: some View {
        TabView {
            OverviewView(filter: $selectedFilter, selectedApp: $selectedApp, apps: $apps)
                .tabItem {
                    Label("Overview", systemImage: "chart.pie")
                }

            SubscribersView(filter: $selectedFilter, selectedApp: $selectedApp)
                .tabItem {
                    Label("Subscribers", systemImage: "person.3")
                }

            AppleDataView(filter: $selectedFilter, selectedApp: $selectedApp)
                .tabItem {
                    Label("Apple Data", systemImage: "apple.logo")
                }

            AppReportingView(filter: $selectedFilter, selectedApp: $selectedApp)
                .tabItem {
                    Label("Reporting", systemImage: "app.badge")
                }

            ActivityView(filter: $selectedFilter, selectedApp: $selectedApp)
                .tabItem {
                    Label("Activity", systemImage: "clock.arrow.circlepath")
                }

            RetentionView(filter: $selectedFilter, selectedApp: $selectedApp)
                .tabItem {
                    Label("Retention", systemImage: "arrow.triangle.2.circlepath")
                }
        }
        .tint(.green)
    }
}

// MARK: - Shared Components

struct AppPicker: View {
    @Binding var selectedApp: String?
    let apps: [AppInfo]

    var body: some View {
        if true { // apps.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    appChip(label: "All Apps", value: nil)
                    ForEach(apps) { app in
                        appChip(label: app.displayName, value: app.bundleId)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    private func appChip(label: String, value: String?) -> some View {
        Button {
            selectedApp = value
        } label: {
            Text(label)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(selectedApp == value ? Color.green : Color(.systemGray5))
                .foregroundStyle(selectedApp == value ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

struct FilterPicker: View {
    @Binding var filter: DateRangeFilter

    var body: some View {
        Picker("Period", selection: $filter) {
            ForEach(DateRangeFilter.allCases, id: \.self) { f in
                Text(f.rawValue).tag(f)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String?
    var color: Color = .primary

    init(_ title: String, value: String, subtitle: String? = nil, color: Color = .primary) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.color = color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(value)
                .font(.title2.bold())
                .foregroundStyle(color)

            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct LoadingOrError: View {
    let isLoading: Bool
    let error: String?
    let retry: () -> Void

    var body: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error {
            ContentUnavailableView {
                Label("Error", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error)
            } actions: {
                Button("Retry", action: retry)
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
            }
        }
    }
}
