import SwiftUI

struct ErrorView: View {
    let error: Error
    let retryAction: () -> Void

    private var errorMessage: String {
        if let apiError = error as? APIError {
            return apiError.localizedDescription ?? "Unknown error"
        } else if let keychainError = error as? KeychainError {
            return keychainError.localizedDescription ?? "Keychain error"
        } else {
            return error.localizedDescription
        }
    }

    private var iconName: String {
        if let apiError = error as? APIError {
            switch apiError {
            case .tokenNotFound, .tokenExpired, .accessDenied:
                return "key.slash"
            case .networkError:
                return "wifi.slash"
            case .rateLimited:
                return "clock.badge.exclamationmark"
            default:
                return "exclamationmark.triangle"
            }
        }
        return "exclamationmark.triangle"
    }

    private var showRetry: Bool {
        if let apiError = error as? APIError {
            return apiError.isRetryable
        }
        return true
    }

    private var recoveryHint: String? {
        if let apiError = error as? APIError {
            switch apiError {
            case .tokenNotFound:
                return "Open Settings to enter your token manually."
            case .tokenExpired:
                return "Please log in to Claude Code again."
            case .accessDenied:
                return "Check your Claude subscription status."
            case .networkError:
                return "Check your internet connection."
            case .rateLimited(let retryAfter):
                if let seconds = retryAfter {
                    return "Please wait \(Int(seconds)) seconds."
                }
                return "Please wait before retrying."
            default:
                return nil
            }
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 32))
                .foregroundColor(.claudeWarning)

            Text(errorMessage)
                .font(.system(size: 12))
                .foregroundColor(.claudeTextPrimary)
                .multilineTextAlignment(.center)

            if let hint = recoveryHint {
                Text(hint)
                    .font(.system(size: 11))
                    .foregroundColor(.claudeTextSecondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                if showRetry {
                    Button("Retry") {
                        retryAction()
                    }
                    .buttonStyle(.bordered)
                }

                if case .tokenNotFound = error as? APIError {
                    Button("Settings") {
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview("Network Error") {
    ErrorView(
        error: APIError.networkError(URLError(.notConnectedToInternet)),
        retryAction: {}
    )
    .background(Color.claudeBackground)
}

#Preview("Token Not Found") {
    ErrorView(
        error: APIError.tokenNotFound,
        retryAction: {}
    )
    .background(Color.claudeBackground)
}

#Preview("Rate Limited") {
    ErrorView(
        error: APIError.rateLimited(retryAfter: 60),
        retryAction: {}
    )
    .background(Color.claudeBackground)
}
