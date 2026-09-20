import SwiftUI
import AVFoundation

@main
struct ATLASMusicApp: App {
    init() {
        configureAudioSession()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.allowAirPlay]
            )
            try session.setActive(true)
        } catch {
            print("ATLAS Music audio session error: \(error)")
        }
    }
}
