import Hummingbird

extension Router {
    /// Creates a versioned API group
    /// - Parameter version: The API version to use
    /// - Returns: RouterGroup for chaining
    func apiGroup(version: APIVersion) -> RouterGroup<Context> {
        return self.group(.init("api"))
            .group(.init(version.pathComponent))
    }
    
    /// Creates a versioned API group with the current API version
    /// - Returns: RouterGroup for chaining
    func currentAPIGroup() -> RouterGroup<Context> {
        return apiGroup(version: .current)
    }
} 