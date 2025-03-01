//
//  ContentView.swift
//  Ecommerce
//

import SwiftUI

struct ContentView: View {
    @Environment(AuthenticationManager.self) private var authManager

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .overlay {
            if authManager.isLoading {
                ProgressView("Checking session...")
                    .controlSize(.large)
            }
        }
        .alert("Session Error", isPresented: .constant(authManager.error != nil)) {
            Button("OK") {
                authManager.error = nil
            }
        } message: {
            if let error = authManager.error {
                Text(error.localizedDescription)
            }
        }
    }
}
