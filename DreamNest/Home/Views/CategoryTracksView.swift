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
    private var myLullabies:   [AudioTrack] { tracks.filter {  $0.isUserCreated } }

    private let allowedTypes: [UTType] = {
        [UTType(filenameExtension: "mp3"), UTType(filenameExtension: "m4a")].compactMap { $0 }
    }()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Upload / Record card (Lullabies only)
                if isLullabies {
                    uploadRecordCard
                }

                // Track sections
                if isLullabies {
                    trackSection(title: "🎵 Lullabies", icon: "moon.stars.fill",
                                 tracks: preDownloaded, canDelete: false)
                    trackSection(title: "🎤 My Recordings", icon: "mic.fill",
                                 tracks: myLullabies, canDelete: true)
                } else {
                    trackSection(title: category.displayName, icon: "music.note.list",
                                 tracks: tracks, canDelete: false)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .padding(.bottom, 100)   // clearance for NowPlayingView
        }
        .navigationTitle(category.displayName)
        .navigationBarTitleDisplayMode(.large)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: allowedTypes.isEmpty ? [.data] : allowedTypes,
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .dreamNestNightMode()
    }

    // MARK: - Upload / Record card

    private var uploadRecordCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Your Own Lullaby")
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
            Text("Upload a song or record your own voice — your child will love it 💛")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                // Upload
                Button { showFileImporter = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up.fill")
                        Text("Upload")
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.08))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(.plain)

                // Record
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
                    HStack(spacing: 6) {
                        Image(systemName: recordingManager.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .foregroundStyle(recordingManager.isRecording ? .red : Color.indigo)
                        Text(recordingManager.isRecording ? "Stop" : "Record")
                            .font(.subheadline.weight(.semibold))
                    }
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
                .buttonStyle(.plain)
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

    // MARK: - Track section

    @ViewBuilder
    private func trackSection(title: String, icon: String,
                               tracks: [AudioTrack], canDelete: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.indigo.opacity(0.8))
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(tracks.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if tracks.isEmpty {
                Text(canDelete
                     ? "Your recordings will appear here."
                     : "No tracks found.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 2) {
                    ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                        TrackRow(
                            track: track,
                            index: index,
                            playlist: tracks,
                            isLullabies: isLullabies,
                            canDelete: canDelete,
                            rootViewModel: rootViewModel,
                            onDelete: { deleteTrack(track) }
                        )
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
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
            deleteError = nil
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
    let canDelete: Bool
    @ObservedObject var rootViewModel: DreamNestRootViewModel
    let onDelete: () -> Void

    private var isCurrent: Bool {
        rootViewModel.nowPlayingViewModel.currentTrackFilename == track.filename
    }
    private var isPlayingCurrent: Bool {
        isCurrent && rootViewModel.nowPlayingViewModel.isPlaying
    }

    var body: some View {
        HStack(spacing: 12) {
            // Track number / playing indicator
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isCurrent ? Color.indigo.opacity(0.4) : Color.white.opacity(0.06))
                    .frame(width: 36, height: 36)

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

            // Title + duration
            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.subheadline)
                    .foregroundStyle(isCurrent ? Color.indigo : .primary)
                    .lineLimit(1)
                Text(track.durationSeconds > 0
                     ? track.durationSeconds.formattedMMSS()
                     : "—")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Favourite (lullabies only)
            if isLullabies {
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                        rootViewModel.toggleFavorite(track.filename)
                    }
                } label: {
                    Image(systemName: rootViewModel.isFavorite(track.filename) ? "heart.fill" : "heart")
                        .font(.system(size: 16))
                        .foregroundStyle(rootViewModel.isFavorite(track.filename) ? .pink : .secondary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }

            // Play / Pause
            Button {
                if isCurrent {
                    rootViewModel.nowPlayingViewModel.togglePlayPause()
                } else {
                    rootViewModel.nowPlayingViewModel.playTrack(track, playlist: playlist, index: index)
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(isCurrent ? Color.indigo : Color.indigo.opacity(0.25))
                        .frame(width: 36, height: 36)
                    Image(systemName: isPlayingCurrent ? "pause.fill" : "play.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .offset(x: isPlayingCurrent ? 0 : 1)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isCurrent
                    ? Color.indigo.opacity(0.10)
                    : Color.white.opacity(0.05))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if canDelete {
                Button(role: .destructive) { onDelete() } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}
