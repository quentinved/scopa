import SwiftUI

@main
struct ScopaApp: App {
    /// The audio session is shaped before anything can play: a banner's video, a web view, the
    /// first sound. Until then it is solo ambient, and whatever claimed it first would stop the
    /// music the player came in with. Shaping claims nothing, so nothing is stopped by it.
    init() {
        AudioSession.shape(.game, why: "launch")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                // The table is dark whatever the phone is set to. Glass takes its tone from
                // the colour scheme, so following the system would dim every tint.
                .preferredColorScheme(.dark)
                .onAppear { DebugLaunch.rotateIfRequested() }
        }
    }
}
