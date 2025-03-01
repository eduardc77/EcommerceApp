import SwiftUI

public enum ToastType {
    case addedToCart
    case addedToFavorites
    case removedFromFavorites
    
    var icon: String {
        switch self {
        case .addedToCart:
            "checkmark.circle.fill"
        case .addedToFavorites:
            "heart.fill"
        case .removedFromFavorites:
            "heart.slash.fill"
        }
    }
    
    var message: String {
        switch self {
        case .addedToCart:
            "Added to Cart"
        case .addedToFavorites:
            "Added to Favorites"
        case .removedFromFavorites:
            "Removed from Favorites"
        }
    }
    
    var color: Color {
        switch self {
        case .addedToCart:
            .green
        case .addedToFavorites:
            .pink
        case .removedFromFavorites:
            .secondary
        }
    }
}

public struct Toast: Identifiable {
    public let id = UUID()
    public let type: ToastType
    
    public init(type: ToastType) {
        self.type = type
    }
}

@Observable
public final class ToastManager {
    public private(set) var toast: Toast?
    private var dismissTask: Task<Void, Never>?
    
    public init() {}
    
    public func show(_ type: ToastType) {
        // Cancel any existing dismiss task
        dismissTask?.cancel()
        
        withAnimation {
            toast = Toast(type: type)
        }
        
        // Schedule new dismiss task
        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            
            withAnimation {
                toast = nil
            }
        }
    }
}

struct ToastContainer: View {
    @Environment(ToastManager.self) private var manager
    
    var body: some View {
        if let toast = manager.toast {
            VStack {
                Spacer()
                HStack(spacing: 8) {
                    Image(systemName: toast.type.icon)
                        .foregroundStyle(toast.type.color)
                        .font(.title3)
                    Text(toast.type.message)
                        .font(.subheadline.weight(.medium))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.thinMaterial, in: .rect(cornerRadius: 12))
                .padding(.horizontal)
                .padding(.bottom, 10)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

private struct BoundsPreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
} 
