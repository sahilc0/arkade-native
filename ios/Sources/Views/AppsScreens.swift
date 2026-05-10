import SwiftUI
import UIKit

// MARK: - Apps Hub

struct AppsScreen: View {
    @Environment(AppManager.self) private var app

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                NavigationLink(value: Screen.assetsIndex) {
                    AppHubCard(
                        icon: "circle.hexagongrid.circle.fill",
                        tint: Arkade.orange,
                        title: "Arkade Mint",
                        subtitle: "Mint, import, and manage custom assets"
                    )
                }

                NavigationLink(value: Screen.boltzIndex) {
                    AppHubCard(
                        icon: "bolt.circle.fill",
                        tint: .yellow,
                        title: "Boltz swaps",
                        subtitle: "Lightning and chain swap recovery"
                    )
                }

                NavigationLink {
                    PartnerAppScreen(
                        title: "DFX",
                        icon: "creditcard.fill",
                        description: "Buy or sell bitcoin with a signed Arkade address.",
                        appKind: .dfx
                    )
                } label: {
                    AppHubCard(
                        icon: "creditcard.circle.fill",
                        tint: Arkade.green,
                        title: "DFX",
                        subtitle: "Buy and sell bitcoin"
                    )
                }

                NavigationLink {
                    PartnerAppScreen(
                        title: "Lendasat",
                        icon: "building.columns.fill",
                        description: "Borrow against your bitcoin without selling it.",
                        appKind: .lendasat
                    )
                } label: {
                    AppHubCard(
                        icon: "building.columns.circle.fill",
                        tint: Arkade.purpleText,
                        title: "Lendasat",
                        subtitle: "Loans backed by bitcoin"
                    )
                }

                NavigationLink {
                    WalletSwapScreen()
                } label: {
                    AppHubCard(
                        icon: "arrow.triangle.2.circlepath.circle.fill",
                        tint: Arkade.blue,
                        title: "Lendaswap",
                        subtitle: "Swap between portfolio assets"
                    )
                }
            }
            .padding(.horizontal, Arkade.hPadding)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(Arkade.canvasGrouped)
        .navigationTitle("Apps")
        .navigationBarTitleDisplayMode(.large)
        .buttonStyle(PressScaleButtonStyle(scale: 0.985))
        .onAppear {
            app.dispatch(.refreshAssets)
            app.dispatch(.connectBoltz)
        }
    }
}

private struct AppHubCard: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(Arkade.smallFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(minHeight: 76)
        .arkadeLiquidCard()
    }
}

struct PartnerAppScreen: View {
    @Environment(AppManager.self) private var app
    let title: String
    let icon: String
    let description: String
    let appKind: PartnerAppKind

    var body: some View {
        ZStack {
            if let partner = app.state.partnerApp, partner.app == appKind {
                if partner.isLoading {
                    loadingView
                } else if let error = partner.error {
                    unavailableView(error)
                } else if let rawUrl = partner.url, let url = URL(string: rawUrl) {
                    WebAppView(url: url)
                        .ignoresSafeArea(edges: .bottom)
                } else {
                    unavailableView("Could not open \(title).")
                }
            } else {
                loadingView
            }
        }
        .frame(maxWidth: .infinity)
        .background(Arkade.canvasGrouped)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            app.dispatch(.loadPartnerApp(app: appKind))
        }
        .onDisappear {
            app.dispatch(.clearPartnerApp)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(Arkade.purpleText)
                .frame(width: 72, height: 72)
                .background(Arkade.purple10)
                .clipShape(Circle())
            Text(title)
                .font(.system(size: 26, weight: .medium, design: .rounded))
                .tracking(Arkade.headingTracking)
            Text(description)
                .font(Arkade.smallFont)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            ProgressView()
                .tint(Arkade.purple)
            Spacer()
        }
    }

    private func unavailableView(_ error: String) -> some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(Arkade.orange)
                .frame(width: 72, height: 72)
                .background(Arkade.orange.opacity(0.12))
                .clipShape(Circle())
            Text("Could not connect")
                .font(.system(size: 24, weight: .medium, design: .rounded))
            Text(error)
                .font(Arkade.smallFont)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                app.haptic(.light)
                app.dispatch(.loadPartnerApp(app: appKind))
            } label: {
                Text("Try again").arkadeButton(.secondary)
            }
            .padding(.horizontal, Arkade.hPadding)
            Spacer()
        }
    }
}

// MARK: - Boltz

struct BoltzIndexScreen: View {
    @Environment(AppManager.self) private var app

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let boltz = app.state.boltz {
                    VStack(spacing: 0) {
                        statusRow("Status", value: boltz.isConnected ? "Connected" : "Disconnected", tint: boltz.isConnected ? Arkade.green : Arkade.red)
                        Divider()
                        statusRow("Send fee", value: boltz.submarineFeePercent.map { String(format: "%.2f%%", $0) } ?? "Unavailable")
                        Divider()
                        statusRow("Receive fee", value: boltz.reverseFeePercent.map { String(format: "%.2f%%", $0) } ?? "Unavailable")
                    }
                    .arkadeLiquidCard()

                    ArkadeSection(title: "Swaps") {
                        if boltz.swaps.isEmpty {
                            EmptySwapsCard()
                        } else {
                            VStack(spacing: 0) {
                                ForEach(boltz.swaps, id: \.id) { swap in
                                    SwapSummaryRow(swap: swap)
                                    if swap.id != boltz.swaps.last?.id { Divider().padding(.leading, 62) }
                                }
                            }
                            .arkadeLiquidCard()
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.large)
                            .tint(Arkade.purple)
                        Text("Connecting to Boltz")
                            .font(Arkade.smallFont)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 160)
                    .arkadeLiquidCard()
                }
            }
            .padding(.horizontal, Arkade.hPadding)
            .padding(.top, 12)
        }
        .background(Arkade.canvasGrouped)
        .navigationTitle("Boltz")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: Screen.boltzSettings) {
                    Image(systemName: "gearshape")
                }
            }
        }
        .onAppear {
            app.dispatch(.connectBoltz)
            app.dispatch(.refreshSwapHistory)
        }
    }

    private func statusRow(_ label: String, value: String, tint: Color? = nil) -> some View {
        HStack {
            Text(label).font(Arkade.smallFont).foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 6) {
                if let tint {
                    Circle().fill(tint).frame(width: 8, height: 8)
                }
                Text(value).font(.system(size: 14, weight: .medium))
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
    }
}

private struct EmptySwapsCard: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "bolt.slash")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.tertiary)
            Text("No swaps yet")
                .font(Arkade.smallFont)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .arkadeLiquidCard()
    }
}

private struct SwapSummaryRow: View {
    let swap: SwapSummary

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor.opacity(0.14))
                .frame(width: 38, height: 38)
                .overlay {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(statusColor)
                }
            VStack(alignment: .leading, spacing: 3) {
                Text(swap.swapType.label)
                    .font(.system(size: 15, weight: .medium))
                Text(swap.status.label)
                    .font(Arkade.tinyFont)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(Arkade.sats(swap.amountSats)) sats")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
    }

    private var statusColor: Color {
        switch swap.status {
        case .completed: Arkade.green
        case .failed, .expired: Arkade.red
        case .refunded: Arkade.orange
        default: Arkade.purpleText
        }
    }
}

extension SwapType {
    var label: String {
        switch self {
        case .submarine: "Arkade to Lightning"
        case .reverseSubmarine: "Lightning to Arkade"
        case .arkToBtcChain: "Arkade to bitcoin"
        case .btcToArkChain: "bitcoin to Arkade"
        }
    }
}

extension SwapStatus {
    var label: String {
        switch self {
        case .created: "Created"
        case .pending: "Pending"
        case .completed: "Completed"
        case .failed: "Failed"
        case .refunded: "Refunded"
        case .expired: "Expired"
        }
    }
}

struct BoltzSwapScreen: View {
    var body: some View {
        WalletSwapScreen()
            .navigationTitle("Swap")
    }
}

struct BoltzSettingsScreen: View {
    @Environment(AppManager.self) private var app

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Button {
                    app.haptic(.light)
                    app.dispatch(.refreshSwapHistory)
                } label: {
                    settingsAction("Recover swaps", subtitle: "Refresh local swap state and claim eligible swaps", icon: "arrow.clockwise")
                }

                Button {
                    app.haptic(.warning)
                    app.dispatch(.disconnectBoltz)
                } label: {
                    settingsAction("Disconnect", subtitle: "Stop the Boltz service connection", icon: "bolt.slash", tint: Arkade.red)
                }
            }
            .padding(Arkade.hPadding)
        }
        .background(Arkade.canvasGrouped)
        .navigationTitle("Boltz settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func settingsAction(_ title: String, subtitle: String, icon: String, tint: Color = Arkade.purpleText) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(tint.opacity(0.12))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 15, weight: .medium)).foregroundStyle(.primary)
                Text(subtitle).font(Arkade.tinyFont).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(15)
        .arkadeLiquidCard()
    }
}

// MARK: - Assets

struct AssetsIndexScreen: View {
    @Environment(AppManager.self) private var app

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let assets = app.state.assets, !assets.assets.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(assets.assets, id: \.assetId) { asset in
                            NavigationLink(value: Screen.assetDetail(assetId: asset.assetId)) {
                                assetRow(asset)
                            }
                            .buttonStyle(.plain)
                            if asset.assetId != assets.assets.last?.assetId { Divider().padding(.leading, 62) }
                        }
                    }
                    .arkadeLiquidCard()
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "circle.dotted")
                            .font(.system(size: 24))
                            .foregroundStyle(.tertiary)
                        Text("No assets")
                            .font(Arkade.smallFont)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 34)
                    .arkadeLiquidCard()
                }
            }
            .padding(.horizontal, Arkade.hPadding)
            .padding(.top, 12)
            .padding(.bottom, 96)
        }
        .background(Arkade.canvasGrouped)
        .navigationTitle("Arkade Mint")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 10) {
                NavigationLink(value: Screen.assetImport) {
                    Text("Import").arkadeButton(.secondary)
                }
                NavigationLink(value: Screen.assetMint) {
                    Text("Mint").arkadeButton(.primary)
                }
            }
            .padding(Arkade.hPadding)
            .background(.regularMaterial)
        }
        .onAppear { app.dispatch(.refreshAssets) }
    }

    private func assetRow(_ asset: AssetSummary) -> some View {
        HStack(spacing: 12) {
            TokenBadge(ticker: asset.ticker)
            VStack(alignment: .leading, spacing: 3) {
                Text(asset.name).font(.system(size: 15, weight: .medium)).foregroundStyle(.primary)
                Text("\(formatAssetAmount(asset.balance, decimals: asset.decimals)) \(asset.ticker)")
                    .font(Arkade.tinyFont)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
    }
}

struct AssetDetailScreen: View {
    @Environment(AppManager.self) private var app
    let assetId: String

    var asset: AssetSummary? {
        app.state.assets?.assets.first { $0.assetId == assetId }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if let asset {
                    TokenBadge(ticker: asset.ticker, size: 64)
                    VStack(spacing: 5) {
                        Text(asset.name)
                            .font(.system(size: 26, weight: .medium, design: .rounded))
                            .tracking(Arkade.headingTracking)
                        Text("\(formatAssetAmount(asset.balance, decimals: asset.decimals)) \(asset.ticker)")
                            .font(Arkade.smallFont)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 10) {
                        NavigationLink(value: Screen.sendForm) {
                            Label("Send", systemImage: "arrow.up.right").arkadeButton(.secondary)
                        }
                        NavigationLink(value: Screen.receiveQrCode) {
                            Label("Receive", systemImage: "arrow.down.left").arkadeButton(.secondary)
                        }
                    }

                    VStack(spacing: 0) {
                        detailRow("Asset ID", value: asset.assetId)
                        Divider()
                        detailRow("Decimals", value: "\(asset.decimals)")
                        Divider()
                        detailRow("Imported", value: asset.isImported ? "Yes" : "No")
                    }
                    .arkadeLiquidCard()
                } else {
                    ContentUnavailableView("Asset not found", systemImage: "questionmark.circle")
                }
            }
            .padding(Arkade.hPadding)
        }
        .background(Arkade.canvasGrouped)
        .navigationTitle(asset?.ticker ?? "Asset")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { app.dispatch(.refreshAssets) }
    }

    private func detailRow(_ label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(Arkade.smallFont).foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium, design: label == "Asset ID" ? .monospaced : .default))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
    }
}

struct AssetMintScreen: View {
    @Environment(AppManager.self) private var app
    @State private var name = ""
    @State private var ticker = ""
    @State private var amount = ""
    @State private var decimals = "8"

    var body: some View {
        AssetFormShell(title: "Mint asset") {
            formField("Name", text: $name)
            formField("Ticker", text: $ticker)
            formField("Amount", text: $amount, keyboard: .numberPad)
            formField("Decimals", text: $decimals, keyboard: .numberPad)
        } bottom: {
            Button {
                app.haptic(.medium)
                app.dispatch(.mintAsset(name: name, ticker: ticker, amount: UInt64(amount) ?? 0, decimals: UInt8(decimals) ?? 8))
            } label: {
                Text("Mint").arkadeButton(.primary)
            }
            .disabled(name.isEmpty || ticker.isEmpty || (UInt64(amount) ?? 0) == 0)
            .opacity(name.isEmpty || ticker.isEmpty || (UInt64(amount) ?? 0) == 0 ? 0.45 : 1)
        }
    }
}

struct AssetMintSuccessScreen: View {
    @Environment(AppManager.self) private var app
    var body: some View {
        SuccessScreen(title: "Minted", systemImage: "checkmark.circle.fill") {
            app.dispatch(.replaceScreen(screen: .assetsIndex))
        }
    }
}

struct AssetBurnScreen: View {
    @Environment(AppManager.self) private var app
    let assetId: String
    @State private var amount = ""

    var body: some View {
        AssetFormShell(title: "Burn asset") {
            formField("Amount", text: $amount, keyboard: .numberPad)
        } bottom: {
            Button {
                app.haptic(.warning)
                app.dispatch(.burnAsset(assetId: assetId, amount: UInt64(amount) ?? 0))
            } label: {
                Text("Burn").arkadeButton(.danger)
            }
        }
    }
}

struct AssetReissueScreen: View {
    @Environment(AppManager.self) private var app
    let assetId: String
    @State private var amount = ""

    var body: some View {
        AssetFormShell(title: "Reissue asset") {
            formField("Amount", text: $amount, keyboard: .numberPad)
        } bottom: {
            Button {
                app.haptic(.medium)
                app.dispatch(.reissueAsset(assetId: assetId, amount: UInt64(amount) ?? 0))
            } label: {
                Text("Reissue").arkadeButton(.primary)
            }
        }
    }
}

struct AssetImportScreen: View {
    @Environment(AppManager.self) private var app
    @State private var assetId = ""
    @State private var showScanner = false

    var body: some View {
        AssetFormShell(title: "Import asset") {
            formField("Asset ID", text: $assetId)
            Button {
                app.haptic(.light)
                showScanner = true
            } label: {
                Label("Scan asset ID", systemImage: "qrcode.viewfinder")
                    .arkadeButton(.secondary)
            }
        } bottom: {
            Button {
                app.haptic(.medium)
                app.dispatch(.importAsset(assetId: assetId.trimmingCharacters(in: .whitespacesAndNewlines)))
            } label: {
                Text("Import").arkadeButton(.primary)
            }
            .disabled(assetId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(assetId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
        }
        .sheet(isPresented: $showScanner) {
            QRScannerSheet(title: "Scan asset ID") { code in
                app.haptic(.success)
                assetId = code
            }
        }
    }
}

struct AssetSettingsScreen: View {
    var body: some View {
        ContentUnavailableView("Asset settings", systemImage: "gearshape")
            .background(Arkade.canvasGrouped)
    }
}

private struct AssetFormShell<Fields: View, Bottom: View>: View {
    let title: String
    @ViewBuilder var fields: Fields
    @ViewBuilder var bottom: Bottom

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                fields
            }
            .padding(Arkade.hPadding)
            .padding(.bottom, 96)
        }
        .background(Arkade.canvasGrouped)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            bottom
                .padding(Arkade.hPadding)
                .background(.regularMaterial)
        }
    }
}

private func formField(_ title: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        Text(title)
            .font(Arkade.tinyFont)
            .foregroundStyle(.secondary)
        TextField(title, text: text)
            .keyboardType(keyboard)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .padding(14)
            .frame(minHeight: 54)
            .background(Arkade.inset)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
