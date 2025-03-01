import Foundation

/**
 This enum defines various HTTP methods used in network requests.
 
 Each case represents a different HTTP method, which can be used to specify the desired action to be performed on the resource identified by the given URL.
 */
public enum HTTPMethod: String, CaseIterable, Identifiable {
    /// The CONNECT method establishes a tunnel to the server identified by the target resource.
    case connect
    
    /// The DELETE method deletes the specified resource.
    case delete
    
    /// The GET method requests a representation of the specified resource. Requests using GET should only retrieve data.
    case get
    
    /// The HEAD method asks for a response identical to that of a GET request, but without the response body.
    case head
    
    /// The OPTIONS method is used to describe the communication options for the target resource.
    case options
    
    /// The PATCH method is used to apply partial modifications to a resource.
    case patch
    
    /// The POST method is used to submit an entity to the specified resource, often causing a change in state or side effects on the server.
    case post
    
    /// The PUT method replaces all current representations of the target resource with the request payload.
    case put
    
    /// The TRACE method performs a message loop-back test along the path to the target resource.
    case trace
    
    /// The unique HTTP method identifier.
    public var id: String { rawValue }
    
    /// The uppercased HTTP method name.
    public var method: String { id.uppercased() }
}

extension HTTPMethod: Sendable {}
