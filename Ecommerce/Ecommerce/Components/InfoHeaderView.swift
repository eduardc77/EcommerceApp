import SwiftUI

import SwiftUI

struct InfoHeaderView<LinkContent: View>: View {
    let systemIcon: String
    let title: String
    let titleFont: Font
    let description: Text?
    let link: LinkContent?
    let iconSize: CGFloat
    
    // Without link
    init(
        systemIcon: String,
        title: String,
        titleFont: Font = .title2,
        description: Text? = nil,
        iconSize: CGFloat = 50
    ) where LinkContent == Never {
        self.systemIcon = systemIcon
        self.title = title
        self.titleFont = titleFont
        self.description = description
        self.link = nil
        self.iconSize = iconSize
    }
    
    // With link
    init(
        systemIcon: String,
        title: String,
        titleFont: Font = .title2,
        description: Text? = nil,
        iconSize: CGFloat = 50,
        @ViewBuilder link: () -> LinkContent
    ) {
        self.systemIcon = systemIcon
        self.title = title
        self.titleFont = titleFont
        self.description = description
        self.link = link()
        self.iconSize = iconSize
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemIcon)
                .font(.system(size: iconSize))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            
            VStack(spacing: 16) {
                Text(title)
                    .font(titleFont)
                    .fontWeight(.bold)
                
                if let description = description {
                    description
                        .font(.subheadline)
                }
                
                if let link = link {
                    link
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .foregroundStyle(.primary)
        .textCase(nil)
    }
}

#Preview {
    NavigationStack {
        VStack(spacing: 30) {
            InfoHeaderView(
                systemIcon: "qrcode.viewfinder",
                title: "Set up authenticator app"
            )
            
            // External link
            InfoHeaderView(
                systemIcon: "lock.shield.fill",
                title: "Two-Factor Authentication",
                description: Text("Add an extra layer of security to your account"),
                link: { Link("Learn more about 2FA...", destination: URL(string: "https://support.apple.com")!) }
            )
            
            // In-app navigation link
            InfoHeaderView(
                systemIcon: "person.2.circle",
                title: "Recovery Contacts",
                description: Text("Add trusted contacts to help recover your account"),
                link: { NavigationLink("Set up recovery contact...") {
                    Text("Recovery Contact Setup")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
                }
            )
            
            // Custom action button styled as link
            InfoHeaderView(
                systemIcon: "gear",
                title: "Settings",
                description: Text("Configure your account preferences"),
                link: { Button("Open settings...") {
                    print("Open settings")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
                }
            )
        }
        .padding()
    }
}
