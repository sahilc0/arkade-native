import SwiftUI
import Foundation

// MARK: - Home

struct HomeScreen: View {
    @Environment(AppManager.self) private var app
    @State private var showScanner = false

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                HomeHeader()

                PortfolioHero()
                    .padding(.top, 8)

                HomeQuickActions(showScanner: $showScanner)

                AssetsHomeSection()

                UpsellsHomeSection()

                RecentActivitySection(limit: 3)
            }
            .padding(.horizontal, Arkade.hPadding)
            .padding(.bottom, 126)
        }
        .background(Arkade.canvasGrouped)
        .safeAreaInset(edge: .bottom) {
            WalletActionDock()
        }
        .refreshable {
            app.dispatch(.refreshAll)
            app.dispatch(.refreshAssets)
            try? await Task.sleep(for: .milliseconds(700))
        }
        .onAppear {
            app.dispatch(.refreshAll)
            app.dispatch(.refreshAssets)
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showScanner) {
            QRScannerSheet(title: "Scan recipient") { code in
                app.haptic(.success)
                app.dispatch(.parseRecipient(input: code))
                app.dispatch(.pushScreen(screen: .sendForm))
            }
        }
    }
}

private struct HomeHeader: View {
    @Environment(AppManager.self) private var app

    var body: some View {
        HStack {
            ArkadeMark(size: 35)
                .frame(width: Arkade.minTap, height: Arkade.minTap)

            Spacer()

            HStack(spacing: 6) {
                NavigationLink {
                    ActivityScreen()
                } label: {
                    HistoryIcon()
                        .stroke(.primary, lineWidth: 1.8)
                        .frame(width: 24, height: 24)
                        .frame(width: Arkade.minTap, height: Arkade.minTap)
                }
                .buttonStyle(PressScaleButtonStyle())
                .simultaneousGesture(TapGesture().onEnded { app.haptic(.light) })
                .accessibilityLabel("View recent activity")

                NavigationLink(value: Screen.settingsMenu) {
                    SettingsIcon()
                        .stroke(.primary, lineWidth: 1.7)
                        .frame(width: 24, height: 24)
                        .frame(width: Arkade.minTap, height: Arkade.minTap)
                }
                .buttonStyle(PressScaleButtonStyle())
                .simultaneousGesture(TapGesture().onEnded { app.haptic(.light) })
                .accessibilityLabel("Open settings")
            }
            .foregroundStyle(.primary)
        }
        .frame(height: 72)
    }
}

private struct ArkadeMark: View {
    let size: CGFloat

    var body: some View {
        ArkadeLogoShape()
            .fill(.primary)
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private struct ArkadeLogoShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 35
        let dx = rect.midX - 17.5 * s
        let dy = rect.midY - 17.5 * s

        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: dx + x * s, y: dy + y * s)
        }

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

        path.move(to: p(8.75, 26.25))
        path.addLine(to: p(8.75, 17.5))
        path.addLine(to: p(26.25, 17.5))
        path.addLine(to: p(26.25, 26.25))
        path.closeSubpath()

        path.move(to: p(8.75, 26.25))
        path.addLine(to: p(0, 26.25))
        path.addLine(to: p(0, 35))
        path.addLine(to: p(8.75, 35))
        path.closeSubpath()

        path.move(to: p(26.25, 26.25))
        path.addLine(to: p(26.25, 35))
        path.addLine(to: p(35, 35))
        path.addLine(to: p(35, 26.25))
        path.closeSubpath()

        return path
    }
}

private struct PortfolioHero: View {
    @Environment(AppManager.self) private var app

    var body: some View {
        Button {
            app.haptic(.light)
            app.dispatch(.setShowBalance(show: !app.state.config.showBalance))
        } label: {
            VStack(spacing: 8) {
                Text(balanceText)
                    .font(.system(size: 56, weight: .medium))
                    .tracking(-1.2)
                    .contentTransition(.numericText())
                    .monospacedDigit()

                if let unitText {
                    Text(unitText)
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(.primary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
            .padding(.bottom, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.99))
        .accessibilityLabel("Portfolio balance")
    }

    private var balanceText: String {
        guard app.state.config.showBalance else { return "••••" }
        guard let balance = app.state.balance else { return "--" }

        switch app.state.config.currencyDisplay {
        case .fiatOnly:
            return balance.fiatValue ?? "$0.00"
        case .both:
            if let fiat = balance.fiatValue { return fiat }
            return "\(Arkade.sats(balance.offchainTotalSats))"
        case .satsOnly:
            return "\(Arkade.sats(balance.offchainTotalSats))"
        }
    }

    private var unitText: String? {
        guard app.state.config.showBalance else { return nil }
        switch app.state.config.currencyDisplay {
        case .fiatOnly: return nil
        case .both:
            guard let balance = app.state.balance else { return "Portfolio" }
            return "\(Arkade.sats(balance.offchainTotalSats)) sats"
        case .satsOnly:
            return "sats"
        }
    }
}

private struct HomeQuickActions: View {
    @Environment(AppManager.self) private var app
    @Binding var showScanner: Bool

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
            NavigationLink(value: Screen.receiveQrCode) {
                HomeQuickAction(icon: .receive, title: "Receive")
            }
            .simultaneousGesture(TapGesture().onEnded {
                app.haptic(.light)
                app.dispatch(.setReceiveType(receiveType: .arkAddress))
                app.dispatch(.generateReceiveAddress)
            })

            NavigationLink(value: Screen.sendForm) {
                HomeQuickAction(icon: .send, title: "Send")
            }
            .simultaneousGesture(TapGesture().onEnded { app.haptic(.light) })

            NavigationLink {
                WalletSwapScreen()
            } label: {
                HomeQuickAction(icon: .swap, title: "Swap")
            }
            .simultaneousGesture(TapGesture().onEnded { app.haptic(.light) })

            Button {
                app.haptic(.light)
                showScanner = true
            } label: {
                HomeQuickAction(icon: .scan, title: "Scan")
            }
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}

private enum HomeActionIcon {
    case receive, send, swap, scan
}

private struct HomeQuickAction: View {
    let icon: HomeActionIcon
    let title: String

    var body: some View {
        VStack(spacing: 6) {
            iconView
                .frame(width: 24, height: 24)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(Arkade.purpleText)
        .frame(maxWidth: .infinity)
        .frame(height: 68)
        .background(Arkade.purple10)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Arkade.purpleText.opacity(0.05), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var iconView: some View {
        switch icon {
        case .receive:
            ReceiveBlockIcon().fill(.foreground)
        case .send:
            SendBlockIcon().fill(.foreground)
        case .swap:
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 20, weight: .semibold))
        case .scan:
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 20, weight: .semibold))
        }
    }
}

private struct AssetsHomeSection: View {
    @Environment(AppManager.self) private var app

    var body: some View {
        ArkadeSection(title: "Assets") {
            VStack(spacing: 8) {
                AssetBalanceRow(
                    ticker: "BTC",
                    name: "Bitcoin",
                    amount: btcAmount,
                    value: app.state.balance?.fiatValue,
                    isInteractive: false
                )

                if let assets = app.state.assets, !assets.assets.isEmpty {
                    ForEach(assets.assets, id: \.assetId) { asset in
                        NavigationLink(value: Screen.assetDetail(assetId: asset.assetId)) {
                            AssetBalanceRow(
                                ticker: asset.ticker,
                                name: asset.name,
                                amount: formatAssetAmount(asset.balance, decimals: asset.decimals),
                                value: asset.isImported ? "Imported" : nil,
                                isInteractive: true
                            )
                        }
                        .buttonStyle(PressScaleButtonStyle(scale: 0.985))
                        .simultaneousGesture(TapGesture().onEnded { app.haptic(.light) })
                    }
                }
            }
        }
    }

    private var btcAmount: String {
        guard let balance = app.state.balance else { return "-- sats" }
        return "\(Arkade.sats(balance.offchainTotalSats)) sats"
    }
}

private struct AssetBalanceRow: View {
    let ticker: String
    let name: String
    let amount: String
    var value: String?
    var isInteractive: Bool

    var body: some View {
        HStack(spacing: 12) {
            TokenBadge(ticker: ticker.isEmpty ? "TKN" : ticker)

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(amount)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if let value {
                Text(value)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.78))
                    .monospacedDigit()
                    .lineLimit(1)
            }

            if isInteractive {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 14)
        .frame(minHeight: 68)
        .arkadeLiquidCard()
    }
}

private struct UpsellsHomeSection: View {
    @Environment(AppManager.self) private var app

    var body: some View {
        ArkadeSection(title: "Do more with your assets") {
            VStack(spacing: 8) {
                NavigationLink {
                    PartnerAppScreen(
                        title: "Lendasat",
                        icon: "building.columns.fill",
                        description: "Borrow against your bitcoin without selling.",
                        appKind: .lendasat
                    )
                } label: {
                    UpsellRow(
                        icon: "building.columns.fill",
                        title: "Borrow against your bitcoin",
                        subtitle: "Get a loan without selling. Self-custodial, no paperwork."
                    )
                }

                NavigationLink {
                    PartnerAppScreen(
                        title: "DFX",
                        icon: "creditcard.fill",
                        description: "Buy or sell bitcoin from the native app.",
                        appKind: .dfx
                    )
                } label: {
                    UpsellRow(
                        icon: "creditcard.fill",
                        title: "Buy or sell bitcoin",
                        subtitle: "Convert between bitcoin and your local currency."
                    )
                }
            }
            .buttonStyle(PressScaleButtonStyle(scale: 0.985))
            .simultaneousGesture(TapGesture().onEnded { app.haptic(.light) })
        }
    }
}

private struct UpsellRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Arkade.purple10)
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Arkade.purpleText)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 14)
        .arkadeLiquidCard()
    }
}

private struct WalletActionDock: View {
    @Environment(AppManager.self) private var app

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(
                stops: [
                    .init(color: Arkade.canvasGrouped.opacity(0), location: 0),
                    .init(color: Arkade.canvasGrouped.opacity(0.62), location: 0.28),
                    .init(color: Arkade.canvasGrouped.opacity(0.96), location: 0.62),
                    .init(color: Arkade.canvasGrouped, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 36)

            HStack(spacing: 8) {
                NavigationLink(value: Screen.sendForm) {
                    WalletDockButton(icon: .send, title: "Send")
                }
                .simultaneousGesture(TapGesture().onEnded { app.haptic(.medium) })

                NavigationLink {
                    WalletSwapScreen()
                } label: {
                    WalletDockButton(icon: .swap, title: "Swap")
                }
                .simultaneousGesture(TapGesture().onEnded { app.haptic(.medium) })

                NavigationLink(value: Screen.receiveQrCode) {
                    WalletDockButton(icon: .receive, title: "Receive")
                }
                .simultaneousGesture(TapGesture().onEnded {
                    app.haptic(.medium)
                    app.dispatch(.setReceiveType(receiveType: .arkAddress))
                    app.dispatch(.generateReceiveAddress)
                })
            }
            .buttonStyle(PressScaleButtonStyle(scale: 0.97))
            .padding(.horizontal, Arkade.hPadding)
            .padding(.bottom, 8)
            .background(Arkade.canvasGrouped)
        }
    }
}

private struct WalletDockButton: View {
    let icon: HomeActionIcon
    let title: String

    var body: some View {
        HStack(spacing: 7) {
            switch icon {
            case .send:
                SendBlockIcon().fill(.white).frame(width: 15, height: 16)
            case .swap:
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 15, weight: .bold))
            case .receive:
                ReceiveBlockIcon().fill(.white).frame(width: 15, height: 21)
            case .scan:
                EmptyView()
            }

            Text(title)
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .lineLimit(1)
        }
        .textCase(.uppercase)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(Arkade.purple)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: Arkade.purpleBg, radius: 0, x: 0, y: 4)
    }
}

private struct RecentActivitySection: View {
    @Environment(AppManager.self) private var app
    var limit: Int?

    var body: some View {
        ArkadeSection(
            title: "Recent activity",
            actionTitle: app.state.transactions.isEmpty ? nil : "View all",
            action: nil
        ) {
            VStack(spacing: 0) {
                if app.state.transactions.isEmpty {
                    EmptyActivityView()
                } else {
                    ForEach(Array(app.state.transactions.prefix(limit ?? app.state.transactions.count).enumerated()), id: \.element.txid) { index, tx in
                        NavigationLink(value: Screen.transactionDetail(txid: tx.txid)) {
                            TransactionRow(tx: tx)
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(TapGesture().onEnded { app.haptic(.light) })

                        if index < min(limit ?? app.state.transactions.count, app.state.transactions.count) - 1 {
                            Divider().padding(.leading, 62)
                        }
                    }
                }
            }
            .arkadeLiquidCard()
        }
        .overlay(alignment: .topTrailing) {
            if !app.state.transactions.isEmpty, limit != nil {
                NavigationLink {
                    ActivityScreen()
                } label: {
                    HStack(spacing: 3) {
                        Text("View all")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Arkade.purpleText)
                }
                .padding(.top, 1)
                .buttonStyle(PressScaleButtonStyle())
            }
        }
    }
}

private struct EmptyActivityView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.tertiary)
            Text("No activity yet")
                .font(Arkade.smallFont)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

private struct ReceiveBlockIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 14
        let sy = rect.height / 20
        var path = Path()
        path.addRect(CGRect(x: 9.33398 * sx, y: 9.84058 * sy, width: 4.66676 * sx, height: 5.07956 * sy))
        path.addRect(CGRect(x: 0, y: 9.84058 * sy, width: 4.66676 * sx, height: 5.07956 * sy))
        path.addRect(CGRect(x: 4.95898 * sx, y: 0, width: 4.66676 * sx, height: 5.07956 * sy))
        path.addRect(CGRect(x: 4.66797 * sx, y: 14.9207 * sy, width: 4.66676 * sx, height: 5.07956 * sy))
        return path
    }
}

private struct SendBlockIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 13
        let sy = rect.height / 14
        let w = 4.33332 * sx
        let h = 4.33332 * sy
        var path = Path()
        path.addRect(CGRect(x: 0, y: 0.499878 * sy, width: w, height: h))
        path.addRect(CGRect(x: 4.33398 * sx, y: 0.499878 * sy, width: w, height: h))
        path.addRect(CGRect(x: 8.66602 * sx, y: 0.499878 * sy, width: w, height: h))
        path.addRect(CGRect(x: 8.66602 * sx, y: 4.83301 * sy, width: w, height: h))
        path.addRect(CGRect(x: 8.66602 * sx, y: 9.16675 * sy, width: w, height: h))
        path.addRect(CGRect(x: 0, y: 9.16675 * sy, width: w, height: h))
        return path
    }
}

private struct HistoryIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        let dx = rect.midX - 12 * s
        let dy = rect.midY - 12 * s
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: dx + x * s, y: dy + y * s) }

        var path = Path()
        path.move(to: p(12, 8))
        path.addLine(to: p(12, 12))
        path.addLine(to: p(14.5, 14.5))

        path.move(to: p(3.05, 11))
        path.addCurve(to: p(3.55, 15), control1: p(2.72, 12.37), control2: p(2.89, 13.72))
        path.addCurve(to: p(12, 21), control1: p(5.1, 18.55), control2: p(8.37, 21))
        path.addCurve(to: p(21, 12), control1: p(16.97, 21), control2: p(21, 16.97))
        path.addCurve(to: p(12, 3), control1: p(21, 7.03), control2: p(16.97, 3))
        path.addCurve(to: p(3.05, 11), control1: p(7.35, 3), control2: p(3.54, 6.53))

        path.move(to: p(3.05, 11))
        path.addLine(to: p(6, 11))
        path.move(to: p(3.05, 11))
        path.addLine(to: p(3.05, 7))
        return path
    }
}

private struct SettingsIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        let dx = rect.midX - 12 * s
        let dy = rect.midY - 12 * s
        func r(_ value: CGFloat) -> CGFloat { value * s }
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: dx + x * s, y: dy + y * s) }

        var path = Path()
        path.addEllipse(in: CGRect(x: dx + 9 * s, y: dy + 9 * s, width: 6 * s, height: 6 * s))
        for angle in stride(from: CGFloat(0), to: CGFloat.pi * 2, by: CGFloat.pi / 3) {
            let cx = 12 + cos(angle) * 6.7
            let cy = 12 + sin(angle) * 6.7
            path.addRoundedRect(
                in: CGRect(x: dx + cx * s - r(1.1), y: dy + cy * s - r(1.1), width: r(2.2), height: r(2.2)),
                cornerSize: CGSize(width: r(0.45), height: r(0.45))
            )
        }
        path.move(to: p(12, 3.6))
        path.addLine(to: p(12, 5.8))
        path.move(to: p(12, 18.2))
        path.addLine(to: p(12, 20.4))
        path.move(to: p(3.6, 12))
        path.addLine(to: p(5.8, 12))
        path.move(to: p(18.2, 12))
        path.addLine(to: p(20.4, 12))
        return path
    }
}

// MARK: - Activity

struct ActivityScreen: View {
    @Environment(AppManager.self) private var app

    var body: some View {
        ScrollView {
            RecentActivitySection(limit: nil)
                .padding(.horizontal, Arkade.hPadding)
                .padding(.top, 12)
        }
        .background(Arkade.canvasGrouped)
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            app.dispatch(.refreshTransactionHistory)
            try? await Task.sleep(for: .milliseconds(600))
        }
    }
}

// MARK: - Transaction Row

struct TransactionRow: View {
    let tx: TransactionItem

    var iconColor: Color {
        if tx.amountSats > 0 { return Arkade.green }
        return Arkade.dark80
    }

    var amountColor: Color {
        if tx.amountSats > 0 { return Arkade.green }
        return .primary
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(iconColor.opacity(0.14))
                .frame(width: 38, height: 38)
                .overlay {
                    Image(systemName: tx.amountSats > 0 ? "arrow.down.left" : "arrow.up.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(iconColor)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(tx.txType.label)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
                Text(tx.displayTime)
                    .font(Arkade.tinyFont)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(Arkade.signedSats(tx.amountSats))
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(amountColor)
                .lineLimit(1)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
    }
}

extension TransactionType {
    var label: String {
        switch self {
        case .boarding: "Boarding"
        case .commitment: "Commitment"
        case .ark: "Ark"
        case .offboard: "Offboard"
        case .submarineSwap: "Lightning send"
        case .reverseSwap: "Lightning receive"
        case .chainSwap: "Chain swap"
        case .assetMint: "Asset mint"
        case .assetBurn: "Asset burn"
        case .assetTransfer: "Asset transfer"
        }
    }
}

// MARK: - Transaction Detail

struct TransactionDetailScreen: View {
    @Environment(AppManager.self) private var app
    let txid: String

    var body: some View {
        let tx = app.state.transactions.first(where: { $0.txid == txid })

        ScrollView {
            if let tx {
                VStack(spacing: Arkade.gap) {
                    VStack(spacing: 6) {
                        Text(Arkade.signedSats(tx.amountSats))
                            .font(Arkade.balanceFont)
                            .tracking(Arkade.headingTracking)
                            .monospacedDigit()
                        Text(tx.isSettled ? "Settled" : "Pending")
                            .font(Arkade.smallFont)
                            .foregroundStyle(tx.isSettled ? Arkade.green : Arkade.orange)
                    }
                    .padding(.vertical, 24)

                    VStack(spacing: 0) {
                        detailRow("Type", value: tx.txType.label)
                        Divider()
                        detailRow("Time", value: tx.displayTime)
                        if let ticker = tx.assetTicker {
                            Divider()
                            detailRow("Asset", value: ticker)
                        }
                    }
                    .arkadeLiquidCard()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Transaction ID")
                            .font(Arkade.tinyFont)
                            .foregroundStyle(.secondary)
                        Text(tx.txid)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.primary.opacity(0.78))
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .arkadeLiquidCard()
                }
                .padding(.horizontal, Arkade.hPadding)
                .padding(.top, 12)
            }
        }
        .background(Arkade.canvasGrouped)
        .navigationTitle("Transaction")
        .navigationBarTitleDisplayMode(.inline)
    }

    func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).font(Arkade.smallFont).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.system(size: 14, weight: .medium))
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
    }
}

func formatAssetAmount(_ amount: UInt64, decimals: UInt8) -> String {
    guard decimals > 0 else { return amount.formatted(.number.grouping(.automatic)) }
    let scale = UInt64(pow(10.0, Double(decimals)))
    let whole = amount / scale
    let fraction = amount % scale
    if fraction == 0 { return whole.formatted(.number.grouping(.automatic)) }
    let fractionText = String(format: "%0*u", Int(decimals), fraction)
        .replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
    return "\(whole.formatted(.number.grouping(.automatic))).\(fractionText)"
}
