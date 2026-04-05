import Foundation
import AVFoundation
import Combine

enum LullabyRecordingError: LocalizedError {
    case permissionDenied
    case recorderSetupFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission denied."
        case .recorderSetupFailed:
            return "Could not start recording."
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
            let tempFile = "dn_lullaby_recording_\(UUID().uuidString).m4a"
            let outURL = tempDir.appendingPathComponent(tempFile)
            tempURL = outURL

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            let recorder = try AVAudioRecorder(url: outURL, settings: settings)
            recorder.delegate = self
            recorder.prepareToRecord()
            recorder.record()
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
        guard flag, let tempURL else {
            onError?(LullabyRecordingError.recorderSetupFailed)
            return
        }

        do {
            let track = try UserLullabiesStorage.saveRecordedLullaby(from: tempURL)
            onSaved?(track)
        } catch {
            onError?(error)
        }
    }
}

