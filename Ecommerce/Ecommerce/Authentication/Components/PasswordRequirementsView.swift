import SwiftUI

struct PasswordRequirementsFooter: View {
    let password: String
    let title: String
    
    init(password: String, title: String = "Password Requirements") {
        self.password = password
        self.title = title
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
            
            VStack(alignment: .leading, spacing: 4) {
                PasswordRequirementRow(
                    text: "At least 12 characters.",
                    isValid: !password.isEmpty && password.count >= 12
                )
                PasswordRequirementRow(
                    text: "At least 1 uppercase letter.",
                    isValid: !password.isEmpty && password.contains(where: { $0.isUppercase })
                )
                PasswordRequirementRow(
                    text: "At least 1 lowercase letters.",
                    isValid: !password.isEmpty && password.contains(where: { $0.isLowercase })
                )
                PasswordRequirementRow(
                    text: "At least 1 number.",
                    isValid: !password.isEmpty && password.contains(where: { $0.isNumber })
                )
                PasswordRequirementRow(
                    text: "At least 1 special character.",
                    isValid: !password.isEmpty && password.contains(where: { "!@#$%^&*()_+-=[]{}|;:,.<>?".contains($0) })
                )
                PasswordRequirementRow(
                    text: "No repeated, sequential, or keyboard patterns",
                    isValid: password.count >= 3 && !containsAnyPatterns(password)
                )
            }
        }
    }
}

private struct PasswordRequirementRow: View {
    let text: String
    let isValid: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            if isValid {
                Image(systemName: "checkmark")
                    .fontWeight(.bold)
                    .foregroundStyle(.green.mix(with: .black, by: 0.2))
                    .font(.footnote)
            }
            
            Text(text)
                .font(.footnote)
                .foregroundStyle(isValid ? .green.mix(with: .black, by: 0.2) : .secondary)
            
            Spacer()
        }
    }
}

private func containsProblematicPatterns(_ password: String) -> Bool {
    return containsKeyboardPattern(password) ||
    containsSequentialPattern(password) ||
    containsRepeatedCharacters(password)
}

private func containsKeyboardPattern(_ password: String) -> Bool {
    let keyboardPattern = """
        (?:qwerty|asdfgh|zxcvbn|dvorak|qwertz|azerty|
        1qaz|2wsx|3edc|4rfv|5tgb|6yhn|7ujm|8ik|9ol|0p|
        zaq1|xsw2|cde3|vfr4|bgt5|nhy6|mju7|ki8|lo9|p0|
        qayz|wsxc|edcv|rfvb|tgbn|yhnm|ujm|ikol|polp)
        """
    
    if let regex = try? NSRegularExpression(pattern: keyboardPattern, options: [.allowCommentsAndWhitespace]),
       let _ = regex.firstMatch(in: password.lowercased(), options: [], range: NSRange(location: 0, length: password.utf8.count)) {
        return true
    }
    return false
}

private func containsSequentialPattern(_ password: String) -> Bool {
    let sequentialPatterns = [
        Array("abcdefghijklmnopqrstuvwxyz"),
        Array("0123456789"),
        Array("qwertyuiop"),
        Array("asdfghjkl"),
        Array("zxcvbnm")
    ]
    
    let lowercasePassword = password.lowercased()
    for pattern in sequentialPatterns {
        let patternLength = 3
        for i in 0...(pattern.count - patternLength) {
            let slice = pattern[i..<(i + patternLength)]
            let forward = String(slice)
            let backward = String(slice.reversed())
            
            if lowercasePassword.contains(forward) || lowercasePassword.contains(backward) {
                return true
            }
        }
    }
    return false
}

private func containsRepeatedCharacters(_ password: String) -> Bool {
    let groups = Dictionary(grouping: password, by: { $0 })
    return groups.contains { $0.value.count >= 3 }
}

private func containsRepeatedOrSequentialPatterns(_ password: String) -> Bool {
    return containsRepeatedCharacters(password) || containsSequentialPattern(password)
}

private func containsAnyPatterns(_ password: String) -> Bool {
    return containsRepeatedOrSequentialPatterns(password) || containsKeyboardPattern(password)
}
