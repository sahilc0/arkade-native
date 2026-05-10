import SwiftUI
import UIKit
import Observation

/// Central app state manager — follows the Pika RMP pattern exactly.
@Observable
@MainActor
final class AppManager: AppReconciler {
    let rust: FfiApp
    var state: AppState
    private var lastRevApplied: UInt64

    init() {
        let dataDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first!.path()
        let network = "bitcoin"

        self.rust = FfiApp(dataDir: dataDir, network: network)
        let initial = rust.state()
        self.state = initial
        self.lastRevApplied = initial.rev
        rust.listenForUpdates(reconciler: self)
    }

    func dispatch(_ action: AppAction) {
        rust.dispatch(action: action)
    }

    func haptic(_ feedbackType: HapticType = .light) {
        guard state.config.hapticsEnabled else { return }
        Self.triggerHaptic(feedbackType)
    }

    nonisolated func reconcile(update: AppUpdate) {
        Task { @MainActor in
            switch update {
            case .fullState(let newState):
                if newState.rev > self.lastRevApplied {
                    self.lastRevApplied = newState.rev
                    self.state = newState
                }
            case .walletCreated:
                break
            case .mnemonicRevealed:
                break
            case .copyToClipboard(let text):
                UIPasteboard.general.string = text
            case .openUrl(let url):
                if let url = URL(string: url) {
                    UIApplication.shared.open(url)
                }
            case .hapticFeedback(let feedbackType):
                Self.triggerHaptic(feedbackType)
            }
        }
    }

    var currentScreen: Screen {
        state.router.screenStack.last ?? .loading
    }

    private static func triggerHaptic(_ type: HapticType) {
        switch type {
        case .light: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium: UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .heavy: UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .success: UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning: UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .error: UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}

// MARK: - Navigation Destination Modifier

struct ArkadeNavigationDestinations: ViewModifier {
    func body(content: Content) -> some View {
        content
            .navigationDestination(for: Screen.self) { screen in
                screenView(for: screen)
            }
    }

    @ViewBuilder
    func screenView(for screen: Screen) -> some View {
        switch screen {
        // Wallet
        case .sendForm: SendFormScreen()
        case .sendDetails: SendDetailsScreen()
        case .sendSuccess: SendSuccessScreen()
        case .receiveAmount: ReceiveAmountScreen()
        case .receiveQrCode: ReceiveQRCodeScreen()
        case .receiveSuccess: ReceiveSuccessScreen()
        case .transactionDetail(let txid): TransactionDetailScreen(txid: txid)

        // Notes
        case .noteForm: NoteFormScreen()
        case .noteRedeem: NoteRedeemScreen()
        case .noteSuccess: NoteSuccessScreen()

        // Apps
        case .boltzIndex: BoltzIndexScreen()
        case .boltzSwap: BoltzSwapScreen()
        case .boltzSettings: BoltzSettingsScreen()
        case .assetsIndex: AssetsIndexScreen()
        case .assetDetail(let id): AssetDetailScreen(assetId: id)
        case .assetMint: AssetMintScreen()
        case .assetMintSuccess: AssetMintSuccessScreen()
        case .assetBurn(let id): AssetBurnScreen(assetId: id)
        case .assetReissue(let id): AssetReissueScreen(assetId: id)
        case .assetImport: AssetImportScreen()
        case .assetSettings: AssetSettingsScreen()

        // Settings
        case .settingsTheme: SettingsThemeScreen()
        case .settingsDisplay: SettingsDisplayScreen()
        case .settingsFiat: SettingsFiatScreen()
        case .settingsGeneral: SettingsGeneralScreen()
        case .settingsHaptics: SettingsHapticsScreen()
        case .settingsNotifications: SettingsNotificationsScreen()
        case .settingsPassword: SettingsPasswordScreen()
        case .settingsBackup: SettingsBackupScreen()
        case .settingsLock: SettingsLockScreen()
        case .settingsAdvanced: SettingsAdvancedScreen()
        case .settingsVtxos: SettingsVtxosScreen()
        case .settingsDelegates: SettingsDelegatesScreen()
        case .settingsAbout: SettingsAboutScreen()
        case .settingsSupport: SettingsSupportScreen()
        case .settingsLogs: SettingsLogsScreen()
        case .settingsReset: SettingsResetScreen()

        default: Text("Screen not implemented")
        }
    }
}

extension View {
    func arkadeNavigationDestinations() -> some View {
        modifier(ArkadeNavigationDestinations())
    }
}
