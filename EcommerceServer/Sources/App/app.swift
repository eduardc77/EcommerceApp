import ArgumentParser
import Dispatch

@main
struct HummingbirdArguments: AsyncParsableCommand, AppArguments {
    static var env: Void = {
        setenv("APP_ENV", "testing", 1)
        return ()
    }()
    
    @Option(name: .shortAndLong)
    var hostname: String = "127.0.0.1"
    
    @Option(name: .shortAndLong)
    var port: Int = 8080
    
    @Flag(name: .shortAndLong)
    var migrate: Bool = false
    
    @Flag(name: .shortAndLong)
    var inMemoryDatabase: Bool = false
    
    func run() async throws {
        let app = try await buildApplication(self)
        try await app.runService()
    }
}

// Add multipart form support to AppRequestContext
extension AppRequestContext {
    var multipartDecoder: MultipartRequestDecoder { .init() }
    var multipartEncoder: MultipartResponseEncoder { .init() }
    var maxUploadSize: Int { 10_000_000 } // 10MB limit
}
