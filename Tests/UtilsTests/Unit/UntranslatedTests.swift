//
//  UntranslatedTests.swift
//  UtilsTests
//
//  Created by Siarhei Ladzeika on 8/16/21.
//

import Foundation
import XCTest
import Utils

class UntranslatedTests: XCTestCase {

    func test_001() {
        XCTAssertTrue(EscapableString(rawString: "\(DefaultUntranslatedPrefixMarker)").isUntranslated(nil))
        XCTAssertTrue(EscapableString(rawString: "\(DefaultUntranslatedPrefixMarker)Hello.strings").isUntranslated(nil))
        XCTAssertFalse(EscapableString(rawString: "H\(DefaultUntranslatedPrefixMarker)ello.strings").isUntranslated(nil))
        XCTAssertFalse(EscapableString(rawString: "Hello.strings\(DefaultUntranslatedPrefixMarker)").isUntranslated(nil))
        XCTAssertFalse(EscapableString(rawString: "").isUntranslated(nil))
    }

    func test_002() {
        let proposedPrefix = "$$"
        XCTAssertFalse(EscapableString(rawString: "\(DefaultUntranslatedPrefixMarker)").isUntranslated(proposedPrefix))
        XCTAssertFalse(EscapableString(rawString: "\(DefaultUntranslatedPrefixMarker)Hello.strings").isUntranslated(proposedPrefix))
        XCTAssertTrue(EscapableString(rawString: "\(proposedPrefix)").isUntranslated(proposedPrefix))
        XCTAssertTrue(EscapableString(rawString: "\(proposedPrefix)Hello.strings").isUntranslated(proposedPrefix))
        XCTAssertFalse(EscapableString(rawString: "H\(DefaultUntranslatedPrefixMarker)ello.strings").isUntranslated(proposedPrefix))
        XCTAssertFalse(EscapableString(rawString: "Hello.strings\(DefaultUntranslatedPrefixMarker)").isUntranslated(proposedPrefix))
        XCTAssertFalse(EscapableString(rawString: "").isUntranslated(proposedPrefix))
    }
}

#if os(Linux)
extension UntranslatedTests {
    static var allTests = [
        ("test_001", test_001),
        ("test_002", test_002),
    ]
}
#endif
