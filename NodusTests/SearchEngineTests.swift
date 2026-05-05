import XCTest
@testable import Nodus

final class SearchEngineTests: XCTestCase {

    let notes = [
        Note(
            url: URL(fileURLWithPath: "/tmp/202604271321 Swift basics.md"),
            body: "SwiftUI tutorial",
            createdAt: Date(),
            updatedAt: Date()
        ),
        Note(
            url: URL(fileURLWithPath: "/tmp/202604271322 Python notes.md"),
            body: "Python tutorial",
            createdAt: Date(),
            updatedAt: Date()
        ),
        Note(
            url: URL(fileURLWithPath: "/tmp/202604271323 Swift advanced.md"),
            body: "Protocols and generics",
            createdAt: Date(),
            updatedAt: Date()
        ),
    ]

    func testANDSearchRequiresAllTerms() {
        let results = SearchEngine.search("swift tutorial", in: notes)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.timestampID, "202604271321")
    }

    func testSingleTermMatchesMultiple() {
        let results = SearchEngine.search("swift", in: notes)
        XCTAssertEqual(results.count, 2)
    }

    func testEmptyQueryReturnsAll() {
        let results = SearchEngine.search("", in: notes)
        XCTAssertEqual(results.count, 3)
    }

    func testCaseInsensitive() {
        let results = SearchEngine.search("SWIFT", in: notes)
        XCTAssertEqual(results.count, 2)
    }

    func testNoMatchReturnsEmpty() {
        let results = SearchEngine.search("kotlin", in: notes)
        XCTAssertTrue(results.isEmpty)
    }

    func testMultipleSpacesInQuery() {
        let results = SearchEngine.search("swift  tutorial", in: notes)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.timestampID, "202604271321")
    }

    func testSearchInBody() {
        let results = SearchEngine.search("generics", in: notes)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.timestampID, "202604271323")
    }

    func testSearchInFilename() {
        let results = SearchEngine.search("python", in: notes)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.timestampID, "202604271322")
    }
}
