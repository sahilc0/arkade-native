import SwiftUI

// MARK: - Onboarding Flow

struct OnboardingFlowScreen: View {
    @Environment(AppManager.self) private var app

    var body: some View {
        switch app.currentScreen {
        case .restoreWallet:
            RestoreWalletScreen()
        case .createWallet:
            CreateWalletScreen()
        case .setPassword:
            SetPasswordScreen()
        case .connecting:
            ConnectingScreen()
        case .onboardingSuccess:
            OnboardingSuccessScreen()
        case .unavailable(let reason):
            UnavailableScreen(reason: reason)
        default:
            InitScreen()
        }
    }
}

// MARK: - Loading

struct LoadingScreen: View {
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            ProgressView()
                .controlSize(.large)
                .tint(Arkade.purple)
        }
    }
}

// MARK: - Init

struct InitScreen: View {
    @Environment(AppManager.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var contentReady = false
    @State private var showOptions = false

    var body: some View {
        ZStack {
            Arkade.bgDark.ignoresSafeArea()
            PixelSunrise()
                .opacity(contentReady ? 1 : 0)
                .animation(.easeOut(duration: reduceMotion ? 0 : 1.1), value: contentReady)

            VStack(spacing: 0) {
                Spacer()

                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        ArkadeOnboardingLogo(size: 32)
                            .foregroundStyle(Arkade.white)

                        HStack(alignment: .center, spacing: 8) {
                            Text("Welcome to Arkade")
                                .font(.system(size: 24, weight: .medium))
                                .tracking(Arkade.headingTracking)
                            InvaderGlyph()
                                .fill(Arkade.white)
                                .frame(width: 24, height: 24)
                        }
                        .foregroundStyle(Arkade.white)
                    }

                    VStack(spacing: 10) {
                        OnboardingBullet(
                            icon: "bolt.fill",
                            text: "Fast payments, swaps, and more"
                        )
                        OnboardingBullet(
                            icon: "globe",
                            text: "Access Lightning, mint assets, and more. All secured by Bitcoin"
                        )
                        OnboardingBullet(
                            icon: "shield.checkered",
                            text: "Stay in control. Settle and withdraw on your terms"
                        )
                    }
                }
                .padding(.horizontal, Arkade.hPadding)
                .opacity(contentReady ? 1 : 0)
                .offset(y: contentReady && !reduceMotion ? 0 : 8)
                .animation(.easeOut(duration: reduceMotion ? 0 : 0.28).delay(reduceMotion ? 0 : 0.08), value: contentReady)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        app.haptic(.medium)
                        app.dispatch(.createWallet(password: ""))
                    } label: {
                        Text("+ Create wallet")
                            .arkadeButton(.primary)
                    }
                    .buttonStyle(PressScaleButtonStyle())

                    Button {
                        app.haptic(.light)
                        showOptions = true
                    } label: {
                        Text("Other login options")
                            .arkadeButton(.clearOnDark)
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
                .padding(.horizontal, Arkade.hPadding)
                .padding(.bottom, 48)
                .opacity(contentReady ? 1 : 0)
                .offset(y: contentReady && !reduceMotion ? 0 : 16)
                .animation(.easeOut(duration: reduceMotion ? 0 : 0.34).delay(reduceMotion ? 0 : 0.18), value: contentReady)
            }

            if !contentReady && !reduceMotion {
                SplashLogo {
                    contentReady = true
                }
            }
        }
        .onAppear {
            if reduceMotion {
                contentReady = true
            }
        }
        .sheet(isPresented: $showOptions) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Other login options")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Arkade.black)

                Button {
                    app.haptic(.light)
                    showOptions = false
                    app.dispatch(.pushScreen(screen: .restoreWallet))
                } label: {
                    Text("Restore wallet")
                        .arkadeButton(.secondary)
                }
                .buttonStyle(PressScaleButtonStyle())
            }
            .padding(Arkade.hPadding)
            .presentationDetents([.height(170)])
            .presentationDragIndicator(.visible)
            .presentationBackground(.regularMaterial)
        }
    }
}

private struct InvaderGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let unit = min(rect.width, rect.height) / 8
        let dx = rect.midX - 4 * unit
        let dy = rect.midY - 4 * unit
        let cells: [(CGFloat, CGFloat)] = [
            (1, 0), (6, 0),
            (2, 1), (5, 1),
            (1, 2), (2, 2), (3, 2), (4, 2), (5, 2), (6, 2),
            (0, 3), (2, 3), (3, 3), (4, 3), (5, 3), (7, 3),
            (0, 4), (1, 4), (2, 4), (3, 4), (4, 4), (5, 4), (6, 4), (7, 4),
            (1, 5), (6, 5),
            (0, 6), (2, 6), (5, 6), (7, 6)
        ]

        var path = Path()
        for (x, y) in cells {
            path.addRect(CGRect(x: dx + x * unit, y: dy + y * unit, width: unit, height: unit))
        }
        return path
    }
}

private struct OnboardingBullet: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Arkade.purpleLight)
                .frame(width: 40, height: 40)
                .background(Arkade.purpleBg)
                .clipShape(Circle())

            Text(text)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Arkade.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }
}

private struct SplashLogo: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settled = false
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            Arkade.bgDark.ignoresSafeArea()
            ArkadeOnboardingLogo(size: 100)
                .foregroundStyle(Arkade.white)
                .scaleEffect(settled ? 0.78 : 1)
                .opacity(settled ? 0 : 1)
                .animation(.easeOut(duration: reduceMotion ? 0 : 0.35), value: settled)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(420))
            settled = true
            try? await Task.sleep(for: .milliseconds(260))
            onComplete()
        }
    }
}

private struct PixelSunrise: View {
    var body: some View {
        VStack {
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Arkade.purple.opacity(0.56),
                            Arkade.purple.opacity(0.25),
                            .clear,
                        ],
                        center: .top,
                        startRadius: 8,
                        endRadius: 280
                    )
                )
                .frame(height: 260)
                .scaleEffect(x: 1.7, y: 1, anchor: .top)
            Spacer()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

private struct ArkadeOnboardingLogo: View {
    let size: CGFloat

    var body: some View {
        ArkadeOnboardingLogoShape()
            .fill(.foreground)
        .frame(width: size, height: size)
    }
}

private struct ArkadeOnboardingLogoShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 35
        let dx = rect.midX - 17.5 * s
        let dy = rect.midY - 17.5 * s
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: dx + x * s, y: dy + y * s) }

        var path = Path()
        path.move(to: p(0, 8.75))
        path.addLine(to: p(8.75, 0))
        path.addLine(to: p(26.25, 0))
        path.addLine(to: p(35, 8.75))
        path.addLine(to: p(35, 17.5))
        path.addLine(to: p(26.25, 17.5))
        path.addLine(to: p(26.25, 8.75))
        path.addLine(to: p(8.75, 8.75))
        path.addLine(to: p(8.75, 17.5))
        path.addLine(to: p(0, 17.5))
        path.closeSubpath()
        path.addRect(CGRect(x: dx + 8.75 * s, y: dy + 17.5 * s, width: 17.5 * s, height: 8.75 * s))
        path.addRect(CGRect(x: dx, y: dy + 26.25 * s, width: 8.75 * s, height: 8.75 * s))
        path.addRect(CGRect(x: dx + 26.25 * s, y: dy + 26.25 * s, width: 8.75 * s, height: 8.75 * s))
        return path
    }
}

// MARK: - Restore

struct RestoreWalletScreen: View {
    @Environment(AppManager.self) private var app
    @State private var privateKey = ""

    var privateKeyInput: String { privateKey.trimmingCharacters(in: .whitespacesAndNewlines) }
    var isNsec: Bool { privateKeyInput.hasPrefix("nsec") }
    var isHexKey: Bool {
        privateKeyInput.count == 64 && privateKeyInput.allSatisfy { $0.isHexDigit }
    }
    var isValidInput: Bool { isNsec || isHexKey }

    var body: some View {
        VStack(spacing: 0) {
            RestoreHeader()

            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Private key")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Arkade.dark50)

                    TextField("nsec...", text: $privateKey, axis: .vertical)
                        .font(.system(size: 16, weight: .regular, design: .monospaced))
                        .lineLimit(1...3)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                        .background(Arkade.dark05)
                        .clipShape(RoundedRectangle(cornerRadius: Arkade.radius, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: Arkade.radius, style: .continuous)
                                .stroke(inputBorderColor, lineWidth: 1)
                        }
                }

                if !privateKeyInput.isEmpty && !isValidInput {
                    Text("Invalid private key format")
                        .font(Arkade.tinyFont)
                        .foregroundStyle(Arkade.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, Arkade.hPadding)
            .padding(.top, 20)

            Spacer()

            Text("Your private key should start with the 'nsec' string. Do not share it with anyone.")
                .font(Arkade.smallFont)
                .foregroundStyle(Arkade.dark50)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Arkade.hPadding)
                .padding(.bottom, 20)

            VStack(spacing: 8) {
                Button {
                    app.haptic(.medium)
                    app.dispatch(.restoreWallet(mnemonic: privateKeyInput, password: ""))
                } label: {
                    Text("Continue").arkadeButton(.primary)
                }
                .disabled(!isValidInput)
                .opacity(isValidInput ? 1 : 0.5)

                Button {
                    app.haptic(.light)
                    app.dispatch(.popScreen)
                } label: {
                    Text("Cancel").arkadeButton(.secondary)
                }
            }
            .padding(.horizontal, Arkade.hPadding)
            .padding(.bottom, 48)
        }
        .background(Arkade.canvas.ignoresSafeArea())
    }

    private var inputBorderColor: Color {
        if privateKeyInput.isEmpty { return Arkade.dark10 }
        return isValidInput ? Arkade.green.opacity(0.45) : Arkade.red.opacity(0.45)
    }
}

private struct RestoreHeader: View {
    @Environment(AppManager.self) private var app

    var body: some View {
        ZStack {
            Text("Restore wallet")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.primary)

            HStack {
                Button {
                    app.haptic(.light)
                    app.dispatch(.popScreen)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Arkade.dark80)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(PressScaleButtonStyle())

                Spacer()
            }
        }
        .frame(height: 56)
        .padding(.horizontal, 4)
    }
}

// MARK: - Stubs

struct CreateWalletScreen: View {
    var body: some View {
        VStack { ProgressView("Creating...").controlSize(.large).tint(Arkade.purple) }
    }
}

struct SetPasswordScreen: View {
    @Environment(AppManager.self) private var app
    var body: some View { Text("Set password").font(Arkade.headingFont) }
}

struct ConnectingScreen: View {
    var body: some View {
        ZStack {
            Arkade.bgDark.ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView().controlSize(.large).tint(Arkade.white)
                Text("Connecting...")
                    .font(Arkade.smallFont)
                    .foregroundStyle(Arkade.gray)
            }
        }
    }
}

struct OnboardingSuccessScreen: View {
    @Environment(AppManager.self) private var app
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle.fill").font(.system(size: 48)).foregroundStyle(Arkade.green)
            Text("Wallet created").font(.system(size: 24, weight: .medium)).tracking(Arkade.headingTracking)
            Spacer()
            Button { app.dispatch(.replaceScreen(screen: .home)) } label: {
                Text("Get started").arkadeButton()
            }
            .padding(.horizontal, Arkade.hPadding)
            .padding(.bottom, 48)
        }
    }
}

// MARK: - Unlock

struct UnlockScreen: View {
    @Environment(AppManager.self) private var app

    var body: some View {
        ZStack {
            Arkade.bgDark.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 12) {
                    Text("Arkade")
                        .font(.system(size: 24, weight: .medium))
                        .tracking(Arkade.headingTracking)
                        .foregroundStyle(Arkade.white)
                    Text("Welcome back")
                        .font(Arkade.smallFont)
                        .foregroundStyle(Arkade.gray)
                }
                Spacer()

                if app.state.busy.connecting {
                    ProgressView().controlSize(.large).tint(Arkade.white)
                        .padding(.bottom, 80)
                } else {
                    Button { app.dispatch(.unlockWallet(password: "")) } label: {
                        Text("Unlock").arkadeButton()
                    }
                    .padding(.horizontal, Arkade.hPadding)
                    .padding(.bottom, 48)
                }
            }
        }
    }
}

// MARK: - Unavailable

struct UnavailableScreen: View {
    let reason: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 40)).foregroundStyle(Arkade.orange)
            Text("Unavailable").font(.system(size: 24, weight: .medium)).tracking(Arkade.headingTracking)
            Text(reason).font(Arkade.smallFont).foregroundStyle(Arkade.dark50).multilineTextAlignment(.center)
        }
        .padding(Arkade.hPadding)
    }
}
