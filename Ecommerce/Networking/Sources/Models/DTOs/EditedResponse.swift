public struct EditedResponse<T: Decodable>: Decodable {
    public let status: Int
    public let response: T
    
    public init(status: Int, response: T) {
        self.status = status
        self.response = response
    }
} 