import SwiftUI

// MARK: - Settings Menu

struct SettingsMenuScreen: View {
    @Environment(AppManager.self) private var app

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                settingsRow("General", subtitle: "Theme, currency, display, haptics", icon: "slider.horizontal.3", dest: .settingsGeneral)
                settingsRow("Password", subtitle: "Passcode and biometric access", icon: "lock", dest: .settingsPassword)
                settingsRow("Backup", subtitle: "Recovery phrase and Nostr backup", icon: "shield.lefthalf.filled", dest: .settingsBackup)
                settingsRow("VTXOs", subtitle: "Inspect and settle recoverable funds", icon: "square.stack.3d.up", dest: .settingsVtxos)
                settingsRow("Delegates", subtitle: "Manage delegated signing", icon: "person.2", dest: .settingsDelegates)
                settingsRow("Advanced", subtitle: "Server, logs, and support tools", icon: "wrench.and.screwdriver", dest: .settingsAdvanced)
                settingsRow("About", subtitle: "Version and project information", icon: "info.circle", dest: .settingsAbout)

                NavigationLink(value: Screen.settingsReset) {
                    SettingsMenuRow(
                        title: "Reset wallet",
                        subtitle: "Remove local wallet data from this device",
                        icon: "exclamationmark.triangle",
                        tint: Arkade.red
                    )
                }
                .buttonStyle(PressScaleButtonStyle(scale: 0.985))
            }
            .padding(.horizontal, Arkade.hPadding)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(Arkade.canvasGrouped)
        .navigationTitle("Settings")
    }

    func settingsRow(_ title: String, subtitle: String, icon: String, dest: Screen) -> some View {
        NavigationLink(value: dest) {
            SettingsMenuRow(title: title, subtitle: subtitle, icon: icon)
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.985))
    }
}

private struct SettingsMenuRow: View {
    let title: String
    let subtitle: String
    let icon: String
    var tint: Color = .secondary

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(tint.opacity(0.10))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(tint == Arkade.red ? Arkade.red : .primary)
                Text(subtitle)
                    .font(Arkade.tinyFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(15)
        .frame(minHeight: 74)
        .arkadeLiquidCard()
    }
}

// MARK: - List Screens

struct SettingsThemeScreen: View {
    @Environment(AppManager.self) private var app
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach([Theme.light, .dark, .system], id: \.self) { theme in
                    Button { app.dispatch(.setTheme(theme: theme)) } label: {
                        HStack {
                            Text(theme.label).font(Arkade.smallFont)
                            Spacer()
                            if app.state.config.theme == theme {
                                Image(systemName: "checkmark").foregroundStyle(Arkade.purple)
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    Divider().background(Arkade.dark20)
                }
            }
            .background(Arkade.dark05)
            .clipShape(RoundedRectangle(cornerRadius: Arkade.radius, style: .continuous))
            .padding(.horizontal, Arkade.hPadding).padding(.top, 8)
        }
        .background(Arkade.canvasGrouped)
        .navigationTitle("Theme")
    }
}

extension Theme {
    var label: String {
        switch self { case .light: "Light"; case .dark: "Dark"; case .system: "System" }
    }
}

struct SettingsDisplayScreen: View {
    @Environment(AppManager.self) private var app
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach([CurrencyDisplay.satsOnly, .fiatOnly, .both], id: \.self) { d in
                    Button { app.dispatch(.setCurrencyDisplay(display: d)) } label: {
                        HStack {
                            Text(d.label).font(Arkade.smallFont)
                            Spacer()
                            if app.state.config.currencyDisplay == d {
                                Image(systemName: "checkmark").foregroundStyle(Arkade.purple)
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    Divider().background(Arkade.dark20)
                }
            }
            .background(Arkade.dark05).clipShape(RoundedRectangle(cornerRadius: Arkade.radius))
            .padding(.horizontal, Arkade.hPadding).padding(.top, 8)
        }
        .background(Arkade.canvasGrouped)
        .navigationTitle("Display")
    }
}

extension CurrencyDisplay {
    var label: String {
        switch self { case .satsOnly: "Sats only"; case .fiatOnly: "Fiat only"; case .both: "Both" }
    }
}

struct SettingsFiatScreen: View {
    @Environment(AppManager.self) private var app
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach([FiatCurrency.usd, .eur, .chf], id: \.self) { c in
                    Button { app.dispatch(.setFiatCurrency(currency: c)) } label: {
                        HStack {
                            Text(c.label).font(Arkade.smallFont)
                            Spacer()
                            if app.state.config.fiatCurrency == c {
                                Image(systemName: "checkmark").foregroundStyle(Arkade.purple)
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    Divider().background(Arkade.dark20)
                }
            }
            .background(Arkade.dark05).clipShape(RoundedRectangle(cornerRadius: Arkade.radius))
            .padding(.horizontal, Arkade.hPadding).padding(.top, 8)
        }
        .background(Arkade.canvasGrouped)
        .navigationTitle("Currency")
    }
}

extension FiatCurrency {
    var label: String {
        switch self { case .usd: "USD"; case .eur: "EUR"; case .chf: "CHF" }
    }
}

// MARK: - Toggle Screens

struct SettingsGeneralScreen: View {
    @Environment(AppManager.self) private var app

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                preferenceRow("Theme", value: app.state.config.theme.label, icon: "circle.lefthalf.filled", dest: .settingsTheme)
                preferenceRow("Display", value: app.state.config.currencyDisplay.label, icon: "textformat.size", dest: .settingsDisplay)
                preferenceRow("Currency", value: app.state.config.fiatCurrency.label, icon: "dollarsign", dest: .settingsFiat)
                preferenceRow("Haptics", value: app.state.config.hapticsEnabled ? "On" : "Off", icon: "hand.tap", dest: .settingsHaptics)
                preferenceRow("Notifications", value: app.state.config.notificationsEnabled ? "On" : "Off", icon: "bell", dest: .settingsNotifications)
            }
            .padding(Arkade.hPadding)
        }
        .background(Arkade.canvasGrouped)
        .navigationTitle("General")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func preferenceRow(_ title: String, value: String, icon: String, dest: Screen) -> some View {
        NavigationLink(value: dest) {
            HStack(spacing: 13) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 38, height: 38)
                    .background(Color.secondary.opacity(0.10))
                    .clipShape(Circle())
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
                Spacer()
                Text(value)
                    .font(Arkade.smallFont)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(15)
            .arkadeLiquidCard()
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.985))
    }
}

struct SettingsHapticsScreen: View {
    @Environment(AppManager.self) private var app
    var body: some View {
        ScrollView {
            Toggle("Haptic feedback", isOn: Binding(
                get: { app.state.config.hapticsEnabled },
                set: { app.dispatch(.setHaptics(enabled: $0)) }
            ))
            .tint(Arkade.purple)
            .padding(12)
            .background(Arkade.dark05)
            .clipShape(RoundedRectangle(cornerRadius: Arkade.radius))
            .padding(.horizontal, Arkade.hPadding).padding(.top, 8)
        }
        .navigationTitle("Haptics")
    }
}

struct SettingsNotificationsScreen: View {
    @Environment(AppManager.self) private var app
    var body: some View {
        ScrollView {
            Toggle("Notifications", isOn: Binding(
                get: { app.state.config.notificationsEnabled },
                set: { app.dispatch(.setNotifications(enabled: $0)) }
            ))
            .tint(Arkade.purple)
            .padding(12)
            .background(Arkade.dark05)
            .clipShape(RoundedRectangle(cornerRadius: Arkade.radius))
            .padding(.horizontal, Arkade.hPadding).padding(.top, 8)
        }
        .navigationTitle("Notifications")
    }
}

struct SettingsPasswordScreen: View {
    var body: some View { Text("Password").font(Arkade.headingFont).navigationTitle("Password") }
}

struct SettingsBackupScreen: View {
    @Environment(AppManager.self) private var app
    var body: some View {
        ScrollView {
            VStack(spacing: Arkade.gap) {
                Button { app.dispatch(.revealMnemonic(password: "")) } label: {
                    HStack {
                        Text("Reveal mnemonic").font(Arkade.smallFont)
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(Arkade.dark30)
                    }
                    .padding(12)
                }
                .buttonStyle(.plain)
                .background(Arkade.dark05)
                .clipShape(RoundedRectangle(cornerRadius: Arkade.radius))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Nostr backup").font(.system(size: 14, weight: .medium))
                    Text("Not yet available").font(Arkade.tinyFont).foregroundStyle(Arkade.dark50)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Arkade.dark05)
                .clipShape(RoundedRectangle(cornerRadius: Arkade.radius))
            }
            .padding(.horizontal, Arkade.hPadding).padding(.top, 8)
        }
        .navigationTitle("Backup")
    }
}

struct SettingsLockScreen: View { var body: some View { Text("Lock").navigationTitle("Lock") } }
struct SettingsAdvancedScreen: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                advancedRow("Support", subtitle: "Help and troubleshooting", icon: "questionmark.circle", dest: .settingsSupport)
                advancedRow("Logs", subtitle: "Inspect app logs", icon: "doc.text.magnifyingglass", dest: .settingsLogs)
                advancedRow("Reset", subtitle: "Remove local wallet data", icon: "exclamationmark.triangle", dest: .settingsReset, tint: Arkade.red)
            }
            .padding(Arkade.hPadding)
        }
        .background(Arkade.canvasGrouped)
        .navigationTitle("Advanced")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func advancedRow(_ title: String, subtitle: String, icon: String, dest: Screen, tint: Color = .secondary) -> some View {
        NavigationLink(value: dest) {
            SettingsMenuRow(title: title, subtitle: subtitle, icon: icon, tint: tint)
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.985))
    }
}

struct SettingsVtxosScreen: View {
    @Environment(AppManager.self) private var app
    var body: some View {
        ScrollView {
            VStack(spacing: Arkade.gap) {
                if let mgmt = app.state.vtxoManagement {
                    VStack(spacing: 4) {
                        Text("\(mgmt.totalSats)").font(.system(size: 24, weight: .medium)).tracking(Arkade.headingTracking)
                        Text("total sats · \(mgmt.vtxos.count) VTXOs").font(Arkade.tinyFont).foregroundStyle(Arkade.dark50)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 16)

                    VStack(spacing: 0) {
                        ForEach(mgmt.vtxos, id: \.outpoint) { vtxo in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(String(vtxo.outpoint.prefix(24)) + "...")
                                        .font(.system(size: 11, design: .monospaced))
                                    Text(vtxo.expiryDisplay).font(Arkade.tinyFont).foregroundStyle(Arkade.dark50)
                                }
                                Spacer()
                                Text("\(vtxo.amountSats) sats")
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                            }
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            Divider().background(Arkade.dark20)
                        }
                    }
                    .background(Arkade.dark05)
                    .clipShape(RoundedRectangle(cornerRadius: Arkade.radius))
                } else {
                    ProgressView().tint(Arkade.purple).padding(32)
                }
            }
            .padding(.horizontal, Arkade.hPadding).padding(.top, 8)
        }
        .navigationTitle("VTXOs")
        .onAppear { app.dispatch(.loadVtxos) }
    }
}

struct SettingsDelegatesScreen: View {
    @Environment(AppManager.self) private var app
    var body: some View {
        ScrollView {
            VStack(spacing: Arkade.gap) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Delegate settlement").font(.system(size: 14, weight: .medium))
                    Text("Pre-sign transactions so the server can settle your VTXOs even when the app is closed.")
                        .font(Arkade.tinyFont).foregroundStyle(Arkade.dark50)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Arkade.purple10)
                .clipShape(RoundedRectangle(cornerRadius: Arkade.radius))

                Button { app.dispatch(.setDelegateEnabled(enabled: true)) } label: {
                    Text("Delegate now").arkadeButton()
                }
            }
            .padding(.horizontal, Arkade.hPadding).padding(.top, 8)
        }
        .navigationTitle("Delegates")
    }
}

struct SettingsAboutScreen: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                row("Version", "0.1.0")
                Divider().background(Arkade.dark20)
                row("Network", "bitcoin")
                Divider().background(Arkade.dark20)
                row("Core", "Rust (RMP)")
            }
            .background(Arkade.dark05)
            .clipShape(RoundedRectangle(cornerRadius: Arkade.radius))
            .padding(.horizontal, Arkade.hPadding).padding(.top, 8)
        }
        .navigationTitle("About")
    }

    func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(Arkade.smallFont).foregroundStyle(Arkade.dark50)
            Spacer()
            Text(value).font(.system(size: 14, weight: .medium))
        }
        .padding(.horizontal, 12).padding(.vertical, 12)
    }
}

struct SettingsSupportScreen: View { var body: some View { Text("Support").navigationTitle("Support") } }
struct SettingsLogsScreen: View { var body: some View { Text("Logs").navigationTitle("Logs") } }

struct SettingsResetScreen: View {
    @Environment(AppManager.self) private var app
    @State private var confirmText = ""

    var body: some View {
        VStack(spacing: Arkade.gap) {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 40)).foregroundStyle(Arkade.red)
                Text("Reset wallet").font(.system(size: 24, weight: .medium)).tracking(Arkade.headingTracking)
                Text("This will delete all wallet data. Type DELETE to confirm.")
                    .font(Arkade.smallFont).foregroundStyle(Arkade.dark50).multilineTextAlignment(.center)
            }

            TextField("Type DELETE", text: $confirmText)
                .multilineTextAlignment(.center)
                .font(Arkade.smallFont)
                .padding(12)
                .background(Arkade.dark10)
                .clipShape(RoundedRectangle(cornerRadius: Arkade.radius))
                .padding(.horizontal, Arkade.hPadding)

            Spacer()

            Button { app.dispatch(.resetWallet) } label: {
                Text("Reset wallet").arkadeButton(.danger)
            }
            .disabled(confirmText != "DELETE")
            .opacity(confirmText != "DELETE" ? 0.5 : 1)
            .padding(.horizontal, Arkade.hPadding).padding(.bottom, 48)
        }
        .navigationTitle("Reset")
    }
}
