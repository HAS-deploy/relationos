import XCTest
@testable import RelationOS

final class IntroTrialClockTests: XCTestCase {
    private let installAtKey = "relationos.intro_trial.install_at"
    private let consumedKey = "relationos.intro_trial.consumed"
    private var defaults: UserDefaults { ContactsStore.appGroupDefaults() }

    override func setUp() {
        super.setUp()
        defaults.removeObject(forKey: installAtKey)
        defaults.removeObject(forKey: consumedKey)
    }

    override func tearDown() {
        defaults.removeObject(forKey: installAtKey)
        defaults.removeObject(forKey: consumedKey)
        super.tearDown()
    }

    func testLengthIsFourteenDays() {
        XCTAssertEqual(IntroTrialClock.length, 14 * 24 * 60 * 60)
    }

    func testFreshStampShowsFourteenDaysRemaining() {
        let clock = IntroTrialClock(defaults: defaults)
        let now = Date()
        clock.recordInstallIfNeeded(now: now)
        XCTAssertTrue(clock.isWithinTrial(now: now))
        XCTAssertEqual(clock.daysRemaining(now: now), 14)
    }

    func testDaysRemainingRoundsUpAndExpiresAtFourteen() {
        let clock = IntroTrialClock(defaults: defaults)
        let now = Date()
        clock.recordInstallIfNeeded(now: now)

        XCTAssertEqual(clock.daysRemaining(now: now.addingTimeInterval(13 * 86400 + 60)), 1)
        XCTAssertTrue(clock.isWithinTrial(now: now.addingTimeInterval(14 * 86400 - 1)))
        XCTAssertFalse(clock.isWithinTrial(now: now.addingTimeInterval(14 * 86400)))
        XCTAssertEqual(clock.daysRemaining(now: now.addingTimeInterval(14 * 86400)), 0)
    }

    func testConsumeEndsTrialImmediately() {
        let clock = IntroTrialClock(defaults: defaults)
        clock.recordInstallIfNeeded()
        XCTAssertTrue(clock.isWithinTrial())
        clock.consume()
        XCTAssertFalse(clock.isWithinTrial())
        XCTAssertEqual(clock.daysRemaining(), 0)
    }

    func testRecordInstallDoesNotOverwriteExistingStamp() {
        let clock = IntroTrialClock(defaults: defaults)
        let first = Date(timeIntervalSince1970: 1_700_000_000)
        clock.recordInstallIfNeeded(now: first)
        let again = clock.recordInstallIfNeeded(now: Date())
        XCTAssertEqual(again, first)
    }
}
