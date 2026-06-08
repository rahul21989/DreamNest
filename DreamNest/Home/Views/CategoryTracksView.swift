import SwiftUI
import UniformTypeIdentifiers

struct CategoryTracksView: View {
    let category: AudioCategory
    let tracks: [AudioTrack]
    @ObservedObject var rootViewModel: DreamNestRootViewModel

    @State private var showFileImporter = false
    @State private var importError: String?
    @State private var deleteError: String?
    @StateObject private var recordingManager = LullabyRecordingManager()

    private var isLullabies: Bool {
        category.id.caseInsensitiveCompare("Lullabies") == .orderedSame
    }
    private var preDownloaded: [AudioTrack] { tracks.filter { !$0.isUserCreated } }

    /// User recordings sorted oldest → newest so the most recent is at the bottom
    private var myLullabies: [AudioTrack] {
        tracks
            .filter { $0.isUserCreated }
            .sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
    }

    private let allowedTypes: [UTType] = {
        [UTType(filenameExtension: "mp3"), UTType(filenameExtension: "m4a")].compactMap { $0 }
    }()

    var body: some View {
        List {
            // ── Upload / Record card (Lullabies only) ──────────────────────
            if isLullabies {
                Section {
                    uploadRecordCard
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                        .listRowSeparator(.hidden)
                }
            }

            // ── Track sections ─────────────────────────────────────────────
            if isLullabies {
                trackSection(
                    title: "🎵 Lullabies",
                    icon: "moon.stars.fill",
                    tracks: preDownloaded,
                    canDelete: false
                )
                trackSection(
                    title: "🎤 My Recordings",
                    icon: "mic.fill",
                    tracks: myLullabies,
                    canDelete: true
                )
            } else {
                trackSection(
                    title: category.displayName,
                    icon: "music.note.list",
                    tracks: tracks,
                    canDelete: false
                )
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .navigationTitle(category.displayName)
        .navigationBarTitleDisplayMode(.large)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: allowedTypes.isEmpty ? [.data] : allowedTypes,
            allowsMultipleSelection: false,
            onCompletion: handleImport
        )
        .dreamNestNightMode()
    }

    // MARK: - Upload / Record card

    private var uploadRecordCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Your Own Lullaby")
                .font(.subheadline.bold())
            Text("Upload a song or record your own voice — your child will love it 💛")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button { showFileImporter = true } label: {
                    Label("Upload", systemImage: "square.and.arrow.up.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(.borderless)   // ← more reliable on iPad than .plain

                Button {
                    if recordingManager.isRecording {
                        recordingManager.stop()
                    } else {
                        importError = nil
                        recordingManager.onSaved = { _ in rootViewModel.refreshAudioLibrary() }
                        recordingManager.onError = { importError = $0.localizedDescription }
                        Task { await recordingManager.start() }
                    }
                } label: {
                    Label(
                        recordingManager.isRecording ? "Stop" : "Record",
                        systemImage: recordingManager.isRecording ? "stop.circle.fill" : "mic.circle.fill"
                    )
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(recordingManager.isRecording
                                ? Color.red.opacity(0.15)
                                : Color.indigo.opacity(0.18))
                    .foregroundStyle(recordingManager.isRecording ? .red : Color.indigo)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .stroke((recordingManager.isRecording ? Color.red : Color.indigo).opacity(0.3),
                                lineWidth: 1))
                }
                .buttonStyle(.borderless)   // ← more reliable on iPad than .plain
            }

            if let err = importError ?? deleteError {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18)
            .stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Track section (returns a Section inside the List)

    @ViewBuilder
    private func trackSection(title: String, icon: String,
                               tracks: [AudioTrack], canDelete: Bool) -> some View {
        Section {
            if tracks.isEmpty {
                Text(canDelete ? "Your recordings will appear here." : "No tracks found.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                    TrackRow(
                        track: track,
                        index: index,
                        playlist: tracks,
                        isLullabies: isLullabies,
                        rootViewModel: rootViewModel,
                        nowPlayingVM: rootViewModel.nowPlayingViewModel
                    )
                    // swipeActions inside a real List → works correctly on all devices
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if canDelete {
                            Button(role: .destructive) {
                                deleteError = nil
                                deleteTrack(track)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .listRowBackground(
                        rowBackground(isCurrent: rootViewModel.nowPlayingViewModel.currentTrackFilename == track.filename)
                    )
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
                }
            }
        } header: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.indigo.opacity(0.8))
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text("(\(tracks.count))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func rowBackground(isCurrent: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(isCurrent ? Color.indigo.opacity(0.15) : Color.white.opacity(0.05))
    }

    // MARK: - Delete

    private func deleteTrack(_ track: AudioTrack) {
        if rootViewModel.nowPlayingViewModel.currentTrackFilename == track.filename {
            rootViewModel.nowPlayingViewModel.stopAllPlaybackAndTimers()
        }
        do {
            try UserLullabiesStorage.deleteUserLullaby(track)
            rootViewModel.removeFavorite(track.filename)
            rootViewModel.refreshAudioLibrary()
        } catch {
            deleteError = error.localizedDescription
        }
    }

    // MARK: - Import

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let started = url.startAccessingSecurityScopedResource()
            Task {
                defer { if started { url.stopAccessingSecurityScopedResource() } }
                do {
                    _ = try await withCheckedThrowingContinuation { cont in
                        DispatchQueue.global(qos: .userInitiated).async {
                            do {
                                let t = try UserLullabiesStorage.importLullaby(from: url)
                                cont.resume(returning: t)
                            } catch { cont.resume(throwing: error) }
                        }
                    }
                    rootViewModel.refreshAudioLibrary()
                    importError = nil
                } catch {
                    importError = error.localizedDescription
                }
            }
        case .failure(let err):
            importError = err.localizedDescription
        }
    }
}

// MARK: - Track Row

private struct TrackRow: View {
    let track: AudioTrack
    let index: Int
    let playlist: [AudioTrack]
    let isLullabies: Bool
    @ObservedObject var rootViewModel: DreamNestRootViewModel
    /// Observed directly so the row re-renders the moment isPlaying changes.
    /// Observing rootViewModel alone is NOT enough — nested ObservableObject
    /// changes don't propagate through a @Published property automatically.
    @ObservedObject var nowPlayingVM: NowPlayingViewModel

    private var isCurrent: Bool {
        nowPlayingVM.currentTrackFilename == track.filename
    }
    private var isPlayingCurrent: Bool {
        isCurrent && nowPlayingVM.isPlaying
    }

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd MMM"   // e.g. "04 Jun"
        return f
    }()

    var body: some View {
        HStack(spacing: 14) {

            // Track number / playing indicator
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isCurrent ? Color.indigo.opacity(0.4) : Color.white.opacity(0.08))
                    .frame(width: 38, height: 38)

                if isPlayingCurrent {
                    Image(systemName: "waveform")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.indigo)
                        .symbolEffect(.variableColor.iterative, options: .repeating)
                } else if isCurrent {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.indigo)
                } else {
                    Text("\(index + 1)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            // Title + subtitle (date for recordings, duration for bundled)
            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.subheadline)
                    .foregroundStyle(isCurrent ? Color.indigo : .primary)
                    .lineLimit(1)

                // User recordings: show "DD MMM" creation date
                // Bundled tracks: show duration
                if track.isUserCreated, let date = track.createdAt {
                    Text(Self.dateFmt.string(from: date))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text(track.durationSeconds > 0
                         ? track.durationSeconds.formattedMMSS() : "—")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            // Favourite (lullabies only)
            if isLullabies {
                Button {
                    rootViewModel.toggleFavorite(track.filename)
                } label: {
                    Image(systemName: rootViewModel.isFavorite(track.filename) ? "heart.fill" : "heart")
                        .font(.system(size: 17))
                        .foregroundStyle(rootViewModel.isFavorite(track.filename) ? .pink : .secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
            }

            // Play / Pause
            Button {
                if isCurrent {
                    nowPlayingVM.togglePlayPause()
                } else {
                    nowPlayingVM.playTrack(track, playlist: playlist, index: index)
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(isCurrent ? Color.indigo : Color.indigo.opacity(0.3))
                        .frame(width: 44, height: 44)
                    Image(systemName: isPlayingCurrent ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .offset(x: isPlayingCurrent ? 0 : 1.5)
                }
                .contentShape(Circle())
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
    }
}
