import SwiftUI
import SwiftData

@main
struct CognoteApp: App {
    private let container = Persistence.makeContainer()

    init() {
        Appearance.apply()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}

struct RootView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @AppStorage(AppTheme.storageKey) private var themeRaw = AppTheme.auto.rawValue

    var body: some View {
        Group {
            if hasOnboarded {
                HomeView()
            } else {
                OnboardingView { hasOnboarded = true }
            }
        }
        .tint(Palette.accent)
        .preferredColorScheme((AppTheme(rawValue: themeRaw) ?? .auto).colorScheme)
        // Palette colours read the theme when they resolve, so rebuild the tree on change.
        .id(themeRaw)
    }
}
