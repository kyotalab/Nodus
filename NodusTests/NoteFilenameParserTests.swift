import XCTest
@testable import Nodus

final class NoteFilenameParserTests: XCTestCase {

    func testExtractsTimestampID() {
        let note = Note(
            url: URL(fileURLWithPath: "/tmp/202604271321 My title.md"),
            body: "",
            createdAt: Date(),
            updatedAt: Date()
        )
        XCTAssertEqual(note.timestampID, "202604271321")
    }

    func testExtractsTitleAfterTimestamp() {
        let note = Note(
            url: URL(fileURLWithPath: "/tmp/202604271321 My title.md"),
            body: "",
            createdAt: Date(),
            updatedAt: Date()
        )
        XCTAssertEqual(note.title, "My title")
    }

    func testIDOnlyFilenameHasEmptyTitle() {
        let note = Note(
            url: URL(fileURLWithPath: "/tmp/202604271321.md"),
            body: "",
            createdAt: Date(),
            updatedAt: Date()
        )
        XCTAssertEqual(note.title, "")
    }

    func testTitleWithMultipleSpaces() {
        let note = Note(
            url: URL(fileURLWithPath: "/tmp/202604271321 Long title with spaces.md"),
            body: "",
            createdAt: Date(),
            updatedAt: Date()
        )
        XCTAssertEqual(note.title, "Long title with spaces")
    }

    func testTxtExtensionDisplayName() {
        let filename = "202604271321 My title.txt"
        XCTAssertEqual(NoteFilenameParser.displayName(from: filename), "202604271321 My title")
    }

    func testTxtExtensionTimestampID() {
        let filename = "202604271321.txt"
        XCTAssertEqual(NoteFilenameParser.timestampID(from: filename), "202604271321")
    }

    func testTxtExtensionIsValid() {
        let filename = "202604271321.txt"
        XCTAssertTrue(NoteFilenameParser.isValidNoteFilename(filename))
    }

    func testInvalidFilenameIsNotValid() {
        XCTAssertFalse(NoteFilenameParser.isValidNoteFilename("README.md"))
        XCTAssertFalse(NoteFilenameParser.isValidNoteFilename("202604271321.txt2"))
    }
}
