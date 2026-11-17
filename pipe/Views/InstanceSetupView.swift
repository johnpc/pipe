import SwiftUI

/// What Feed and Search show until the app has a Piped instance. pipe ships with
/// no server: the user enters the address of the instance they use, or tries
/// the hosted demo library (labelled sample clips, no streaming service).
struct InstanceSetupView: View {
    @ObservedObject var settings: AppSettings
    @State private var draft = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "server.rack")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
                    .padding(.top, 48)
                Text("Choose a Piped instance")
                    .font(.title2).bold()
                Text("pipe doesn't come with a server. Enter the address of the Piped instance you use, and the app will fetch everything from there.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 32)

                TextField("https://pipedapi.example.com", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .accessibilityIdentifier("instanceSetupField")
                    .padding(.horizontal, 32)
                Button("Use this instance") { settings.instanceURL = draft }
                    .buttonStyle(.borderedProminent)
                    .disabled(!SettingsLogic.isValidInstanceDraft(draft))
                    .accessibilityIdentifier("instanceSetupSave")

                Divider().padding(.horizontal, 48)
                Text("Just looking? The demo library has a few labelled sample clips and no real videos.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 32)
                Button("Try the demo library") { settings.useDemoInstance() }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("useDemoLibrary")
                Text("You can change this any time in Settings.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.bottom, 32)
        }
        .accessibilityIdentifier("instanceSetup")
    }
}
