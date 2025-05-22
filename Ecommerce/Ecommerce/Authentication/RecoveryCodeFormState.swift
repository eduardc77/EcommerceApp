import Foundation
import Observation

@Observable
final class RecoveryCodeFormState {
    // MARK: - Properties
    var recoveryCode = ""
    var showError = false
    var error: Error?
    
    // Format: xxxx-xxxx-xxxx-xxxx
    private let codeLength = 19
    private let groupSize = 4
    private let separator = "-"
    
    // MARK: - Computed Properties
    var formattedCode: String {
        let cleaned = recoveryCode.filter { $0.isNumber || $0.isLetter }
        var result = ""
        var index = 0
        
        for char in cleaned {
            if index > 0 && index % groupSize == 0 && index < 16 {
                result += separator
            }
            result.append(char)
            index += 1
        }
        
        return String(result.prefix(codeLength))
    }
    
    var isValidFormat: Bool {
        let cleaned = recoveryCode.filter { $0.isNumber || $0.isLetter }
        return cleaned.count == 16
    }
    
    // MARK: - Methods
    func setError(_ error: Error?) {
        self.error = error
        self.showError = error != nil
    }
    
    func reset() {
        recoveryCode = ""
        showError = false
        error = nil
    }
} 