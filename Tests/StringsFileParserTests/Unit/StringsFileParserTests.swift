//
//  StringsFileParserTests.swift
//  StringsFileParserTests
//
//  Created by Sergey Ladeiko on 7.09.21.
//

import XCTest
import PathKit
@testable import Utils
import TokenParser
@testable import StringsFileParser

class StringsFileParserTests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_001() throws {

        let tmp = try Path.uniqueTemporary()
        defer { try? tmp.delete() }

        let input = tmp + "input.\(StringsFile.fileExtension)"
        let output = tmp + "output.\(StringsFile.fileExtension)"

        try input.write("/* just comment */\n\"A\" = \"1\";", encoding: StringsFile.defaultEncoding)

        try output.write("\"A\" = \"1\";", encoding: StringsFile.defaultEncoding)

        let source = try StringsFile(path: input)
        let destination = try StringsFile(path: output)

        try source.copyComment(fromKey: EscapableString(rawString: "A"), toFile: destination)

        XCTAssertEqual(try output.read(StringsFile.defaultEncoding), "\"A\" = \"1\";")

        try destination.save()

        XCTAssertEqual(try output.read(StringsFile.defaultEncoding), "/* just comment */\n\"A\" = \"1\";")

    }

    func test_002() throws {

        let tmp = try Path.uniqueTemporary()
        defer { try? tmp.delete() }

        let input = tmp + "input.\(StringsFile.fileExtension)"
        let output = tmp + "output.\(StringsFile.fileExtension)"

        try input.write("/* just comment */\n\"A\" = \"1\";", encoding: StringsFile.defaultEncoding)

        try output.write("\n\"A\" = \"1\";", encoding: StringsFile.defaultEncoding)

        let source = try StringsFile(path: input)
        let destination = try StringsFile(path: output)

        try source.copyComment(fromKey: EscapableString(rawString: "A"), toFile: destination)

        XCTAssertEqual(try output.read(StringsFile.defaultEncoding), "\n\"A\" = \"1\";")

        try destination.save()

        XCTAssertEqual(try output.read(StringsFile.defaultEncoding), "\n/* just comment */\n\"A\" = \"1\";")

    }

    func test_003() throws {

        let tmp = try Path.uniqueTemporary()
        defer { try? tmp.delete() }

        let input = tmp + "input.\(StringsFile.fileExtension)"
        let output = tmp + "output.\(StringsFile.fileExtension)"

        try input.write("/* just comment */\n\"A\" = \"1\";", encoding: StringsFile.defaultEncoding)

        try output.write("/* just comment X */\n\"A\" = \"1\";", encoding: StringsFile.defaultEncoding)

        let source = try StringsFile(path: input)
        let destination = try StringsFile(path: output)

        try source.copyComment(fromKey: EscapableString(rawString: "A"), toFile: destination)

        XCTAssertEqual(try output.read(StringsFile.defaultEncoding), "/* just comment X */\n\"A\" = \"1\";")

        try destination.save()

        XCTAssertEqual(try output.read(StringsFile.defaultEncoding), "/* just comment */\n\"A\" = \"1\";")

    }

    func test_004() throws {

        let tmp = try Path.uniqueTemporary()
        defer { try? tmp.delete() }

        let input = tmp + "input.\(StringsFile.fileExtension)"
        let output = tmp + "output.\(StringsFile.fileExtension)"

        try input.write("// just comment\n\"A\" = \"1\";", encoding: StringsFile.defaultEncoding)

        try output.write("// just comment X\n\"A\" = \"1\";", encoding: StringsFile.defaultEncoding)

        let source = try StringsFile(path: input)
        let destination = try StringsFile(path: output)

        try source.copyComment(fromKey: EscapableString(rawString: "A"), toFile: destination)

        XCTAssertEqual(try output.read(StringsFile.defaultEncoding), "// just comment X\n\"A\" = \"1\";")

        try destination.save()

        XCTAssertEqual(try output.read(StringsFile.defaultEncoding), "// just comment\n\"A\" = \"1\";")

    }

    func test_005() {

        let tokens = [
            Token.init(type: .singleLineComment, mode: .escapingComment, prefix: "//",
                       innerValue: .init(rawString: "Hello \(EscapableString.tagNamePrefix)Tag=\(EscapableString.tagValueDelimiter)Some Value\(EscapableString.tagValueDelimiter)"), suffix: ""),
            Token.init(type: .multiLineComment, mode: .escapingComment, prefix: "/*",
                       innerValue: .init(rawString: "Hello \(EscapableString.tagNamePrefix)Tag2=\(EscapableString.tagValueDelimiter)Some2 Value\(EscapableString.tagValueDelimiter)"), suffix: "*/"),
        ]

        let entity = TextCommentEntity(tokens: tokens)
        XCTAssertEqual(entity.valueForTag(for: "Tag"), EscapableString(rawString: "Some Value"))
        XCTAssertEqual(entity.valueForTag(for: "Tag2"), EscapableString(rawString: "Some2 Value"))
    }
}


#if os(Linux)
extension StringsFileParserTests {
    static var allTests = [
        ("test_001", test_001),
        ("test_002", test_002),
        ("test_003", test_003),
        ("test_004", test_004),
        ("test_005", test_005),
    ]
}
#endif
