import XCTest

#if canImport(sitescopeCore)
    @testable import sitescopeCore
#else
    @testable import sitescope
#endif

final class AppearancePreferenceTests: XCTestCase {
    func testStoredRawValuesStayStable() {
        XCTAssertEqual(AppearancePreference.allCases.map(\.rawValue), ["system", "light", "dark"])
        XCTAssertEqual(AppearancePreference.storageKey, "appearance")
    }

    func testMissingOrUnknownValueFollowsSystem() {
        XCTAssertEqual(AppearancePreference(stored: nil), .system)
        XCTAssertEqual(AppearancePreference(stored: "sepia"), .system)
        XCTAssertEqual(AppearancePreference(stored: "dark"), .dark)
    }

    func testLabelsMatchSettingsPicker() {
        XCTAssertEqual(AppearancePreference.allCases.map(\.label), ["System", "Light", "Dark"])
    }
}
