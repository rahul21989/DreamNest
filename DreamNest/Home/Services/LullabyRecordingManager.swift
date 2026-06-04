import Foundation
import AVFoundation
import Combine

enum LullabyRecordingError: LocalizedError {
    case permissionDenied
    case recorderSetupFailed
    case mp3EncodingUnavailable

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission denied."
        case .recorderSetupFailed:
            return "Could not start recording."
        case .mp3EncodingUnavailable:
            return "MP3 recording is not available on this device."
        }
    }
}

/// Simple record/stop manager that saves a voice lullaby into Documents.
@MainActor
final class LullabyRecordingManager: NSObject, ObservableObject {
    @Published private(set) var isRecording: Bool = false

    private var recorder: AVAudioRecorder?
    private var tempURL: URL?

    /// Called when a new lullaby is saved successfully.
    var onSaved: ((AudioTrack) -> Void)?
    /// Called on failures (permission/setup/copy).
    var onError: ((Error) -> Void)?

    func start() async {
        do {
            let granted = await requestPermission()
            guard granted else { throw LullabyRecordingError.permissionDenied }

            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)

            let tempDir = FileManager.default.temporaryDirectory
            let tempFile = "dn_lullaby_recording_\(UUID().uuidString).mp3"
            let outURL = tempDir.appendingPathComponent(tempFile)
            tempURL = outURL

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEGLayer3),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 128000,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            let recorder = try AVAudioRecorder(url: outURL, settings: settings)
            recorder.delegate = self
            recorder.prepareToRecord()
            guard recorder.record() else {
                throw LullabyRecordingError.mp3EncodingUnavailable
            }
            self.recorder = recorder
            isRecording = true
        } catch {
            onError?(error)
        }
    }

    func stop() {
        guard isRecording else { return }
        isRecording = false
        recorder?.stop()
    }

    private func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}

extension LullabyRecordingManager: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        self.recorder = nil
        guard flag, let tempURL else {
            self.tempURL = nil
            reactivatePlaybackSession()
            onError?(LullabyRecordingError.recorderSetupFailed)
            return
        }

        do {
            let track = try UserLullabiesStorage.saveRecordedLullaby(from: tempURL)
            self.tempURL = nil
            reactivatePlaybackSession()
            onSaved?(track)
        } catch {
            self.tempURL = nil
            reactivatePlaybackSession()
            onError?(error)
        }
    }

    private func reactivatePlaybackSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.allowBluetooth, .allowAirPlay])
            try session.setActive(true)
        } catch {
            // Keep this best-effort; playback service will re-assert on play.
        }
    }
}

