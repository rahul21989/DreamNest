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

    var body: some View {
        let isLullabies = category.id.compare("Lullabies", options: .caseInsensitive) == .orderedSame

        let preDownloaded = tracks.filter { !$0.isUserCreated }
        let myLullabies = tracks.filter { $0.isUserCreated }

        let allowedTypes: [UTType] = {
            let mp3 = UTType(filenameExtension: "mp3")
            let m4a = UTType(filenameExtension: "m4a")
            return [mp3, m4a].compactMap { $0 }
        }()

        List {
            if isLullabies {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Lullabies")
                            .font(.headline)

                        HStack(spacing: 12) {
                            Button {
                                showFileImporter = true
                            } label: {
                                Label("Upload", systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)

                            Button {
                                if recordingManager.isRecording {
                                    recordingManager.stop()
                                } else {
                                    importError = nil
                                    recordingManager.onSaved = { _ in
                                        rootViewModel.refreshAudioLibrary()
                                    }
                                    recordingManager.onError = { err in
                                        importError = err.localizedDescription
                                    }
                                    Task { await recordingManager.start() }
                                }
                            } label: {
                                Label(
                                    recordingManager.isRecording ? "Stop" : "Record",
                                    systemImage: recordingManager.isRecording ? "stop.circle.fill" : "mic.circle.fill"
                                )
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        }

                        if let importError {
                            Text(importError)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                        if let deleteError {
                            Text(deleteError)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("Pre-downloaded") {
                    if preDownloaded.isEmpty {
                        Text("No pre-downloaded lullabies found.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(preDownloaded.enumerated()), id: \.element.id) { index, track in
                            lullabyRow(track: track, index: index, playlist: preDownloaded, isLullabies: true, canDelete: false)
                        }
                    }
                }

                Section("My Lullabies") {
                    if myLullabies.isEmpty {
                        Text("Upload or record a lullaby to save it here.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(myLullabies.enumerated()), id: \.element.id) { index, track in
                            lullabyRow(track: track, index: index, playlist: myLullabies, isLullabies: true, canDelete: true)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deleteError = nil
                                        deleteUserLullaby(track)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            } else {
                Section {
                    ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .center) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(track.title)
                                        .font(.headline)
                                    Text(track.filename)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(track.durationSeconds.formattedMMSS())
                                        .font(.subheadline)
                                }

                                VStack(alignment: .trailing, spacing: 8) {
                                    Button {
                                        rootViewModel.nowPlayingViewModel.playTrack(track, playlist: tracks, index: index)
                                    } label: {
                                        Text("Play")
                                            .font(.headline)
                                            .frame(minWidth: 78)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .accessibilityLabel("Play \(track.title)")
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(category.displayName)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: allowedTypes.isEmpty ? [UTType.data] : allowedTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                let started = url.startAccessingSecurityScopedResource()
                Task {
                    defer {
                        if started {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }
                    do {
                        _ = try await awaitCopyImported(url)
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

    @ViewBuilder
    private func lullabyRow(track: AudioTrack, index: Int, playlist: [AudioTrack], isLullabies: Bool, canDelete: Bool) -> some View {
        let isCurrent = rootViewModel.nowPlayingViewModel.currentTrackFilename == track.filename
        let isPlayingCurrent = isCurrent && rootViewModel.nowPlayingViewModel.isPlaying

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(.headline)
                    if isCurrent {
                        HStack(spacing: 6) {
                            Image(systemName: isPlayingCurrent ? "speaker.wave.2.fill" : "speaker.wave.2")
                            Text(isPlayingCurrent ? "Playing" : "Paused")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Text(track.filename)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(track.durationSeconds.formattedMMSS())
                        .font(.subheadline)
                }

                VStack(alignment: .trailing, spacing: 8) {
                    if isLullabies {
                        Button {
                            rootViewModel.toggleFavorite(track.filename)
                        } label: {
                            Image(systemName: rootViewModel.isFavorite(track.filename) ? "heart.fill" : "heart")
                                .font(.system(size: 22, weight: .semibold))
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.bordered)
                        .tint(.pink)
                        .accessibilityLabel(rootViewModel.isFavorite(track.filename) ? "Unfavorite \(track.title)" : "Favorite \(track.title)")
                    }

                    Button {
                        if isCurrent {
                            rootViewModel.nowPlayingViewModel.togglePlayPause()
                        } else {
                            rootViewModel.nowPlayingViewModel.playTrack(track, playlist: playlist, index: index)
                        }
                    } label: {
                        Text(isCurrent ? (isPlayingCurrent ? "Pause" : "Play") : "Play")
                            .font(.headline)
                            .frame(minWidth: 78)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel(isCurrent ? (isPlayingCurrent ? "Pause \(track.title)" : "Play \(track.title)") : "Play \(track.title)")

                    if canDelete {
                        Button(role: .destructive) {
                            deleteError = nil
                            deleteUserLullaby(track)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 20, weight: .semibold))
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Delete \(track.title)")
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .listRowBackground(isCurrent ? Color.accentColor.opacity(0.10) : nil)
    }

    private func deleteUserLullaby(_ track: AudioTrack) {
        if rootViewModel.nowPlayingViewModel.currentTrackFilename == track.filename {
            rootViewModel.nowPlayingViewModel.stopAllPlaybackAndTimers()
        }
        do {
            try UserLullabiesStorage.deleteUserLullaby(track)
            rootViewModel.refreshAudioLibrary()
        } catch {
            deleteError = error.localizedDescription
        }
    }
}

private extension CategoryTracksView {
    func tryToCopyImported(_ url: URL) throws -> AudioTrack {
        // Keep import work off the main thread.
        return try UserLullabiesStorage.importLullaby(from: url)
    }

    func awaitCopyImported(_ url: URL) async throws -> AudioTrack {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let track = try UserLullabiesStorage.importLullaby(from: url)
                    continuation.resume(returning: track)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

