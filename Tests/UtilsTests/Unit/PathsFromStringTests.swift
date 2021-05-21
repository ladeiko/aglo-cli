//
//  PathsFromStringTests.swift
//  UtilsTests
//
//  Created by Sergey Ladeiko on 26.08.21.
//

import XCTest
import Utils
import PathKit

class PathsFromStringTests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_001() {
        XCTAssertEqual("/root/a,/root/b".toPaths(), [Path("/root/a"), Path("/root/b")])
    }

    func test_002() {
        XCTAssertEqual("/root/a|/root/b".toPaths(), [Path("/root/a"), Path("/root/b")])
    }
}

#if os(Linux)
extension PathsFromStringTests {
    static var allTests = [
        ("test_001", test_001),
        ("test_002", test_002),
    ]
}
#endif
