import SwiftUI

struct UploadRowView: View {
    let upload: UploadRecord
    let onReveal: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
                .font(.body)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(upload.filename)
                    .font(.subheadline)
                    .lineLimit(1)
                Text("\(upload.deviceName) \u{2014} \(upload.receivedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isHovering {
                HStack(spacing: 12) {
                    Button { onReveal() } label: {
                        Image(systemName: "folder")
                            .font(.body)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .help("Show in Finder")

                    Button { onDelete() } label: {
                        Image(systemName: "trash")
                            .font(.body)
                            .foregroundStyle(.red)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .help("Delete")
                }
                .transition(.opacity)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }

    private var statusIcon: String {
        switch upload.transcriptionStatus {
        case .received, .queued: "clock"
        case .transcribing: "waveform"
        case .completed: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        case .skipped: "minus.circle"
        }
    }

    private var statusColor: Color {
        switch upload.transcriptionStatus {
        case .received, .queued: .orange
        case .transcribing: .blue
        case .completed: .green
        case .failed: .red
        case .skipped: .gray
        }
    }
}
