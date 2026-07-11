import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var player: PlayerState
    @ObservedObject var recents: RecentsStore
    var onDone: (() -> Void)? = nil
    @State private var instanceDraft = ""

    private let sleepOptions = [15, 30, 45, 60]

    var body: some View {
        List {
            Section {
                Toggle("Offline Mode", isOn: $settings.offlineMode)
                    .accessibilityIdentifier("offlineModeToggle")
            } header: {
                Text("Playback")
            } footer: {
                Text("Show your downloads and hide tabs that need a connection.")
            }

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

            CastQualitySection(settings: settings)

            Section("Sleep Timer") {
                if let remaining = player.sleepMinutesRemaining {
                    HStack {
                        Label("\(remaining) min remaining", systemImage: "moon.zzz.fill")
                        Spacer()
                        Button("Cancel") { player.startSleepTimer(minutes: nil) }
                            .foregroundColor(.red)
                    }
                } else if player.stopAfterCurrentEpisode {
                    HStack {
                        Label("Stops after this episode", systemImage: "moon.zzz.fill")
                        Spacer()
                        Button("Cancel") { player.stopAfterCurrentEpisode = false }
                            .foregroundColor(.red)
                    }
                } else {
                    ForEach(sleepOptions, id: \.self) { mins in
                        Button("Sleep after \(mins) min") { player.startSleepTimer(minutes: mins) }
                    }
                    Button("Sleep at end of episode") { player.stopAfterCurrentEpisode = true }
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

            Section("Watch History") {
                if recents.items.isEmpty {
                    Text("No watch history").foregroundStyle(.secondary)
                } else {
                    Text("\(recents.items.count) watched")
                        .foregroundStyle(.secondary)
                    Button("Clear Watch History") { recents.clear() }
                        .foregroundColor(.red)
                }
            }

            DiagnosticsSection(settings: settings, log: player.log)
        }
        .navigationTitle("Settings")
        .toolbar {
            if let onDone {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onDone).accessibilityIdentifier("settingsDone")
                }
            }
        }
        .onAppear { instanceDraft = settings.instanceURL }
    }
}
