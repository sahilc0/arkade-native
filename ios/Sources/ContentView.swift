import SwiftUI

struct ContentView: View {
    @Environment(AppManager.self) private var app

    var body: some View {
        Group {
            switch app.state.auth {
            case .unauthenticated:
                OnboardingFlowScreen()
            case .locked:
                UnlockScreen()
            case .connecting:
                ConnectingScreen()
            case .connected:
                WalletRootView()
            }
        }
        .background(Arkade.canvasGrouped.ignoresSafeArea())
        .preferredColorScheme(app.state.config.theme.colorScheme)
        .overlay(alignment: .top) {
            if let toast = app.state.toast {
                ToastView(toast: toast) {
                    app.dispatch(.clearToast)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeOut(duration: 0.2), value: app.state.toast?.message)
            }
        }
        .tint(Arkade.purple)
    }
}

// MARK: - Wallet Root

struct WalletRootView: View {
    var body: some View {
        NavigationStack {
            HomeScreen()
                .arkadeNavigationDestinations()
        }
        .tint(Arkade.purple)
    }
}

// MARK: - Toast

struct ToastView: View {
    let toast: Toast
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: toast.isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                .font(.subheadline)
            Text(toast.message)
                .font(Arkade.smallFont)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .foregroundStyle(Arkade.white)
        .background(toast.isError ? Arkade.red : Arkade.green)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 8)
        .padding(.top, 60)
        .onTapGesture(perform: onDismiss)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { onDismiss() }
        }
    }
}
