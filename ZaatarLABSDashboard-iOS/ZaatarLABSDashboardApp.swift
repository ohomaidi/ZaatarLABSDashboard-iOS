import SwiftUI

@main
struct ZaatarLABSDashboardApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var api = APIService.shared
    @State private var didLogout = false

    var body: some Scene {
        WindowGroup {
            if api.isAuthenticated {
                MainTabView()
                    .environmentObject(api)
                    .onAppear {
                        // Re-register device token after login
                        if let token = UserDefaults.standard.string(forKey: "apns_device_token") {
                            Task { await api.registerDeviceToken(token) }
                        }
                    }
            } else {
                LoginView(autoPromptBiometrics: !didLogout)
                    .environmentObject(api)
            }
        }
        .onChange(of: api.isAuthenticated) { oldValue, newValue in
            if oldValue == true && newValue == false {
                didLogout = true
            } else if newValue == true {
                didLogout = false
            }
        }
    }
}
