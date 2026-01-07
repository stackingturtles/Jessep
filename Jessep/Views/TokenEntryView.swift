import SwiftUI

struct TokenEntryView: View {
    @Binding var isPresented: Bool
    @State private var token = ""
    @State private var error: String?
    @State private var isSaving = false

    var onSave: ((String) -> Void)?

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "key.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.claudeProgressBar)

                Text("Enter Token Manually")
                    .font(.headline)

                Text("If you don't have Claude Code installed, you can enter your OAuth token manually.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Token input
            VStack(alignment: .leading, spacing: 8) {
                SecureField("Paste your OAuth token", text: $token)
                    .textFieldStyle(.roundedBorder)

                if let error = error {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            // Instructions
            DisclosureGroup("How to get your token") {
                VStack(alignment: .leading, spacing: 8) {
                    instructionStep(1, "Open claude.ai in your browser")
                    instructionStep(2, "Open Developer Tools (Cmd+Option+I)")
                    instructionStep(3, "Go to the Network tab")
                    instructionStep(4, "Filter requests by \"usage\"")
                    instructionStep(5, "Find the request to /api/oauth/usage")
                    instructionStep(6, "In the Headers, find the Authorization header")
                    instructionStep(7, "Copy the token after \"Bearer \"")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
            }

            Spacer()

            // Buttons
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("Save Token") {
                    saveToken()
                }
                .buttonStyle(.borderedProminent)
                .disabled(token.isEmpty || isSaving)
                .keyboardShortcut(.return)
            }
        }
        .padding(24)
        .frame(width: 400, height: 400)
    }

    private func instructionStep(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .fontWeight(.medium)
                .frame(width: 20, alignment: .trailing)
            Text(text)
        }
    }

    private func saveToken() {
        isSaving = true
        error = nil

        // Validate token format (basic check)
        let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanToken.isEmpty else {
            error = "Please enter a token"
            isSaving = false
            return
        }

        // Remove "Bearer " prefix if present
        let tokenValue = cleanToken.hasPrefix("Bearer ")
            ? String(cleanToken.dropFirst(7))
            : cleanToken

        do {
            try KeychainService.saveManualToken(tokenValue)
            onSave?(tokenValue)
            isPresented = false
        } catch {
            self.error = "Failed to save token: \(error.localizedDescription)"
        }

        isSaving = false
    }
}

// MARK: - Preview

#Preview {
    TokenEntryView(isPresented: .constant(true))
}
