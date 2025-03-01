import Foundation

extension String {
    func formattedAsDate() -> String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = dateFormatter.date(from: self) {
            return date.formatted(
                .dateTime
                .month(.wide)
                .day(.twoDigits)
                .year()
            )
        }
        // Fallback: try without fractional seconds
        dateFormatter.formatOptions = [.withInternetDateTime]
        if let date = dateFormatter.date(from: self) {
            return date.formatted(
                .dateTime
                .month(.wide)
                .day(.twoDigits)
                .year()
            )
        }
        
        return self
    }
} 