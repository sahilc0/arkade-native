import SwiftUI
import Foundation

// MARK: - Home

struct HomeScreen: View {
    @Environment(AppManager.self) private var app

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                HomeHeader()
                    .padding(.top, 8)

                PortfolioHero()

                HomeQuickActions()

                AssetsHomeSection()

                UpsellsHomeSection()

                RecentActivitySection(limit: 3)
            }
            .padding(.horizontal, Arkade.hPadding)
            .padding(.bottom, 28)
        }
        .background(Arkade.canvasGrouped)
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
    }
}

private struct HomeHeader: View {
    @Environment(AppManager.self) private var app

    var body: some View {
        HStack {
            HStack(spacing: 10) {
                ArkadeMark(size: 38)
                Text("Arkade")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .tracking(Arkade.headingTracking)
            }

            Spacer()

            HStack(spacing: 6) {
                NavigationLink {
                    ActivityScreen()
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 19, weight: .medium))
                        .frame(width: Arkade.minTap, height: Arkade.minTap)
                }
                .buttonStyle(PressScaleButtonStyle())
                .simultaneousGesture(TapGesture().onEnded { app.haptic(.light) })
                .accessibilityLabel("View recent activity")

                NavigationLink(value: Screen.settingsMenu) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 19, weight: .medium))
                        .frame(width: Arkade.minTap, height: Arkade.minTap)
                }
                .buttonStyle(PressScaleButtonStyle())
                .simultaneousGesture(TapGesture().onEnded { app.haptic(.light) })
                .accessibilityLabel("Open settings")
            }
            .foregroundStyle(.primary)
        }
        .frame(height: 54)
    }
}

private struct ArkadeMark: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(Arkade.purple)
            Image(systemName: "bolt.horizontal.fill")
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(Arkade.white)
        }
        .frame(width: size, height: size)
        .shadow(color: Arkade.purple.opacity(0.24), radius: 14, x: 0, y: 8)
        .accessibilityHidden(true)
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
                    .font(Arkade.balanceFont)
                    .tracking(Arkade.headingTracking)
                    .contentTransition(.numericText())
                    .fontDesign(.rounded)
                    .monospacedDigit()

                Text(balanceCaption)
                    .font(Arkade.smallFont)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.bottom, 2)
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

    private var balanceCaption: String {
        guard app.state.config.showBalance else { return "Tap to show balance" }
        switch app.state.config.currencyDisplay {
        case .fiatOnly:
            return "Portfolio"
        case .both:
            guard let balance = app.state.balance else { return "Portfolio" }
            return "\(Arkade.sats(balance.offchainTotalSats)) sats"
        case .satsOnly:
            return "sats available"
        }
    }
}

private struct HomeQuickActions: View {
    @Environment(AppManager.self) private var app
    @State private var showScanner = false

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
            NavigationLink(value: Screen.receiveQrCode) {
                HomeQuickAction(icon: "arrow.down.left", title: "Receive")
            }
            .simultaneousGesture(TapGesture().onEnded {
                app.haptic(.light)
                app.dispatch(.setReceiveType(receiveType: .arkAddress))
                app.dispatch(.generateReceiveAddress)
            })

            NavigationLink(value: Screen.sendForm) {
                HomeQuickAction(icon: "arrow.up.right", title: "Send")
            }
            .simultaneousGesture(TapGesture().onEnded { app.haptic(.light) })

            NavigationLink {
                WalletSwapScreen()
            } label: {
                HomeQuickAction(icon: "arrow.triangle.2.circlepath", title: "Swap")
            }
            .simultaneousGesture(TapGesture().onEnded { app.haptic(.light) })

            Button {
                app.haptic(.light)
                showScanner = true
            } label: {
                HomeQuickAction(icon: "qrcode.viewfinder", title: "Scan")
            }
        }
        .buttonStyle(PressScaleButtonStyle())
        .sheet(isPresented: $showScanner) {
            QRScannerSheet(title: "Scan recipient") { code in
                app.haptic(.success)
                app.dispatch(.parseRecipient(input: code))
                app.dispatch(.pushScreen(screen: .sendForm))
            }
        }
    }
}

private struct HomeQuickAction: View {
    let icon: String
    let title: String

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .semibold))
                .frame(width: 24, height: 24)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(Arkade.purpleText)
        .frame(maxWidth: .infinity)
        .frame(height: 70)
        .background(Arkade.purple10)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Arkade.purple20.opacity(0.5), lineWidth: 1)
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
                    name: "bitcoin",
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
                .frame(width: 42, height: 42)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
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
