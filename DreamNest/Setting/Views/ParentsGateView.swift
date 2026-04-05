import SwiftUI

struct ParentsGateView: View {
    @ObservedObject var rootViewModel: DreamNestRootViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var pinText: String = ""
    @State private var isUnlocked = false

    private let parentPIN = "1234"

    var body: some View {
        NavigationStack {
            if isUnlocked {
                ParentsView(rootViewModel: rootViewModel)
                    .navigationTitle("Parents")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { dismiss() }
                                .buttonStyle(.borderedProminent)
                        }
                    }
            } else {
                VStack(spacing: 20) {
                    Text("Enter Parent PIN")
                        .font(.title2)
                        .bold()
                    Text("This unlocks routine editing and settings.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    VStack(spacing: 12) {
                        TextField("PIN", text: $pinText)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .font(.title2)
                            .multilineTextAlignment(.center)
                            .padding(12)
                            .background(Color.accentColor.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        Button {
                            if pinText == parentPIN {
                                isUnlocked = true
                            } else {
                                pinText = ""
                            }
                        } label: {
                            Text("Unlock")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 8)
                    }

                    Spacer()

                    Text("No data leaves your device.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            }
        }
        .navigationViewStyle(.stack)
        .dreamNestNightMode()
    }
}

