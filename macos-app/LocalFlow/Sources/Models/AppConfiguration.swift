import Foundation

struct AppConfiguration: Codable {
    var audioSaveDirectory: String
    var transcriptionSaveDirectory: String
    var serverPort: Int
    var autoTranscribe: Bool
    var autoDeleteAudioAfterTranscription: Bool
    var superWhisperRecordingsPath: String
    var filenamePrefix: String

    static let defaultAudioDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Documents/LocalFlow/audio").path
    static let defaultTranscriptionDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Documents/LocalFlow/transcriptions").path
    static let defaultSuperWhisperPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Documents/Apps/superwhisper/recordings").path

    static let configFileURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("LocalFlow")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("config.json")
    }()

    init() {
        self.audioSaveDirectory = Self.defaultAudioDir
        self.transcriptionSaveDirectory = Self.defaultTranscriptionDir
        self.serverPort = 8080
        self.autoTranscribe = true
        self.autoDeleteAudioAfterTranscription = false
        self.superWhisperRecordingsPath = Self.defaultSuperWhisperPath
        self.filenamePrefix = "localflow"
    }

    static func load() -> AppConfiguration {
        guard let data = try? Data(contentsOf: configFileURL),
              let config = try? JSONDecoder().decode(AppConfiguration.self, from: data) else {
            let config = AppConfiguration()
            config.save()
            return config
        }
        return config
    }

    func save() {
        ensureDirectoriesExist()
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(self) {
            try? data.write(to: Self.configFileURL)
        }
    }

    private func ensureDirectoriesExist() {
        let fm = FileManager.default
        try? fm.createDirectory(atPath: audioSaveDirectory, withIntermediateDirectories: true)
        try? fm.createDirectory(atPath: transcriptionSaveDirectory, withIntermediateDirectories: true)
    }
}
