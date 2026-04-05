import SwiftUI

struct RoutineEditorView: View {
    @ObservedObject var rootViewModel: DreamNestRootViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Routine

    let onSave: (Routine) -> Void

    @State private var addTrackFilename: String
    @State private var addDurationSeconds: Int = 60

    private var tracks: [AudioTrack] { rootViewModel.audioLibrary.tracks }
    private var trackByFilename: [String: AudioTrack] {
        Dictionary(uniqueKeysWithValues: tracks.map { ($0.filename, $0) })
    }

    init(
        rootViewModel: DreamNestRootViewModel,
        routine: Routine,
        onSave: @escaping (Routine) -> Void
    ) {
        self.rootViewModel = rootViewModel
        self._draft = State(initialValue: routine)
        self.onSave = onSave
        self._addTrackFilename = State(initialValue: rootViewModel.audioLibrary.tracks.first?.filename ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Routine Name")) {
                    TextField("Name", text: $draft.name)
                }

                Section(header: Text("Steps")) {
                    if draft.steps.isEmpty {
                        Text("Add at least one Track + duration step.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(draft.steps.indices, id: \.self) { idx in
                            stepRow(index: idx)
                        }
                    }

                    addStepSection()
                }
            }
            .navigationTitle("Edit Routine")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(.bordered)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .dreamNestNightMode()
        .onAppear {
            if addTrackFilename.isEmpty {
                addTrackFilename = tracks.first?.filename ?? ""
            }
        }
    }

    private func stepRow(index idx: Int) -> some View {
        let trackTitle: String = {
            let filename = draft.steps[idx].trackFilename
            return trackByFilename[filename]?.title ?? filename
        }()

        let stepDuration = Int(draft.steps[idx].durationSeconds.rounded())

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Step \(idx + 1)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Menu {
                        ForEach(tracks) { track in
                            Button {
                                draft.steps[idx].trackFilename = track.filename
                            } label: {
                                Text(track.title)
                            }
                        }
                    } label: {
                        Text(trackTitle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)

                    HStack {
                        Stepper(
                            value: Binding<Int>(
                                get: { Int(draft.steps[idx].durationSeconds.rounded()) },
                                set: { draft.steps[idx].durationSeconds = TimeInterval($0) }
                            ),
                            in: 5...900,
                            step: 5
                        ) {
                            Text("\(stepDuration) sec")
                                .font(.body)
                        }
                    }
                }

                VStack(spacing: 8) {
                    Button {
                        if idx > 0 {
                            draft.steps.swapAt(idx, idx - 1)
                        }
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .disabled(idx == 0)

                    Button {
                        if idx + 1 < draft.steps.count {
                            draft.steps.swapAt(idx, idx + 1)
                        }
                    } label: {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .disabled(idx + 1 >= draft.steps.count)

                    Button {
                        draft.steps.remove(at: idx)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .tint(.red)
                }
            }
        }
    }

    private func addStepSection() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add Step")
                .font(.headline)

            Menu {
                ForEach(tracks) { track in
                    Button {
                        addTrackFilename = track.filename
                    } label: {
                        Text(track.title)
                    }
                }
            } label: {
                Text(trackByFilename[addTrackFilename]?.title ?? "Select Track")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)

            Stepper(value: $addDurationSeconds, in: 5...900, step: 5) {
                Text("Duration: \(addDurationSeconds) sec")
            }

            Button {
                guard !addTrackFilename.isEmpty else { return }
                draft.steps.append(
                    RoutineStep(
                        trackFilename: addTrackFilename,
                        durationSeconds: TimeInterval(addDurationSeconds)
                    )
                )
            } label: {
                Text("Add")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(tracks.isEmpty || addTrackFilename.isEmpty)
        }
        .padding(.vertical, 4)
    }

    private func save() {
        // Keep only steps that reference tracks that exist in the bundled library.
        let filteredSteps = draft.steps.filter { trackByFilename[$0.trackFilename] != nil }
        draft.steps = filteredSteps
        draft.updatedAt = .now

        onSave(draft)
    }
}

