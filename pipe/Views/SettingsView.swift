import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var player: PlayerState
    @State private var instanceDraft = ""

    private let sleepOptions = [15, 30, 45, 60]

    var body: some View {
        List {
            Section("Piped Instance") {
                TextField("https://pipedapi…", text: $instanceDraft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                HStack {
                    Button("Save") { settings.instanceURL = instanceDraft }
                        .disabled(!SettingsLogic.isValidInstanceDraft(instanceDraft))
                    Spacer()
                    Button("Reset") {
                        settings.resetInstance()
                        instanceDraft = settings.instanceURL
                    }.foregroundColor(.secondary)
                }
            }

            Section("Sleep Timer") {
                if let remaining = player.sleepMinutesRemaining {
                    HStack {
                        Label("\(remaining) min remaining", systemImage: "moon.zzz.fill")
                        Spacer()
                        Button("Cancel") { player.startSleepTimer(minutes: nil) }
                            .foregroundColor(.red)
                    }
                } else {
                    ForEach(sleepOptions, id: \.self) { mins in
                        Button("Sleep after \(mins) min") { player.startSleepTimer(minutes: mins) }
                    }
                }
            }

            Section("Search History") {
                if settings.searchHistory.isEmpty {
                    Text("No recent searches").foregroundStyle(.secondary)
                } else {
                    ForEach(settings.searchHistory, id: \.self) { term in
                        Text(term)
                    }
                    Button("Clear History") { settings.clearHistory() }
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("Settings")
        .onAppear { instanceDraft = settings.instanceURL }
    }
}
