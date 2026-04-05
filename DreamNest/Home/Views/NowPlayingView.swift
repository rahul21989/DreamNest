import SwiftUI

struct NowPlayingView: View {
    @ObservedObject var rootViewModel: DreamNestRootViewModel
    @ObservedObject var nowPlayingViewModel: NowPlayingViewModel

    @State private var sliderDraft: Double = 0
    @State private var isSeeking = false
    @State private var selectedRoutineID: UUID?

    private let sleepTimerOptions = [1, 2, 5, 10, 15]

    private var activeRoutineID: UUID? {
        if case let .running(routineID: rid, stepIndex: _) = nowPlayingViewModel.routineState {
            return rid
        }
        return nil
    }

    private var selectedRoutine: Routine? {
        rootViewModel.routines.first(where: { $0.id == selectedRoutineID })
    }

    private func remainingLabel(_ seconds: TimeInterval) -> String {
        if seconds <= 0 { return "0:00" }
        return seconds.formattedMMSS()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top row: transport controls.
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    if let idx = nowPlayingViewModel.currentTrackIndex,
                       idx < nowPlayingViewModel.playlist.count {
                        let track = nowPlayingViewModel.playlist[idx]
                        Text(track.title)
                            .font(.headline)
                            .lineLimit(1)
                        Text("Category: \(track.category)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Ready when you are")
                            .font(.headline)
                    }
                }
                Spacer()

                HStack(spacing: 12) {
                    Button {
                        nowPlayingViewModel.togglePlayPause()
                    } label: {
                        Image(systemName: nowPlayingViewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 34))
                    }
                    .accessibilityLabel(nowPlayingViewModel.isPlaying ? "Pause" : "Play")

                    Button {
                        nowPlayingViewModel.previous()
                    } label: {
                        Image(systemName: "backward.end.fill")
                            .font(.system(size: 26))
                    }
                    .disabled(nowPlayingViewModel.playlist.isEmpty)
                    .accessibilityLabel("Previous track")

                    Button {
                        nowPlayingViewModel.next()
                    } label: {
                        Image(systemName: "forward.end.fill")
                            .font(.system(size: 26))
                    }
                    .disabled(nowPlayingViewModel.playlist.isEmpty)
                    .accessibilityLabel("Next track")
                }
            }

            // Progress slider + remaining.
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(nowPlayingViewModel.currentTimeSeconds.formattedMMSS())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(nowPlayingViewModel.durationSeconds.formattedMMSS())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Slider(
                    value: $sliderDraft,
                    in: 0...1,
                    step: 0.001,
                    onEditingChanged: { editing in
                        isSeeking = editing
                        if !editing {
                            nowPlayingViewModel.seek(toProgress: sliderDraft)
                        }
                    }
                )
                .accessibilityLabel("Playback progress")

                HStack(spacing: 12) {
                    Text("Remaining:")
                        .font(.subheadline)
                    Spacer()
                    Text(remainingLabel(nowPlayingViewModel.sleepTimerState.isRunning
                                        ? nowPlayingViewModel.sleepTimerState.remainingSeconds
                                        : nowPlayingViewModel.remainingSeconds))
                        .font(.subheadline)
                        .bold()
                }
            }

            // Volume.
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Volume")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(nowPlayingViewModel.volume * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: Binding(
                        get: { Double(nowPlayingViewModel.volume) },
                        set: { nowPlayingViewModel.setVolume(Float($0)) }
                    ),
                    in: 0...1,
                    step: 0.01
                )
                .accessibilityLabel("Volume")
            }

            // Sleep timer.
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Sleep Timer")
                        .font(.subheadline)
                    Spacer()
                    if nowPlayingViewModel.sleepTimerState.isRunning {
                        Button("Cancel") {
                            nowPlayingViewModel.cancelSleepTimer()
                        }
                        .buttonStyle(.bordered)
                    }
                }

                HStack(spacing: 10) {
                    ForEach(sleepTimerOptions, id: \.self) { minutes in
                        Button {
                            nowPlayingViewModel.startSleepTimer(
                                minutes: minutes,
                                fadeOutSeconds: rootViewModel.parentsSettings.fadeOutSeconds
                            )
                        } label: {
                            Text("\(minutes)m")
                                .font(.headline)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(Color.accentColor)
                        .disabled(nowPlayingViewModel.isPlaying == false && nowPlayingViewModel.playlist.isEmpty)
                    }
                }
                .padding(.top, 2)

                Button {
                    startPlaybackForQuickSleepAndStartTimer()
                } label: {
                    Text("Quick Sleep (\(rootViewModel.parentsSettings.defaultSleepTimerMinutes)m)")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.top, 4)
            }

            // Routine.
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Routine")
                        .font(.subheadline)
                    Spacer()
                    if case .running = nowPlayingViewModel.routineState {
                        Button {
                            nowPlayingViewModel.stopRoutine()
                        } label: {
                            Text("Stop")
                        }
                        .buttonStyle(.bordered)
                    }
                }

                if rootViewModel.routines.isEmpty {
                    Text("Create a routine in Parents.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Select routine", selection: Binding(
                        get: { selectedRoutineID ?? rootViewModel.routines.first?.id },
                        set: { selectedRoutineID = $0 }
                    )) {
                        ForEach(rootViewModel.routines) { routine in
                            Text(routine.name).tag(routine.id)
                        }
                    }
                    .pickerStyle(.menu)

                    Button {
                        guard let selectedRoutine else { return }
                        if activeRoutineID == selectedRoutine.id {
                            nowPlayingViewModel.stopRoutine()
                        } else {
                            nowPlayingViewModel.startRoutine(selectedRoutine)
                        }
                    } label: {
                        Text(activeRoutineID == selectedRoutine?.id ? "Playing" : "Start Routine")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedRoutine == nil)
                }
            }
        }
        .padding(16)
        .background(Color.accentColor.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .onAppear {
            sliderDraft = nowPlayingViewModel.progress
            if selectedRoutineID == nil {
                selectedRoutineID = rootViewModel.routines.first?.id
            }
        }
        .onChange(of: nowPlayingViewModel.progress) { newValue in
            guard !isSeeking else { return }
            sliderDraft = newValue
        }
        .animation(nil, value: isSeeking)
    }

    private func startPlaybackForQuickSleepAndStartTimer() {
        let minutes = rootViewModel.parentsSettings.defaultSleepTimerMinutes
        let fadeOutSeconds = rootViewModel.parentsSettings.fadeOutSeconds

        if let selectedRoutine {
            // If a routine is selected, start it.
            nowPlayingViewModel.startRoutine(selectedRoutine)
            nowPlayingViewModel.startSleepTimer(minutes: minutes, fadeOutSeconds: fadeOutSeconds)
            return
        }

        // Otherwise, play a lullaby: favorites first, then the rest.
        let lullabiesCategory = rootViewModel.categories.first { cat in
            cat.id.caseInsensitiveCompare("Lullabies") == .orderedSame
        }

        guard let category = lullabiesCategory else {
            nowPlayingViewModel.startSleepTimer(minutes: minutes, fadeOutSeconds: fadeOutSeconds)
            return
        }

        let lullabies = rootViewModel.tracks(in: category)
        guard !lullabies.isEmpty else {
            nowPlayingViewModel.startSleepTimer(minutes: minutes, fadeOutSeconds: fadeOutSeconds)
            return
        }

        let favorites = lullabies.filter { rootViewModel.favoriteTrackFilenames.contains($0.filename) }
        let remaining = lullabies.filter { !rootViewModel.favoriteTrackFilenames.contains($0.filename) }
        let orderedPlaylist = (favorites + remaining)

        guard let firstTrack = orderedPlaylist.first else {
            nowPlayingViewModel.startSleepTimer(minutes: minutes, fadeOutSeconds: fadeOutSeconds)
            return
        }

        nowPlayingViewModel.playTrack(
            firstTrack,
            playlist: orderedPlaylist,
            index: 0
        )

        nowPlayingViewModel.startSleepTimer(minutes: minutes, fadeOutSeconds: fadeOutSeconds)
    }
}

