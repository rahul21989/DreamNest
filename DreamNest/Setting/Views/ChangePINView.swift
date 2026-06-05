import SwiftUI

struct ChangePINView: View {
    let store: ParentsSettingsStore

    @Environment(\.dismiss) private var dismiss

    @State private var currentPIN: String = ""
    @State private var newPIN: String = ""
    @State private var confirmPIN: String = ""
    @State private var errorMessage: String = ""
    @State private var success: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            if success {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.green)
                    Text("PIN Updated")
                        .font(.title2)
                        .bold()
                    Text("Your new PIN is saved.")
                        .foregroundStyle(.secondary)
                    Button("Done") { dismiss() }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                SecureField("Current PIN", text: $currentPIN)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .font(.title2)
                    .multilineTextAlignment(.center)
                    .padding(12)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                SecureField("New PIN (4+ digits)", text: $newPIN)
                    .keyboardType(.numberPad)
                    .textContentType(.newPassword)
                    .font(.title2)
                    .multilineTextAlignment(.center)
                    .padding(12)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                SecureField("Confirm New PIN", text: $confirmPIN)
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
                    guard currentPIN == store.storedPIN else {
                        errorMessage = "Current PIN is incorrect."
                        currentPIN = ""
                        return
                    }
                    guard newPIN.count >= 4 else {
                        errorMessage = "New PIN must be at least 4 digits."
                        return
                    }
                    guard newPIN == confirmPIN else {
                        errorMessage = "New PINs don't match."
                        confirmPIN = ""
                        return
                    }
                    store.savePIN(newPIN)
                    success = true
                    errorMessage = ""
                } label: {
                    Text("Update PIN")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(currentPIN.isEmpty || newPIN.isEmpty || confirmPIN.isEmpty)

                Spacer()
            }
        }
        .padding(20)
    }
}
