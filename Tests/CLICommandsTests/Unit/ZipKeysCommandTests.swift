//
//  UtilsTests.swift
//  CLICommandsTests
//
//  Created by Siarhei Ladzeika
//

import XCTest
import PathKit
import StringsFileParser
@testable import SwiftCLI
@testable import CLICommands

class ZipKeysCommandTests: XCTestCase {

    func testGoWithArguments() throws {

        let tmp = try Path.processUniqueTemporary() + UUID().uuidString
        let input = tmp + "input"
        let output = tmp + "output"

        defer {
            try? tmp.delete()
        }

        let locales: [String] = [
            "ru",
            "en",
        ]

        let filesCount = 3
        let keysCount = 3

        for locale in locales {
            for fileIndex in 0..<filesCount {
                let folder = input + (locale + "." + StringsFileParser.LocalizedStringsFile.localeFolderExtension)
                let file = folder + ("FILE_\(pad(fileIndex)).\(StringsFileParser.StringsFile.fileExtension)")

                try folder.mkpath()

                var rows: [String: String] = [:]

                for keyIndex in 0..<keysCount {
                    rows["KEY_\(pad(keyIndex))"] = "VALUE_\(pad(keyIndex))"
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

        let cmd = ZipKeysCommand()
        let (result, _, _) = runCommand(cmd) { $0.go(with: [cmd.name, "--sort", input.string, output.string]) }
        XCTAssertEqual(result, 0, "Command should have succeeded")
//        XCTAssertEqual(out, "")
//        XCTAssertEqual(err, "")

        for locale in locales {

            let resultFile = output
                + (locale + "." + StringsFileParser.LocalizedStringsFile.localeFolderExtension)
                + (ZipKeysCommand.defaultOutput + "." + StringsFileParser.StringsFile.fileExtension)

            let content = try resultFile.read(StringsFileParser.StringsFile.defaultEncoding)

            var expectedContent = ""

            for fileIndex in 0..<filesCount {
                for keyIndex in 0..<keysCount {
                    let row = """
                                "FILE_\(pad(fileIndex)).\(StringsFileParser.StringsFile.fileExtension):KEY_\(pad(keyIndex))" = "VALUE_\(pad(keyIndex))";
                                """

                    expectedContent += row + (0..<StringsFileParser.LogicalParser.newEntriesSuffixNewLinesCount).map({ _ in "\n" })
                }
            }

            XCTAssertEqual(content, expectedContent)
        }
    }

}

#if os(Linux)
extension ZipKeysCommandTests {
    static var allTests = [
        ("testGoWithArguments", testGoWithArguments),
    ]
}
#endif
