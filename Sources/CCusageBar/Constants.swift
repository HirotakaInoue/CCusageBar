import Foundation

enum Constants {
    static let refreshInterval: TimeInterval = 120
    static let apiURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    static let keychainService = "Claude Code-credentials"
    static let usagePageURL = URL(string: "https://claude.ai/settings/usage")!
    static let userAgent = "claude-code/2.0.31"
    static let anthropicBeta = "oauth-2025-04-20"

    static let barFilled: Character = "▓"
    static let barEmpty: Character = "░"
    static let barLength = 8
}
