import Observation
import Networking

@Observable
@MainActor
public final class PermissionManager {
    private let authManager: AuthManager
    
    public init(authManager: AuthManager) {
        self.authManager = authManager
    }
    
    public var currentUserRole: Role? {
        authManager.currentUser?.role
    }
    
    public func hasPermission(_ permission: Permission) -> Bool {
        guard let role = currentUserRole else { return false }
        return role.permissions.contains(permission)
    }
    
    public func canManageUser(_ user: UserResponse) -> Bool {
        guard let currentUser = authManager.currentUser else { return false }
        
        // Admins can manage all users
        if currentUser.role == .admin { return true }
        
        // Users can only manage themselves
        return currentUser.id == user.id
    }
    
    public func canManageProduct(_ product: ProductResponse) -> Bool {
        guard let currentUser = authManager.currentUser else { return false }
        
        switch currentUser.role {
        case .admin:
            return true
        case .staff:
            // Staff can manage all products
            return true
        case .seller:
            // Sellers can manage their own products
            return currentUser.id == product.seller.id
        case .customer:
            return false
        }
    }
} 
