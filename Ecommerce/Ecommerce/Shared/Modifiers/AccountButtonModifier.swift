import SwiftUI

struct AccountButtonModifier: ViewModifier {
    @State private var showAccount = false
    
    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAccount = true
                    } label: {
                        Image(systemName: "person.crop.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showAccount) {
                NavigationStack {
                    AccountView()
                }
            }
    }
}

extension View {
    func withAccountButton() -> some View {
        modifier(AccountButtonModifier())
    }
} 
