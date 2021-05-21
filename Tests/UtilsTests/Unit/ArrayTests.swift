//
//  UtilsTests.swift
//  StringsFileTests
//
//  Created by Siarhei Ladzeika on 29.07.21.
//

import XCTest
import Utils

class ArrayTests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_001() {
        XCTAssertEqual([0, 1, 2].removingLastElements(0), [0, 1, 2])
        XCTAssertEqual([0, 1, 2].removingLastElements(1), [0, 1])
        XCTAssertEqual([0, 1, 2].removingLastElements(2), [0])
    }

    func test_002() {
        XCTAssertEqual([0, 1, 2, 2].lastElements(where: { $0 == 2 }), [2, 2])
        XCTAssertEqual([0, 1, 2, 2].lastElements(where: { $0 == 1 }), [])
    }
}

#if os(Linux)
extension ArrayTests {
    static var allTests = [
        ("test_001", test_001),
        ("test_002", test_002),
    ]
}
#endif
