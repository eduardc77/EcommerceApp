import Foundation
import JWTKit
import Hummingbird

/// JSON Web Key Set representation
public struct JWKSResponse: Codable, ResponseEncodable {
    /// The array of JWK objects
    public var keys: [JWKSKey]
    
    /// Initialize a JWKS with an array of JWK objects
    public init(keys: [JWKSKey]) {
        self.keys = keys
    }
}

/// Individual key in a JWKS
public struct JWKSKey: Codable {
    /// Key type (RSA, EC, etc.)
    public var kty: String
    
    /// Key usage
    public var use: String
    
    /// Key ID
    public var kid: String
    
    /// Algorithm
    public var alg: String
    
    /// Modulus for RSA keys
    public var n: String?
    
    /// Exponent for RSA keys
    public var e: String?
    
    /// X coordinate for EC keys
    public var x: String?
    
    /// Y coordinate for EC keys
    public var y: String?
    
    /// Curve for EC keys
    public var crv: String?
}

extension JWTKeyCollection {
    /// Export the public keys as a JWKS (JSON Web Key Set)
    /// This method creates a manual JWKS response with the current signing key
    public func jwks() async throws -> JWKSResponse {
        // Since we can't directly access the internal keys of JWTKeyCollection,
        // we'll create a basic JWKS with our known key
        
        // For HMAC key, we only expose the key ID and algorithm information
        // but not the actual key material (as that would be a security risk)
        let key = JWKSKey(
            kty: "oct",                // oct for symmetric keys
            use: "sig",                // sig for signature
            kid: "hb_local",           // Use the same key ID as in Application+build.swift
            alg: "HS256"               // Same algorithm as configured
        )
        
        return JWKSResponse(keys: [key])
    }
} 