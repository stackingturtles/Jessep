import SwiftUI

struct UsageProgressBar: View {
    let title: String
    let subtitle: String
    let percentage: Double
    var prediction: String? = nil
    var showInfoButton: Bool = false
    var onInfoTap: (() -> Void)? = nil

    @State private var animatedPercentage: Double = 0

    private var clampedPercentage: Double {
        min(max(percentage, 0), 100)
    }

    private var percentageColor: Color {
        if clampedPercentage >= 100 {
            return .claudeError
        } else if clampedPercentage >= 80 {
            return .claudeWarning
        } else {
            return .claudeTextSecondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Title row
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.claudeTextPrimary)

                if showInfoButton {
                    Button(action: { onInfoTap?() }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11))
                            .foregroundColor(.claudeTextSecondary)
                    }
                    .buttonStyle(.plain)
                    .help("Learn more about this limit")
                }

                Spacer()
            }

            // Subtitle (reset time)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundColor(.claudeTextSecondary)

            // Progress bar row
            HStack(spacing: 8) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Track
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.claudeProgressTrack)

                        // Fill
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.claudeProgressBar)
                            .frame(width: geometry.size.width * (animatedPercentage / 100))
                    }
                }
                .frame(height: 8)

                // Percentage label
                Text("\(Int(clampedPercentage))% used")
                    .font(.system(size: 11))
                    .foregroundColor(percentageColor)
                    .frame(width: 60, alignment: .trailing)
            }

            // Prediction (optional)
            if let prediction = prediction {
                Text("At current rate: \(prediction)")
                    .font(.system(size: 10))
                    .foregroundColor(.claudeTextSecondary)
                    .opacity(0.8)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                animatedPercentage = clampedPercentage
            }
        }
        .onChange(of: percentage, perform: { newValue in
            withAnimation(.easeOut(duration: 0.3)) {
                animatedPercentage = min(max(newValue, 0), 100)
            }
        })
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        UsageProgressBar(
            title: "Current session",
            subtitle: "Resets in 3 hr 52 min",
            percentage: 25
        )

        UsageProgressBar(
            title: "All models",
            subtitle: "Resets Thu 8:59 AM",
            percentage: 60,
            prediction: "Limit in 2 hr 15 min"
        )

        UsageProgressBar(
            title: "Sonnet only",
            subtitle: "Resets Thu 10:59 AM",
            percentage: 73,
            showInfoButton: true
        )

        UsageProgressBar(
            title: "At limit",
            subtitle: "Resetting...",
            percentage: 100
        )
    }
    .padding()
    .background(Color.claudeBackground)
}
