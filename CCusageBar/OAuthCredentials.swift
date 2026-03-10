import Foundation

struct OAuthCredentials: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Int64 // Unix timestamp in milliseconds

    func isExpiringSoon(margin: TimeInterval = Constants.tokenRefreshMargin) -> Bool {
        let expiresDate = Date(timeIntervalSince1970: Double(expiresAt) / 1000.0)
        return Date().addingTimeInterval(margin) >= expiresDate
    }

    var isExpired: Bool {
        let expiresDate = Date(timeIntervalSince1970: Double(expiresAt) / 1000.0)
        return Date() >= expiresDate
    }
}

struct TokenRefreshResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }

    func toCredentials() -> OAuthCredentials {
        let expiresAt = Int64(Date().timeIntervalSince1970 * 1000) + Int64(expiresIn) * 1000
        return OAuthCredentials(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt
        )
    }
}
