import Foundation
import Security

final class UsageService {
    private var cachedCredentials: OAuthCredentials?

    // MARK: - Public API

    func fetchUsage() async -> UsageResponse? {
        guard var creds = loadCredentials() else { return nil }

        // Proactive refresh if expiring soon
        if creds.isExpiringSoon() {
            if let refreshed = await refreshToken(using: creds.refreshToken) {
                creds = refreshed
                saveCredentials(refreshed)
            }
        }

        // Call API
        let (usage, statusCode) = await callAPI(token: creds.accessToken)
        if let usage { return usage }

        // On 401: refresh and retry once
        if statusCode == 401 {
            guard let refreshed = await refreshToken(using: creds.refreshToken) else {
                clearCachedCredentials()
                return nil
            }
            saveCredentials(refreshed)
            let (retryUsage, _) = await callAPI(token: refreshed.accessToken)
            return retryUsage
        }

        return nil
    }

    // MARK: - Credential Loading (cache → app storage → Keychain)

    private func loadCredentials() -> OAuthCredentials? {
        if let cached = cachedCredentials { return cached }

        if let fromFile = loadFromAppStorage() {
            cachedCredentials = fromFile
            return fromFile
        }

        if let fromKeychain = loadFromKeychain() {
            cachedCredentials = fromKeychain
            return fromKeychain
        }

        return nil
    }

    private func loadFromAppStorage() -> OAuthCredentials? {
        let path = Constants.appCredentialsPath
        guard FileManager.default.fileExists(atPath: path),
              let data = FileManager.default.contents(atPath: path)
        else { return nil }
        return try? JSONDecoder().decode(OAuthCredentials.self, from: data)
    }

    private func loadFromKeychain() -> OAuthCredentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.keychainService,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let accessToken = oauth["accessToken"] as? String,
              let refreshToken = oauth["refreshToken"] as? String,
              let expiresAt = oauth["expiresAt"] as? Int64
        else { return nil }

        return OAuthCredentials(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt
        )
    }

    // MARK: - Token Refresh

    private func refreshToken(using refreshToken: String) async -> OAuthCredentials? {
        var request = URLRequest(url: Constants.tokenRefreshURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body: [String: String] = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": Constants.oauthClientId,
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            let tokenResponse = try JSONDecoder().decode(TokenRefreshResponse.self, from: data)
            return tokenResponse.toCredentials()
        } catch {
            return nil
        }
    }

    // MARK: - Credential Persistence

    private func saveCredentials(_ creds: OAuthCredentials) {
        cachedCredentials = creds
        guard let data = try? JSONEncoder().encode(creds) else { return }

        let url = URL(fileURLWithPath: Constants.appCredentialsPath)
        let tempURL = URL(fileURLWithPath: Constants.appCredentialsPath + ".tmp")

        FileManager.default.createFile(atPath: tempURL.path, contents: data)
        do {
            _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL)
        } catch {
            // First write or replaceItem failure: write directly
            try? data.write(to: url, options: .atomic)
            try? FileManager.default.removeItem(at: tempURL)
        }
    }

    private func clearCachedCredentials() {
        cachedCredentials = nil
        try? FileManager.default.removeItem(atPath: Constants.appCredentialsPath)
    }

    // MARK: - API Call

    private func callAPI(token: String) async -> (UsageResponse?, Int?) {
        var request = URLRequest(url: Constants.apiURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Constants.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(Constants.anthropicBeta, forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return (nil, nil) }
            guard http.statusCode == 200 else { return (nil, http.statusCode) }
            let usage = try JSONDecoder().decode(UsageResponse.self, from: data)
            return (usage, 200)
        } catch {
            return (nil, nil)
        }
    }
}
