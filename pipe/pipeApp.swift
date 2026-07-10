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
        // No-op when the Cast SDK isn't linked. Skipped under UI tests: starting
        // Cast discovery raises the local-network permission alert, whose system
        // dialog covers the app and fails every subsequent tap.
        if !MockMode.isEnabled() {
            GoogleCaster.bootstrap()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
