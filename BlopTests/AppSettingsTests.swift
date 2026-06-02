import Testing
import Foundation
import SwiftUI
@testable import Blop

@Suite("AppSettings")
struct AppSettingsTests {

    @Test("preferredColorScheme returns .light for 'light' preference")
    func lightScheme() {
        let settings = AppSettings()
        settings.themePreference = "light"
        #expect(settings.preferredColorScheme == .light)
        UserDefaults.standard.removeObject(forKey: "themePreference")
    }

    @Test("preferredColorScheme returns .dark for 'dark' preference")
    func darkScheme() {
        let settings = AppSettings()
        settings.themePreference = "dark"
        #expect(settings.preferredColorScheme == .dark)
        UserDefaults.standard.removeObject(forKey: "themePreference")
    }

    @Test("preferredColorScheme returns nil for 'system' preference")
    func systemScheme() {
        let settings = AppSettings()
        settings.themePreference = "system"
        #expect(settings.preferredColorScheme == nil)
        UserDefaults.standard.removeObject(forKey: "themePreference")
    }

    @Test("preferredColorScheme returns nil for unrecognised preference string")
    func unknownScheme() {
        let settings = AppSettings()
        settings.themePreference = "auto"
        #expect(settings.preferredColorScheme == nil)
        UserDefaults.standard.removeObject(forKey: "themePreference")
    }

    @Test("migrationThreshold defaults to 3 when no value is stored")
    func migrationThresholdDefault() {
        UserDefaults.standard.removeObject(forKey: "migrationThreshold")
        let settings = AppSettings()
        #expect(settings.migrationThreshold == 3)
    }
}
