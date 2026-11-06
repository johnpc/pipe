import SwiftUI

/// Settings section for the default audio language on dubbed videos.
struct AudioLanguageSection: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Section {
            Picker("Audio Language", selection: $settings.audioLanguage) {
                ForEach(AudioLanguageLogic.settingsChoices(), id: \.self) { code in
                    Text(AudioLanguageLogic.displayName(code)).tag(code)
                }
            }
            .accessibilityIdentifier("audioLanguagePicker")
        } header: {
            Text("Audio Language")
        } footer: {
            Text("For videos dubbed into several languages. If yours isn't offered, English plays, then the original audio.")
        }
    }
}
