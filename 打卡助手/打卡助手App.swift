import SwiftUI

@main
struct DakazhushouApp: App {
    @StateObject private var store = HealthStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(.light)
        }
    }
}
