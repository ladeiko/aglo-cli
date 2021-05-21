//
//  TokenParserTests.swift
//  TokenParserTests
//
//  Created by Siarhei Ladzeika
//

import XCTest
import TokenParser
import Utils

class TokenParserTests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_001() throws {
        let tokens = try TokenParser.parse("")
        XCTAssertTrue(tokens.isEmpty)
    }

    func test_002() throws {
        let value = "   "
        let tokens = try TokenParser.parse(value)
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens.first!.type, .spaces)
        XCTAssertEqual(tokens.first!.value, value)
        XCTAssertEqual(tokens.first!.innerValue, EscapableString(rawString: value))
    }

    func test_003() throws {
        let value = "   \n"
        let tokens = try TokenParser.parse(value)
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens.first!.type, .spaces)
        XCTAssertEqual(tokens.first!.value, value)
        XCTAssertEqual(tokens.first!.innerValue, EscapableString(rawString: value))
    }

    func test_004() throws {
        let innerValue = "   "
        let value = """
                    //\(innerValue)
                    """
        let tokens = try TokenParser.parse(value)
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens.first!.type, .singleLineComment)
        XCTAssertEqual(tokens.first!.value, value)
        XCTAssertEqual(tokens.first!.innerValue, EscapableString(rawString: innerValue))
    }

    func test_005() throws {
        let innerValue = "   "
        let value = """
                    //\(innerValue)\n
                    """
        let tokens = try TokenParser.parse(value)
        XCTAssertEqual(tokens.count, 2)

        XCTAssertEqual(tokens[0].type, .singleLineComment)
        XCTAssertEqual(tokens.first!.value, "//\(innerValue)")
        XCTAssertEqual(tokens.first!.innerValue, EscapableString(rawString: innerValue))

        XCTAssertEqual(tokens[1].type, .spaces)
        XCTAssertEqual(tokens[1].value, "\n")
        XCTAssertEqual(tokens[1].innerValue, EscapableString(rawString: "\n"))
    }

    func test_006() throws {
        let innerValue = "   "
        let value = """
                    //\(innerValue)\n\n
                    """
        let tokens = try TokenParser.parse(value)
        XCTAssertEqual(tokens.count, 2)
        XCTAssertEqual(tokens[0].type, .singleLineComment)
        XCTAssertEqual(tokens[0].value, "//\(innerValue)")
        XCTAssertEqual(tokens[0].innerValue, EscapableString(rawString: innerValue))

        XCTAssertEqual(tokens[1].value, "\n\n")
        XCTAssertEqual(tokens[1].innerValue, EscapableString(rawString: "\n\n"))
    }

    func test_007() throws {
        let innerValue = "123"
        let value = """
                    "\(innerValue)\"
                    """
        let tokens = try TokenParser.parse(value)
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].type, .string)
        XCTAssertEqual(tokens[0].value, value)
        XCTAssertEqual(tokens[0].innerValue, EscapableString(rawString: innerValue))
    }

    func test_008() throws {
        let innerValue = "12\\n\\t3"
        let unescapedInnerValue = "12\n\t3"
        let value = """
                    "\(innerValue)"
                    """
        let tokens = try TokenParser.parse(value)
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].type, .string)
        XCTAssertEqual(tokens[0].value, value)
        XCTAssertEqual(tokens[0].innerValue, EscapableString(rawString: unescapedInnerValue))
    }

    func test_009() throws {
        let innerValue = ";"
        let value = """
                    \(innerValue)
                    """
        let tokens = try TokenParser.parse(value)
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].type, .semicomma)
        XCTAssertEqual(tokens[0].value, value)
        XCTAssertEqual(tokens[0].innerValue, EscapableString(rawString: innerValue))
    }

    func test_010() throws {
        let innerValue = ";"
        let value = """
                    \(innerValue)\n
                    """
        let tokens = try TokenParser.parse(value)
        XCTAssertEqual(tokens.count, 2)
        XCTAssertEqual(tokens[0].type, .semicomma)
        XCTAssertEqual(tokens[0].value, ";")
        XCTAssertEqual(tokens[0].innerValue, EscapableString(rawString: ";"))

        XCTAssertEqual(tokens[1].type, .spaces)
        XCTAssertEqual(tokens[1].value, "\n")
        XCTAssertEqual(tokens[1].innerValue, EscapableString(rawString: "\n"))
    }

    func test_011() throws {
        let innerValue = ";"
        let value = """
                    \(innerValue)\(innerValue)
                    """
        let tokens = try TokenParser.parse(value)
        XCTAssertEqual(tokens.count, 2)
        XCTAssertEqual(tokens[0].type, .semicomma)
        XCTAssertEqual(tokens[0].value, ";")
        XCTAssertEqual(tokens[0].innerValue, EscapableString(rawString: ";"))

        XCTAssertEqual(tokens[1].type, .semicomma)
        XCTAssertEqual(tokens[1].value, ";")
        XCTAssertEqual(tokens[1].innerValue, EscapableString(rawString: ";"))
    }

    func test_012() throws {
        let value = """
                    "a"=="1";
                    """
        let tokens = try TokenParser.parse(value)
        XCTAssertEqual(tokens.count, 5)
        XCTAssertEqual(tokens[0].type, .string)
        XCTAssertEqual(tokens[0].value, "\"a\"")
        XCTAssertEqual(tokens[0].innerValue, EscapableString(rawString: "a"))

        XCTAssertEqual(tokens[1].type, .equation)
        XCTAssertEqual(tokens[1].value, "=")
        XCTAssertEqual(tokens[1].innerValue, EscapableString(rawString: "="))

        XCTAssertEqual(tokens[2].type, .equation)
        XCTAssertEqual(tokens[2].value, "=")
        XCTAssertEqual(tokens[2].innerValue, EscapableString(rawString: "="))

        XCTAssertEqual(tokens[3].type, .string)
        XCTAssertEqual(tokens[3].value, "\"1\"")
        XCTAssertEqual(tokens[3].innerValue, EscapableString(rawString: "1"))

        XCTAssertEqual(tokens[4].type, .semicomma)
        XCTAssertEqual(tokens[4].value, ";")
        XCTAssertEqual(tokens[4].innerValue, EscapableString(rawString: ";"))
    }

    func test_013() throws {
        let value = """
                    /* Hello
                    */
                    """
        let tokens = try TokenParser.parse(value)
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].type, .multiLineComment)
        XCTAssertEqual(tokens[0].value, "/* Hello\n*/")
        XCTAssertEqual(tokens[0].innerValue, EscapableString(rawString: " Hello\n"))
    }

    func test_014() throws {
        let value = """
                    "a" ="1";
                    """
        let tokens = try TokenParser.parse(value)

        XCTAssertEqual(tokens.count, 5)
        XCTAssertEqual(tokens[0].type, .string)
        XCTAssertEqual(tokens[0].value, "\"a\"")
        XCTAssertEqual(tokens[0].innerValue, EscapableString(rawString: "a"))

        XCTAssertEqual(tokens[1].type, .spaces)
        XCTAssertEqual(tokens[1].value, " ")
        XCTAssertEqual(tokens[1].innerValue, EscapableString(rawString: " "))

        XCTAssertEqual(tokens[2].type, .equation)
        XCTAssertEqual(tokens[2].value, "=")
        XCTAssertEqual(tokens[2].innerValue, EscapableString(rawString: "="))

        XCTAssertEqual(tokens[3].type, .string)
        XCTAssertEqual(tokens[3].value, "\"1\"")
        XCTAssertEqual(tokens[3].innerValue, EscapableString(rawString: "1"))

        XCTAssertEqual(tokens[4].type, .semicomma)
        XCTAssertEqual(tokens[4].value, ";")
        XCTAssertEqual(tokens[4].innerValue, EscapableString(rawString: ";"))

        XCTAssertEqual(tokens.map({ $0.value }).joined(), value)
    }

    func test_015() throws {
        let value = """
                    /* Hello
                    \\**/
                    """
        let tokens = try TokenParser.parse(value)
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].type, .multiLineComment)
        XCTAssertEqual(tokens[0].value, "/* Hello\n\\**/")
        XCTAssertEqual(tokens[0].innerValue, EscapableString(rawString: " Hello\n\\*"))
    }

    func test_016() throws {
        let value = """
                    /* Hello
                     * World
                    \\**/
                    """
        let tokens = try TokenParser.parse(value)
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].type, .multiLineComment)
        XCTAssertEqual(tokens[0].value, "/* Hello\n * World\n\\**/")
        XCTAssertEqual(tokens[0].innerValue, EscapableString(rawString: " Hello\n * World\n\\*"))
    }

    func test_017() throws {
//        let value = "1.将设备连接到iTunes, 前往\"应用\"选项卡后向下滚动到\"文件分享\ \"\n2.选择\"铃声\"应用\n3.选择右侧\"文件分享\"部分中的铃声，并将其保存到桌面\n4.双击已复制的铃声后在iTunes中点击\"同步\""
//        let tokens = try TokenParser.parse(value)
//        XCTAssertEqual(tokens.map({ $0.value }).joined(separator: ""), value)
    }

}

#if os(Linux)
extension TokenParserTests {
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
    ]
}
#endif
