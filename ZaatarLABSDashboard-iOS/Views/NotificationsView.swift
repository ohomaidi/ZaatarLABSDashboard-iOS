import SwiftUI

struct NotificationsView: View {
    var store = NotificationStore.shared

    var body: some View {
        NavigationStack {
            Group {
                if store.notifications.isEmpty {
                    ContentUnavailableView(
                        "No Notifications",
                        systemImage: "bell.slash",
                        description: Text("Push notifications you receive will appear here.")
                    )
                } else {
                    List {
                        ForEach(store.notifications) { notification in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(notification.title)
                                    .font(.subheadline.bold())
                                Text(notification.body)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(notification.receivedAt, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 2)
                        }
                        .onDelete(perform: delete)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Notifications")
            .toolbar {
                if !store.notifications.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear All", role: .destructive) {
                            store.clearAll()
                        }
                        .font(.subheadline)
                    }
                }
            }
            .onAppear {
                store.clearBadge()
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        store.remove(at: offsets)
    }
}
