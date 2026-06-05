import SwiftUI

struct ParentsGateView: View {
    @ObservedObject var rootViewModel: DreamNestRootViewModel

    @Environment(\.dismiss) private var dismiss

    // The three possible states this view can be in
    private enum Mode {
        case setup          // first time – no PIN stored yet
        case unlock         // normal entry
        case change         // inside parents area, changing PIN
    }

    @State private var mode: Mode = .unlock
    @State private var pinText: String = ""
    @State private var newPINText: String = ""
    @State private var confirmPINText: String = ""
    @State private var errorMessage: String = ""
    @State private var isUnlocked = false
    @State private var showChangePIN = false

    private var store: ParentsSettingsStore { rootViewModel.parentsSettingsStore }

    var body: some View {
        NavigationStack {
            Group {
                if isUnlocked {
                    ParentsView(
                        rootViewModel: rootViewModel,
                        onChangePINTapped: { showChangePIN = true }
                    )
                    .navigationTitle("Parents")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { dismiss() }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                    .sheet(isPresented: $showChangePIN) {
                        changePINSheet
                    }
                } else if mode == .setup {
                    setupPINView
                } else {
                    enterPINView
                }
            }
        }
        .navigationViewStyle(.stack)
        .dreamNestNightMode()
        .onAppear {
            mode = store.hasPIN ? .unlock : .setup
        }
    }

    // MARK: - Enter PIN

    private var enterPINView: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.accentColor)

            Text("Enter Parent PIN")
                .font(.title2)
                .bold()

            Text("This unlocks routine editing and settings.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                SecureField("PIN", text: $pinText)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .font(.title2)
                    .multilineTextAlignment(.center)
                    .padding(12)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button {
                    if pinText == store.storedPIN {
                        isUnlocked = true
                        errorMessage = ""
                    } else {
                        pinText = ""
                        errorMessage = "Incorrect PIN. Please try again."
                    }
                } label: {
                    Text("Unlock")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(pinText.isEmpty)
                .padding(.top, 8)
            }

            Spacer()

            Text("No data leaves your device.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }

    // MARK: - Setup PIN (first time)

    private var setupPINView: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.badge.plus")
                .font(.system(size: 44))
                .foregroundStyle(Color.accentColor)

            Text("Create a Parent PIN")
                .font(.title2)
                .bold()

            Text("Choose a PIN to protect parent settings and routines.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                SecureField("New PIN (4+ digits)", text: $newPINText)
                    .keyboardType(.numberPad)
                    .textContentType(.newPassword)
                    .font(.title2)
                    .multilineTextAlignment(.center)
                    .padding(12)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                SecureField("Confirm PIN", text: $confirmPINText)
                    .keyboardType(.numberPad)
                    .textContentType(.newPassword)
                    .font(.title2)
                    .multilineTextAlignment(.center)
                    .padding(12)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button {
                    guard newPINText.count >= 4 else {
                        errorMessage = "PIN must be at least 4 digits."
                        return
                    }
                    guard newPINText == confirmPINText else {
                        errorMessage = "PINs don't match. Please try again."
                        confirmPINText = ""
                        return
                    }
                    store.savePIN(newPINText)
                    isUnlocked = true
                    errorMessage = ""
                } label: {
                    Text("Set PIN & Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(newPINText.isEmpty || confirmPINText.isEmpty)
                .padding(.top, 8)
            }

            Spacer()
        }
        .padding(20)
    }

    // MARK: - Change PIN sheet

    private var changePINSheet: some View {
        NavigationStack {
            ChangePINView(store: store)
                .navigationTitle("Change PIN")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { showChangePIN = false }
                    }
                }
        }
        .dreamNestNightMode()
    }
}
