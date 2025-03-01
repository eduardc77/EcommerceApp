import Foundation

/// User role for access control
public enum Role: String, Codable, Sendable {
    /// Full system access - can manage everything
    case admin = "admin"
    /// Limited admin access for customer support and order processing
    case staff = "staff"
    /// Can manage their own store, products, and orders
    case seller = "seller"
    /// Regular user who can browse and purchase
    case customer = "customer"

    /// Default role for new users
    static var `default`: Role { .customer }

    /// Check if this role has administrative privileges
    var isAdmin: Bool {
        switch self {
        case .admin:
            return true
        case .staff, .seller, .customer:
            return false
        }
    }

    /// Check if this role can manage products
    var canManageProducts: Bool {
        switch self {
        case .admin, .staff:
            return true
        case .seller:
            return true
        case .customer:
            return false
        }
    }

    /// Check if this role can process orders
    var canProcessOrders: Bool {
        switch self {
        case .admin, .staff, .seller:
            return true
        case .customer:
            return false
        }
    }

    /// Check if this role can access customer support features
    var canAccessSupport: Bool {
        switch self {
        case .admin, .staff:
            return true
        case .seller, .customer:
            return false
        }
    }

    /// Get the permissions for this role
    var permissions: Set<Permission> {
        switch self {
        case .admin:
            return Set(Permission.allCases)
        case .staff:
            return [.viewProducts, .manageAllProducts, .viewUsers, .manageUsers]
        case .seller:
            return [.viewProducts, .manageOwnProducts, .viewUsers]
        case .customer:
            return [.viewProducts, .viewUsers]
        }
    }
} 