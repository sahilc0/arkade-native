import SwiftUI

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

                    Text("Bitcoin, faster")
                        .font(Arkade.smallFont)
                        .foregroundStyle(Arkade.gray)
                }

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        app.dispatch(.createWallet(password: ""))
                    } label: {
                        Text("Create wallet")
                            .arkadeButton(.primary)
                    }

                    Button {
                        app.dispatch(.pushScreen(screen: .restoreWallet))
                    } label: {
                        Text("Restore wallet")
                            .arkadeButton(.secondary)
                    }
                }
                .padding(.horizontal, Arkade.hPadding)
                .padding(.bottom, 48)
            }
        }
    }
}

// MARK: - Restore

struct RestoreWalletScreen: View {
    @Environment(AppManager.self) private var app
    @State private var mnemonic = ""

    var wordCount: Int { mnemonic.split(separator: " ").count }

    var body: some View {
        VStack(spacing: Arkade.gap) {
            Spacer()

            VStack(spacing: 8) {
                Text("Restore wallet")
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
