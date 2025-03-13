import Foundation

extension Store {
    public enum File: APIEndpoint {
        case upload(file: FileData, filename: String?)
        case download(filename: String)
        
        public var path: String {
            switch self {
            case .upload:
                return "/files"
            case .download(let filename):
                return "/files/\(filename)"
            }
        }
        
        public var httpMethod: HTTPMethod {
            switch self {
            case .upload:
                return .post
            case .download:
                return .get
            }
        }
        
        public var requestBody: Any? {
            switch self {
            case .upload(let file, _):
                return file.data
            case .download:
                return nil
            }
        }
        
        public var formParams: [String: String]? {
            switch self {
            case .upload(_, let filename):
                if let filename = filename {
                    return ["File-Name": filename]
                }
                return nil
            case .download:
                return nil
            }
        }
    }
} 