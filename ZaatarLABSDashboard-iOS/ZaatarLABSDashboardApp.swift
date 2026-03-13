import SwiftUI

@main
struct ZaatarLABSDashboardApp: App {
    @StateObject private var api = APIService.shared
    @State private var didLogout = false

    var body: some Scene {
        WindowGroup {
            if api.isAuthenticated {
                MainTabView()
                    .environmentObject(api)
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
