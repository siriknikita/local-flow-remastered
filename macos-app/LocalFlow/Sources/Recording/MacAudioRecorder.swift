import AVFoundation
import SwiftUI

@MainActor
final class MacAudioRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var audioLevel: Float = 0

    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private var currentFileURL: URL?

    private let recordingSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 44100,
        AVNumberOfChannelsKey: 1,
        AVEncoderBitRateKey: 128_000,
    ]

    func startRecording(saveDirectory: String, filenamePrefix: String) -> URL? {
        let dir = URL(fileURLWithPath: saveDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let timestamp = Self.formatTimestamp(Date())
        let filename = "\(timestamp)_\(filenamePrefix)_local.m4a"
        let fileURL = dir.appendingPathComponent(filename)

        do {
            let recorder = try AVAudioRecorder(url: fileURL, settings: recordingSettings)
            recorder.isMeteringEnabled = true
            recorder.prepareToRecord()
            guard recorder.record() else { return nil }

            audioRecorder = recorder
            currentFileURL = fileURL
            isRecording = true
            recordingDuration = 0
            audioLevel = 0

            // Use a timer that directly calls updateMeter on main actor
            let meteringTimer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
                guard let self else { return }
                MainActor.assumeIsolated {
                    self.updateMeter()
                }
            }
            RunLoop.main.add(meteringTimer, forMode: .common)
            timer = meteringTimer

            return fileURL
        } catch {
            print("[MacRecorder] Failed to start: \(error)")
            return nil
        }
    }

    func stopRecording() -> URL? {
        timer?.invalidate()
        timer = nil

        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        audioLevel = 0
        recordingDuration = 0

        let url = currentFileURL
        currentFileURL = nil
        return url
    }

    func cancelRecording() {
        let url = stopRecording()
        if let url {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func updateMeter() {
        guard isRecording, let recorder = audioRecorder else { return }
        recordingDuration = recorder.currentTime
        recorder.updateMeters()
        let db = recorder.averagePower(forChannel: 0)
        let clamped = max(-60.0, min(db, 0.0))
        audioLevel = (clamped + 60.0) / 60.0
    }

    private static func formatTimestamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return f.string(from: date)
    }
}
