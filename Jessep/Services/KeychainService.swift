import Security
import Foundation

enum KeychainError: LocalizedError {
    case tokenNotFound
    case invalidData
    case unexpectedError(OSStatus)
    case saveFailed(OSStatus)
    case deleteFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .tokenNotFound:
            return "Claude Code not installed or not logged in"
        case .invalidData:
            return "Invalid keychain data format"
        case .unexpectedError(let status):
            return "Keychain error: \(status)"
        case .saveFailed(let status):
            return "Failed to save token: \(status)"
        case .deleteFailed(let status):
            return "Failed to delete token: \(status)"
        }
    }
}

struct KeychainService {
    private static let claudeCodeService = "Claude Code-credentials"
    private static let manualTokenService = "com.stackingturtles.Jessep.token"
    private static let manualTokenAccount = "oauth_token"

    // MARK: - Get Token (tries both sources)

    static func getToken() throws -> String {
        print("[Jessep] KeychainService.getToken() called")

        // First try Claude Code credentials
        if let token = try? getClaudeCodeToken() {
            print("[Jessep] Token retrieved from Claude Code keychain")
            return token
        }

        // Fall back to manual token
        if let token = try? getManualToken() {
            print("[Jessep] Token retrieved from manual entry")
            return token
        }

        print("[Jessep] ERROR: No token found in keychain")
        throw KeychainError.tokenNotFound
    }

    // MARK: - Claude Code Token

    static func getClaudeCodeToken() throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: claudeCodeService,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            throw KeychainError.tokenNotFound
        }

        guard let data = result as? Data else {
            throw KeychainError.invalidData
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String else {
            throw KeychainError.invalidData
        }

        return token
    }

    static func hasClaudeCodeToken() -> Bool {
        (try? getClaudeCodeToken()) != nil
    }

    // MARK: - Manual Token

    static func getManualToken() throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: manualTokenService,
            kSecAttrAccount as String: manualTokenAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            throw KeychainError.tokenNotFound
        }

        guard let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }

        return token
    }

    static func saveManualToken(_ token: String) throws {
        let data = token.data(using: .utf8)!

        // Delete existing token first
        try? deleteManualToken()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: manualTokenService,
            kSecAttrAccount as String: manualTokenAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    static func deleteManualToken() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: manualTokenService,
            kSecAttrAccount as String: manualTokenAccount
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    static func hasManualToken() -> Bool {
        (try? getManualToken()) != nil
    }

    // MARK: - Token Status

    enum TokenSource {
        case claudeCode
        case manual
        case none
    }

    static func tokenSource() -> TokenSource {
        if hasClaudeCodeToken() {
            return .claudeCode
        } else if hasManualToken() {
            return .manual
        } else {
            return .none
        }
    }
}
