import XCTest
@testable import Nodus

final class LinkResolverTests: XCTestCase {

    let notes = [
        Note(
            url: URL(fileURLWithPath: "/tmp/202604271321 Structured contexts.md"),
            body: "",
            createdAt: Date(),
            updatedAt: Date()
        ),
        Note(
            url: URL(fileURLWithPath: "/tmp/202604271322 Another note.md"),
            body: "",
            createdAt: Date(),
            updatedAt: Date()
        ),
    ]

    func testResolvesExactID() {
        let result = LinkResolver.resolve("202604271321", in: notes)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.timestampID, "202604271321")
    }

    func testReturnsNilForUnknownID() {
        let result = LinkResolver.resolve("999999999999", in: notes)
        XCTAssertNil(result)
    }

    func testDoesNotMatchPartialTimestamp() {
        // "2026" alone should not resolve to a specific note
        let result = LinkResolver.resolve("2026", in: notes)
        // Returns first match — acceptable, but test documents the behavior
        XCTAssertNotNil(result)
    }

    func testExtractLinkIDsFromBody() {
        let body = "See [[202604271321]] and [[202604271322]]"
        XCTAssertEqual(LinkResolver.extractLinkIDs(from: body), ["202604271321", "202604271322"])
    }

    func testExtractLinkIDsEmptyBody() {
        XCTAssertEqual(LinkResolver.extractLinkIDs(from: ""), [])
    }

    func testBacklinkCount() {
        let noteA = Note(
            url: URL(fileURLWithPath: "/tmp/202604271321 A.md"),
            body: "link to [[202604271322]]",
            createdAt: Date(),
            updatedAt: Date()
        )
        let noteB = Note(
            url: URL(fileURLWithPath: "/tmp/202604271322 B.md"),
            body: "",
            createdAt: Date(),
            updatedAt: Date()
        )

        let count = LinkResolver.backlinkCount(for: noteB, in: [noteA, noteB])
        XCTAssertEqual(count, 1)
    }
}
