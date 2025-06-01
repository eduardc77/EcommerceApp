import Foundation
import Observation

@Observable
final class RecoveryCodeFormState {
    // MARK: - Properties
    var recoveryCode = ""
    var showError = false
    var error: Error?
    var fieldErrors: [String: String] = [:]
    
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
        fieldErrors["recoveryCode"] == nil && recoveryCode.isValidRecoveryCodeFormat
    }
    
    /// Sets a validation error string in fieldErrors["recoveryCode"] if the code is invalid
    func validateCode() {
        if recoveryCode.isEmpty {
            fieldErrors["recoveryCode"] = "Recovery code is required."
        } else if !recoveryCode.isValidRecoveryCodeFormat {
            fieldErrors["recoveryCode"] = "Format: xxxx-xxxx-xxxx-xxxx"
        } else {
            fieldErrors.removeValue(forKey: "recoveryCode")
        }
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

// String extension for recovery code format validation
extension String {
    var isValidRecoveryCodeFormat: Bool {
        let pattern = "^[0-9a-zA-Z]{4}-[0-9a-zA-Z]{4}-[0-9a-zA-Z]{4}-[0-9a-zA-Z]{4}$"
        return self.range(of: pattern, options: .regularExpression) != nil
    }
} 