//
//  LocalizedStringsFileTests.swift
//  StringsFileParser
//
//  Created by Siarhei Ladzeika on 29.07.21.
//

import XCTest
import PathKit
import Utils
@testable import StringsFileParser

class LocalizedStringsFileTests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_001() throws {

        let filename = "Hello.\(StringsFileParser.StringsFile.fileExtension)"
        let tmp = try Path.uniqueTemporary()
        defer { try? tmp.delete() }

        let locales = [
            "en",
            "ru",
        ].map({ Locale(identifier: $0) })

        let content = """
                    "a" = "1";
                    """

        try locales.forEach({ locale in
            try (tmp + (locale.identifier + ".\(LocalizedStringsFile.localeFolderExtension)")).mkpath()
            try (tmp + (locale.identifier + ".\(LocalizedStringsFile.localeFolderExtension)") + filename).write(content)
        })

        let defaultLocale = LocalizedStringsFile.defaultLocale
        let file = try LocalizedStringsFile(path: (tmp + (locales[0].identifier + ".\(LocalizedStringsFile.localeFolderExtension)") + filename), defaultLocale: defaultLocale, locales: nil)
        XCTAssertEqual(Set(file.files.keys), Set(locales))

        file.files.forEach({
            XCTAssertEqual($0.value.string, content)
        })

        // Add locale with empty file
        let newLocale = Locale(identifier: "fr")
        try file.addLocale(newLocale, mode: .createNew(copingContentFromLocale: nil))

        XCTAssertEqual(Set(file.files.keys), Set(locales.appending(newLocale)))
        XCTAssertEqual(file.files[newLocale]!.string, "")

        // Add locale copying content from another localwe
        let nextNewLocale = Locale(identifier: "de")
        try file.addLocale(nextNewLocale, mode: .createNew(copingContentFromLocale: locales.first!))

        XCTAssertEqual(Set(file.files.keys), Set(locales.appending(newLocale).appending(nextNewLocale)))
        XCTAssertEqual(file.files[nextNewLocale]!.string, content)

        // Locale deletion
        try file.removeLocale(newLocale)
        XCTAssertFalse((tmp + (newLocale.identifier + ".\(LocalizedStringsFile.localeFolderExtension)") + filename).exists)
    }

    func test_002() throws {

        let filename = "Hello.\(StringsFileParser.StringsFile.fileExtension)"
        let tmp = try Path.uniqueTemporary()
        defer { try? tmp.delete() }

        let locales = [
            "en",
            "ru",
        ].map({ Locale(identifier: $0) })

        try locales.forEach({ locale in
            try (tmp + (locale.identifier + ".\(LocalizedStringsFile.localeFolderExtension)")).mkpath()
            try (tmp + (locale.identifier + ".\(LocalizedStringsFile.localeFolderExtension)") + filename).write("")
        })

        try (tmp + (locales[0].identifier + ".\(LocalizedStringsFile.localeFolderExtension)") + filename).write("""
                                                                                                                "a" = "1";
                                                                                                                """)

        let defaultLocale = LocalizedStringsFile.defaultLocale
        let file = try LocalizedStringsFile(path: (tmp + (locales[0].identifier + ".\(LocalizedStringsFile.localeFolderExtension)") + filename), defaultLocale: defaultLocale, locales: nil)
        XCTAssertEqual(Set(file.files.keys), Set(locales))

        XCTAssertEqual(file.absentKeys(), [locales[1]: Set([EscapableString(rawString: "a")])])

        try file.addAbsentKeys()

        XCTAssertEqual(file.absentKeys().count, 0)

        let c1: String = try (tmp + (locales[1].identifier + ".\(LocalizedStringsFile.localeFolderExtension)") + filename).read()
        XCTAssertEqual(c1, "")

        try file.save()
        let c2: String = try (tmp + (locales[1].identifier + ".\(LocalizedStringsFile.localeFolderExtension)") + filename).read()
        XCTAssertEqual(c2, """
                        "a" = "\(LocalizedStringsFile.defaultAbsentValue)";\n\n
                        """)
    }

    func test_003() throws {

        let filename = "Hello.\(StringsFileParser.StringsFile.fileExtension)"
        let tmp = try Path.uniqueTemporary()
        defer { try? tmp.delete() }

        let locales = [
            "en",
            "ru",
            "fr",
        ].map({ Locale(identifier: $0) })

        try locales.forEach({ locale in
            try (tmp + (locale.identifier + ".\(LocalizedStringsFile.localeFolderExtension)")).mkpath()
            try (tmp + (locale.identifier + ".\(LocalizedStringsFile.localeFolderExtension)") + filename).write("")
        })

        let defaultLocale = LocalizedStringsFile.defaultLocale
        let sourceLocale = locales[0]
        let destLocale = Set(locales).subtracting(Set([sourceLocale])).first!
        let otherLocale = Set(locales).subtracting(Set([sourceLocale, destLocale])).first!

        try (tmp + (sourceLocale.identifier + ".\(LocalizedStringsFile.localeFolderExtension)") + filename).write("""
                                                                                                                "a" = "1";
                                                                                                                """)

        let file = try LocalizedStringsFile(path: (tmp + (locales[0].identifier + ".\(LocalizedStringsFile.localeFolderExtension)") + filename), defaultLocale: defaultLocale, locales: nil)
        XCTAssertEqual(Set(file.files.keys), Set(locales))

        XCTAssertEqual(try (tmp + (destLocale.identifier + ".\(LocalizedStringsFile.localeFolderExtension)") + filename).read(), "")
        XCTAssertEqual(try (tmp + (otherLocale.identifier + ".\(LocalizedStringsFile.localeFolderExtension)") + filename).read(), "")

        try file.syncKeys(from: sourceLocale, to: Set([destLocale]))

        XCTAssertEqual(try (tmp + (destLocale.identifier + ".\(LocalizedStringsFile.localeFolderExtension)") + filename).read(), "")
        XCTAssertEqual(try (tmp + (otherLocale.identifier + ".\(LocalizedStringsFile.localeFolderExtension)") + filename).read(), "")

        try file.save()
        XCTAssertEqual(try (tmp + (destLocale.identifier + ".\(LocalizedStringsFile.localeFolderExtension)") + filename).read(), """
                        "a" = "\(LocalizedStringsFile.defaultAbsentValue)";\n\n
                        """)
        XCTAssertEqual(try (tmp + (otherLocale.identifier + ".\(LocalizedStringsFile.localeFolderExtension)") + filename).read(), "")
    }

    func test_004() throws {
        let tmp = try Path.uniqueTemporary()
        defer { try? tmp.delete() }

        let locales = [
            "en",
            "ru",
            "fr",
        ]

        func createFile(_ path: Path) throws {
            try path.parent().mkpath()
            try path.write("", encoding: StringsFileParser.StringsFile.defaultEncoding)
        }

        try locales.forEach({ locale in
            try createFile(tmp
                    + "\(locale).\(LocalizedStringsFile.localeFolderExtension)"
                    + "1.\(StringsFile.fileExtension)")
            try createFile(tmp
                    + "\(locale).\(LocalizedStringsFile.localeFolderExtension)"
                    + "2.\(StringsFile.fileExtension)")
        })

        let files = try LocalizedStringsFile.scan(paths: [tmp], locales: nil, filenames: nil)
        XCTAssertEqual(files.count, 2)
        XCTAssertEqual(files[0].filename, "1")
        XCTAssertEqual(files[1].filename, "2")
        XCTAssertEqual(files[0].files.keys.map({ $0.identifier }).sorted(), locales.sorted())
        XCTAssertEqual(files[1].files.keys.map({ $0.identifier }).sorted(), locales.sorted())
    }

    func test_005() throws {
        let tmp = try Path.uniqueTemporary()
        defer { try? tmp.delete() }

        let locales = [
            "en",
            "ru",
            "fr",
        ]

        func createFile(_ path: Path) throws {
            try path.parent().mkpath()
            try path.write("", encoding: StringsFileParser.StringsFile.defaultEncoding)
        }

        try locales.forEach({ locale in
            try createFile(tmp
                    + "\(locale).\(LocalizedStringsFile.localeFolderExtension)"
                    + "1.\(StringsFile.fileExtension)")
            try createFile(tmp
                    + "\(locale).\(LocalizedStringsFile.localeFolderExtension)"
                    + "2.\(StringsFile.fileExtension)")
        })

        let files = try LocalizedStringsFile.scan(paths: [tmp], locales: nil, filenames: ["1"])
        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files[0].filename, "1")
        XCTAssertEqual(files[0].files.keys.map({ $0.identifier }).sorted(), locales.sorted())
    }

    func test_006() throws {
        let tmp = try Path.uniqueTemporary()
        defer { try? tmp.delete() }

        let locales = [
            "en",
            "ru",
            "fr",
        ]

        func createFile(_ path: Path) throws {
            try path.parent().mkpath()
            try path.write("", encoding: StringsFileParser.StringsFile.defaultEncoding)
        }

        try locales.forEach({ locale in
            try createFile(tmp
                    + "\(locale).\(LocalizedStringsFile.localeFolderExtension)"
                    + "1.\(StringsFile.fileExtension)")
            try createFile(tmp
                    + "\(locale).\(LocalizedStringsFile.localeFolderExtension)"
                    + "2.\(StringsFile.fileExtension)")
        })

        let filteredLocale = locales.first!
        let files = try LocalizedStringsFile.scan(paths: [tmp], locales: [Locale(identifier: filteredLocale)], filenames: nil)
        XCTAssertEqual(files.count, 2)
        XCTAssertEqual(files[0].filename, "1")
        XCTAssertEqual(files[1].filename, "2")
        XCTAssertEqual(files[0].files.keys.map({ $0.identifier }).filter({ $0 == filteredLocale }).sorted(), locales.filter({ $0 == filteredLocale }).sorted())
        XCTAssertEqual(files[1].files.keys.map({ $0.identifier }).filter({ $0 == filteredLocale }).sorted(), locales.filter({ $0 == filteredLocale }).sorted())
    }

    func test_007() throws {
        let tmp = try Path.uniqueTemporary()
        defer { try? tmp.delete() }

        let locales = [
            "en",
            "ru",
            "fr",
        ]

        func createFile(_ path: Path) throws {
            try path.parent().mkpath()
            try path.write("", encoding: StringsFileParser.StringsFile.defaultEncoding)
        }


        try locales.forEach({ locale in
            try createFile(tmp
                    + "\(locale).\(LocalizedStringsFile.localeFolderExtension)"
                    + "1.\(StringsFile.fileExtension)")
            try createFile(tmp
                    + "\(locale).\(LocalizedStringsFile.localeFolderExtension)"
                    + "2.\(StringsFile.fileExtension)")
        })

        let targetLocale = locales.first!

        let targetFile = tmp
                + "\(targetLocale).\(LocalizedStringsFile.localeFolderExtension)"
                + "1.\(StringsFile.fileExtension)"

        let files = try LocalizedStringsFile.scan(paths: [targetFile], locales: nil, filenames: nil)
        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files[0].filename, "1")
        XCTAssertEqual(files[0].files.keys.map({ $0.identifier }).sorted(), locales.sorted())
    }
}

#if os(Linux)
extension LocalizedStringsFileTests {
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
