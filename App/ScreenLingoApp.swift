import SwiftUI

@main
struct ScreenLingoApp: App {
    @StateObject private var session = TranslationSessionController()

    var body: some Scene {
        WindowGroup {
            HomeView(session: session)
        }
    }
}
