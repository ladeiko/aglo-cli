//
//  RenameKeyCommandTests.swift
//  CLICommands
//
//  Created by Siarhei Ladzeika on 8/5/21.
//

import XCTest
import PathKit
import StringsFileParser
@testable import SwiftCLI
@testable import CLICommands

class RenameKeyCommandTests: XCTestCase {

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
        let keysCount = 3

        var oldName: String!
        var newName: String!

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
                    if oldName == nil {
                        oldName = $0
                        newName = $0 + "_NEWNAME"
                    }
                    let row = """
                                "\($0)" = "\(rows[$0]!)";
                                """
                    fileContent += row + "\n"
                })

                try file.write(fileContent, encoding: StringsFileParser.StringsFile.defaultEncoding)
            }
        }

        let cmd = RenameKeyCommand()
        let (result, out, err) = runCommand(cmd) { $0.go(with: [cmd.name, input.string, oldName, newName]) }
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
                    rows["KEY_\(pad(keyIndex))"] = "VALUE_\(pad(keyIndex))"
                }

                var expectedContent = ""

                let val = rows[oldName]
                rows.removeValue(forKey: oldName)
                rows[newName] = val

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
extension RenameKeyCommandTests {
    static var allTests = [
        ("testGoWithArguments", testGoWithArguments),
    ]
}
#endif
