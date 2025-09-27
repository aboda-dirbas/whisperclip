import Foundation
import AVFoundation

extension Notification.Name {
    /// Posted by AudioRecorder when the .stop() call finishes writing the file
    static let didFinishRecording = Notification.Name("AudioRecorderDidFinishRecording")
    static let recordingError = Notification.Name("AudioRecorderRecordingError")
}

/// Observable helper that wraps `AVAudioRecorder`
final class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    private var recorder: AVAudioRecorder?
    private var resetPending = false
    private var startTimestamp: Int64 = 0

    /// Where the next file will be written
    private(set) var outputURL: URL?

    /// Start a new recording
    private func getRecordingDir() -> URL {
        let appDir = GenericHelper.getAppSupportDirectory()
        return appDir.appendingPathComponent("recordings")
    }

    func start() throws {
        if isRecording {
            Logger.log("Recording already in progress", log: Logger.audio, type: .debug)
            throw NSError(domain: "AudioRecorder", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Recording already in progress"])
        }

        // 1. Destination URL — Desktop/recording‑<timestamp>.m4a
        let dir = getRecordingDir()
        try GenericHelper.folderCreate(folder: dir)
        GenericHelper.folderCleanOldFiles(folder: dir, days: 1)

        let fileName = "recording-\(GenericHelper.getUnixTimestamp()).m4a"
        let fileURL = dir.appendingPathComponent(fileName)

        // 2. Recorder settings (AAC 44.1 kHz stereo)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 192_000
        ]

        // 3. Create & prepare recorder
        recorder = try AVAudioRecorder(url: fileURL, settings: settings)
        recorder?.delegate = self
        recorder?.isMeteringEnabled = true
        recorder?.prepareToRecord()

        // 4. Start!
        guard recorder?.record() == true else {
            throw NSError(domain: "AudioRecorder", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Could not start recording"])
        }

        startTimestamp = GenericHelper.getUnixTimestamp()
        outputURL   = fileURL
        isRecording = true
    }

    func getLevel() -> Float {
        guard let recorder = recorder, isRecording else {
            return 0.0
        }

        recorder.updateMeters()
        return recorder.averagePower(forChannel: 0)
    }

    /// Stop the current recording (if any)
    func stop() {
        Logger.log("Stopping recording", log: Logger.audio)
        recorder?.stop()
    }

    private func wait() {
        Logger.log("Waiting for recording to stop", log: Logger.audio)
        for _ in 0..<10 {
            if !isRecording {
                break
            }
            usleep(50_000)
        }
        Logger.log("Recording stopped: \(isRecording)", log: Logger.audio)
    }

    private func deleteOutputFile() {
        if let url = outputURL {
            GenericHelper.deleteFile(file: url)
            outputURL = nil
        }
    }

    func reset() {
        resetPending = true
        stop()
        wait()

        deleteOutputFile()
        recorder = nil
        isRecording = false
        resetPending = false
    }

    deinit {
        reset()
    }
}

extension AudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Logger.log("Recording encode error: \(error?.localizedDescription ?? "Unknown error")", log: Logger.audio, type: .error)
        isRecording = false

        if !resetPending {
            if let err = error {
                NotificationCenter.default.post(name: .recordingError, object: err)
            } else {
                NotificationCenter.default.post(name: .recordingError, object: "Recording encode error")
            }
        }
    }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        isRecording = false
        Logger.log("Recording finished: \(flag)", log: Logger.audio)

        if !resetPending {
            if !flag {
                NotificationCenter.default.post(name: .recordingError, object: "Recording failed")
            } else {
                NotificationCenter.default.post(name: .didFinishRecording, object: outputURL)
            }
        }
    }
}
