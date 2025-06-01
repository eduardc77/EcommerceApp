import Foundation
import Observation
import Networking

@Observable
final class PersonalInformationFormState {
    // MARK: - Properties
    var displayName = ""
    var dateOfBirth: Date?
    var gender: Gender = .notSpecified
    var fieldErrors: [String: String] = [:]
    var isValid = false
    
    // MARK: - Initialization
    func initializeWith(user: UserResponse?) {
        guard let user = user else { return }
        displayName = user.displayName
        
        if let dateOfBirthString = user.dateOfBirth {
            dateOfBirth = ISO8601DateFormatter().date(from: dateOfBirthString)
        } else {
            dateOfBirth = nil
        }
        
        if let genderString = user.gender, !genderString.isEmpty {
            gender = Gender(rawValue: genderString) ?? .notSpecified
        } else {
            gender = .notSpecified
        }
        
        validateAll()
    }
    
    // MARK: - Validation
    func validateAll() {
        validateDisplayName()
        validateDateOfBirth()
        validateGender()
    }
    
    func validateDisplayName() {
        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if displayName.isEmpty {
            fieldErrors["displayName"] = "Display name is required"
        } else if trimmedDisplayName.isEmpty {
            fieldErrors["displayName"] = "Display name cannot be empty or only whitespace"
        } else if displayName.count > 100 {
            fieldErrors["displayName"] = "Display name must not exceed 100 characters"
        } else {
            fieldErrors.removeValue(forKey: "displayName")
        }
        updateValidState()
    }
    
    func validateDateOfBirth() {
        if let dateOfBirth = dateOfBirth {
            let now = Date()
            let calendar = Calendar.current
            
            if dateOfBirth > now {
                fieldErrors["dateOfBirth"] = "Date of birth cannot be in the future"
            } else if let yearsAgo = calendar.date(byAdding: .year, value: -150, to: now),
                      dateOfBirth < yearsAgo {
                fieldErrors["dateOfBirth"] = "Date of birth cannot be more than 150 years ago"
            } else {
                fieldErrors.removeValue(forKey: "dateOfBirth")
            }
        } else {
            fieldErrors.removeValue(forKey: "dateOfBirth")
        }
        updateValidState()
    }
    
    func validateGender() {
        // Gender is always valid since it's an enum with predefined values
        fieldErrors.removeValue(forKey: "gender")
        updateValidState()
    }
    
    private func updateValidState() {
        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        isValid = !trimmedDisplayName.isEmpty && 
                 trimmedDisplayName.count <= 100 && 
                 fieldErrors.isEmpty
    }
    
    // MARK: - Reset
    func reset() {
        displayName = ""
        dateOfBirth = nil
        gender = .notSpecified
        fieldErrors = [:]
        isValid = false
    }
} 