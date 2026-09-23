import SwiftUI

@main
struct ScopaApp: App {
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
