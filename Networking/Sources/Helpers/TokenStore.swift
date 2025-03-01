import Foundation
import KeychainSwift
import OSLog

public protocol TokenStoreProtocol: Actor {
    func getToken() async throws -> OAuthToken?
    func setToken(_ token: OAuthToken) async throws
    func deleteToken() async
    func invalidateToken() async throws
}

public actor TokenStore: TokenStoreProtocol {
    private let keychain: KeychainSwift
    private let tokenKey = "auth_token"
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()

    public init() {
        self.keychain = KeychainSwift()
    }

    public func getToken() async throws -> OAuthToken? {
        guard let tokenData = keychain.getData(tokenKey) else {
            return nil
        }
        do {
            return try jsonDecoder.decode(Token.self, from: tokenData)
        } catch {
            throw NetworkError.decodingError(description: "Failed to decode token: \(error.localizedDescription)")
        }
    }
    
    public func setToken(_ token: OAuthToken) async throws {
        do {
            let tokenData = try JSONEncoder().encode(token)
            if !keychain.set(tokenData, forKey: tokenKey) {
                throw NetworkError.encodingError(description: "Failed to save token")
            }
        } catch {
            throw NetworkError.encodingError(description: "Failed to encode token: \(error.localizedDescription)")
        }
    }
    
    public func deleteToken() async {
        keychain.delete(tokenKey)
    }
    
    public func invalidateToken() async throws {
        if !keychain.delete(tokenKey) {
            throw NetworkError.custom(description: "Failed to delete token")
        }
        Logger.networking.info("Token invalidated")
    }
}
