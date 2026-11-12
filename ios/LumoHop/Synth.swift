import AVFoundation

/// All sound is synthesized: short plucked tones for hops plus a quiet three-note drone.
final class Synth {
    enum Wave { case sine, triangle, square, saw }
    private struct Voice {
        var freq: Double, slideTo: Double, dur: Double, vol: Double, wave: Wave
        var delay: Int      // samples left before the voice starts
        var n: Int = 0      // samples played
        var phase: Double = 0
    }

    private let engine = AVAudioEngine()
    private var source: AVAudioSourceNode?
    private var voices: [Voice] = []
    private let lock = NSLock()
    private var sampleRate = 44100.0
    private var padPhase: [Double] = [0, 0, 0]
    private var lfoPhase: [Double] = [0, 0, 0]
    private var started = false
    var muted = false { didSet { engine.mainMixerNode.outputVolume = muted ? 0 : 0.6 } }

    init() {
        let sr = engine.outputNode.outputFormat(forBus: 0).sampleRate
        if sr > 0 { sampleRate = sr }
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }
        let node = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let self = self, let raw = buffers[0].mData else { return noErr }
            self.render(raw.assumingMemoryBound(to: Float.self), Int(frameCount))
            return noErr
        }
        source = node
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.6
    }

    func start() {
        guard !started, source != nil else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            started = true
        } catch { started = false }
    }

    private func render(_ out: UnsafeMutablePointer<Float>, _ count: Int) {
        let sr = sampleRate, twoPi = 2 * Double.pi
        let padFreq = [98.0, 146.83, 196.5]
        lock.lock()
        for i in 0..<count {
            var s = 0.0
            for k in 0..<3 {
                padPhase[k] += twoPi * padFreq[k] / sr; if padPhase[k] > twoPi { padPhase[k] -= twoPi }
                lfoPhase[k] += twoPi * (0.07 + Double(k) * 0.05) / sr; if lfoPhase[k] > twoPi { lfoPhase[k] -= twoPi }
                s += sin(padPhase[k]) * (0.028 + 0.018 * sin(lfoPhase[k]))
            }
            var v = 0
            while v < voices.count {
                if voices[v].delay > 0 { voices[v].delay -= 1; v += 1; continue }
                let tt = Double(voices[v].n) / sr
                if tt >= voices[v].dur { voices.remove(at: v); continue }
                let f = voices[v].slideTo > 0 ? voices[v].freq * pow(voices[v].slideTo / voices[v].freq, tt / voices[v].dur) : voices[v].freq
                voices[v].phase += f / sr; if voices[v].phase >= 1 { voices[v].phase -= 1 }
                let ph = voices[v].phase
                let w: Double
                switch voices[v].wave {
                case .sine: w = sin(twoPi * ph)
                case .triangle: w = 4 * abs(ph - 0.5) - 1
                case .square: w = ph < 0.5 ? 0.6 : -0.6
                case .saw: w = (2 * ph - 1) * 0.7
                }
                let env = tt < 0.012 ? tt / 0.012 : exp(-5.5 * (tt - 0.012) / voices[v].dur)
                s += w * env * voices[v].vol
                voices[v].n += 1; v += 1
            }
            out[i] = Float(max(-1, min(1, s)))
        }
        lock.unlock()
    }

    private func tone(_ freq: Double, _ dur: Double, _ wave: Wave, _ vol: Double, delay: Double = 0, slideTo: Double = 0) {
        guard started, !muted else { return }
        lock.lock()
        if voices.count < 24 {
            voices.append(Voice(freq: freq, slideTo: slideTo, dur: dur, vol: vol, wave: wave, delay: Int(delay * sampleRate)))
        }
        lock.unlock()
    }

    private func note(_ n: Int) -> Double {
        let penta = [0.0, 2, 4, 7, 9]
        return 392 * pow(2, (penta[n % 5] + 12 * Double(n / 5)) / 12)
    }

    func hop(_ n: Int) {
        let f = note(min(max(n, 0), 11))
        tone(f, 0.4, .triangle, 0.22); tone(f * 2, 0.55, .sine, 0.09, delay: 0.04); tone(f * 1.5, 0.5, .sine, 0.05, delay: 0.09)
    }
    func rehop() { tone(294, 0.2, .triangle, 0.1) }
    func leap() { tone(480, 0.14, .sine, 0.07, slideTo: 960) }
    func wall() { tone(190, 0.07, .square, 0.04) }
    func gem() { tone(1568, 0.2, .sine, 0.13); tone(2093, 0.32, .sine, 0.1, delay: 0.07) }
    func dead() { tone(330, 0.6, .saw, 0.1, slideTo: 60); tone(165, 0.7, .sine, 0.14, slideTo: 40) }
}
