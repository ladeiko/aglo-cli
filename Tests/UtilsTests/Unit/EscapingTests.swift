//
//  EscapingTests.swift
//  UtilsTests
//
//  Created by Siarhei Ladzeika on 8/16/21.
//

import XCTest
@testable import Utils

class EscapingTests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_001() {
        XCTAssertEqual(escapeKeyValueString("""
                                "
                                1
                                """), "\\\"\\n1")
    }

    func test_002() throws {
        XCTAssertEqual(try unescapeKeyValueString("""
                                \"
                                """), "\"")
        XCTAssertEqual(try unescapeKeyValueString("""
                                \\u0041
                                """), "A")
        XCTAssertEqual(try unescapeKeyValueString("""
                                \\U00000041
                                """), "A")

        let bytes: [UInt8] = [0x5c, 0x20] //  => "\ "
        let data = Data(bytes: bytes, count: bytes.count)
        let val = String(data: data, encoding: .utf8)!
        XCTAssertThrowsError(try unescapeKeyValueString(val))
    }

    func test_003() {
        XCTAssertEqual(escapeKeyValueString("""
                                \\
                                """), "\\\\")
    }

    func test_004() throws {
        XCTAssertEqual(String(describing: try EscapableString(escapedString: "\\u0041")), "<EscapableString: rawString = 'A', escapedString = '\\u0041'>")
        XCTAssertEqual((try EscapableString(escapedString: "\\u0041")).escapedString, "\\u0041")
        XCTAssertEqual((try EscapableString(escapedString: "\\u0041")).rawString, "A")
        XCTAssertNotEqual(try EscapableString(escapedString: "\\u0041"), EscapableString(rawString: "A"))
    }

    func test_005() {
        XCTAssertEqual([
            EscapableString(rawString: "1"),
            EscapableString(rawString: "2"),
        ].replacing("12", with: "3456"), [
            EscapableString(rawString: "34"),
            EscapableString(rawString: "56"),
        ])

        XCTAssertEqual([
            EscapableString(rawString: "1"),
            EscapableString(rawString: "2"),
        ].replacing("12", with: "34567"), [
            EscapableString(rawString: "34"),
            EscapableString(rawString: "567"),
        ])

        XCTAssertEqual([
            EscapableString(rawString: "1"),
            EscapableString(rawString: "2"),
        ].replacing("12", with: "345678"), [
            EscapableString(rawString: "345"),
            EscapableString(rawString: "678"),
        ])

        XCTAssertEqual([
            EscapableString(rawString: "12"),
            EscapableString(rawString: "34"),
        ].replacing("1234", with: "56"), [
            EscapableString(rawString: "5"),
            EscapableString(rawString: "6"),
        ])

        XCTAssertEqual([
            EscapableString(rawString: "12"),
            EscapableString(rawString: "34"),
        ].replacing("1234", with: "567"), [
            EscapableString(rawString: "5"),
            EscapableString(rawString: "67"),
        ])

        XCTAssertEqual([
            EscapableString(rawString: "12"),
            EscapableString(rawString: "34"),
        ].replacing("1234", with: ""), [
            EscapableString(rawString: ""),
            EscapableString(rawString: ""),
        ])

        XCTAssertEqual([
            EscapableString(rawString: "123456"),
            EscapableString(rawString: "345678"),
        ].replacing("63", with: ""), [
            EscapableString(rawString: "12345"),
            EscapableString(rawString: "45678"),
        ])
    }

    func test_006() {

        XCTAssertTrue([
            EscapableString(rawString: "\(EscapableString.tagNamePrefix)hello=\(EscapableString.tagValueDelimiter)123\(EscapableString.tagValueDelimiter)"),
            EscapableString(rawString: "45"),
        ].containsTag("hello"))

        XCTAssertFalse([
            EscapableString(rawString: "\(EscapableString.tagNamePrefix)hello=\(EscapableString.tagValueDelimiter)123\(EscapableString.tagValueDelimiter)"),
            EscapableString(rawString: "45"),
        ].containsTag("hello1"))

        XCTAssertEqual([
            EscapableString(rawString: "\(EscapableString.tagNamePrefix)hello=\(EscapableString.tagValueDelimiter)123\(EscapableString.tagValueDelimiter)"),
            EscapableString(rawString: "45"),
        ].valueForTag("hello"), "123")

        XCTAssertEqual([
            EscapableString(rawString: "\(EscapableString.tagNamePrefix)hello=\(EscapableString.tagValueDelimiter)123\(EscapableString.tagValueDelimiter)"),
            EscapableString(rawString: "45"),
        ].deletingTag("hello"), [
            EscapableString(rawString: ""),
            EscapableString(rawString: "45"),
        ])

        XCTAssertEqual([
            EscapableString(rawString: "\(EscapableString.tagNamePrefix)hello=\(EscapableString.tagValueDelimiter)123\(EscapableString.tagValueDelimiter)"),
            EscapableString(rawString: "45"),
        ].updatingTag("hello", to: "NEW"), [
            EscapableString(rawString: "\(EscapableString.tagNamePrefix)hello=\(EscapableString.tagValueDelimiter)NEW\(EscapableString.tagValueDelimiter)"),
            EscapableString(rawString: "45"),
        ])

        XCTAssertEqual([
            EscapableString(rawString: "\(EscapableString.tagNamePrefix)hello1=\(EscapableString.tagValueDelimiter)123\(EscapableString.tagValueDelimiter)"),
            EscapableString(rawString: "45"),
        ].updatingTag("hello", to: "NEW"), [
            EscapableString(rawString: "\(EscapableString.tagNamePrefix)hello=\(EscapableString.tagValueDelimiter)NEW\(EscapableString.tagValueDelimiter) @@hello1=\(EscapableString.tagValueDelimiter)123\(EscapableString.tagValueDelimiter)"),
            EscapableString(rawString: "45"),
        ])

        XCTAssertEqual([
            EscapableString(rawString: "\(EscapableString.tagNamePrefix)hello=\(EscapableString.tagValueDelimiter)123\(EscapableString.tagValueDelimiter)"),
        ].updatingTag("hello", to: "NEW"), [
            EscapableString(rawString: "\(EscapableString.tagNamePrefix)hello=\(EscapableString.tagValueDelimiter)NEW\(EscapableString.tagValueDelimiter)"),
        ])

        XCTAssertEqual([
            EscapableString(rawString: ""),
        ].updatingTag("hello", to: "NEW"), [
            EscapableString(rawString: "@@hello=\(EscapableString.tagValueDelimiter)NEW\(EscapableString.tagValueDelimiter)"),
        ])
    }

    func test_007() throws {
        XCTAssertEqual(try EscapableString(rawString: "hello:world").parseAsStringsFilenameAndKey().filename, "hello")
        XCTAssertEqual(try EscapableString(rawString: "hello.strings:world").parseAsStringsFilenameAndKey().filename, "hello")
        XCTAssertEqual(try EscapableString(rawString: "hello.strings:tewiuwoie").parseAsStringsFilenameAndKey().key, "tewiuwoie")
        XCTAssertThrowsError(try EscapableString(rawString: "hello").parseAsStringsFilenameAndKey().filename)
        XCTAssertThrowsError(try EscapableString(rawString: "hello:").parseAsStringsFilenameAndKey().filename)
        XCTAssertThrowsError(try EscapableString(rawString: "").parseAsStringsFilenameAndKey().filename)
        XCTAssertThrowsError(try EscapableString(rawString: ":").parseAsStringsFilenameAndKey().filename)
        XCTAssertEqual(try EscapableString(rawString: "hello: ").parseAsStringsFilenameAndKey().filename, "hello")
        XCTAssertEqual(try EscapableString(rawString: "hello: ").parseAsStringsFilenameAndKey().key, " ")
    }
}

#if os(Linux)
extension EscapingTests {
    static var allTests = [
        ("test_001", test_001),
        ("test_002", test_002),
        ("test_003", test_003),
        ("test_004", test_004),
        ("test_005", test_005),
        ("test_006", test_006),
        ("test_007", test_007),
    ]
}
#endif
