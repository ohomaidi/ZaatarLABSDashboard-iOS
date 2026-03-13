import SwiftUI
import LocalAuthentication

struct LoginView: View {
    @EnvironmentObject var api: APIService
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    /// Controls whether Face ID auto-triggers on appear
    var autoPromptBiometrics: Bool = true

    /// Whether a saved password exists so we can offer biometric login
    private var hasSavedPassword: Bool {
        api.hasSavedPassword
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Logo on black background
                VStack(spacing: 12) {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 24))

                    Text("ZaatarLABS")
                        .font(.largeTitle.bold())

                    Text("Dashboard")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 16) {
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.password)
                        .submitLabel(.go)
                        .onSubmit { login() }

                    Button(action: login) {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Sign In")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .controlSize(.large)
                    .disabled(password.isEmpty || isLoading)

                    if hasSavedPassword {
                        Button(action: authenticateWithBiometrics) {
                            Label("Sign in with Face ID", systemImage: "faceid")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.green)
                        .controlSize(.large)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 40)

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            if hasSavedPassword && autoPromptBiometrics {
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    authenticateWithBiometrics()
                }
            }
        }
    }

    private func login() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await api.login(password: password)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func authenticateWithBiometrics() {
        let context = LAContext()
        var authError: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) else {
            errorMessage = "Biometric authentication not available"
            return
        }

        isLoading = true
        errorMessage = nil

        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Sign in to ZaatarLABS Dashboard") { success, error in
            Task { @MainActor in
                if success {
                    do {
                        try await api.loginWithSavedPassword()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                } else if let error {
                    errorMessage = error.localizedDescription
                }
                isLoading = false
            }
        }
    }
}
