import SwiftUI

@main
struct MixLayerApp: App {
    @StateObject private var player = AudioPlayerModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(player)
                .task {
                    await player.bootstrapLibrary()
                    if ProcessInfo.processInfo.arguments.contains("--autoplay-sample") {
                        try? await Task.sleep(for: .milliseconds(600))
                        player.playSample()
                    }
                }
        }
    }
}
