import XCTest
@testable import RelationOS

final class ContactMemoryExtractorTests: XCTestCase {

    func testEmptyNotesReturnsExplicitFallback() async {
        let contact = Contact(name: "Ada", notes: "   ")
        let memory = await ContactMemoryExtractor.shared.extract(contact: contact)
        XCTAssertFalse(memory.usedOnDeviceModel)
        XCTAssertEqual(memory.facts, [])
        XCTAssertNotNil(memory.fallbackReason)
        XCTAssertTrue(memory.brief.contains("Ada"))
    }

    func testHeuristicBriefUsesLeadingSentences() {
        let contact = Contact(
            name: "Ada",
            notes: "Met at WWDC. Works on compilers. Kids play soccer. Follow up about lunch."
        )
        let memory = ContactMemoryExtractor.shared.heuristicExtract(
            contact: contact,
            interactions: [],
            reason: "test fallback"
        )
        XCTAssertFalse(memory.usedOnDeviceModel)
        XCTAssertEqual(memory.fallbackReason, "test fallback")
        XCTAssertTrue(memory.brief.contains("WWDC"))
        XCTAssertTrue(memory.brief.contains("compilers"))
        XCTAssertTrue(memory.facts.contains(where: { $0.contains("soccer") }))
        XCTAssertTrue(memory.followUps.contains(where: { $0.lowercased().contains("follow") }))
    }

    func testHeuristicSuggestsReachOutWhenContactIsCold() {
        let stale = Date().addingTimeInterval(-30 * 86400)
        let contact = Contact(name: "Grace", notes: "College roommate.", lastInteractedAt: stale)
        let memory = ContactMemoryExtractor.shared.heuristicExtract(
            contact: contact,
            interactions: [],
            reason: "test fallback"
        )
        XCTAssertTrue(memory.followUps.contains(where: { $0.contains("30 days") }))
    }

    func testAvailabilityDegradesWithoutCrashing() {
        // On this host Foundation Models is typically unavailable. The
        // public probe must still return a concrete status — never crash.
        switch ContactMemoryExtractor.status {
        case .available:
            XCTAssertTrue(ContactMemoryExtractor.isAvailable)
        case .unavailable(let reason):
            XCTAssertFalse(reason.isEmpty)
            XCTAssertFalse(ContactMemoryExtractor.isAvailable)
        }
    }
}
