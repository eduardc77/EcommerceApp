import SwiftUI

struct TOTPIntroView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    InfoHeaderView(
                        systemIcon: "lock.shield.fill",
                        title: "Authenticator App",
                        titleFont: .title,
                        description: Text("""
                        Time-based One-Time Password Authenticator adds an extra layer of security to your account by requiring both your password and a verification code from an authenticator app.
                        
                        You'll need an authenticator app like Google Authenticator, Microsoft Authenticator, or Authy to complete setup.
                        """),
                        iconSize: 70,
                        link: {
                            Link("Learn more", destination: URL(string: "https://support.apple.com")!)
                                .font(.callout)
                                .accessibilityLabel("Learn more about authenticator app")
                        }
                    )
                }
                .frame(maxWidth: .infinity)
                .listRowInsets(.init(top: 0, leading: 10, bottom: 0, trailing: 10))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .contentMargins(.top, 16, for: .scrollContent)
            .safeAreaInset(edge: .bottom) {
                NavigationLink {
                    TOTPSetupView()
                } label: {
                    Text("Continue")
                        .fontWeight(.medium)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding([.horizontal, .bottom], 20)
                .accessibilityHint("Proceed to the next step")
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .interactiveDismissDisabled()
        }
    }
}
