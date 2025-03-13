public protocol AuthServiceProtocol {
    // ... existing code ...
    func changePassword(_ request: ChangePasswordRequest) async throws -> MessageResponse
    func forgotPassword(_ request: ForgotPasswordRequest) async throws -> MessageResponse
    func resetPassword(_ request: ResetPasswordRequest) async throws -> MessageResponse
}

public actor AuthService: AuthServiceProtocol {
    // ... existing code ...
    
    public func changePassword(_ request: ChangePasswordRequest) async throws -> MessageResponse {
        try await networkManager.request(
            endpoint: Store.Authentication.changePassword(current: request.currentPassword, new: request.newPassword),
            method: .post,
            requiresAuthorization: true
        )
    }
    
    public func forgotPassword(_ request: ForgotPasswordRequest) async throws -> MessageResponse {
        try await networkManager.request(
            endpoint: Store.Authentication.forgotPassword(email: request.email),
            method: .post,
            requiresAuthorization: false
        )
    }
    
    public func resetPassword(_ request: ResetPasswordRequest) async throws -> MessageResponse {
        try await networkManager.request(
            endpoint: Store.Authentication.resetPassword(email: request.email, code: request.code, newPassword: request.newPassword),
            method: .post,
            requiresAuthorization: false
        )
    }
} 