import SwiftUI

struct SplashScreenView: View {
    @Binding var isPresented: Bool
    @State private var opacity: Double = 0.0
    @State private var quoteOpacity: Double = 0.0
    @State private var scale: CGFloat = 0.95

    var body: some View {
        ZStack {
            // Background matching Claude theme
            Color.claudeBackground
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // App icon with subtle animation
                if let image = NSImage(named: "AppIcon") {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 180, height: 180)
                        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                        .scaleEffect(scale)
                        .opacity(opacity)
                } else {
                    // Fallback if AppIcon isn't available yet
                    Image(systemName: "chart.bar.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .foregroundStyle(.white.opacity(0.9))
                        .scaleEffect(scale)
                        .opacity(opacity)
                }

                // App name
                Text("JESSEP")
                    .font(.system(size: 42, weight: .bold, design: .default))
                    .foregroundStyle(Color.claudeTextPrimary)
                    .tracking(4)
                    .opacity(opacity)

                // Quote section
                VStack(spacing: 16) {
                    Text("\"Son, we live in a world that has tokens,\nand those tokens have to be guarded\nby men with guns.\"")
                        .font(.system(size: 15, weight: .medium, design: .serif))
                        .foregroundStyle(Color.claudeTextSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .italic()
                        .opacity(quoteOpacity)

                    Text("— Lt. Colonel Jessep")
                        .font(.system(size: 13, weight: .semibold, design: .serif))
                        .foregroundStyle(Color.claudeTextSecondary.opacity(0.8))
                        .opacity(quoteOpacity)
                }
                .padding(.horizontal, 40)

                Spacer()

                // Subtle hint
                Text("Click anywhere to continue")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color.claudeTextSecondary.opacity(0.5))
                    .opacity(quoteOpacity)
                    .padding(.bottom, 20)
            }
        }
        .onAppear {
            // Staggered animation
            withAnimation(.easeOut(duration: 0.8)) {
                opacity = 1.0
                scale = 1.0
            }

            // Delay quote appearance
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeOut(duration: 0.6)) {
                    quoteOpacity = 1.0
                }
            }

            // Auto-dismiss after 3.5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                dismissSplash()
            }
        }
        .onTapGesture {
            // Allow manual dismissal
            dismissSplash()
        }
    }

    private func dismissSplash() {
        withAnimation(.easeInOut(duration: 0.5)) {
            opacity = 0.0
            quoteOpacity = 0.0
            scale = 1.1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isPresented = false
        }
    }
}

// MARK: - Preview

#Preview {
    SplashScreenView(isPresented: .constant(true))
        .frame(width: 600, height: 500)
}
