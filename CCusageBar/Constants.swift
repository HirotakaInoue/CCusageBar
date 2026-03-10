import Foundation

enum Constants {
    static let refreshInterval: TimeInterval = 120
    static let apiURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    static let keychainService = "Claude Code-credentials"
    static let usagePageURL = URL(string: "https://claude.ai/settings/usage")!
    static let userAgent = "claude-code/2.0.31"
    static let anthropicBeta = "oauth-2025-04-20"

    static let tokenRefreshURL = URL(string: "https://api.anthropic.com/v1/oauth/token")!
    static let oauthClientId = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    static let tokenRefreshMargin: TimeInterval = 30 * 60 // 30 minutes before expiry
    static let appCredentialsPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return home + "/.claude/ccusagebar-tokens.json"
    }()

    static let barFilled: Character = "█"
    static let barEmpty: Character = "░"
    static let barLength = 8
}
