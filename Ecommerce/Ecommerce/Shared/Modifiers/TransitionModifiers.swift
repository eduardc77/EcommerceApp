import SwiftUI

private struct TransitionSourceModifier: ViewModifier {
    let id: AnyHashable
    let namespace: Namespace.ID
    
    func body(content: Content) -> some View {
        content
            .matchedTransitionSource(id: id, in: namespace) { src in
                src
                    .clipShape(.rect(cornerRadius: 12))
            }
    }
}

extension View {
    func transitionSource(id: AnyHashable, namespace: Namespace.ID) -> some View {
        modifier(TransitionSourceModifier(id: id, namespace: namespace))
    }
} 
