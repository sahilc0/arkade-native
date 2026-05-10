import SwiftUI

// MARK: - Note Form

struct NoteFormScreen: View {
    @Environment(AppManager.self) private var app
    @State private var noteInput = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enter ArkNote")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    TextEditor(text: $noteInput)
                        .frame(height: 100)
                        .padding(12)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                if let flow = app.state.arknoteFlow {
                    if let amount = flow.parsedAmountSats {
                        VStack(spacing: 4) {
                            Text("\(amount)")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                            Text("sats")
                                .foregroundStyle(.secondary)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity)
                        .glassEffect(.regular.tint(.green), in: RoundedRectangle(cornerRadius: 16))
                    }

                    if let error = flow.error {
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }

                VStack(spacing: 12) {
                    Button {
                        app.dispatch(.parseArkNote(input: noteInput))
                    } label: {
                        Text("Parse note")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.glass)
                    .disabled(noteInput.isEmpty)

                    if app.state.arknoteFlow?.parsedAmountSats != nil {
                        NavigationLink(value: Screen.noteRedeem) {
                            Text("Redeem")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.glassProminent)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .navigationTitle("ArkNote")
    }
}

// MARK: - Note Redeem

struct NoteRedeemScreen: View {
    @Environment(AppManager.self) private var app

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            if let flow = app.state.arknoteFlow {
                VStack(spacing: 4) {
                    Text("\(flow.parsedAmountSats ?? 0)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                    Text("sats")
                        .foregroundStyle(.secondary)
                }

                if flow.isRedeeming {
                    ProgressView("Redeeming...")
                        .controlSize(.large)
                } else {
                    Button {
                        app.dispatch(.confirmRedeemArkNote)
                    } label: {
                        Text("Confirm redeem")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.glassProminent)
                    .padding(.horizontal, 40)
                }

                if let error = flow.error {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
            }

            Spacer()
        }
        .navigationTitle("Redeem")
    }
}

// MARK: - Note Success

struct NoteSuccessScreen: View {
    @Environment(AppManager.self) private var app

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
            if let flow = app.state.arknoteFlow {
                Text("Redeemed \(flow.redeemedAmountSats ?? 0) sats!")
                    .font(.title.bold())
            }
            Spacer()
            Button {
                app.dispatch(.replaceScreen(screen: .home))
            } label: {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.glassProminent)
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }
}
