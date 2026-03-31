import SwiftUI
import ApplicationServices

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var currentStep = 0
    @State private var accessibilityGranted = false
    @State private var checkTimer: Timer?
    @State private var pulseRing = false

    var body: some View {
        VStack(spacing: 0) {
            // Page dots
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { step in
                    Capsule()
                        .fill(step <= currentStep ? Color.accentColor : Color.secondary.opacity(0.2))
                        .frame(width: step == currentStep ? 24 : 8, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                }
            }
            .padding(.top, 24)

            Spacer()

            Group {
                switch currentStep {
                case 0: welcomeStep
                case 1: accessibilityStep
                case 2: readyStep
                default: EmptyView()
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .animation(.easeInOut(duration: 0.35), value: currentStep)

            Spacer()

            // Back button for steps 2 and 3
            if currentStep > 0 {
                Button {
                    withAnimation { currentStep -= 1 }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.caption2)
                        Text("Back")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 16)
            }
        }
        .frame(width: 500, height: 420)
        .onDisappear {
            checkTimer?.invalidate()
        }
    }

    // MARK: - Step 1: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.blue.gradient)
                    .frame(width: 80, height: 80)
                    .shadow(color: .blue.opacity(0.3), radius: 12, y: 4)
                Image(systemName: "rectangle.split.2x2")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(.white)
            }

            Text("Welcome to TilePilot")
                .font(.title)
                .fontWeight(.bold)

            Text("Declarative window layouts for macOS.\nDefine once, apply with one keypress.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .lineSpacing(4)

            Button {
                withAnimation { currentStep = 1 }
            } label: {
                Text("Get Started")
                    .frame(width: 160)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Step 2: Accessibility

    private var accessibilityStep: some View {
        VStack(spacing: 20) {
            ZStack {
                // Pulsing ring (only when waiting)
                if !accessibilityGranted {
                    Circle()
                        .stroke(Color.orange.opacity(0.4), lineWidth: 2)
                        .frame(width: 72, height: 72)
                        .scaleEffect(pulseRing ? 1.5 : 1.0)
                        .opacity(pulseRing ? 0 : 0.6)
                        .animation(
                            .easeOut(duration: 1.8).repeatForever(autoreverses: false),
                            value: pulseRing
                        )

                    Circle()
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1.5)
                        .frame(width: 72, height: 72)
                        .scaleEffect(pulseRing ? 1.2 : 1.0)
                        .opacity(pulseRing ? 0 : 0.4)
                        .animation(
                            .easeOut(duration: 1.8).repeatForever(autoreverses: false).delay(0.3),
                            value: pulseRing
                        )
                }

                if accessibilityGranted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 48))
                        .foregroundStyle(.orange)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: accessibilityGranted)

            Text("Accessibility Permission")
                .font(.title2)
                .fontWeight(.bold)

            Text("TilePilot needs Accessibility access to move and resize windows. This is standard for all window management apps.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .frame(maxWidth: 360)

            if accessibilityGranted {
                Text("Permission granted!")
                    .foregroundStyle(.green)
                    .fontWeight(.medium)

                Button {
                    withAnimation { currentStep = 2 }
                } label: {
                    Text("Continue")
                        .frame(width: 160)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                VStack(spacing: 8) {
                    Button {
                        openAccessibilitySettings()
                    } label: {
                        Label("Open System Settings", systemImage: "gear")
                            .frame(width: 200)
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)

                    Text("Waiting for permission...")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 40)
        .onAppear {
            accessibilityGranted = AXIsProcessTrusted()
            startAccessibilityPolling()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                pulseRing = true
            }
        }
        .onDisappear {
            checkTimer?.invalidate()
        }
    }

    // MARK: - Step 3: Ready

    private var readyStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("All Set!")
                .font(.title)
                .fontWeight(.bold)

            // Mini layout preview
            miniLayoutPreview
                .padding(.vertical, 4)

            HStack(spacing: 4) {
                Text("Press")
                    .foregroundStyle(.secondary)
                Text("\u{2318}\u{21E7}1")
                    .fontDesign(.monospaced)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.1))
                    )
                Text("to try a layout.")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Button {
                    if let firstName = appState.config.layouts.keys.sorted().first {
                        appState.applyLayout(named: firstName)
                    }
                } label: {
                    Label("Apply Sample", systemImage: "rectangle.split.2x2")
                }
                .controlSize(.large)
                .disabled(appState.config.layouts.isEmpty)

                Button {
                    appState.completeOnboarding()
                    dismiss()
                } label: {
                    Text("Done")
                        .frame(width: 80)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Mini Layout Preview

    private var miniLayoutPreview: some View {
        HStack(spacing: 3) {
            VStack(spacing: 3) {
                tilePreview(label: "Browser", color: .blue)
                tilePreview(label: "Notes", color: .green)
            }
            .frame(width: 70)

            tilePreview(label: "Editor", color: .purple)
        }
        .frame(width: 180, height: 100)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
    }

    private func tilePreview(label: String, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(color.opacity(0.12))
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(color.opacity(0.25), lineWidth: 1)
            )
            .overlay {
                Text(label)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(color)
            }
    }

    // MARK: - Helpers

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func startAccessibilityPolling() {
        checkTimer?.invalidate()
        checkTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            let trusted = AXIsProcessTrusted()
            DispatchQueue.main.async {
                if trusted && !accessibilityGranted {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        accessibilityGranted = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation { currentStep = 2 }
                    }
                    checkTimer?.invalidate()
                }
            }
        }
    }
}
