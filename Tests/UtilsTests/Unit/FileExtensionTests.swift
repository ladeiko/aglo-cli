//
//  UtilsTests.swift
//  CLICommandsTests
//
//  Created by Siarhei Ladzeika on 7.08.21.
//

import Foundation
import XCTest
import Utils

class FileExtensionTests: XCTestCase {

    func test_001() {
        XCTAssertEqual("Hello".removingFileExtension(), "Hello")
        XCTAssertEqual("Hello.strings".removingFileExtension(), "Hello")
        XCTAssertEqual("Hello.World.strings".removingFileExtension(), "Hello.World")
    }

    func test_002() {
        XCTAssertEqual("Hello.strings".fileExtension(), "strings")
        XCTAssertEqual("Hello.".fileExtension(), "")
        XCTAssertNil("Hello".fileExtension())
    }
}

#if os(Linux)
extension FileExtensionTests {
    static var allTests = [
        ("test_001", test_001),
        ("test_002", test_002),
    ]
}
#endif
