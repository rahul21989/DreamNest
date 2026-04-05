import SwiftUI

struct ParentsView: View {
    @ObservedObject var rootViewModel: DreamNestRootViewModel

    @State private var showEditor = false
    @State private var draftRoutine: Routine = Routine(name: "New Routine", steps: [])

    @State private var defaultTimerMinutes: Int = 10
    @State private var fadeOutSeconds: Int = 20

    private let sleepOptions = [1, 2, 5, 10, 15]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Settings
                VStack(alignment: .leading, spacing: 10) {
                    Text("Settings")
                        .font(.headline)
                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading) {
                            Text("Default Sleep Timer")
                                .font(.subheadline)
                            Picker("Default Sleep Timer", selection: $defaultTimerMinutes) {
                                ForEach(sleepOptions, id: \.self) { minutes in
                                    Text("\(minutes) minutes").tag(minutes)
                                }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: defaultTimerMinutes) { _, newValue in
                                rootViewModel.updateParentsSettings(
                                    ParentsSettings(
                                        defaultSleepTimerMinutes: newValue,
                                        fadeOutSeconds: fadeOutSeconds
                                    )
                                )
                            }
                        }

                        VStack(alignment: .leading) {
                            Text("Fade Out Duration (seconds)")
                                .font(.subheadline)
                            Stepper(
                                value: $fadeOutSeconds,
                                in: 5...40,
                                step: 5
                            ) {
                                Text("\(fadeOutSeconds) sec")
                                    .font(.body)
                            }
                            .onChange(of: fadeOutSeconds) { _, newValue in
                                rootViewModel.updateParentsSettings(
                                    ParentsSettings(
                                        defaultSleepTimerMinutes: defaultTimerMinutes,
                                        fadeOutSeconds: newValue
                                    )
                                )
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.accentColor.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                // Routines
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Routines")
                            .font(.headline)
                        Spacer()
                        Button {
                            draftRoutine = Routine(name: "New Routine", steps: [])
                            showEditor = true
                        } label: {
                            Text("New")
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if rootViewModel.routines.isEmpty {
                        Text("No routines yet. Create one with Track + duration steps.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(rootViewModel.routines) { routine in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(routine.name)
                                                .font(.headline)
                                            Text("\(routine.steps.count) steps")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        HStack(spacing: 10) {
                                            Button {
                                                draftRoutine = routine
                                                showEditor = true
                                            } label: {
                                                Text("Edit")
                                            }
                                            .buttonStyle(.bordered)

                                            Button {
                                                rootViewModel.deleteRoutine(id: routine.id)
                                            } label: {
                                                Text("Delete")
                                            }
                                            .buttonStyle(.bordered)
                                            .tint(.red)
                                        }
                                    }
                                }
                                .padding(12)
                                .background(Color.accentColor.opacity(0.10))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .sheet(isPresented: $showEditor) {
            RoutineEditorView(
                rootViewModel: rootViewModel,
                routine: draftRoutine
            ) { savedRoutine in
                rootViewModel.upsertRoutine(savedRoutine)
                showEditor = false
            }
        }
        .onAppear {
            defaultTimerMinutes = rootViewModel.parentsSettings.defaultSleepTimerMinutes
            fadeOutSeconds = rootViewModel.parentsSettings.fadeOutSeconds
        }
        .dreamNestNightMode()
    }
}

