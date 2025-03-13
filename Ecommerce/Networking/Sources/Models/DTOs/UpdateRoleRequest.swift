public struct UpdateRoleRequest: Codable, Sendable {
    public let role: Role
    
    public init(role: Role) {
        self.role = role
    }
} 