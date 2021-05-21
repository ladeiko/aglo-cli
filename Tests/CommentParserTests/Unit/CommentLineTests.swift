//
//  CommentParserTests.swift
//  CommentParser
//
//  Created by Siarhei Ladzeika on 8/16/21.
//

import XCTest
@testable import CommentParser

class CommentLineTests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_001() {
        let lines = CommentLine.commentLines(from: "  hello world  ")
        XCTAssertEqual(lines, [CommentLine(leadingSpaces: "  ", text: "hello world", trailingSpaces: "  ")])
    }

    func test_002() {
        let lines = CommentLine.commentLines(from: "  hello  World  ")
        XCTAssertEqual(lines, [CommentLine(leadingSpaces: "  ", text: "hello  World", trailingSpaces: "  ")])
    }

    func test_003() {
        let text = "  hello world\nhello world2  "
        let lines = CommentLine.commentLines(from: text)
        XCTAssertEqual(lines, [
            CommentLine(leadingSpaces: "  ", text: "hello world", trailingSpaces: "\n"),
            CommentLine(leadingSpaces: "", text: "hello world2", trailingSpaces: "  "),
        ])
    }

    func test_004() {
        let lines = CommentLine.commentLines(from: "  * hello world \n* hello world2  ")
        XCTAssertEqual(lines, [
            CommentLine(leadingSpaces: "  * ", text: "hello world", trailingSpaces: " \n"),
            CommentLine(leadingSpaces: "* ", text: "hello world2", trailingSpaces: "  "),
        ])

        let comment = Comment(lines: lines)
        XCTAssertEqual(comment.text, "hello world hello world2")

        let newComment = comment.updatingText("new text")
        XCTAssertEqual(newComment.lines, [
            CommentLine(leadingSpaces: "  * ", text: "new text", trailingSpaces: " \n"),
        ])
        XCTAssertEqual(newComment.text, "new text")
        XCTAssertEqual(newComment.compose(), "  * new text \n")
    }
}

#if os(Linux)
extension CommentLineTests {
    static var allTests = [
        ("test_001", test_001),
        ("test_002", test_002),
        ("test_003", test_003),
        ("test_004", test_004),
    ]
}
#endif
