import SwiftUI
import AVFoundation

@main
struct pipeApp: App {
    init() {
        // Serve bundled fixtures instead of the live API when UI testing.
        MockMode.activateIfNeeded()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        // Initialize the Cast context once, before any CastStore is created.
        // No-op when the Cast SDK isn't linked.
        GoogleCaster.bootstrap()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
