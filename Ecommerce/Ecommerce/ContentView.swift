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
                SignInView()
            }
        }
    }
}
