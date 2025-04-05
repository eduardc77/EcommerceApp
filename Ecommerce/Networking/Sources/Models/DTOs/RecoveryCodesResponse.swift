public struct RecoveryCodesResponse: Codable, Sendable {
    public let codes: [String]
    public let message: String
    public let expiresAt: String
    
    public init(codes: [String], message: String, expiresAt: String) {
        self.codes = codes
        self.message = message
        self.expiresAt = expiresAt
    }
}

public struct RecoveryCodesStatusResponse: Codable, Sendable {
    public let totalCodes: Int
    public let usedCodes: Int
    public let remainingCodes: Int
    public let expiredCodes: Int
    public let validCodes: Int
    public let shouldRegenerate: Bool
    public let nextExpirationDate: String?
    
    public init(totalCodes: Int, usedCodes: Int, remainingCodes: Int, expiredCodes: Int, validCodes: Int, shouldRegenerate: Bool, nextExpirationDate: String?) {
        self.totalCodes = totalCodes
        self.usedCodes = usedCodes
        self.remainingCodes = remainingCodes
        self.expiredCodes = expiredCodes
        self.validCodes = validCodes
        self.shouldRegenerate = shouldRegenerate
        self.nextExpirationDate = nextExpirationDate
    }
}

public struct RegenerateCodesRequest: Codable {
    public let password: String
    
    public init(password: String) {
        self.password = password
    }
}

public struct RecoveryCodeVerifyRequest: Codable {
    public let code: String
    public let stateToken: String
    
    public init(code: String, stateToken: String) {
        self.code = code
        self.stateToken = stateToken
    }
}
