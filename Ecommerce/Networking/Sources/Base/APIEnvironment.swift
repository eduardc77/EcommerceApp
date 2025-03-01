import Foundation

public protocol APIEnvironment: APIRequestData {
    var scheme: String { get }
    var host: String { get }
    var port: Int? { get }
    var apiVersion: String? { get }
    var domain: String { get }
}

public extension APIEnvironment {
    var scheme: String { "https" }
    var host: String { "" }
    var port: Int? { nil }
    var domain: String { "" }
}
