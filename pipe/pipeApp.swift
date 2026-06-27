import SwiftUI
import AVFoundation

@main
struct pipeApp: App {
    init() {
        // Serve bundled fixtures instead of the live API when UI testing.
        MockMode.activateIfNeeded()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
