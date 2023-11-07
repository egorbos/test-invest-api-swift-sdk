import Foundation

public struct TestError {
    private let message: String
    
    init(message: String) {
        self.message = message
    }
}

extension TestError: LocalizedError {
    public var errorDescription: String? { return message }
    public var failureReason: String? { return message }
    public var recoverySuggestion: String? { return "" }
    public var helpAnchor: String? { return "" }
}
