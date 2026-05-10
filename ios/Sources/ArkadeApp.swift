import SwiftUI

@main
struct ArkadeApp: App {
    @State private var appManager = AppManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appManager)
        }
    }
}
