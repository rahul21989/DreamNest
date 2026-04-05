import SwiftUI

struct SettingsTabView: View {
    @ObservedObject var rootViewModel: DreamNestRootViewModel

    @StateObject private var viewModel = SettingsTabViewModel()

    @State private var showParents = false
    @State private var showClearDataConfirm = false
    @State private var feedbackText: String = ""

    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Parent (PIN protected)")
                            .font(.headline)
                        Text("Routines and settings stay on this device.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("App") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(viewModel.appVersionString)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Sleep Defaults") {
                    HStack {
                        Text("Quick Sleep")
                        Spacer()
                        Text("\(rootViewModel.parentsSettings.defaultSleepTimerMinutes)m")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Fade Out")
                        Spacer()
                        Text("\(rootViewModel.parentsSettings.fadeOutSeconds)s")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Parents Area") {
                    Button {
                        showParents = true
                    } label: {
                        HStack {
                            Text("Open Parents")
                            Spacer()
                            Image(systemName: "lock.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Feedback") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tell us what to improve")
                            .font(.headline)

                        TextEditor(text: $feedbackText)
                            .frame(height: 120)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.secondary.opacity(0.25))
                            )

                        Button {
                            let to = "goyal021989@gmail.com"
                            let subject = "DreamNest Feedback"
                            let body = feedbackText.trimmingCharacters(in: .whitespacesAndNewlines)
                                .isEmpty
                                ? "Hi DreamNest team,\n\nI have some feedback:\n"
                                : feedbackText

                            let subjectEncoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
                            let bodyEncoded = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? body

                            let urlString = "mailto:\(to)?subject=\(subjectEncoded)&body=\(bodyEncoded)"
                            if let url = URL(string: urlString) {
                                openURL(url)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "envelope.fill")
                                Text("Send Feedback")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showClearDataConfirm = true
                    } label: {
                        Text("Clear Data")
                    }
                }
            }
            .navigationTitle("SETTING")
            .sheet(isPresented: $showParents) {
                ParentsGateView(rootViewModel: rootViewModel)
            }
            .confirmationDialog(
                "Clear Data?",
                isPresented: $showClearDataConfirm,
                titleVisibility: .visible
            ) {
                Button("Cancel", role: .cancel) {}
                Button("Clear Data", role: .destructive) {
                    rootViewModel.logoutLocalDataAndStopPlayback()
                }
            } message: {
                Text("This clears locally saved routines and settings on this device (no network, no account).")
            }
        }
        .dreamNestNightMode()
    }
}

