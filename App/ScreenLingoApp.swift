import SwiftUI

@main
struct ScreenLingoApp: App {
    @StateObject private var session = TranslationSessionController()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            HomeView(session: session)
                .onChange(of: scenePhase) { phase in
                    if phase == .background {
                        session.handleAppBackgrounded()
                    }
                }
        }
    }
}
