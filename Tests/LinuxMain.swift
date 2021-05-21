import XCTest

import CLICommandsTests
import CommentParserTests
import RollbackTests
import StringsFileParserTests
import TokenParserTests
import UtilsTests
import XMLTokenParserTests

var tests = [XCTestCaseEntry]()
tests += CLICommandsTests.__allTests()
tests += CommentParserTests.__allTests()
tests += RollbackTests.__allTests()
tests += StringsFileParserTests.__allTests()
tests += TokenParserTests.__allTests()
tests += UtilsTests.__allTests()
tests += XMLTokenParserTests.__allTests()

XCTMain(tests)
