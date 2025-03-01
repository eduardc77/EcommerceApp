import Foundation

/// Available permissions for roles
public enum Permission: String, Codable, CaseIterable {
    case viewProducts
    case manageOwnProducts
    case manageAllProducts
    case viewUsers
    case manageUsers
    case manageRoles
} 