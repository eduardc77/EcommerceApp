public struct SessionResponse: Codable, Sendable, Identifiable {
    public let id: String
    public let deviceName: String
    public let ipAddress: String
    public let userAgent: String
    public let lastUsedAt: String
    public let createdAt: String
    public let isCurrent: Bool
    
    public init(id: String, deviceName: String, ipAddress: String, userAgent: String, lastUsedAt: String, createdAt: String, isCurrent: Bool) {
        self.id = id
        self.deviceName = deviceName
        self.ipAddress = ipAddress
        self.userAgent = userAgent
        self.lastUsedAt = lastUsedAt
        self.createdAt = createdAt
        self.isCurrent = isCurrent
    }
}

public struct SessionListResponse: Codable, Sendable {
    public let sessions: [SessionResponse]
    public let currentSessionId: String?
    
    public init(sessions: [SessionResponse], currentSessionId: String?) {
        self.sessions = sessions
        self.currentSessionId = currentSessionId
    }
} 
