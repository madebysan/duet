import SwiftUI

@main
struct MixLayerApp: App {
    @StateObject private var player = AudioPlayerModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(player)
                .onChange(of: scenePhase) { _, phase in
                    // Keep each file's place even if the app is closed from the background.
                    if phase != .active { player.saveCurrentPosition() }
                }
                .task {
                    await player.bootstrapLibrary()
                    if ProcessInfo.processInfo.arguments.contains("--autoplay-sample") {
                        try? await Task.sleep(for: .milliseconds(600))
                        player.togglePlayback()
                    }
                }
        }
    }
}
