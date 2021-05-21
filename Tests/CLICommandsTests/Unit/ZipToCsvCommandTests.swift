//
//  ZipToCsvCommandTests.swift
//  CLICommandsTests
//
//  Created by Siarhei Ladzeika on 8/8/21.
//

import XCTest
import PathKit
import StringsFileParser
@testable import SwiftCLI
@testable import CLICommands

class ZipToCsvCommandTests: XCTestCase {

    func testGoWithArguments() throws {

        let tmp = try Path.processUniqueTemporary() + UUID().uuidString
        let input = tmp + "input"
        let output = tmp + "output" + "test.csv"

        defer {
            try? tmp.delete()
        }

        let locales: [String] = [
            "ru",
            "en",
        ]

        let filesCount = 3
        let keysCount = 3

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

        let cmd = ZipToCsvCommand()
        let (result, out, err) = runCommand(cmd) { $0.go(with: [cmd.name, input.string, output.string]) }
        XCTAssertEqual(result, 0, "Command should have succeeded")
        XCTAssertEqual(out, "")
        XCTAssertEqual(err, "")

        let resultFile = output
        let content = try resultFile.read(StringsFileParser.StringsFile.defaultEncoding)

        var expectedContent = "KEY," + locales.sorted().joined(separator: ",") + "\n"

        for fileIndex in 0..<filesCount {
            for keyIndex in 0..<keysCount {

                var row = "FILE_\(pad(fileIndex)).\(StringsFileParser.StringsFile.fileExtension):KEY_\(pad(keyIndex))"

                for (localeIndex, locale) in locales.sorted().enumerated() {
                    if localeIndex % 2 == 0 {
                        row += "," + csvEscape("VALUE \"\(locale)\" \(pad(keyIndex))")
                    }
                    else {
                        row += ",VALUE_\(locale)_\(pad(keyIndex))"
                    }
                }

                expectedContent += row + "\n"
            }
        }

        XCTAssertEqual(content, expectedContent)
    }

}

#if os(Linux)
extension ZipToCsvCommandTests {
    static var allTests = [
        ("testGoWithArguments", testGoWithArguments),
    ]
}
#endif
