import Foundation
import AVFoundation
import Combine

enum LullabyRecordingError: LocalizedError {
    case permissionDenied
    case recorderSetupFailed
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone access was denied. Go to Settings → DreamNest to enable it."
        case .recorderSetupFailed:
            return "Could not start recording. Please try again."
        case .saveFailed:
            return "Recording finished but could not be saved. Please try again."
        }
    }
}

/// Records a voice lullaby and saves it to the app's Documents directory.
@MainActor
final class LullabyRecordingManager: NSObject, ObservableObject {

    @Published private(set) var isRecording: Bool = false

    private var recorder: AVAudioRecorder?
    private var tempURL: URL?

    var onSaved: ((AudioTrack) -> Void)?
    var onError: ((Error) -> Void)?

    // MARK: - Start

    func start() async {
        do {
            // 1. Request microphone permission
            let granted = await requestPermission()
            guard granted else { throw LullabyRecordingError.permissionDenied }

            // 2. Configure audio session for recording
            //    .mixWithOthers lets any currently-playing lullaby keep playing
            //    while the microphone captures the parent's voice.
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .mixWithOthers]
            )
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            // 3. Build temp file URL — use .m4a (AAC), the only lossy format iOS
            //    supports for recording. kAudioFormatMPEGLayer3 (MP3) throws an
            //    OSStatus error on every iOS device.
            let tempFile = "dn_lullaby_\(UUID().uuidString).m4a"
            let outURL   = FileManager.default.temporaryDirectory
                               .appendingPathComponent(tempFile)
            tempURL = outURL

            // 4. AAC @ 44.1 kHz — excellent quality, small file size
            let settings: [String: Any] = [
                AVFormatIDKey:             Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey:           44_100,
                AVNumberOfChannelsKey:     1,
                AVEncoderAudioQualityKey:  AVAudioQuality.high.rawValue,
                AVEncoderBitRateKey:       128_000
            ]

            // 5. Create recorder
            let recorder = try AVAudioRecorder(url: outURL, settings: settings)
            recorder.delegate = self
            recorder.prepareToRecord()

            guard recorder.record() else {
                throw LullabyRecordingError.recorderSetupFailed
            }

            self.recorder = recorder
            isRecording   = true

        } catch {
            onError?(error)
        }
    }

    // MARK: - Stop

    func stop() {
        guard isRecording else { return }
        isRecording = false
        recorder?.stop()      // triggers audioRecorderDidFinishRecording
    }

    // MARK: - Permission

    private func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}

// MARK: - AVAudioRecorderDelegate

extension LullabyRecordingManager: AVAudioRecorderDelegate {

    nonisolated func audioRecorderDidFinishRecording(
        _ recorder: AVAudioRecorder,
        successfully flag: Bool
    ) {
        Task { @MainActor in
            self.recorder = nil
            defer {
                self.reactivatePlaybackSession()
                self.tempURL = nil
            }

            guard flag, let url = self.tempURL else {
                self.onError?(LullabyRecordingError.saveFailed)
                return
            }

            do {
                let track = try UserLullabiesStorage.saveRecordedLullaby(from: url)
                self.onSaved?(track)
            } catch {
                self.onError?(error)
            }
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(
        _ recorder: AVAudioRecorder,
        error: Error?
    ) {
        Task { @MainActor in
            self.recorder  = nil
            self.tempURL   = nil
            self.isRecording = false
            self.reactivatePlaybackSession()
            self.onError?(error ?? LullabyRecordingError.recorderSetupFailed)
        }
    }

    // Restore playback-only session after recording ends
    private func reactivatePlaybackSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(
            .playback,
            mode: .default,
            options: [.allowBluetooth, .allowAirPlay]
        )
        try? session.setActive(true)
    }
}
