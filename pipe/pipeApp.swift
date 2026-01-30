import SwiftUI
import AVFoundation

@main
struct pipeApp: App {
    init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
