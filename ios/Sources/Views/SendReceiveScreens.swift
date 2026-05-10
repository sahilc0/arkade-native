import SwiftUI
import UIKit

// MARK: - Send Form

struct SendFormScreen: View {
    @Environment(AppManager.self) private var app
    @State private var recipient = ""
    @State private var amount = ""
    @State private var selectedAssetId: String?
    @State private var showReserveNote = false
    @State private var showScanner = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recipient address")
                        .font(Arkade.tinyFont)
                        .foregroundStyle(.secondary)

                    TextField("Address, invoice, LNURL, or BIP21", text: $recipient, axis: .vertical)
                        .lineLimit(1...4)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .font(Arkade.smallFont)
                        .padding(14)
                        .frame(minHeight: 54)
                        .background(Arkade.inset)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .onChange(of: recipient) { _, value in
                            if value.count > 10 {
                                app.dispatch(.parseRecipient(input: value))
                            }
                        }

                    HStack(spacing: 8) {
                        if let flow = app.state.sendFlow, flow.recipientType != .unknown {
                            Label(flow.recipientType.label, systemImage: "checkmark.circle.fill")
                                .font(Arkade.tinyFont)
                                .foregroundStyle(Arkade.green)
                        }
                        Spacer()
                        Button {
                            app.haptic(.light)
                            showScanner = true
                        } label: {
                            Label("Scan", systemImage: "qrcode.viewfinder")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .buttonStyle(.borderless)
                    }
                }

                if !assetChoices.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Asset")
                            .font(Arkade.tinyFont)
                            .foregroundStyle(.secondary)

                        Menu {
                            Button {
                                app.haptic(.light)
                                selectedAssetId = nil
                                amount = ""
                            } label: {
                                Label("bitcoin", systemImage: "bitcoinsign.circle.fill")
                            }

                            ForEach(assetChoices, id: \.assetId) { asset in
                                Button {
                                    app.haptic(.light)
                                    selectedAssetId = asset.assetId
                                    amount = ""
                                } label: {
                                    Text("\(asset.ticker) · \(asset.name)")
                                }
                            }
                        } label: {
                            HStack(spacing: 12) {
                                TokenBadge(ticker: selectedAsset?.ticker ?? "BTC", size: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(selectedAsset.map { "\($0.name) (\($0.ticker))" } ?? "bitcoin")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(.primary)
                                    Text(selectedAssetBalanceLabel)
                                        .font(Arkade.tinyFont)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(14)
                            .frame(minHeight: 68)
                            .background(Arkade.inset)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Amount")
                            .font(Arkade.tinyFont)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Max") {
                            app.haptic(.light)
                            applyMax()
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Arkade.purpleText)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        TextField("0", text: $amount)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 34, weight: .medium, design: .rounded))
                            .tracking(Arkade.headingTracking)
                            .monospacedDigit()
                            .disabled(amountLocked)
                        Text(selectedAsset?.ticker ?? "sats")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .frame(minHeight: 88)
                    .arkadeLiquidCard()

                    if showReserveNote {
                        Text("330 sats are kept in reserve to protect assets.")
                            .font(Arkade.tinyFont)
                            .foregroundStyle(Arkade.orange)
                    } else {
                        Text(selectedAssetBalanceLabel)
                            .font(Arkade.tinyFont)
                            .foregroundStyle(.secondary)
                    }
                }

                if let error = app.state.sendFlow?.error {
                    Text(error)
                        .font(Arkade.smallFont)
                        .foregroundStyle(Arkade.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, Arkade.hPadding)
            .padding(.top, 12)
            .padding(.bottom, 96)
        }
        .background(Arkade.canvasGrouped)
        .navigationTitle("Send")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                app.haptic(.medium)
                submit()
            } label: {
                Text(selectedAsset == nil ? "Continue" : "Send asset")
                    .arkadeButton(.primary)
            }
            .disabled(buttonDisabled)
            .opacity(buttonDisabled ? 0.45 : 1)
            .padding(Arkade.hPadding)
            .background(.regularMaterial)
        }
        .onAppear {
            app.dispatch(.refreshAssets)
            app.dispatch(.refreshBalance)
            app.dispatch(.connectBoltz)
            if recipient.isEmpty, let existing = app.state.sendFlow?.recipient, !existing.isEmpty {
                recipient = existing
            }
            if amount.isEmpty, let sats = app.state.sendFlow?.amountSats, sats > 0 {
                amount = "\(sats)"
            }
        }
        .onChange(of: app.state.sendFlow?.amountSats ?? 0) { _, sats in
            guard amountLocked, sats > 0 else { return }
            amount = "\(sats)"
        }
        .sheet(isPresented: $showScanner) {
            QRScannerSheet(title: "Scan recipient") { code in
                app.haptic(.success)
                recipient = code
                app.dispatch(.parseRecipient(input: code))
            }
        }
    }

    private var assetChoices: [AssetSummary] {
        app.state.assets?.assets ?? []
    }

    private var selectedAsset: AssetSummary? {
        guard let selectedAssetId else { return nil }
        return assetChoices.first { $0.assetId == selectedAssetId }
    }

    private var selectedAssetBalanceLabel: String {
        if let selectedAsset {
            return "\(formatAssetAmount(selectedAsset.balance, decimals: selectedAsset.decimals)) \(selectedAsset.ticker) available"
        }
        let sats = app.state.balance?.offchainTotalSats ?? 0
        return "\(Arkade.sats(sats)) sats available"
    }

    private var buttonDisabled: Bool {
        recipient.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || effectiveAmount == 0
            || app.state.sendFlow?.error != nil
    }

    private var parsedAmount: UInt64 {
        if let selectedAsset {
            return parseAssetAmount(amount, decimals: selectedAsset.decimals)
        }
        return UInt64(amount.filter(\.isNumber)) ?? 0
    }

    private var effectiveAmount: UInt64 {
        if amountLocked, let invoiceAmount = app.state.sendFlow?.amountSats {
            return invoiceAmount
        }
        return parsedAmount
    }

    private var amountLocked: Bool {
        app.state.sendFlow?.recipientType == .lightningInvoice
            && (app.state.sendFlow?.amountSats ?? 0) > 0
    }

    private func applyMax() {
        if let selectedAsset {
            amount = formatAssetAmount(selectedAsset.balance, decimals: selectedAsset.decimals)
            return
        }

        let available = app.state.balance?.offchainTotalSats ?? 0
        let hasAssets = !(app.state.assets?.assets ?? []).isEmpty
        let maxSendable = hasAssets && available > 330 ? available - 330 : available
        showReserveNote = hasAssets
        amount = "\(maxSendable)"
    }

    private func submit() {
        let cleanRecipient = recipient.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanRecipient.isEmpty, parsedAmount > 0 else { return }

        if let selectedAsset {
            app.dispatch(.transferAsset(assetId: selectedAsset.assetId, recipient: cleanRecipient, amount: parsedAmount))
        } else {
            app.dispatch(.parseRecipient(input: cleanRecipient))
            app.dispatch(.setSendAmount(sats: effectiveAmount))
            app.dispatch(.pushScreen(screen: .sendDetails))
        }
    }
}

extension RecipientType {
    var label: String {
        switch self {
        case .arkAddress: "Arkade address"
        case .bitcoinAddress: "bitcoin address"
        case .lightningInvoice: "Lightning invoice"
        case .lnUrl: "LNURL"
        case .bip21: "BIP21"
        case .arkNote: "ArkNote"
        case .unknown: "Unknown"
        }
    }
}

// MARK: - Send Details

struct SendDetailsScreen: View {
    @Environment(AppManager.self) private var app

    var body: some View {
        if let flow = app.state.sendFlow {
            ScrollView {
                VStack(spacing: Arkade.gap) {
                    VStack(spacing: 6) {
                        Text("\(Arkade.sats(flow.amountSats ?? 0))")
                            .font(Arkade.balanceFont)
                            .tracking(Arkade.headingTracking)
                            .monospacedDigit()
                        Text("sats")
                            .font(Arkade.smallFont)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 24)

                    VStack(spacing: 0) {
                        row("To", value: flow.confirmation?.recipientDisplay ?? flow.recipient)
                        Divider()
                        row("Type", value: flow.recipientType.label)
                        if let fee = flow.estimatedFeeSats {
                            Divider()
                            row("Fee", value: "\(Arkade.sats(fee)) sats")
                        }
                        if flow.confirmation?.isSwap == true {
                            Divider()
                            row("Route", value: "Boltz Lightning swap")
                        }
                    }
                    .arkadeLiquidCard()

                    if let error = flow.error {
                        Text(error)
                            .font(Arkade.smallFont)
                            .foregroundStyle(Arkade.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, Arkade.hPadding)
                .padding(.top, 12)
                .padding(.bottom, 96)
            }
            .background(Arkade.canvasGrouped)
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Group {
                    if flow.isSending {
                        ProgressView()
                            .controlSize(.large)
                            .tint(Arkade.purple)
                            .frame(maxWidth: .infinity, minHeight: 48)
                    } else {
                        Button {
                            app.haptic(.medium)
                            app.dispatch(.confirmSend)
                        } label: {
                            Text(flow.recipientType == .lightningInvoice ? "Pay invoice" : "Confirm send").arkadeButton(.primary)
                        }
                    }
                }
                .padding(Arkade.hPadding)
                .background(.regularMaterial)
            }
        } else {
            ContentUnavailableView("No send in progress", systemImage: "paperplane")
        }
    }

    func row(_ label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(Arkade.smallFont).foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
    }
}

// MARK: - Send Success

struct SendSuccessScreen: View {
    @Environment(AppManager.self) private var app
    var body: some View {
        SuccessScreen(title: "Sent", systemImage: "checkmark.circle.fill") {
            app.dispatch(.replaceScreen(screen: .home))
        }
    }
}

// MARK: - Receive Amount

struct ReceiveAmountScreen: View {
    @Environment(AppManager.self) private var app
    @State private var amount = ""
    @State private var receiveType: ReceiveType = .arkAddress

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Picker("Receive via", selection: $receiveType) {
                    Text("Arkade").tag(ReceiveType.arkAddress)
                    Text("On-chain").tag(ReceiveType.boardingAddress)
                    Text("Lightning").tag(ReceiveType.lightningInvoice)
                }
                .pickerStyle(.segmented)

                if receiveType == .lightningInvoice {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        TextField("0", text: $amount)
                            .keyboardType(.numberPad)
                            .font(.system(size: 34, weight: .medium, design: .rounded))
                            .monospacedDigit()
                        Text("sats")
                            .font(Arkade.smallFont)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .arkadeLiquidCard()
                }
            }
            .padding(Arkade.hPadding)
        }
        .background(Arkade.canvasGrouped)
        .navigationTitle("Receive")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            NavigationLink(value: Screen.receiveQrCode) {
                Text(receiveType == .lightningInvoice ? "Generate invoice" : "Generate address")
                    .arkadeButton(.primary)
            }
            .simultaneousGesture(TapGesture().onEnded {
                app.haptic(.medium)
                app.dispatch(.setReceiveType(receiveType: receiveType))
                if receiveType == .lightningInvoice, let sats = UInt64(amount), sats > 0 {
                    app.dispatch(.setReceiveAmount(sats: sats))
                }
                app.dispatch(.generateReceiveAddress)
            })
            .padding(Arkade.hPadding)
            .background(.regularMaterial)
        }
    }
}

// MARK: - Receive QR Code

struct ReceiveQRCodeScreen: View {
    @Environment(AppManager.self) private var app
    @State private var selectedTicker: ReceiveAssetTicker = .btc
    @State private var showAmountSheet = false
    @State private var showCopySheet = false
    @State private var amount = ""

    enum ReceiveAssetTicker: String, CaseIterable, Identifiable {
        case btc = "BTC"
        case usdt = "USDT"
        case usdc = "USDC"
        var id: String { rawValue }
        var name: String {
            switch self {
            case .btc: "Bitcoin"
            case .usdt: "USDT"
            case .usdc: "USDC"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: 14) {
                receiveAssetMenu

                if let flow = app.state.receiveFlow, flow.isGenerating {
                    ProgressView()
                        .controlSize(.large)
                        .tint(Arkade.purple)
                        .frame(width: 260, height: 260)
                } else if let flow = app.state.receiveFlow, let error = flow.error {
                    ContentUnavailableView("Could not generate receive code", systemImage: "exclamationmark.triangle", description: Text(error))
                        .frame(minHeight: 260)
                } else {
                    QRCodeView(data: qrData)
                        .frame(width: 300, height: 300)
                        .padding(14)
                        .background(Arkade.white)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 6)
                        .onTapGesture {
                            copy(qrData)
                        }

                    if requestedAmount > 0 {
                        Text("Requesting \(Arkade.sats(requestedAmount)) \(selectedTicker == .btc ? "sats" : selectedTicker.rawValue)")
                            .font(Arkade.smallFont)
                            .foregroundStyle(.secondary)
                    }

                    Text(displayAddress)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .truncationMode(.middle)
                        .padding(.horizontal, 30)
                        .textSelection(.enabled)
                }
            }

            Spacer(minLength: 0)
        }
        .background(Arkade.canvasGrouped)
        .navigationTitle("Receive")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                LinearGradient(
                    stops: [
                        .init(color: Arkade.canvasGrouped.opacity(0), location: 0),
                        .init(color: Arkade.canvasGrouped.opacity(0.78), location: 0.55),
                        .init(color: Arkade.canvasGrouped, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 24)

                HStack(spacing: 10) {
                    Button {
                        app.haptic(.light)
                        amount = requestedAmount > 0 ? "\(requestedAmount)" : ""
                        showAmountSheet = true
                    } label: {
                        Text(requestedAmount > 0 ? "Edit amount" : "Add amount")
                            .arkadeButton(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    Button {
                        app.haptic(.light)
                        showCopySheet = true
                    } label: {
                        Text("Copy").arkadeButton(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                ShareLink(item: qrData) {
                    Text("Share")
                        .arkadeButton(.primary)
                }
            }
            .padding(.horizontal, Arkade.hPadding)
            .padding(.bottom, 8)
            .background(Arkade.canvasGrouped)
        }
        .sheet(isPresented: $showAmountSheet) {
            NavigationStack {
                VStack(spacing: 16) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        TextField("0", text: $amount)
                            .keyboardType(.numberPad)
                            .font(.system(size: 34, weight: .medium, design: .rounded))
                            .monospacedDigit()
                        Text(selectedTicker == .btc ? "sats" : selectedTicker.rawValue)
                            .font(Arkade.smallFont)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .arkadeLiquidCard()

                    Button {
                        app.haptic(.medium)
                        let sats = UInt64(amount.filter(\.isNumber)) ?? 0
                        app.dispatch(.setReceiveAmount(sats: sats))
                        app.dispatch(.generateReceiveAddress)
                        showAmountSheet = false
                    } label: {
                        Text("Set amount").arkadeButton(.primary)
                    }

                    if requestedAmount > 0 {
                        Button {
                            app.haptic(.light)
                            app.dispatch(.setReceiveAmount(sats: 0))
                            app.dispatch(.generateReceiveAddress)
                            showAmountSheet = false
                        } label: {
                            Text("Clear amount").arkadeButton(.secondary)
                        }
                    }

                    Spacer()
                }
                .padding(Arkade.hPadding)
                .background(Arkade.canvasGrouped)
                .navigationTitle("Add amount")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showCopySheet) {
            CopyAddressSheet(
                unified: qrData,
                address: displayAddress,
                onCopy: copy
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            if app.state.receiveFlow == nil {
                app.dispatch(.setReceiveType(receiveType: .arkAddress))
                app.dispatch(.generateReceiveAddress)
            }
        }
    }

    private var receiveAssetMenu: some View {
        Menu {
            ForEach(ReceiveAssetTicker.allCases) { ticker in
                Button {
                    app.haptic(.light)
                    selectedTicker = ticker
                } label: {
                    Text(ticker.name)
                }
            }
        } label: {
            HStack(spacing: 8) {
                TokenBadge(ticker: selectedTicker.rawValue, size: 24)
                Text(selectedTicker.name)
                    .font(.system(size: 14, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(Arkade.inset)
            .clipShape(Capsule())
        }
    }

    private var qrData: String {
        app.state.receiveFlow?.qrData ?? app.state.receiveFlow?.addressOrInvoice ?? ""
    }

    private var displayAddress: String {
        app.state.receiveFlow?.addressOrInvoice ?? "Generating address..."
    }

    private var requestedAmount: UInt64 {
        app.state.receiveFlow?.amountSats ?? 0
    }

    private func copy(_ value: String) {
        guard !value.isEmpty else { return }
        app.haptic(.light)
        UIPasteboard.general.string = value
        app.dispatch(.clearToast)
    }
}

private struct CopyAddressSheet: View {
    let unified: String
    let address: String
    let onCopy: (String) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                addressRow(title: "Unified", value: unified)
                addressRow(title: "Arkade", value: address)
                Spacer()
            }
            .padding(Arkade.hPadding)
            .background(Arkade.canvasGrouped)
            .navigationTitle("Copy address")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func addressRow(title: String, value: String) -> some View {
        Button {
            onCopy(value)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary)
                    Text(value.isEmpty ? "Unavailable" : value)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Image(systemName: "doc.on.doc")
                    .foregroundStyle(Arkade.purpleText)
            }
            .padding(15)
            .arkadeLiquidCard()
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.985))
        .disabled(value.isEmpty)
    }
}

// MARK: - Receive Success

struct ReceiveSuccessScreen: View {
    @Environment(AppManager.self) private var app
    var body: some View {
        SuccessScreen(title: "Received", systemImage: "checkmark.circle.fill") {
            app.dispatch(.replaceScreen(screen: .home))
        }
    }
}

struct SuccessScreen: View {
    let title: String
    let systemImage: String
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: systemImage)
                .font(.system(size: 54, weight: .medium))
                .foregroundStyle(Arkade.green)
            Text(title)
                .font(.system(size: 25, weight: .medium, design: .rounded))
                .tracking(Arkade.headingTracking)
            Spacer()
            Button(action: onDone) {
                Text("Done").arkadeButton(.primary)
            }
            .padding(.horizontal, Arkade.hPadding)
            .padding(.bottom, 28)
        }
        .background(Arkade.canvasGrouped)
    }
}

private func parseAssetAmount(_ text: String, decimals: UInt8) -> UInt64 {
    let parts = text.split(separator: ".", maxSplits: 1).map(String.init)
    let whole = UInt64(parts.first?.filter(\.isNumber) ?? "") ?? 0
    let scale = UInt64(pow(10.0, Double(decimals)))
    guard decimals > 0 else { return whole }

    let fractionString = parts.count > 1 ? String(parts[1].filter(\.isNumber).prefix(Int(decimals))) : ""
    let paddedFraction = fractionString.padding(toLength: Int(decimals), withPad: "0", startingAt: 0)
    let fraction = UInt64(paddedFraction) ?? 0
    return whole * scale + fraction
}
