import SwiftUI

struct NowPlayingView: View {
    @ObservedObject var rootViewModel: DreamNestRootViewModel
    @ObservedObject var nowPlayingViewModel: NowPlayingViewModel

    @State private var sliderDraft: Double  = 0
    @State private var isSeeking            = false
    @State private var showExtras           = false   // sleep timer + routine
    @State private var selectedRoutineID: UUID?

    private let timerOptions = [1, 2, 5, 10, 15]

    private var activeRoutineID: UUID? {
        if case let .running(routineID: rid, stepIndex: _) = nowPlayingViewModel.routineState {
            return rid
        }
        return nil
    }
    private var selectedRoutine: Routine? {
        rootViewModel.routines.first { $0.id == selectedRoutineID }
    }
    private var isPlaying: Bool { nowPlayingViewModel.isPlaying }
    private var hasTrack: Bool  { nowPlayingViewModel.currentTrackIndex != nil }

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white.opacity(0.25))
                .frame(width: 36, height: 3)
                .padding(.top, 10)
                .padding(.bottom, 6)

            if hasTrack {
                playerContent
            } else {
                idleContent
            }
        }
        .padding(.bottom, 14)
        .background(
            ZStack {
                // Blurred dark card
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(red: 0.10, green: 0.08, blue: 0.25).opacity(0.97))
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            }
        )
        .shadow(color: .black.opacity(0.4), radius: 20, y: 8)
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
    }

    // MARK: - Idle (nothing playing)

    private var idleContent: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.indigo.opacity(0.3))
                    .frame(width: 48, height: 48)
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.indigo.opacity(0.9))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Ready for dreamtime")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Text("Pick a lullaby to begin")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            // Quick sleep shortcut
            Button {
                quickSleep()
            } label: {
                Image(systemName: "powersleep")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.indigo.opacity(0.9))
                    .padding(12)
                    .background(Color.indigo.opacity(0.2))
                    .clipShape(Circle())
            }
            .disabled(rootViewModel.audioLibrary.tracks.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    // MARK: - Player content

    private var playerContent: some View {
        VStack(spacing: 12) {
            trackInfo
            progressSection
            transportControls
            Divider().overlay(Color.white.opacity(0.1))
            extrasToggleRow
            if showExtras {
                sleepTimerSection
                    .transition(.opacity.combined(with: .move(edge: .top)))
                if !rootViewModel.routines.isEmpty {
                    routineSection
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(.horizontal, 16)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showExtras)
    }

    // MARK: - Track info

    private var trackInfo: some View {
        HStack(spacing: 12) {
            // Album art placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(
                        colors: [Color.indigo.opacity(0.6), Color.purple.opacity(0.5)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 46, height: 46)
                Image(systemName: "music.note")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }

            VStack(alignment: .leading, spacing: 3) {
                if let idx = nowPlayingViewModel.currentTrackIndex,
                   idx < nowPlayingViewModel.playlist.count {
                    let track = nowPlayingViewModel.playlist[idx]
                    Text(track.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        if isPlaying {
                            Image(systemName: "waveform")
                                .font(.caption2)
                                .foregroundStyle(Color.indigo)
                                .symbolEffect(.variableColor.iterative, options: .repeating)
                        }
                        Text(track.category)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()

            // Sleep timer badge when running
            if nowPlayingViewModel.sleepTimerState.isRunning {
                VStack(spacing: 2) {
                    Image(systemName: "timer")
                        .font(.caption2)
                        .foregroundStyle(Color.orange)
                    Text(nowPlayingViewModel.sleepTimerState.remainingSeconds.formattedMMSS())
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Color.orange)
                }
            }
        }
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(spacing: 4) {
            Slider(
                value: $sliderDraft,
                in: 0...1,
                step: 0.001,
                onEditingChanged: { editing in
                    isSeeking = editing
                    if !editing { nowPlayingViewModel.seek(toProgress: sliderDraft) }
                }
            )
            .tint(Color.indigo)

            HStack {
                Text(nowPlayingViewModel.currentTimeSeconds.formattedMMSS())
                Spacer()
                Text(nowPlayingViewModel.durationSeconds.formattedMMSS())
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Transport controls

    private var transportControls: some View {
        HStack(spacing: 0) {
            // Volume icon
            Image(systemName: "speaker.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 28)

            Slider(
                value: Binding(
                    get: { Double(nowPlayingViewModel.volume) },
                    set: { nowPlayingViewModel.setVolume(Float($0)) }
                ),
                in: 0...1, step: 0.01
            )
            .tint(Color.white.opacity(0.5))
            .frame(maxWidth: 100)

            Image(systemName: "speaker.wave.3.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 28)

            Spacer()

            // Playback controls
            HStack(spacing: 20) {
                Button { nowPlayingViewModel.previous() } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(nowPlayingViewModel.playlist.isEmpty ? .secondary : .primary)
                }
                .disabled(nowPlayingViewModel.playlist.isEmpty)

                Button { nowPlayingViewModel.togglePlayPause() } label: {
                    ZStack {
                        Circle()
                            .fill(Color.indigo)
                            .frame(width: 52, height: 52)
                            .shadow(color: Color.indigo.opacity(0.5), radius: 8, y: 3)
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .offset(x: isPlaying ? 0 : 1.5)
                    }
                }

                Button { nowPlayingViewModel.next() } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(nowPlayingViewModel.playlist.isEmpty ? .secondary : .primary)
                }
                .disabled(nowPlayingViewModel.playlist.isEmpty)
            }
        }
    }

    // MARK: - Extras toggle

    private var extrasToggleRow: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                showExtras.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: showExtras ? "chevron.up" : "chevron.down")
                    .font(.caption2)
                Text(showExtras ? "Hide Sleep Tools" : "Sleep Timer & Routine")
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Sleep timer

    private var sleepTimerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Sleep Timer", systemImage: "timer")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if nowPlayingViewModel.sleepTimerState.isRunning {
                    Button("Cancel") { nowPlayingViewModel.cancelSleepTimer() }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .tint(.orange)
                }
            }

            HStack(spacing: 8) {
                ForEach(timerOptions, id: \.self) { m in
                    let active = nowPlayingViewModel.sleepTimerState.isRunning
                    Button {
                        nowPlayingViewModel.startSleepTimer(
                            minutes: m,
                            fadeOutSeconds: rootViewModel.parentsSettings.fadeOutSeconds
                        )
                    } label: {
                        Text("\(m)m")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(active ? Color.orange.opacity(0.15) : Color.white.opacity(0.08))
                            .foregroundStyle(active ? Color.orange : .primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                // Quick Sleep
                Button {
                    quickSleep()
                } label: {
                    Label("Quick", systemImage: "powersleep")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.indigo.opacity(0.25))
                        .foregroundStyle(Color.indigo)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Routine

    private var routineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Routine", systemImage: "list.bullet.rectangle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if case .running = nowPlayingViewModel.routineState {
                    Button("Stop") { nowPlayingViewModel.stopRoutine() }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .tint(.red)
                }
            }

            HStack(spacing: 8) {
                Picker("Routine", selection: Binding(
                    get: { selectedRoutineID ?? rootViewModel.routines.first?.id },
                    set: { selectedRoutineID = $0 }
                )) {
                    ForEach(rootViewModel.routines) { r in
                        Text(r.name).tag(Optional(r.id))
                    }
                }
                .pickerStyle(.menu)
                .font(.caption)
                .tint(Color.indigo)

                Button {
                    guard let r = selectedRoutine else { return }
                    activeRoutineID == r.id
                        ? nowPlayingViewModel.stopRoutine()
                        : nowPlayingViewModel.startRoutine(r)
                } label: {
                    Text(activeRoutineID == selectedRoutine?.id ? "Running" : "Start")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.indigo.opacity(0.25))
                        .foregroundStyle(Color.indigo)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(selectedRoutine == nil)
            }
        }
    }

    // MARK: - Quick sleep helper

    private func quickSleep() {
        let minutes = rootViewModel.parentsSettings.defaultSleepTimerMinutes
        let fade    = rootViewModel.parentsSettings.fadeOutSeconds
        let vm      = rootViewModel.nowPlayingViewModel

        let lullabyCat = rootViewModel.categories.first {
            $0.id.caseInsensitiveCompare("Lullabies") == .orderedSame
        }
        let lullabies = lullabyCat.map { rootViewModel.tracks(in: $0) } ?? []

        if !lullabies.isEmpty && !vm.isPlaying {
            let favs = lullabies.filter { rootViewModel.favoriteTrackFilenames.contains($0.filename) }
            let rest = lullabies.filter { !rootViewModel.favoriteTrackFilenames.contains($0.filename) }
            let playlist = favs + rest
            vm.playTrack(playlist[0], playlist: playlist, index: 0)
        }
        vm.startSleepTimer(minutes: minutes, fadeOutSeconds: fade)
    }
}
