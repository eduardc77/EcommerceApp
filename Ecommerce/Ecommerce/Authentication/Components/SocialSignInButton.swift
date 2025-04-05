import SwiftUI

struct SocialSignInButton: View {
    let title: String
    let action: () async throws -> Void
    @State private var isLoading = false
    @State private var error: Error?
    
    var body: some View {
        Button {
            Task {
                isLoading = true
                defer { isLoading = false }
                do {
                    try await action()
                } catch {
                    self.error = error
                }
            }
        } label: {
            HStack {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(title)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isLoading)
        .alert("Sign In Failed", isPresented: .init(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("OK") {
                error = nil
            }
        } message: {
            if let error {
                Text(error.localizedDescription)
            }
        }
    }
} 