public extension String {
    func maskEmail() -> String {
        let components = self.split(separator: "@")
        guard components.count == 2 else { return self }
        
        let name = String(components[0])
        let domain = String(components[1])
        
        let maskedName: String
        if name.count <= 2 {
            maskedName = String(repeating: "*", count: name.count)
        } else {
            maskedName = name.prefix(2) + String(repeating: "*", count: name.count - 2)
        }
        
        return maskedName + "@" + domain
    }
} 
