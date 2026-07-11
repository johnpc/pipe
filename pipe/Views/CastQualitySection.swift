import SwiftUI

/// Settings section for the preferred cast resolution. Extracted from
/// `SettingsView` so each stays focused and under the line limit.
struct CastQualitySection: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Section {
            Picker("Cast Quality", selection: $settings.castQuality) {
                ForEach(CastQuality.allCases) { quality in
                    Text(quality.label).tag(quality)
                }
            }
            .accessibilityIdentifier("castQualityPicker")
        } header: {
            Text("Cast Quality")
        } footer: {
            Text("Higher resolutions depend on your Piped instance — some only offer 360p.")
        }
    }
}
