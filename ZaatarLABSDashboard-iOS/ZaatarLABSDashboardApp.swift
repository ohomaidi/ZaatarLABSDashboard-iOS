import SwiftUI

@main
struct ZaatarLABSDashboardApp: App {
    @StateObject private var api = APIService.shared

    var body: some Scene {
        WindowGroup {
            if api.isAuthenticated {
                MainTabView()
                    .environmentObject(api)
            } else {
                LoginView()
                    .environmentObject(api)
            }
        }
    }
}
