import XCTest
@testable import EmojiOverdrive

final class SafetyPolicyTests: XCTestCase {
    func testSettingsClampBPMAndIntensity() {
        var settings = ExperienceSettings()
        settings.bpm = 999
        settings.intensity = 9
        settings.orbitDensity = -4

        XCTAssertEqual(settings.clampedBPM, SafetyPolicy.maximumBPM)
        XCTAssertEqual(settings.clampedIntensity, 1)
        XCTAssertEqual(settings.clampedDensity, 0.25)
    }

    func testDimFlashingLightsRequiresReducedExperience() {
        let overrides = SafetyOverrides(
            reduceMotion: false,
            dimFlashingLights: true,
            reduceTransparency: false
        )

        XCTAssertTrue(overrides.requiresReducedExperience)
        XCTAssertLessThanOrEqual(SafetyPolicy.dimFlashingIntensityCap, 0.34)
    }

    func testTorchAndSessionCapsRemainConservative() {
        XCTAssertLessThanOrEqual(SafetyPolicy.maximumTorchLevel, 0.12)
        XCTAssertLessThanOrEqual(SafetyPolicy.maximumSessionSeconds, 45)
        XCTAssertLessThanOrEqual(SafetyPolicy.maximumHapticIntensity, 0.72)
    }

    func testAbsoluteSessionDeadline() {
        XCTAssertEqual(SafetyPolicy.remainingSeconds(atElapsed: 0), 45)
        XCTAssertEqual(SafetyPolicy.remainingSeconds(atElapsed: 44.9), 1)
        XCTAssertEqual(SafetyPolicy.remainingSeconds(atElapsed: 45), 0)
        XCTAssertFalse(SafetyPolicy.hasReachedSessionLimit(elapsed: 44.999))
        XCTAssertTrue(SafetyPolicy.hasReachedSessionLimit(elapsed: 45))
    }

    func testEmojiLibraryHasEnoughStableOrbitEntries() {
        XCTAssertGreaterThanOrEqual(EmojiLibrary.all.count, 6)
        XCTAssertTrue(EmojiLibrary.all.contains("🤯"))
        XCTAssertTrue(EmojiLibrary.all.contains("🌀"))
    }
}
