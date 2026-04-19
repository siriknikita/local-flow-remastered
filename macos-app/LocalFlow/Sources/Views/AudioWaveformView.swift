import SwiftUI

struct AudioWaveformView: View {
    let level: Float

    private let barCount = 7
    private let barSpacing: CGFloat = 4

    var body: some View {
        HStack(spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                WaveformBar(level: level, index: index, totalBars: barCount)
            }
        }
    }
}

private struct WaveformBar: View {
    let level: Float
    let index: Int
    let totalBars: Int

    // Bars near center are taller
    private var scaleFactor: CGFloat {
        let center = CGFloat(totalBars - 1) / 2.0
        let distance = abs(CGFloat(index) - center) / center
        return 1.0 - distance * 0.6
    }

    private var barHeight: CGFloat {
        let minHeight: CGFloat = 8
        let maxHeight: CGFloat = 60
        let normalized = CGFloat(level) * scaleFactor
        return minHeight + normalized * (maxHeight - minHeight)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(.red.opacity(0.5))
            .frame(width: 4, height: barHeight)
            .animation(.easeOut(duration: 0.08), value: level)
    }
}
