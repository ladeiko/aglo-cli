//
//  SortKeysCommandTests.swift
//  CLICommandsTests
//
//  Created by Siarhei Ladzeika on 8/3/21.
//

import XCTest
import PathKit
import StringsFileParser
@testable import SwiftCLI
@testable import CLICommands

class SortKeysCommandTests: XCTestCase {

    func testCaseSensitiveSorting() throws {

        let tmp = try Path.processUniqueTemporary() + UUID().uuidString
        let input = tmp + "input"

        defer {
            try? tmp.delete()
        }

        let locales: [String] = [
            "ru",
            "en",
        ]

        let filesCount = 3
        let keysCount = 4

        for locale in locales {
            for fileIndex in 0..<filesCount {
                let folder = input + (locale + "." + StringsFileParser.LocalizedStringsFile.localeFolderExtension)
                let file = folder + ("FILE_\(pad(fileIndex)).\(StringsFileParser.StringsFile.fileExtension)")

                try folder.mkpath()

                var rows: [String: String] = [:]

                for keyIndex in (0..<keysCount).reversed() {
                    rows["KEYA_\(pad(keyIndex))"] = "VALUE_\(pad(keyIndex))"
                    rows["keyb_\(pad(keyIndex))"] = "VALUE_\(pad(keyIndex))"
                }

                var fileContent = ""

                rows.keys.sorted().forEach({
                    let row = """
                                "\($0)" = "\(rows[$0]!)";
                                """
                    fileContent += row + "\n"
                })

                try file.write(fileContent, encoding: StringsFileParser.StringsFile.defaultEncoding)
            }
        }

        let cmd = SortKeysCommand()
        let (result, out, err) = runCommand(cmd) { $0.go(with: [cmd.name, input.string]) }
        XCTAssertEqual(result, 0, "Command should have succeeded")
        XCTAssertEqual(out, "")
        XCTAssertEqual(err, "")

        for locale in locales {

            for fileIndex in 0..<filesCount {
                let folder = input + (locale + "." + StringsFileParser.LocalizedStringsFile.localeFolderExtension)
                let file = folder + ("FILE_\(pad(fileIndex)).\(StringsFileParser.StringsFile.fileExtension)")

                try folder.mkpath()

                var rows: [String: String] = [:]

                for keyIndex in 0..<keysCount {
                    rows["KEYA_\(pad(keyIndex))"] = "VALUE_\(pad(keyIndex))"
                    rows["keyb_\(pad(keyIndex))"] = "VALUE_\(pad(keyIndex))"
                }

                var expectedContent = ""

                rows.keys.sorted().forEach({
                    let row = """
                                "\($0)" = "\(rows[$0]!)";
                                """
                    expectedContent += row + "\n"
                })

                let content = try file.read(StringsFileParser.StringsFile.defaultEncoding)
                XCTAssertEqual(content, expectedContent)
            }
        }
    }

    func testCaseInsensitiveSorting() throws {

        let tmp = try Path.processUniqueTemporary() + UUID().uuidString
        let input = tmp + "input"

        defer {
            try? tmp.delete()
        }

        let locales: [String] = [
            "ru",
            "en",
        ]

        let filesCount = 3
        let keysCount = 4

        for locale in locales {
            for fileIndex in 0..<filesCount {
                let folder = input + (locale + "." + StringsFileParser.LocalizedStringsFile.localeFolderExtension)
                let file = folder + ("FILE_\(pad(fileIndex)).\(StringsFileParser.StringsFile.fileExtension)")

                try folder.mkpath()

                var rows: [String: String] = [:]

                for keyIndex in (0..<keysCount).reversed() {
                    rows["keyb_\(pad(keyIndex))"] = "VALUE_\(pad(keyIndex))"
                    rows["KEYA_\(pad(keyIndex))"] = "VALUE_\(pad(keyIndex))"
                }

                var fileContent = ""

                rows.keys.sorted(by: { $0.lowercased() < $1.lowercased() }).forEach({
                    let row = """
                                "\($0)" = "\(rows[$0]!)";
                                """
                    fileContent += row + "\n"
                })

                try file.write(fileContent, encoding: StringsFileParser.StringsFile.defaultEncoding)
            }
        }

        let cmd = SortKeysCommand()
        let (result, out, err) = runCommand(cmd) { $0.go(with: [cmd.name, "--case-insensitive", input.string]) }
        XCTAssertEqual(result, 0, "Command should have succeeded")
        XCTAssertEqual(out, "")
        XCTAssertEqual(err, "")

        for locale in locales {

            for fileIndex in 0..<filesCount {
                let folder = input + (locale + "." + StringsFileParser.LocalizedStringsFile.localeFolderExtension)
                let file = folder + ("FILE_\(pad(fileIndex)).\(StringsFileParser.StringsFile.fileExtension)")

                try folder.mkpath()

                var rows: [String: String] = [:]

                for keyIndex in 0..<keysCount {
                    rows["KEYA_\(pad(keyIndex))"] = "VALUE_\(pad(keyIndex))"
                    rows["keyb_\(pad(keyIndex))"] = "VALUE_\(pad(keyIndex))"
                }

                var expectedContent = ""

                rows.keys.sorted().forEach({
                    let row = """
                                "\($0)" = "\(rows[$0]!)";
                                """
                    expectedContent += row + "\n"
                })

                let content = try file.read(StringsFileParser.StringsFile.defaultEncoding)
                XCTAssertEqual(content, expectedContent)
            }
        }
    }
}

#if os(Linux)
extension SortKeysCommandTests {
    static var allTests = [
        ("testCaseSensitiveSorting", testCaseSensitiveSorting),
        ("testCaseInsensitiveSorting", testCaseInsensitiveSorting),
    ]
}
#endif
