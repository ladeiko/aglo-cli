//
//  UtilsTests.swift
//  CLICommandsTests
//
//  Created by Siarhei Ladzeika on 7.08.21.
//

import Foundation
import XCTest
import Rollback
import PathKit

class RollbackTests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_001() throws {

        let tmp = try Path.processUniqueTemporary() + UUID().uuidString
        try tmp.mkpath()

        defer {
            try? tmp.delete()
        }

        let file = tmp + "a.txt"

        let value = "A"
        try file.write(value, encoding: .utf8)

        let rollback = Rollback()
        try rollback.protectFile(at: file)

        XCTAssertEqual(try file.read(.utf8), value)
        try file.write(value + value, encoding: .utf8)

        XCTAssertEqual(try file.read(.utf8), value + value)
        try rollback.restore()

        XCTAssertEqual(try file.read(.utf8), value)
    }

    func test_002() throws {

        let tmp = try Path.processUniqueTemporary() + UUID().uuidString
        try tmp.mkpath()

        defer {
            try? tmp.delete()
        }

        let file = tmp + "a.txt"

        let value = "A"
        try file.write(value, encoding: .utf8)

        let rollback = Rollback()
        try rollback.deleteFile(at: file)

        XCTAssertTrue(file.exists)

        try rollback.restore()

        XCTAssertFalse(file.exists)
    }
}

#if os(Linux)
extension RollbackTests {
    static var allTests = [
        ("test_001", test_001),
        ("test_002", test_002),
    ]
}
#endif
