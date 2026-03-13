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

    func add(title: String, body: String) {
        let notification = StoredNotification(
            id: UUID().uuidString,
            title: title,
            body: body,
            receivedAt: Date()
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
        saveNotification(notification)
        completionHandler([.banner, .sound, .badge])
    }

    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        saveNotification(response.notification)
        completionHandler()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        Task { @MainActor in
            NotificationStore.shared.clearBadge()
        }
    }

    private var savedNotificationIDs = Set<String>()

    private func saveNotification(_ notification: UNNotification) {
        let requestID = notification.request.identifier
        guard !savedNotificationIDs.contains(requestID) else { return }
        savedNotificationIDs.insert(requestID)

        let content = notification.request.content
        let title = content.title
        let body = content.body
        guard !title.isEmpty || !body.isEmpty else { return }
        Task { @MainActor in
            NotificationStore.shared.add(title: title, body: body)
        }
    }
}
