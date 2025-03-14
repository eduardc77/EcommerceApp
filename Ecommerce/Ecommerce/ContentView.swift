//
//  ContentView.swift
//  Ecommerce
//

import SwiftUI

enum AppFlow {
    case login
    case main
}

struct ContentView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @State private var currentFlow: AppFlow = .login

    var body: some View {
        Group {
            switch currentFlow {
            case .login:
                LoginView()
            case .main:
                MainTabView()
            }
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
            updateFlow()
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

    private func updateFlow() {
        if authManager.isAuthenticated {
            currentFlow = .main
        } else {
            currentFlow = .login
        }
    }
}
