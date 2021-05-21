//
//  TokenParserTests.swift
//  UtilsTests
//
//  Created by Siarhei Ladzeika
//

import XCTest
import Utils

class SplitIntoLinesTests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_001() {
        let lines = "1 2 3".splitIntoLines(limit: 1)
        XCTAssertEqual(lines, ["1", "2", "3"])
    }

    func test_002() {
        let lines = "11 222 3333".splitIntoLines(limit: 1)
        XCTAssertEqual(lines, ["11", "222", "3333"])
    }

    func test_003() {
        let lines = "11 222 3333".splitIntoLines(limit: 3)
        XCTAssertEqual(lines, ["11", "222", "3333"])
    }

    func test_004() {
        let lines = "11 222 3333".splitIntoLines(limit: 4)
        XCTAssertEqual(lines, ["11 222", "3333"])
    }

    func test_005() {
        let lines = "11,222,3333".splitIntoLines(limit: 0)
        XCTAssertEqual(lines, ["11,", "222,", "3333"])
    }
}

#if os(Linux)
extension SplitIntoLinesTests {
    static var allTests = [
        ("test_001", test_001),
        ("test_002", test_002),
        ("test_003", test_003),
        ("test_004", test_004),
        ("test_005", test_005),
    ]
}
#endif
