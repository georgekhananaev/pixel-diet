import Foundation

/// Support and project links shown in the Help menu, About and Help windows.
enum AppLinks {
    static let repository = URL(staticString: "https://github.com/georgekhananaev/pixel-diet")
    static let issues = URL(staticString: "https://github.com/georgekhananaev/pixel-diet/issues")
    static let newIssue = URL(staticString: "https://github.com/georgekhananaev/pixel-diet/issues/new")
    static let privacyPolicy = URL(staticString: "https://github.com/georgekhananaev/pixel-diet/blob/main/PRIVACY.md")
    static let supportEmailAddress = "george@khananaev.com"
    static let supportEmail = URL(staticString: "mailto:george@khananaev.com?subject=PixelDiet%20Support")
}

private extension URL {
    /// For compile-time constant URLs that are known to be valid.
    init(staticString: StaticString) {
        guard let url = URL(string: "\(staticString)") else {
            preconditionFailure("Invalid URL literal: \(staticString)")
        }
        self = url
    }
}
