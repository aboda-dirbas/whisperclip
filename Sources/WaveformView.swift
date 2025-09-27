import SwiftUI
import AVFoundation
import AppKit

struct WaveformView: View {
    /// Your existing recorder
    var audio: AudioRecorder

    /// Keep the last N levels
    @State private var levels: [Float] = Array(repeating: -160, count: 120)
    private let maxSamples = 120

    /// Drive sampling at 20 Hz
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let barCount = levels.count
                guard barCount > 0 && audio.isRecording else { return }

                let barWidth = size.width / CGFloat(maxSamples)
                let midY     = size.height / 2

                for (i, level) in levels.enumerated() {
                    // Convert from dB to linear (0…1)
                    let lin = CGFloat(pow(10, level / 20))
                    // Scale to view height (clamped 0…1)
                    let h   = max(0, min(1, lin)) * size.height
                    // Center bar vertically
                    let y   = midY - h/2
                    let x   = CGFloat(i) * barWidth

                    let rect = CGRect(x: x,
                                      y: y,
                                      width: barWidth * 0.8,
                                      height: h)

                    context.fill(
                        Path(rect),
                        with: .color(.accentColor)
                    )
                }
            }
            .clipped()
            .onReceive(timer) { _ in
                if audio.isRecording {
                    let newLevel = audio.getLevel()
                    levels.append(newLevel)
                    if levels.count > maxSamples {
                        levels.removeFirst(levels.count - maxSamples)
                    }
                } else {
                    levels = Array(repeating: -160, count: maxSamples)
                }
            }
        }
        .frame(height: 160)
        .animation(.easeOut(duration: 0.1), value: levels)
    }
}