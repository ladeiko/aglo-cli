//
//  SetValueCommandTests.swift
//  CLICommandsTests
//
//  Created by Siarhei Ladzeika on 8/22/21.
//

import XCTest
import PathKit
import Utils
import StringsFileParser
@testable import SwiftCLI
@testable import CLICommands

class SetValueCommandTests: XCTestCase {

    func testSetPlainValue() throws {

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
        let keysCount = 3
        var keyToSet: EscapableString!

        for (localeIndex, locale) in locales.sorted().enumerated() {
            for fileIndex in 0..<filesCount {
                let folder = input + (locale + "." + StringsFileParser.LocalizedStringsFile.localeFolderExtension)
                let file = folder + ("FILE_\(pad(fileIndex)).\(StringsFileParser.StringsFile.fileExtension)")

                try folder.mkpath()

                var rows: [String: String] = [:]

                for keyIndex in 0..<keysCount {
                    if localeIndex % 2 == 0 {
                        rows["KEY_\(pad(keyIndex))"] = "VALUE \\\"\(locale)\\\" \(pad(keyIndex))"
                    }
                    else {
                        rows["KEY_\(pad(keyIndex))"] = "VALUE_\(locale)_\(pad(keyIndex))"
                    }
                }

                if keyToSet == nil {
                    keyToSet = try EscapableString(escapedString: rows.first!.key)
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

        let newValue = EscapableString(rawString: "weyrty8wqgfiobasdjvbsasigoG^T)YO*DYG*YDGbwofyqbwocvqwbvo")
        let beforeFiles = try LocalizedStringsFile.scan(paths: [input])
        XCTAssertEqual(beforeFiles.count, filesCount)
        beforeFiles.forEach({
            XCTAssertEqual($0.files.keys.map({ $0.identifier }).sorted(), locales.sorted())
            $0.files.forEach({
                XCTAssertNotNil($0.value.valueForKey(keyToSet))
                XCTAssertNotEqual($0.value.valueForKey(keyToSet)!, newValue)
            })
        })

        let cmd = SetValueCommand()
        let (result, out, err) = runCommand(cmd) { $0.go(with: [cmd.name, "--unescape", input.string, keyToSet.escapedString, newValue.escapedString]) }
        XCTAssertEqual(result, 0, "Command should have succeeded")
        XCTAssertEqual(out, "")
        XCTAssertEqual(err, "")

        let afterFiles = try LocalizedStringsFile.scan(paths: [input])
        XCTAssertEqual(afterFiles.count, filesCount)
        afterFiles.forEach({
            XCTAssertEqual($0.files.keys.map({ $0.identifier }).sorted(), locales.sorted())
            $0.files.forEach({
                XCTAssertEqual($0.value.valueForKey(keyToSet), newValue)
            })
        })
    }

    func testSetValueWithLineBreak() throws {

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
        let keysCount = 3
        var keyToSet: EscapableString!

        for (localeIndex, locale) in locales.sorted().enumerated() {
            for fileIndex in 0..<filesCount {
                let folder = input + (locale + "." + StringsFileParser.LocalizedStringsFile.localeFolderExtension)
                let file = folder + ("FILE_\(pad(fileIndex)).\(StringsFileParser.StringsFile.fileExtension)")

                try folder.mkpath()

                var rows: [String: String] = [:]

                for keyIndex in 0..<keysCount {
                    if localeIndex % 2 == 0 {
                        rows["KEY_\(pad(keyIndex))"] = "VALUE \\\"\(locale)\\\" \(pad(keyIndex))"
                    }
                    else {
                        rows["KEY_\(pad(keyIndex))"] = "VALUE_\(locale)_\(pad(keyIndex))"
                    }
                }

                if keyToSet == nil {
                    keyToSet = try EscapableString(escapedString: rows.first!.key)
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

        let newValue = EscapableString(rawString: "weyrty8wqgfiobasdjvbsasigoG\n^T)YO*DYG*YDGbwofyqbwocvqwbvo")
        let beforeFiles = try LocalizedStringsFile.scan(paths: [input])
        XCTAssertEqual(beforeFiles.count, filesCount)
        beforeFiles.forEach({
            XCTAssertEqual($0.files.keys.map({ $0.identifier }).sorted(), locales.sorted())
            $0.files.forEach({
                XCTAssertNotNil($0.value.valueForKey(keyToSet))
                XCTAssertNotEqual($0.value.valueForKey(keyToSet)!, newValue)
            })
        })

        let cmd = SetValueCommand()
        let (result, out, err) = runCommand(cmd) { $0.go(with: [cmd.name, "--unescape", input.string, keyToSet.escapedString, newValue.escapedString]) }
        XCTAssertEqual(result, 0, "Command should have succeeded")
        XCTAssertEqual(out, "")
        XCTAssertEqual(err, "")

        let afterFiles = try LocalizedStringsFile.scan(paths: [input])
        XCTAssertEqual(afterFiles.count, filesCount)
        afterFiles.forEach({
            XCTAssertEqual($0.files.keys.map({ $0.identifier }).sorted(), locales.sorted())
            $0.files.forEach({
                XCTAssertEqual($0.value.valueForKey(keyToSet), newValue)
            })
        })
    }

    func testDeleteValue() throws {

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
        let keysCount = 3
        var keyToSet: EscapableString!

        for (localeIndex, locale) in locales.sorted().enumerated() {
            for fileIndex in 0..<filesCount {
                let folder = input + (locale + "." + StringsFileParser.LocalizedStringsFile.localeFolderExtension)
                let file = folder + ("FILE_\(pad(fileIndex)).\(StringsFileParser.StringsFile.fileExtension)")

                try folder.mkpath()

                var rows: [String: String] = [:]

                for keyIndex in 0..<keysCount {
                    if localeIndex % 2 == 0 {
                        rows["KEY_\(pad(keyIndex))"] = "VALUE \\\"\(locale)\\\" \(pad(keyIndex))"
                    }
                    else {
                        rows["KEY_\(pad(keyIndex))"] = "VALUE_\(locale)_\(pad(keyIndex))"
                    }
                }

                if keyToSet == nil {
                    keyToSet = try EscapableString(escapedString: rows.first!.key)
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

        let beforeFiles = try LocalizedStringsFile.scan(paths: [input])
        XCTAssertEqual(beforeFiles.count, filesCount)
        beforeFiles.forEach({
            XCTAssertEqual($0.files.keys.map({ $0.identifier }).sorted(), locales.sorted())
            $0.files.forEach({
                XCTAssertNotNil($0.value.valueForKey(keyToSet))
            })
        })

        let cmd = SetValueCommand()
        let (result, out, err) = runCommand(cmd) { $0.go(with: [cmd.name, "--unescape", input.string, keyToSet.escapedString]) }
        XCTAssertEqual(result, 0, "Command should have succeeded")
        XCTAssertEqual(out, "")
        XCTAssertEqual(err, "")

        let afterFiles = try LocalizedStringsFile.scan(paths: [input])
        XCTAssertEqual(afterFiles.count, filesCount)
        afterFiles.forEach({
            XCTAssertEqual($0.files.keys.map({ $0.identifier }).sorted(), locales.sorted())
            $0.files.forEach({
                XCTAssertNil($0.value.valueForKey(keyToSet))
            })
        })
    }
}

#if os(Linux)
extension SetValueCommandTests {
    static var allTests = [
        ("testSetPlainValue", testSetPlainValue),
        ("testSetValueWithLineBreak", testSetValueWithLineBreak),
        ("testDeleteValue", testDeleteValue),
    ]
}
#endif
