import Foundation
import Security

final class UsageService {
    private var cachedToken: String?

    func getOAuthToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.keychainService,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String
        else {
            return nil
        }
        return token
    }

    func fetchUsage() async -> UsageResponse? {
        guard let token = cachedToken ?? getOAuthToken() else { return nil }
        cachedToken = token

        if let usage = await callAPI(token: token) {
            return usage
        }

        // Retry with fresh token
        cachedToken = nil
        guard let freshToken = getOAuthToken() else { return nil }
        cachedToken = freshToken
        return await callAPI(token: freshToken)
    }

    private func callAPI(token: String) async -> UsageResponse? {
        var request = URLRequest(url: Constants.apiURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Constants.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(Constants.anthropicBeta, forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            return try JSONDecoder().decode(UsageResponse.self, from: data)
        } catch {
            return nil
        }
    }
}
