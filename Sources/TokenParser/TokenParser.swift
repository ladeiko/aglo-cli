//
//  FileParser.swift
//  TokenParser
//
//  Created by Siarhei Ladzeika on 24.05.21.
//

import Foundation

fileprivate enum Mode {
    case spaces(startIndex: String.Index)
    case preComment(startIndex: String.Index)
    case singleLineComment(startIndex: String.Index)
    case multiLineComment(startIndex: String.Index)
    case multiLineCommentEscape(startIndex: String.Index)
    case preCloseMultiLineComment(startIndex: String.Index)
    case string(startIndex: String.Index, quoted: Bool)
    case stringEscape(startIndex: String.Index)
}

public struct TokenParser {

    public static func parse(_ content: String) throws -> [Token] {

        var tokens = [Token]()
        var mode: Mode = .spaces(startIndex: content.startIndex)

        var column = 0

        var line = 1 {
            didSet {
                column = 0
            }
        }

        var currentIndex: String.Index = content.startIndex

        for c in content {

            column += 1

            switch mode {

            case let .spaces(startIndex):

                if c == "\"" {

                    if content.distance(from: startIndex, to: currentIndex) > 0 {
                        let value = String(content[startIndex...content.index(before: currentIndex)])
                        tokens.append(try Token(type: .spaces,
                                                value: value,
                                                startInnerInclusive: value.startIndex,
                                                endInnerExclusive: value.endIndex,
                                                mode: .raw))
                    }

                    mode = .string(startIndex: currentIndex, quoted: true)
                    break
                }

                if c == "=" {

                    if content.distance(from: startIndex, to: currentIndex) > 0 {
                        let value = String(content[startIndex...content.index(before: currentIndex)])
                        tokens.append(try Token(type: .spaces,
                                                value: value,
                                                startInnerInclusive: value.startIndex,
                                                endInnerExclusive: value.endIndex,
                                                mode: .raw))
                    }

                    let value = String(content[currentIndex...currentIndex])
                    tokens.append(try Token(type: .equation,
                                            value: value,
                                            startInnerInclusive: value.startIndex,
                                            endInnerExclusive: value.endIndex,
                                            mode: .raw))
                    mode = .spaces(startIndex: content.index(after: currentIndex))
                    break
                }

                if c == ";" {

                    if content.distance(from: startIndex, to: currentIndex) > 0 {
                        let value = String(content[startIndex...content.index(before: currentIndex)])
                        tokens.append(try Token(type: .spaces,
                                                value: value,
                                                startInnerInclusive: value.startIndex,
                                                endInnerExclusive: value.endIndex,
                                                mode: .raw))
                    }

                    let value = String(content[currentIndex...currentIndex])
                    tokens.append(try Token(type: .semicomma,
                                            value: value,
                                            startInnerInclusive: value.startIndex,
                                            endInnerExclusive: value.endIndex,
                                            mode: .raw))

                    mode = .spaces(startIndex: content.index(after: currentIndex))
                    break
                }

                if c == "/" {

                    if content.distance(from: startIndex, to: currentIndex) > 0 {
                        let value = String(content[startIndex...content.index(before: currentIndex)])
                        tokens.append(try Token(type: .spaces,
                                                value: value,
                                                startInnerInclusive: value.startIndex,
                                                endInnerExclusive: value.endIndex,
                                                mode: .raw))
                    }

                    mode = .preComment(startIndex: currentIndex)
                    break
                }

                switch c {
                case " ", "\t": break
                case "\n":
                    line += 1
                default:
                    if c.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) }) {

                        if content.distance(from: startIndex, to: currentIndex) > 0 {
                            let value = String(content[startIndex...content.index(before: currentIndex)])
                            tokens.append(try Token(type: .spaces,
                                                    value: value,
                                                    startInnerInclusive: value.startIndex,
                                                    endInnerExclusive: value.endIndex,
                                                    mode: .raw))
                        }

                        mode = .string(startIndex: currentIndex, quoted: false)
                    }
                    else {
                        throw TokenParserError.unexpectedCharacter(character: c, line: line, column: column)
                    }
                }

            case let .preComment(startIndex):

                if c == "/" {
                    mode = .singleLineComment(startIndex: content.index(startIndex, offsetBy: 2))
                    break
                }

                if c == "*" {
                    mode = .multiLineComment(startIndex: content.index(startIndex, offsetBy: 2))
                    break
                }

                //mode = .spaces(startIndex: startIndex)
                throw TokenParserError.unexpectedCharacter(character: c, line: line, column: column)

            case let .singleLineComment(startIndex):

                if c == "\n" {
                    let value = String(content[content.index(startIndex, offsetBy: -2)...content.index(before: currentIndex)])
                    tokens.append(try Token(type: .singleLineComment,
                                            value: value,
                                            startInnerInclusive: value.index(value.startIndex, offsetBy: 2),
                                            endInnerExclusive: value.endIndex,
                                            mode: .raw))

                    mode = .spaces(startIndex: currentIndex)
                    line += 1
                }

            case let .multiLineComment(startIndex):

                if c == "\\" {
                    mode = .multiLineCommentEscape(startIndex: startIndex)
                    break
                }

                if c == "*" {
                    mode = .preCloseMultiLineComment(startIndex: startIndex)
                    break
                }

                if c == "\n" {
                    line += 1
                }

            case let .multiLineCommentEscape(startIndex):

                if c == "\n" {
                    line += 1
                }

                mode = .multiLineComment(startIndex: startIndex)

            case let .preCloseMultiLineComment(startIndex):

                if c == "/" {
                    let value = String(content[content.index(startIndex, offsetBy: -2)...currentIndex])
                    tokens.append(try Token(type: .multiLineComment,
                                            value: value,
                                            startInnerInclusive: value.index(value.startIndex, offsetBy: 2),
                                            endInnerExclusive: value.index(value.endIndex, offsetBy: -2),
                                            mode: .escapingComment))
                    mode = .spaces(startIndex: content.index(currentIndex, offsetBy: 1))
                    break
                }

                if c == "\n" {
                    line += 1
                }

                mode = .multiLineComment(startIndex: startIndex)

            case let .string(startIndex, quoted):

                if !quoted {
                    if !c.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) }) {
                        let value = String(content[startIndex..<currentIndex])
                        tokens.append(try Token(type: .string,
                                                value: value,
                                                startInnerInclusive: value.startIndex,
                                                endInnerExclusive: value.endIndex,
                                                mode: .escaping))
                        mode = .spaces(startIndex: currentIndex)
                        break
                    }
                }
                else {

                    if c == "\\" {
                        mode = .stringEscape(startIndex: startIndex)
                        break
                    }

                    if c == "\"" {
                        let value = String(content[startIndex...currentIndex])
                        tokens.append(try Token(type: .string,
                                                value: value,
                                                startInnerInclusive: value.index(after: value.startIndex),
                                                endInnerExclusive: value.index(before: value.endIndex),
                                                mode: .escaping))
                        mode = .spaces(startIndex: content.index(after: currentIndex))
                        break
                    }
                }

                if c == "\n" {
                    line += 1
                }

            case let .stringEscape(startIndex):

                if c == "\n" {
                    line += 1
                }

                mode = .string(startIndex: startIndex, quoted: true)
            }

            currentIndex = content.index(currentIndex, offsetBy: 1)
        }

        switch mode {
        case let .spaces(startIndex):
            if content.distance(from: startIndex, to: currentIndex) > 0 {
                let value = String(content[startIndex...content.index(currentIndex, offsetBy: -1)])
                tokens.append(try Token(type: .spaces,
                                        value: value,
                                        startInnerInclusive: value.startIndex,
                                        endInnerExclusive: value.endIndex,
                                        mode: .raw))
            }

        case let .singleLineComment(startIndex):
            let value = String(content[content.index(startIndex, offsetBy: -2)...content.index(currentIndex, offsetBy: -1)])
            tokens.append(try Token(type: .singleLineComment,
                                    value: value,
                                    startInnerInclusive: value.index(value.startIndex, offsetBy: 2),
                                    endInnerExclusive: value.endIndex,
                                    mode: .raw))

        default:
            let description: String
            switch mode {
            case .multiLineComment: description = "incomplete multiline comment"
            case .multiLineCommentEscape: description = "incomplete multiline comment escape"
            case .preCloseMultiLineComment: description = "incomplete comment closure"
            case .preComment: description = "incomplete comment beginning"
            case .singleLineComment: fatalError()
            case .spaces: fatalError()
            case .string: description = "incomplete string"
            case .stringEscape: description = "incomplete string escape"
            }
            throw TokenParserError.unexpectedEndOfFile(description: description)
        }

        return tokens
    }
}
