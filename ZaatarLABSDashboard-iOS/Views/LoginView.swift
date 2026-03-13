import SwiftUI

struct LoginView: View {
    @EnvironmentObject var api: APIService
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 60))
                        .foregroundStyle(.green)

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
}
