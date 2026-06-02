import Foundation
import SwiftUI

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @AppStorage("migrationThreshold") var migrationThreshold: Int = 3
    @AppStorage("themePreference") var themePreference: String = "system"

    var preferredColorScheme: ColorScheme? {
        switch themePreference {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    #if os(macOS)
    @AppStorage("gitRepoBookmark") private var gitRepoBookmarkData: Data = Data()

    var gitRepoURL: URL? {
        get {
            guard !gitRepoBookmarkData.isEmpty else { return nil }
            var isStale = false
            return try? URL(
                resolvingBookmarkData: gitRepoBookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        }
        set {
            if let url = newValue,
               let data = try? url.bookmarkData(options: .withSecurityScope) {
                gitRepoBookmarkData = data
            } else {
                gitRepoBookmarkData = Data()
            }
        }
    }
    #else
    var gitRepoURL: URL? {
        get { nil }
        set { }
    }
    #endif
}
