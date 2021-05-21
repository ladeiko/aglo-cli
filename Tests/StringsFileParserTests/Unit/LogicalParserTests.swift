//
//  LogicalParserTests.swift
//  StringsFileTests
//
//  Created by Siarhei Ladzeika on 29.07.21.
//

import XCTest
import PathKit
import Utils
@testable import StringsFileParser

class LogicalParserTests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_001() throws {
        let parser = LogicalParser()
        try parser.parse(string: "")
        XCTAssertTrue(parser.allEntries.isEmpty)
    }

    func test_002() throws {
        let parser = LogicalParser()
        try parser.parse(string: "//")
        XCTAssertTrue(parser.allEntries.isEmpty)
    }

    func test_003() throws {
        let parser = LogicalParser()
        XCTAssertThrowsError(try parser.parse(string: """
                                                    "a"="1"
                                                    """))
    }

    func test_004() throws {
        let parser = LogicalParser()
        XCTAssertThrowsError(try parser.parse(string: """
                                                    "a"=="1";
                                                    """))
    }

    func test_005() throws {
        let parser = LogicalParser()
        XCTAssertThrowsError(try parser.parse(string: """
                                                    "a"=;"1";
                                                    """))
    }

    func test_006() throws {
        let parser = LogicalParser()
        XCTAssertThrowsError(try parser.parse(string: """
                                                    "a"="1;
                                                    """))
    }

    func test_007() throws {
        let parser = LogicalParser()
        try parser.parse(string: """
                                "a"="1";
                                """)
        XCTAssertEqual(parser.allEntries.count, 1)
        XCTAssertTrue(parser.entries[0].commentEntities.isEmpty)
        XCTAssertEqual(parser.entries[0].keyEntity.innerValue, EscapableString(rawString: "a"))
        XCTAssertEqual(parser.entries[0].valueEntity.innerValue, EscapableString(rawString: "1"))
        XCTAssertEqual(parser.entries[0].equationEntity.innerValue, EscapableString(rawString: "="))
        XCTAssertEqual(parser.entries[0].semicommaEntity.innerValue, EscapableString(rawString: ";"))
    }

    func test_008() throws {
        let parser = LogicalParser()
        try parser.parse(string: """
                                //hello
                                "a"="1";
                                """)
        XCTAssertEqual(parser.allEntries.count, 1)
        XCTAssertEqual(parser.entries[0].commentEntities.count, 1)
        XCTAssertEqual(parser.entries[0].commentEntities.first!.innerValues, [EscapableString(rawString: "hello")])
        XCTAssertEqual(parser.entries[0].keyEntity.innerValue, EscapableString(rawString: "a"))
        XCTAssertEqual(parser.entries[0].valueEntity.innerValue, EscapableString(rawString: "1"))
        XCTAssertEqual(parser.entries[0].equationEntity.innerValue, EscapableString(rawString: "="))
        XCTAssertEqual(parser.entries[0].semicommaEntity.innerValue, EscapableString(rawString: ";"))
    }

    func test_009() throws {
        let parser = LogicalParser()
        try parser.parse(string: """
                                /* hello
                                */
                                "a"="1";
                                """)
        XCTAssertEqual(parser.allEntries.count, 1)
        XCTAssertEqual(parser.entries[0].commentEntities.count, 1)
        XCTAssertEqual(parser.entries[0].commentEntities.first!.innerValues, [EscapableString(rawString: " hello\n")])
        XCTAssertEqual(parser.entries[0].keyEntity.innerValue, EscapableString(rawString: "a"))
        XCTAssertEqual(parser.entries[0].valueEntity.innerValue, EscapableString(rawString: "1"))
        XCTAssertEqual(parser.entries[0].equationEntity.innerValue, EscapableString(rawString: "="))
        XCTAssertEqual(parser.entries[0].semicommaEntity.innerValue, EscapableString(rawString: ";"))
    }

    func test_010() throws {
        let parser = LogicalParser()
        try parser.parse(string: """
                                /* hello
                                */
                                "a"="1";

                                // hello2
                                "b"="2";
                                """)
        XCTAssertEqual(parser.allEntries.count, 2)
        XCTAssertEqual(parser.entries[0].commentEntities.count, 1)
        XCTAssertEqual(parser.entries[0].commentEntities.first!.innerValues, [EscapableString(rawString: " hello\n")])
        XCTAssertEqual(parser.entries[0].keyEntity.innerValue, EscapableString(rawString: "a"))
        XCTAssertEqual(parser.entries[0].valueEntity.innerValue, EscapableString(rawString: "1"))
        XCTAssertEqual(parser.entries[0].equationEntity.innerValue, EscapableString(rawString: "="))
        XCTAssertEqual(parser.entries[0].semicommaEntity.innerValue, EscapableString(rawString: ";"))

        XCTAssertEqual(parser.entries[1].commentEntities.count, 1)
        XCTAssertEqual(parser.entries[1].commentEntities.first!.innerValues, [EscapableString(rawString: " hello2")])
        XCTAssertEqual(parser.entries[1].keyEntity.innerValue, EscapableString(rawString: "b"))
        XCTAssertEqual(parser.entries[1].valueEntity.innerValue, EscapableString(rawString: "2"))
        XCTAssertEqual(parser.entries[1].equationEntity.innerValue, EscapableString(rawString: "="))
        XCTAssertEqual(parser.entries[1].semicommaEntity.innerValue, EscapableString(rawString: ";"))
    }

    func test_011() throws {
        let value = """
                    /* Header
                    */

                    /* hello
                    */
                    "a"="1";

                    // hello2
                    "b" ="2";
                    """
        let parser = LogicalParser()
        try parser.parse(string: value)
        XCTAssertEqual(parser.allEntries.count, 4)
        XCTAssertEqual(parser.entries[0].commentEntities.count, 1)
        XCTAssertEqual(parser.entries[0].commentEntities.first!.innerValues, [EscapableString(rawString: " hello\n")])
        XCTAssertEqual(parser.entries[0].keyEntity.innerValue, EscapableString(rawString: "a"))
        XCTAssertEqual(parser.entries[0].valueEntity.innerValue, EscapableString(rawString: "1"))
        XCTAssertEqual(parser.entries[0].equationEntity.innerValue, EscapableString(rawString: "="))
        XCTAssertEqual(parser.entries[0].semicommaEntity.innerValue, EscapableString(rawString: ";"))

        XCTAssertEqual(parser.entries[1].commentEntities.count, 1)
        XCTAssertEqual(parser.entries[1].commentEntities.first!.innerValues, [EscapableString(rawString: " hello2")])
        XCTAssertEqual(parser.entries[1].keyEntity.innerValue, EscapableString(rawString: "b"))
        XCTAssertEqual(parser.entries[1].valueEntity.innerValue, EscapableString(rawString: "2"))
        XCTAssertEqual(parser.entries[1].equationEntity.innerValue, EscapableString(rawString: "="))
        XCTAssertEqual(parser.entries[1].semicommaEntity.innerValue, EscapableString(rawString: ";"))

        XCTAssertNotNil(parser.headerEntry)
        XCTAssertEqual(parser.headerEntry!.commentEntities.map({ $0.innerValues }), [[EscapableString(rawString: " Header\n")]])
        XCTAssertEqual(parser.compose(), value)
    }

    func test_012() throws {
        let value = """
                    /* Header
                    */

                    /* prehello
                    */

                    /* hello
                    */
                    "a"="1";

                    // prehello2

                    // hello2
                    "b" ="2";
                    """
        let parser = LogicalParser()
        try parser.parse(string: value)
        XCTAssertEqual(parser.allEntries.count, 6)

        XCTAssertNotNil(parser.headerEntry)
        XCTAssertEqual(parser.headerEntry!.commentEntities.count, 1)
        XCTAssertEqual(parser.headerEntry!.commentEntities[0].innerValues, [EscapableString(rawString: " Header\n")])

        XCTAssertEqual(parser.entries.count, 2)

        XCTAssertEqual(parser.entries[0].commentEntities.count, 1)
        XCTAssertEqual(parser.entries[0].commentEntities[0].innerValues, [EscapableString(rawString: " hello\n")])
        XCTAssertEqual(parser.entries[0].keyEntity.innerValue, EscapableString(rawString: "a"))
        XCTAssertEqual(parser.entries[0].valueEntity.innerValue, EscapableString(rawString: "1"))
        XCTAssertEqual(parser.entries[0].equationEntity.innerValue, EscapableString(rawString: "="))
        XCTAssertEqual(parser.entries[0].semicommaEntity.innerValue, EscapableString(rawString: ";"))

        XCTAssertEqual(parser.entries[1].commentEntities.count, 1)
        XCTAssertEqual(parser.entries[1].commentEntities[0].innerValues, [EscapableString(rawString: " hello2")])
        XCTAssertEqual(parser.entries[1].keyEntity.innerValue, EscapableString(rawString: "b"))
        XCTAssertEqual(parser.entries[1].valueEntity.innerValue, EscapableString(rawString: "2"))
        XCTAssertEqual(parser.entries[1].equationEntity.innerValue, EscapableString(rawString: "="))
        XCTAssertEqual(parser.entries[1].semicommaEntity.innerValue, EscapableString(rawString: ";"))

        XCTAssertEqual(parser.compose(), value)
    }

    func test_013() throws {
        let parser = LogicalParser()
        try parser.parse(string: """
                                            /* Header
                                            */

                                            /* prehello
                                            */

                                            /* hello
                                            */
                                            "a"="1";

                                            // prehello2

                                            // hello2
                                            "b" ="2";
                                            """)
        XCTAssertEqual(parser.allEntries.count, 6)
        XCTAssertEqual(parser.entries[0].commentEntities.count, 1)
        XCTAssertEqual(parser.entries[0].commentEntities[0].innerValues, [EscapableString(rawString: " hello\n")])
        XCTAssertEqual(parser.entries[0].keyEntity.innerValue, EscapableString(rawString: "a"))
        XCTAssertEqual(parser.entries[0].valueEntity.innerValue, EscapableString(rawString: "1"))
        XCTAssertEqual(parser.entries[0].equationEntity.innerValue, EscapableString(rawString: "="))
        XCTAssertEqual(parser.entries[0].semicommaEntity.innerValue, EscapableString(rawString: ";"))

        XCTAssertEqual(parser.entries[1].commentEntities.count, 1)
        XCTAssertEqual(parser.entries[1].commentEntities[0].innerValues, [EscapableString(rawString: " hello2")])
        XCTAssertEqual(parser.entries[1].keyEntity.innerValue, EscapableString(rawString: "b"))
        XCTAssertEqual(parser.entries[1].valueEntity.innerValue, EscapableString(rawString: "2"))
        XCTAssertEqual(parser.entries[1].equationEntity.innerValue, EscapableString(rawString: "="))
        XCTAssertEqual(parser.entries[1].semicommaEntity.innerValue, EscapableString(rawString: ";"))

        try parser.setValue(EscapableString(rawString: "newValue"), forKey: EscapableString(rawString: "a"))

        XCTAssertEqual(parser.allEntries.count, 6)
        XCTAssertEqual(parser.entries[0].commentEntities.count, 1)
        XCTAssertEqual(parser.entries[0].commentEntities[0].innerValues, [EscapableString(rawString: " hello\n")])
        XCTAssertEqual(parser.entries[0].keyEntity.innerValue, EscapableString(rawString: "a"))
        XCTAssertEqual(parser.entries[0].valueEntity.innerValue, EscapableString(rawString: "newValue"))
        XCTAssertEqual(parser.entries[0].equationEntity.innerValue, EscapableString(rawString: "="))
        XCTAssertEqual(parser.entries[0].semicommaEntity.innerValue, EscapableString(rawString: ";"))

        XCTAssertEqual(parser.entries[1].commentEntities.count, 1)
        XCTAssertEqual(parser.entries[1].commentEntities[0].innerValues, [EscapableString(rawString: " hello2")])
        XCTAssertEqual(parser.entries[1].commentEntities[0].values, ["// hello2"])
        XCTAssertEqual(parser.entries[1].keyEntity.innerValue, EscapableString(rawString: "b"))
        XCTAssertEqual(parser.entries[1].valueEntity.innerValue, EscapableString(rawString: "2"))
        XCTAssertEqual(parser.entries[1].equationEntity.innerValue, EscapableString(rawString: "="))
        XCTAssertEqual(parser.entries[1].semicommaEntity.innerValue, EscapableString(rawString: ";"))

        XCTAssertEqual(parser.keys.count, 2)
        XCTAssertEqual(parser.keys.sorted(), [EscapableString(rawString: "a"), EscapableString(rawString: "b")])

        try parser.renameKey(EscapableString(rawString: "a"), to: EscapableString(rawString: "c"))

        XCTAssertEqual(parser.keys.count, 2)
        XCTAssertEqual(parser.keys.sorted(), [EscapableString(rawString: "b"), EscapableString(rawString: "c")])

        try parser.removeValueForKey(EscapableString(rawString: "c"))

        XCTAssertEqual(parser.keys.count, 1)
        XCTAssertEqual(parser.keys.sorted(), [EscapableString(rawString: "b")])

        XCTAssertEqual(parser.allEntries.count, 5)
        XCTAssertEqual(parser.entries.count, 1)
        XCTAssertEqual(parser.entries[0].commentEntities.count, 1)
        XCTAssertEqual(parser.entries[0].commentEntities[0].innerValues, [EscapableString(rawString: " hello2")])
        XCTAssertEqual(parser.entries[0].keyEntity.innerValue, EscapableString(rawString: "b"))
        XCTAssertEqual(parser.entries[0].valueEntity.innerValue, EscapableString(rawString: "2"))
        XCTAssertEqual(parser.entries[0].equationEntity.innerValue, EscapableString(rawString: "="))
        XCTAssertEqual(parser.entries[0].semicommaEntity.innerValue, EscapableString(rawString: ";"))

        try parser.setValue(EscapableString(rawString: "newValue"), forKey: EscapableString(rawString: "b"))

        XCTAssertEqual(parser.allEntries.count, 5)
        XCTAssertEqual(parser.entries[0].commentEntities.count, 1)
        XCTAssertEqual(parser.entries[0].commentEntities[0].innerValues, [EscapableString(rawString: " hello2")])
        XCTAssertEqual(parser.entries[0].keyEntity.innerValue, EscapableString(rawString: "b"))
        XCTAssertEqual(parser.entries[0].valueEntity.innerValue, EscapableString(rawString: "newValue"))
        XCTAssertEqual(parser.entries[0].equationEntity.innerValue, EscapableString(rawString: "="))
        XCTAssertEqual(parser.entries[0].semicommaEntity.innerValue, EscapableString(rawString: ";"))
    }

    func test_014() throws {
        let parser = LogicalParser()
        try parser.parse(string: """
                                            """)
        XCTAssertEqual(parser.allEntries.count, 0)

        try parser.setValue(EscapableString(rawString: "1"), forKey: EscapableString(rawString: "a"))
        try parser.setValue(EscapableString(rawString: "2"), forKey: EscapableString(rawString: "b"))

        XCTAssertEqual(parser.compose(), """
                                        "a" = "1";\n
                                        "b" = "2";\n\n
                                        """)
    }

    func test_015() throws {
        let parser = LogicalParser()
        try [

            """
            /*
              InfoPlist.strings
              LocalizationTutorialApp

              Created by Hello World on 2016/07/25.
              Copyright © 2016 Mega Fake. All rights reserved.
            */
            "CFBundleDisplayName" = "MyApp";
            "NSHumanReadableCopyright" = "2019 Mega Fake. All rights reserved.";
            """,

            """
            "NO_INTERNET_CONNECTION_TITLE" = "No Internet Сonnection";

            "NO_INTERNET_CONNECTION" = "Check your device settings and try again.";
            """,

            """

            /* Shown whe there is no concrete problem description */
            "UNKNOWN_TITLE" = "An Error Occured";

            """,

        ].forEach({
            try parser.parse(string: $0)
            XCTAssertEqual($0, parser.compose())
        })
    }

    func test_016() throws {
        let parser = LogicalParser()
        try parser.parse(string: """

                                /* Shown whe there is no concrete problem description */
                                "UNKNOWN_TITLE" = "An Error Occured";

                                """)

        try parser.setValue(EscapableString(rawString: "What is this?"), forKey: EscapableString(rawString: "UNKNOWN_TITLE"))

        XCTAssertEqual(parser.compose(), """

                                /* Shown whe there is no concrete problem description */
                                "UNKNOWN_TITLE" = "What is this?";

                                """)
    }

    func test_017() throws {
        let parser = LogicalParser()
        try parser.parse(string: """

                                /* Shown whe there is no concrete problem description */
                                "UNKNOWN_TITLE" = "\\u0041";

                                """)

        XCTAssertEqual(parser.valueForKey(EscapableString(rawString: "UNKNOWN_TITLE")), try EscapableString(escapedString: "\\u0041"))
        XCTAssertNotEqual(parser.valueForKey(EscapableString(rawString: "UNKNOWN_TITLE")), EscapableString(rawString: "A"))

        try parser.setValue(EscapableString(rawString: "What is this?"), forKey: EscapableString(rawString: "UNKNOWN_TITLE"))

        XCTAssertEqual(parser.compose(), """

                                /* Shown whe there is no concrete problem description */
                                "UNKNOWN_TITLE" = "What is this?";

                                """)
    }

    func test_018() throws {
        let parser = LogicalParser()
        try parser.parse(string: "")
        XCTAssertEqual(parser.allEntries.count, 0)

        try parser.setValue(EscapableString(rawString: "\u{0041}"), forKey: EscapableString(rawString: "a"))

        XCTAssertEqual(parser.compose(), """
                                        "a" = "A";\((0..<LogicalParser.newEntriesSuffixNewLinesCount).map({ _ in "\n" }).joined())
                                        """)

        try parser.setValue(EscapableString(rawString: "\u{0041}"), forKey: EscapableString(rawString: "b"))

        XCTAssertEqual(parser.compose(), """
                                        "a" = "A";\((0..<LogicalParser.newEntriesSuffixNewLinesCount).map({ _ in "\n" }).joined())"b" = "A";\((0..<LogicalParser.newEntriesSuffixNewLinesCount).map({ _ in "\n" }).joined())
                                        """)
    }

    func test_019() throws {
        let parser = LogicalParser()
        try parser.parse(string: """
                                "b" = "2";
                                "a" = "1";\n
                                """)
        try parser.sort()

        XCTAssertEqual(parser.compose(), """
                                        "a" = "1";
                                        "b" = "2";\n
                                        """)
    }

    func test_020() throws {
        let parser = LogicalParser()
        try parser.parse(string: """
                                "b" = "2";
                                "a" = "1";
                                """)
        try parser.sort()

        XCTAssertEqual(parser.compose(), """
                                        "a" = "1";
                                        "b" = "2";
                                        """)
    }

    func test_021() throws {
        let parser = LogicalParser()
        try parser.parse(string: """
                                // Comment B
                                "b" = "2";
                                // Comment A
                                "a" = "1";
                                """)
        try parser.sort()

        XCTAssertEqual(parser.compose(), """
                                        // Comment A
                                        "a" = "1";
                                        // Comment B
                                        "b" = "2";
                                        """)
    }

    func test_022() throws {
        let parser = LogicalParser()
        try parser.parse(string: """
                                /* Comment B
                                */
                                "b" = "2";

                                /* Comment A
                                */
                                "a" = "1";
                                """)
        try parser.sort()

        XCTAssertEqual(parser.compose(), """
                                        /* Comment A
                                        */
                                        "a" = "1";

                                        /* Comment B
                                        */
                                        "b" = "2";
                                        """)
    }

    func test_023() throws {
        let parser = LogicalParser()
        try parser.parse(string: """
                                "a\\nb" = "1\\n2";
                                """)
        XCTAssertEqual(parser.compose(), """
                                        "a\\nb" = "1\\n2";
                                        """)
    }

    func test_024() throws {
        let parser = LogicalParser()
        try parser.parse(string: """
                                /* hello.strings
                                */
                                "a"="1";
                                """)
        XCTAssertEqual(parser.allEntries.count, 2)
        XCTAssertNotNil(parser.headerEntry)
        XCTAssertEqual(parser.headerEntry!.commentEntities.count, 1)
        XCTAssertEqual(parser.headerEntry!.commentEntities.first!.innerValues, [EscapableString(rawString: " hello.strings\n")])
        XCTAssertNotNil(parser.headerEntry!.spaceEntity)
        XCTAssertEqual(parser.headerEntry!.spaceEntity!.innerValue, EscapableString(rawString: "\n"))
        XCTAssertEqual(parser.entries[0].commentEntities.count, 0)
        XCTAssertEqual(parser.entries[0].keyEntity.innerValue, EscapableString(rawString: "a"))
        XCTAssertEqual(parser.entries[0].valueEntity.innerValue, EscapableString(rawString: "1"))
        XCTAssertEqual(parser.entries[0].equationEntity.innerValue, EscapableString(rawString: "="))
        XCTAssertEqual(parser.entries[0].semicommaEntity.innerValue, EscapableString(rawString: ";"))
    }

    func test_025() throws {
        let parser = LogicalParser()
        try parser.parse(string: """
                                /* hello.strings
                                */

                                "a"="1";
                                """)
        XCTAssertEqual(parser.allEntries.count, 2)
        XCTAssertNotNil(parser.headerEntry)
        XCTAssertEqual(parser.headerEntry!.commentEntities.count, 1)
        XCTAssertEqual(parser.headerEntry!.commentEntities.first!.innerValues, [EscapableString(rawString: " hello.strings\n")])
        XCTAssertNotNil(parser.headerEntry!.spaceEntity)
        XCTAssertEqual(parser.headerEntry!.spaceEntity!.innerValue, EscapableString(rawString: "\n\n"))
        XCTAssertEqual(parser.entries[0].commentEntities.count, 0)
        XCTAssertEqual(parser.entries[0].keyEntity.innerValue, EscapableString(rawString: "a"))
        XCTAssertEqual(parser.entries[0].valueEntity.innerValue, EscapableString(rawString: "1"))
        XCTAssertEqual(parser.entries[0].equationEntity.innerValue, EscapableString(rawString: "="))
        XCTAssertEqual(parser.entries[0].semicommaEntity.innerValue, EscapableString(rawString: ";"))
    }
}

#if os(Linux)
extension LogicalParserTests {
    static var allTests = [
        ("test_001", test_001),
        ("test_002", test_002),
        ("test_003", test_003),
        ("test_004", test_004),
        ("test_005", test_005),
        ("test_006", test_006),
        ("test_007", test_007),
        ("test_008", test_008),
        ("test_009", test_009),
        ("test_010", test_010),
        ("test_011", test_011),
        ("test_012", test_012),
        ("test_013", test_013),
        ("test_014", test_014),
        ("test_015", test_015),
        ("test_016", test_016),
        ("test_017", test_017),
        ("test_018", test_018),
        ("test_019", test_019),
        ("test_020", test_020),
        ("test_021", test_021),
        ("test_022", test_022),
        ("test_023", test_023),
        ("test_024", test_024),
        ("test_025", test_025),
    ]
}
#endif
