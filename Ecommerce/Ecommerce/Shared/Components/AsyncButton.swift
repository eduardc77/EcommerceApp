import SwiftUI

public struct AsyncButton<Label: View>: View {
    public var role: ButtonRole? = nil
    public var font: Font = .headline
    public var action: () async -> Void
    @ViewBuilder public let label: () -> Label

    @MainActor
    @State private var isRunning = false

    public var body: some View {
        Button(role: role) {
            isRunning = true
            Task {
                await action()
                isRunning = false
            }
        } label: {
            Group {
                if isRunning {
                    ProgressView()
                } else {
                    label()
                        .font(font)
                }
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
        }
        .disabled(isRunning)
    }
}

public extension AsyncButton where Label == Text {
    init(
        _ titleKey: LocalizedStringKey,
        role: ButtonRole? = nil,
        font: Font = .headline,
        action: @escaping () async -> Void
    ) {
        self.init(role: role, font: font, action: action) { Text(titleKey) }
    }
}

#Preview {
    AsyncButton("Async Task") {
        try? await Task.sleep(nanoseconds: 6_000_000_000)
    }
    .padding()
}
