//
//  TokenParserError.swift
//  TokenParser
//
//  Created by Siarhei Ladzeika on 3/15/20.
//

import Foundation

public enum TokenParserError: Error, LocalizedError {

    case unexpectedCharacter(character: Character, line: Int, column: Int)
    case unexpectedEndOfFile(description: String)

    public var errorDescription: String? {
        switch self {

        case let .unexpectedCharacter(character, line, column):
            return "TokenParserError: unexpected character '\(character)' at \(line):\(column)"

        case let .unexpectedEndOfFile(description: description):
            return "TokenParserError: unexpected end of file: \(description)"
        }
    }
}
