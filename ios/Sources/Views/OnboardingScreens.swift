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
                        PixelArkadeLogo(size: 32)
                            .foregroundStyle(Arkade.white)

                        Text("Welcome to Arkade")
                            .font(.system(size: 24, weight: .medium))
                            .tracking(Arkade.headingTracking)
                            .foregroundStyle(Arkade.white)
                    }

                    VStack(spacing: 10) {
                        OnboardingBullet(
                            icon: "bolt.fill",
                            text: "Fast payments, swaps, and more"
                        )
                        OnboardingBullet(
                            icon: "globe",
                            text: "Access Lightning, mint assets, and more. All secured by bitcoin"
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
                        app.dispatch(.pushScreen(screen: .restoreWallet))
                    } label: {
                        Text("Import wallet")
                            .arkadeButton(.secondaryOnDark)
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
            PixelArkadeLogo(size: 104)
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

private struct PixelArkadeLogo: View {
    let size: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let unit = min(proxy.size.width, proxy.size.height) / 4
            Path { path in
                path.addRect(CGRect(x: 0, y: unit, width: unit, height: unit))
                path.addRect(CGRect(x: unit, y: 0, width: 2 * unit, height: unit))
                path.addRect(CGRect(x: 3 * unit, y: unit, width: unit, height: unit))
                path.addRect(CGRect(x: 0, y: 2 * unit, width: unit, height: unit))
                path.addRect(CGRect(x: unit, y: 2 * unit, width: 2 * unit, height: unit))
                path.addRect(CGRect(x: 3 * unit, y: 2 * unit, width: unit, height: unit))
                path.addRect(CGRect(x: 0, y: 3 * unit, width: unit, height: unit))
                path.addRect(CGRect(x: 3 * unit, y: 3 * unit, width: unit, height: unit))
            }
            .fill(.foreground)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Restore

struct RestoreWalletScreen: View {
    @Environment(AppManager.self) private var app
    @State private var mnemonic = ""

    var wordCount: Int { mnemonic.split(separator: " ").count }

    var body: some View {
        VStack(spacing: Arkade.gap) {
            HStack {
                Button {
                    app.haptic(.light)
                    app.dispatch(.popScreen)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Arkade.dark80)
                        .frame(width: 44, height: 44)
                        .background(Arkade.dark05)
                        .clipShape(Circle())
                }
                .buttonStyle(PressScaleButtonStyle())

                Spacer()
            }
            .padding(.horizontal, Arkade.hPadding)
            .padding(.top, 12)

            Spacer()

            VStack(spacing: 8) {
                Text("Import wallet")
                    .font(.system(size: 24, weight: .medium))
                    .tracking(Arkade.headingTracking)
                Text("Enter your 12-word recovery phrase")
                    .font(Arkade.smallFont)
                    .foregroundStyle(Arkade.dark50)
            }

            TextEditor(text: $mnemonic)
                .frame(height: 100)
                .padding(12)
                .background(Arkade.dark10)
                .clipShape(RoundedRectangle(cornerRadius: Arkade.radius))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(.horizontal, Arkade.hPadding)

            Text("\(wordCount) / 12 words")
                .font(Arkade.tinyFont)
                .foregroundStyle(wordCount >= 12 ? Arkade.green : Arkade.dark50)

            Spacer()

            Button {
                app.dispatch(.restoreWallet(mnemonic: mnemonic, password: ""))
            } label: {
                Text("Restore")
                    .arkadeButton(.primary)
            }
            .disabled(wordCount < 12)
            .opacity(wordCount < 12 ? 0.5 : 1)
            .padding(.horizontal, Arkade.hPadding)
            .padding(.bottom, 48)
        }
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
