import SwiftUI

struct WalletSwapScreen: View {
    @Environment(AppManager.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var step: SwapStep = .selectFrom
    @State private var search = ""
    @State private var amount = "1"
    @State private var amountMode: AmountMode = .fiat
    @State private var fromAssetId = "btc"
    @State private var toAssetId: String?
    @State private var showingToPicker = false
    @State private var showingReview = false
    @State private var swapTurn = 0

    enum SwapStep { case selectFrom, compose }
    enum AmountMode { case asset, fiat }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 14) {
                    switch step {
                    case .selectFrom:
                        SwapAssetList(
                            title: "Choose asset to swap",
                            subtitle: "Select the asset you want to trade from.",
                            search: $search,
                            assets: filteredAssets,
                            selectedId: fromAssetId
                        ) { asset in
                            app.haptic(.light)
                            fromAssetId = asset.id
                            if toAssetId == asset.id { toAssetId = nil }
                            search = ""
                            withAnimation(.smooth(duration: 0.24)) {
                                step = .compose
                            }
                        }
                        .transition(.move(edge: .leading).combined(with: .opacity))

                    case .compose:
                        SwapComposer(
                            amount: amount,
                            amountMode: amountMode,
                            fromAsset: fromAsset,
                            toAsset: toAsset,
                            quote: quote,
                            swapTurn: swapTurn,
                            onToggleMode: toggleAmountMode,
                            onSwapSides: swapSides,
                            onChooseReceive: { showingToPicker = true }
                        )
                        .transition(.move(edge: .trailing).combined(with: .opacity))

                        SwapKeypad(amount: amount) { key in
                            app.haptic(.light)
                            pressKey(key)
                        }

                        Button {
                            app.haptic(.medium)
                            showingReview = true
                        } label: {
                            Text("Continue")
                                .arkadeButton(.primary)
                        }
                        .disabled(toAsset == nil || Double(amount) ?? 0 <= 0)
                        .opacity(toAsset == nil || Double(amount) ?? 0 <= 0 ? 0.45 : 1)
                    }
                }
                .padding(.horizontal, Arkade.hPadding)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .background(Arkade.canvasGrouped)
        .navigationTitle("Swap")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if step == .compose {
                        app.haptic(.light)
                        withAnimation(.smooth(duration: 0.22)) { step = .selectFrom }
                    } else {
                        dismiss()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                }
            }
        }
        .sheet(isPresented: $showingToPicker) {
            SwapAssetPickerSheet(
                title: "Choose asset to receive",
                assets: assets.filter { $0.id != fromAsset.id },
                selectedId: toAssetId
            ) { asset in
                app.haptic(.light)
                toAssetId = asset.id
                showingToPicker = false
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingReview) {
            SwapReviewSheet(quote: quote) {
                app.haptic(.warning)
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            app.dispatch(.refreshAssets)
            if fromAssetId == "btc", let first = assets.first?.id {
                fromAssetId = first
            }
        }
    }

    private var assets: [SwapAsset] {
        var rows: [SwapAsset] = [
            SwapAsset(
                id: "btc",
                name: "bitcoin",
                ticker: "BTC",
                balance: app.state.balance.map { "\(Arkade.sats($0.offchainTotalSats)) sats" } ?? "-- sats",
                fiat: app.state.balance?.fiatValue,
                usdPrice: 81_500
            )
        ]

        if let assets = app.state.assets?.assets {
            rows.append(contentsOf: assets.map {
                SwapAsset(
                    id: $0.assetId,
                    name: $0.name,
                    ticker: $0.ticker,
                    balance: "\(formatAssetAmount($0.balance, decimals: $0.decimals)) \($0.ticker)",
                    fiat: nil,
                    usdPrice: prototypeUsd(ticker: $0.ticker)
                )
            })
        }

        if rows.count < 2 {
            rows.append(
                SwapAsset(
                    id: "prototype-usdc",
                    name: "USDC",
                    ticker: "USDC",
                    balance: "0 USDC",
                    fiat: "$0.00",
                    usdPrice: 1
                )
            )
        }

        return rows
    }

    private var filteredAssets: [SwapAsset] {
        let normalized = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return assets }
        return assets.filter {
            $0.name.lowercased().contains(normalized) || $0.ticker.lowercased().contains(normalized)
        }
    }

    private var fromAsset: SwapAsset {
        assets.first { $0.id == fromAssetId } ?? assets[0]
    }

    private var toAsset: SwapAsset? {
        guard let toAssetId else { return nil }
        return assets.first { $0.id == toAssetId && $0.id != fromAsset.id }
    }

    private var quote: SwapQuote {
        buildQuote(amount: amount, mode: amountMode, from: fromAsset, to: toAsset)
    }

    private func toggleAmountMode() {
        app.haptic(.light)
        withAnimation(.smooth(duration: 0.18)) {
            amountMode = amountMode == .fiat ? .asset : .fiat
        }
    }

    private func swapSides() {
        guard let toAsset else { return }
        app.haptic(.light)
        swapTurn += 1
        let currentFrom = fromAsset.id
        fromAssetId = toAsset.id
        toAssetId = currentFrom
    }

    private func pressKey(_ key: String) {
        if key == "delete" {
            amount = String(amount.dropLast())
            if amount.isEmpty { amount = "0" }
            return
        }
        if key == "." && amount.contains(".") { return }
        let base = amount == "0" ? "" : amount
        amount = String((base + key).prefix(10))
    }
}

struct SwapAsset: Identifiable, Hashable {
    let id: String
    let name: String
    let ticker: String
    let balance: String
    let fiat: String?
    let usdPrice: Double
}

struct SwapQuote {
    let fromAsset: SwapAsset
    let toAsset: SwapAsset?
    let fromAmount: String
    let fromFiat: String
    let toAmount: String
    let toFiat: String
    let rateLabel: String
}

private struct SwapAssetList: View {
    let title: String
    let subtitle: String
    @Binding var search: String
    let assets: [SwapAsset]
    let selectedId: String?
    let onSelect: (SwapAsset) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .tracking(Arkade.headingTracking)
                Text(subtitle)
                    .font(Arkade.smallFont)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search assets", text: $search)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 50)
            .background(Arkade.inset)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(spacing: 4) {
                if assets.isEmpty {
                    Text("No assets found")
                        .font(Arkade.smallFont)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 120)
                        .arkadeLiquidCard()
                } else {
                    ForEach(assets) { asset in
                        Button {
                            onSelect(asset)
                        } label: {
                            SwapAssetRow(asset: asset, active: selectedId == asset.id)
                        }
                        .buttonStyle(PressScaleButtonStyle(scale: 0.985))
                    }
                }
            }
        }
    }
}

private struct SwapAssetRow: View {
    let asset: SwapAsset
    var active = false

    var body: some View {
        HStack(spacing: 12) {
            TokenBadge(ticker: asset.ticker, size: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(asset.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)
                Text(asset.balance)
                    .font(Arkade.smallFont)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let fiat = asset.fiat {
                Text(fiat)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.76))
                    .monospacedDigit()
            }

            if active {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Arkade.purpleText)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minHeight: 64)
        .background(active ? Arkade.purple10 : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct SwapComposer: View {
    let amount: String
    let amountMode: WalletSwapScreen.AmountMode
    let fromAsset: SwapAsset
    let toAsset: SwapAsset?
    let quote: SwapQuote
    let swapTurn: Int
    let onToggleMode: () -> Void
    let onSwapSides: () -> Void
    let onChooseReceive: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            VStack(spacing: 18) {
                HStack(spacing: 10) {
                    TokenBadge(ticker: fromAsset.ticker)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fromAsset.name)
                            .font(.system(size: 15, weight: .medium))
                        Text(fromAsset.balance)
                            .font(Arkade.tinyFont)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(amountMode == .fiat ? fromAsset.ticker : "USD", action: onToggleMode)
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(Arkade.inset)
                        .clipShape(Capsule())
                }

                VStack(spacing: 5) {
                    Text(amountMode == .fiat ? "$\(amount)" : amount)
                        .font(.system(size: 46, weight: .medium, design: .rounded))
                        .tracking(Arkade.headingTracking)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .contentTransition(.numericText())
                    Text(amountMode == .fiat ? "\(quote.fromAmount) \(fromAsset.ticker)" : quote.fromFiat)
                        .font(Arkade.smallFont)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(18)
            .frame(minHeight: 208)
            .arkadeLiquidCard()

            Button(action: onSwapSides) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 18, weight: .semibold))
                    .rotationEffect(.degrees(Double(swapTurn * 180)))
                    .frame(width: Arkade.minTap, height: Arkade.minTap)
                    .foregroundStyle(Arkade.purpleText)
                    .background(Arkade.surface)
                    .clipShape(Circle())
                    .arkadeLiquidCard(cornerRadius: Arkade.radiusPill)
            }
            .buttonStyle(PressScaleButtonStyle())
            .disabled(toAsset == nil)
            .opacity(toAsset == nil ? 0.45 : 1)
            .padding(.vertical, -8)
            .zIndex(1)

            Button(action: onChooseReceive) {
                HStack(spacing: 12) {
                    if let toAsset {
                        TokenBadge(ticker: toAsset.ticker)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Receive \(toAsset.ticker)")
                                .font(.system(size: 15, weight: .medium))
                            Text("\(quote.toAmount) \(toAsset.ticker)")
                                .font(Arkade.tinyFont)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(quote.toFiat)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.78))
                    } else {
                        Circle()
                            .fill(Arkade.inset)
                            .frame(width: 36, height: 36)
                            .overlay {
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Receive")
                                .font(.system(size: 15, weight: .medium))
                            Text("Choose asset")
                                .font(Arkade.tinyFont)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 15)
                .frame(minHeight: 68)
                .arkadeLiquidCard()
            }
            .buttonStyle(PressScaleButtonStyle(scale: 0.985))
        }
    }
}

private struct SwapKeypad: View {
    let amount: String
    let onPress: (String) -> Void

    private let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", ".", "0", "delete"]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 2) {
            ForEach(keys, id: \.self) { key in
                Button {
                    onPress(key)
                } label: {
                    Group {
                        if key == "delete" {
                            Image(systemName: "delete.left")
                        } else {
                            Text(key)
                        }
                    }
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityLabel(key == "delete" ? "Delete digit" : key)
            }
        }
        .padding(.vertical, 4)
        .accessibilityLabel("Swap keypad for \(amount)")
    }
}

private struct SwapAssetPickerSheet: View {
    let title: String
    let assets: [SwapAsset]
    let selectedId: String?
    let onSelect: (SwapAsset) -> Void
    @State private var search = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                SwapAssetList(
                    title: title,
                    subtitle: "Pick the asset for this side of the swap.",
                    search: $search,
                    assets: filteredAssets,
                    selectedId: selectedId,
                    onSelect: onSelect
                )
                .padding(Arkade.hPadding)
            }
            .background(Arkade.canvasGrouped)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var filteredAssets: [SwapAsset] {
        let normalized = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return assets }
        return assets.filter {
            $0.name.lowercased().contains(normalized) || $0.ticker.lowercased().contains(normalized)
        }
    }
}

private struct SwapReviewSheet: View {
    let quote: SwapQuote
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Review swap")
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .tracking(Arkade.headingTracking)
                Text("Check the route and estimated totals.")
                    .font(Arkade.smallFont)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 14) {
                HStack(spacing: -8) {
                    TokenBadge(ticker: quote.fromAsset.ticker, size: 48)
                    if let toAsset = quote.toAsset {
                        TokenBadge(ticker: toAsset.ticker, size: 48)
                    }
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Swap route")
                        .font(Arkade.tinyFont)
                        .foregroundStyle(.secondary)
                    Text("\(quote.fromAsset.ticker) to \(quote.toAsset?.ticker ?? "asset")")
                        .font(.system(size: 21, weight: .medium, design: .rounded))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()
                metric("Swap \(quote.fromAsset.ticker)", value: "\(quote.fromAmount) \(quote.fromAsset.ticker)")
                metric("Receive \(quote.toAsset?.ticker ?? "asset")", value: quote.toAsset.map { "\(quote.toAmount) \($0.ticker)" } ?? "Choose asset")
                metric("Total value", value: quote.toFiat)
                metric("Rate", value: quote.toAsset.map { "1 \(quote.fromAsset.ticker) = \(quote.rateLabel) \($0.ticker)" } ?? "Pending")
                metric("Arrival", value: "About 12 seconds")
            }
            .padding(18)
            .arkadeLiquidCard()

            Button(action: onConfirm) {
                Text("Confirm swap")
                    .arkadeButton(.primary)
            }
            .disabled(true)
            .opacity(0.5)

            Spacer(minLength: 0)
        }
        .padding(Arkade.hPadding)
        .background(Arkade.canvasGrouped)
    }

    private func metric(_ label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(Arkade.smallFont)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .multilineTextAlignment(.trailing)
        }
        .frame(minHeight: 28)
    }
}

private func buildQuote(
    amount: String,
    mode: WalletSwapScreen.AmountMode,
    from: SwapAsset,
    to: SwapAsset?
) -> SwapQuote {
    let parsed = Double(amount) ?? 0
    let fromUnits = mode == .fiat && from.usdPrice > 0 ? parsed / from.usdPrice : parsed
    let fromFiat = mode == .fiat ? parsed : fromUnits * from.usdPrice
    let toUnits = to.map { $0.usdPrice > 0 ? fromFiat / $0.usdPrice : 0 } ?? 0
    let rate = to.map { $0.usdPrice > 0 ? from.usdPrice / $0.usdPrice : 0 } ?? 0

    return SwapQuote(
        fromAsset: from,
        toAsset: to,
        fromAmount: compactNumber(fromUnits),
        fromFiat: currency(fromFiat),
        toAmount: compactNumber(toUnits),
        toFiat: currency(toUnits * (to?.usdPrice ?? 0)),
        rateLabel: compactNumber(rate)
    )
}

private func prototypeUsd(ticker: String) -> Double {
    let normalized = ticker.uppercased()
    if normalized == "BTC" { return 81_500 }
    if normalized.contains("USD") { return 1 }
    if normalized == "POP" { return 0.0042 }
    return max(0.01, Double(normalized.count) * 0.17)
}

private func compactNumber(_ value: Double) -> String {
    let maximum = value >= 1 ? 4 : 8
    return value.formatted(.number.precision(.fractionLength(0...maximum)).grouping(.automatic))
}

private func currency(_ value: Double) -> String {
    value.formatted(.currency(code: "USD").precision(.fractionLength(2)))
}
