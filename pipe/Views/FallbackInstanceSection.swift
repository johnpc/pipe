import SwiftUI

/// Settings section for the optional fallback Piped instance: the one pipe
/// tries when the main instance can't be reached (see `InstanceFailover`).
struct FallbackInstanceSection: View {
    @ObservedObject var settings: AppSettings
    @State private var draft = ""

    var body: some View {
        Section {
            TextField("https://another-pipedapi…", text: $draft)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .accessibilityIdentifier("fallbackInstanceField")
            HStack {
                Button("Save") { settings.fallbackInstanceURL = draft }
                    .disabled(!SettingsLogic.isValidInstanceDraft(draft))
                Spacer()
                Button("Clear") {
                    settings.fallbackInstanceURL = AppSettings.noInstance
                    draft = settings.fallbackInstanceURL
                }.foregroundColor(.secondary)
            }
        } header: {
            Text("Fallback Instance")
        } footer: {
            Text("Optional. If your instance can't be reached, pipe tries this one instead and keeps using it for five minutes before checking yours again.")
        }
        .onAppear { draft = settings.fallbackInstanceURL }
    }
}
