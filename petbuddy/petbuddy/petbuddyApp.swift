import SwiftUI

@main
struct petbuddyApp: App {
    @StateObject private var runtime = PetBuddyRuntime()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(runtime)
        }
        .defaultSize(width: 700, height: 760)
        .windowToolbarStyle(.unified)
    }
}
