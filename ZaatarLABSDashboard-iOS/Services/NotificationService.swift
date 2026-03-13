import UIKit
import SwiftUI
import UserNotifications

@MainActor
@Observable
class NotificationStore {
    static let shared = NotificationStore()

    var notifications: [StoredNotification] = []
    var unreadCount: Int = 0

    private let storageKey = "stored_notifications"
    private let unreadKey = "unread_notification_count"

    private init() {
        loadNotifications()
        removeOlderThan30Days()
        unreadCount = UserDefaults.standard.integer(forKey: unreadKey)
    }

    func add(id: String = UUID().uuidString, title: String, body: String, date: Date = Date()) {
        // Skip if already stored
        guard !notifications.contains(where: { $0.id == id }) else { return }
        let notification = StoredNotification(
            id: id,
            title: title,
            body: body,
            receivedAt: date
        )
        notifications.insert(notification, at: 0)
        unreadCount += 1
        save()
        UserDefaults.standard.set(unreadCount, forKey: unreadKey)
        UNUserNotificationCenter.current().setBadgeCount(unreadCount)
    }

    func clearBadge() {
        unreadCount = 0
        UserDefaults.standard.set(0, forKey: unreadKey)
        UNUserNotificationCenter.current().setBadgeCount(0)
    }

    func remove(at offsets: IndexSet) {
        notifications.remove(atOffsets: offsets)
        save()
    }

    func clearAll() {
        notifications.removeAll()
        clearBadge()
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(notifications) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadNotifications() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([StoredNotification].self, from: data) else { return }
        notifications = saved
    }

    /// Sync any delivered notifications from the notification center that we haven't stored yet.
    /// This catches notifications received while the app was killed or in the background
    /// that the user didn't tap on (so didReceive never fired).
    func syncDeliveredNotifications() {
        UNUserNotificationCenter.current().getDeliveredNotifications { [weak self] delivered in
            let existingIDs = Set((self?.notifications ?? []).map { $0.id })
            var newItems: [StoredNotification] = []
            for notification in delivered {
                let id = notification.request.identifier
                guard !existingIDs.contains(id) else { continue }
                let content = notification.request.content
                guard !content.title.isEmpty || !content.body.isEmpty else { continue }
                newItems.append(StoredNotification(
                    id: id,
                    title: content.title,
                    body: content.body,
                    receivedAt: notification.date
                ))
            }
            guard !newItems.isEmpty else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                // Sort newest first, insert at top
                let sorted = newItems.sorted { $0.receivedAt > $1.receivedAt }
                self.notifications.insert(contentsOf: sorted, at: 0)
                self.unreadCount += sorted.count
                self.save()
                UserDefaults.standard.set(self.unreadCount, forKey: self.unreadKey)
            }
        }
    }

    private func removeOlderThan30Days() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let before = notifications.count
        notifications.removeAll { $0.receivedAt < cutoff }
        if notifications.count != before { save() }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        requestNotificationPermission()
        return true
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            if let error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("APNs device token: \(token)")
        UserDefaults.standard.set(token, forKey: "apns_device_token")

        Task {
            await APIService.shared.registerDeviceToken(token)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }

    // Show notification banner even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        storeNotification(notification)
        completionHandler([.banner, .sound, .badge])
    }

    // Handle notification tap (from background/locked)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        storeNotification(response.notification)
        completionHandler()
    }

    private var savedIDs = Set<String>()

    private func storeNotification(_ notification: UNNotification) {
        let id = notification.request.identifier
        guard !savedIDs.contains(id) else { return }
        savedIDs.insert(id)

        let content = notification.request.content
        let title = content.title
        let body = content.body
        guard !title.isEmpty || !body.isEmpty else { return }
        let date = notification.date
        Task { @MainActor in
            NotificationStore.shared.add(id: id, title: title, body: body, date: date)
        }
    }
}
