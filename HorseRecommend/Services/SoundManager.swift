import AudioToolbox
import AVFoundation

enum SoundManager {
    private static var player: AVAudioPlayer?

    // MARK: - Public

    static func playXPGain() {
        playFile("xp_gain") ?? playSystem(1057)
    }

    static func playLevelUp() {
        playFile("level_up") ?? playSystem(1025)
    }

    static func playTitleUp() {
        if playFile("title_up") == nil {
            playSystem(1016)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                playSystem(1025)
            }
        }
    }

    // MARK: - Private

    @discardableResult
    private static func playFile(_ name: String) -> Void? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") ??
                        Bundle.main.url(forResource: name, withExtension: "mp3") else { return nil }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
        return ()
    }

    private static func playSystem(_ id: SystemSoundID) {
        AudioServicesPlaySystemSound(id)
    }
}
