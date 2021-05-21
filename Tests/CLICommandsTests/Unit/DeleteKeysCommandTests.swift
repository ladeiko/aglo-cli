//
//  DeleteKeysCommandTests.swift
//  CLICommands
//
//  Created by Siarhei Ladzeika on 3.08.21.
//

import XCTest
import PathKit
import StringsFileParser
@testable import SwiftCLI
@testable import CLICommands

class DeleteKeysCommandTests: XCTestCase {

    func testGoWithArguments() throws {

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

        let indexesToDelete = (0..<keysCount).enumerated().filter({ $0.element % 2 != 0 }).map({ $0.element })
        let cmd = DeleteKeysCommand()
        let keysCmd: [String] = indexesToDelete.map({ ["KEY_\(pad($0))"] }).flatMap({ $0 })
        let (result, out, err) = runCommand(cmd) { $0.go(with: [cmd.name]
                                                            .appending(contentsOf: [input.string])
                                                            .appending(contentsOf: keysCmd)) }
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
                    if indexesToDelete.contains(keyIndex) {
                        continue
                    }
                    rows["KEY_\(pad(keyIndex))"] = "VALUE_\(pad(keyIndex))"
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
extension DeleteKeysCommandTests {
    static var allTests = [
        ("testGoWithArguments", testGoWithArguments),
    ]
}
#endif
