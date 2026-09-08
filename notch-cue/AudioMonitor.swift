import AVFoundation
import SwiftUI
import Combine
import Accelerate

class AudioMonitor: ObservableObject {
    private var audioEngine: AVAudioEngine
    private var inputNode: AVAudioInputNode?
    private var timer: Timer?
    /// Exponential moving average weight for each new buffer's RMS.
    /// Higher = more responsive, lower = steadier/less jittery.
    private let smoothingFactor: Float = 0.25

    @Published var rmsLevel: Float = 0


    init() {
        audioEngine = AVAudioEngine()
        inputNode = audioEngine.inputNode
    }

    func startMonitoring() {
        let format = inputNode!.outputFormat(forBus: 0)

        inputNode!.installTap(onBus: 0, bufferSize: 256, format: format) { [weak self] buffer, time in
            guard let self = self else { return }

            let rms = self.rms(buffer: buffer)
            DispatchQueue.main.async {
                // Standard EMA: nudge the published level toward the latest
                // reading instead of jumping straight to it, so it doesn't
                // flicker on and off between buffers.
                self.rmsLevel += self.smoothingFactor * (rms - self.rmsLevel)
            }
        }

        do {
            try audioEngine.start()
        } catch {
            print("Error starting audio engine: \(error)")
        }
    }

    func stopMonitoring() {
        inputNode?.removeTap(onBus: 0)
        audioEngine.stop()
    }

    private func rms(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }
        let frameLength = vDSP_Length(buffer.frameLength)

        var rmsValue: Float = 0
        vDSP_rmsqv(channelData, 1, &rmsValue, frameLength)

        return rmsValue
    }
}
