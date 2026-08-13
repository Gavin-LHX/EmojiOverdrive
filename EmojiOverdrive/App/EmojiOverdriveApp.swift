import SwiftUI

@main
struct EmojiOverdriveApp: App {
    @StateObject private var experience = ExperienceController()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(experience)
                .preferredColorScheme(.dark)
        }
    }
}

