import Foundation

public actor RateLimiter {
    private let maxPermits: Int
    private var availablePermits: Int
    private let refillInterval: TimeInterval
    private var lastRefillTime: Date
    
    public init(maxPermits: Int = 10, refillInterval: TimeInterval = 1.0) {
        self.maxPermits = maxPermits
        self.availablePermits = maxPermits
        self.refillInterval = refillInterval
        self.lastRefillTime = Date()
    }
    
    public func waitForPermit() async throws {
        while availablePermits <= 0 {
            try await Task.sleep(nanoseconds: UInt64(refillInterval * 1_000_000_000))
            refillPermits()
        }
        availablePermits -= 1
    }
    
    private func refillPermits() {
        let now = Date()
        let timeElapsed = now.timeIntervalSince(lastRefillTime)
        let permitsToAdd = Int(timeElapsed / refillInterval)
        if permitsToAdd > 0 {
            availablePermits = min(maxPermits, availablePermits + permitsToAdd)
            lastRefillTime = now
        }
    }
}
