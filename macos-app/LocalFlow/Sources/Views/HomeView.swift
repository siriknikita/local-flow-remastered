import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var recorder: MacAudioRecorder

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                recordSection
                transcriptsSection
            }
            .padding(24)
        }
        .navigationTitle("Home")
    }

    // MARK: - Record Section

    private var recordSection: some View {
        VStack(spacing: 16) {
            ZStack {
                if recorder.isRecording {
                    AudioWaveformView(level: recorder.audioLevel)
                        .frame(width: 200, height: 80)
                        .transition(.opacity)
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if recorder.isRecording {
                            appState.stopRecording()
                        } else {
                            appState.startRecording()
                        }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(recorder.isRecording ? .red : .accentColor)
                            .frame(width: 72, height: 72)

                        if recorder.isRecording {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.white)
                                .frame(width: 24, height: 24)
                        } else {
                            Image(systemName: "mic.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                        }
                    }
                    .glassEffect(.regular, in: .circle)
                }
                .buttonStyle(.plain)
            }

            if recorder.isRecording {
                Text(formattedDuration(recorder.recordingDuration))
                    .font(.system(.title3, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            } else {
                Text("Tap to record")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .animation(.easeInOut(duration: 0.2), value: recorder.isRecording)
    }

    // MARK: - Recent Transcripts

    private var transcriptsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Transcripts")
                .font(.headline)

            if appState.recentUploads.isEmpty {
                Text("No recordings yet. Record audio or receive from your phone.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(appState.recentUploads.prefix(15)) { upload in
                        uploadRow(upload)
                    }
                }
            }
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
    }

    private func uploadRow(_ upload: UploadRecord) -> some View {
        UploadRowView(upload: upload, onReveal: {
            revealInFinder(upload)
        }, onDelete: {
            deleteUpload(upload)
        })
    }

    private func revealInFinder(_ upload: UploadRecord) {
        let audioURL = URL(fileURLWithPath: appState.config.audioSaveDirectory)
            .appendingPathComponent(upload.filename)
        if FileManager.default.fileExists(atPath: audioURL.path) {
            NSWorkspace.shared.activateFileViewerSelecting([audioURL])
        } else {
            // Try transcription directory
            let baseName = URL(fileURLWithPath: upload.filename).deletingPathExtension().lastPathComponent
            let textURL = URL(fileURLWithPath: appState.config.transcriptionSaveDirectory)
                .appendingPathComponent("\(baseName).txt")
            if FileManager.default.fileExists(atPath: textURL.path) {
                NSWorkspace.shared.activateFileViewerSelecting([textURL])
            }
        }
    }

    private func deleteUpload(_ upload: UploadRecord) {
        // Delete audio file
        let audioURL = URL(fileURLWithPath: appState.config.audioSaveDirectory)
            .appendingPathComponent(upload.filename)
        try? FileManager.default.removeItem(at: audioURL)

        // Delete transcription file
        let baseName = URL(fileURLWithPath: upload.filename).deletingPathExtension().lastPathComponent
        let textURL = URL(fileURLWithPath: appState.config.transcriptionSaveDirectory)
            .appendingPathComponent("\(baseName).txt")
        try? FileManager.default.removeItem(at: textURL)

        // Remove from list
        appState.recentUploads.removeAll { $0.id == upload.id }
    }

    // MARK: - Helpers

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let tenths = Int(duration * 10) % 10
        return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
    }

}
