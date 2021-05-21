//
//  Token.swift
//  TokenParser
//
//  Created by Siarhei Ladzeika on 7/17/21.
//

import Foundation
import Utils

public enum TokenError: Error, LocalizedError {
    case passthrough(error: Error, type: TokenType,
                     value: String,
                     startInnerInclusive: String.Index,
                     endInnerExclusive: String.Index,
                     mode: TokenInnerValueMode)

    public var errorDescription: String? {
        switch self {
            case let .passthrough(error, type, value, startInnerInclusive: _, endInnerExclusive: _, mode):
                return "\(error) in '\(value)' using type = \(type), mode = \(mode)"
        }
    }

}

open class Token: CustomStringConvertible, Equatable {

    // MARK: - Public vars

    public static let notQuotedStringAllowedCharacterSet: CharacterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))

    public static let equation = "="
    public static let semicomma = ";"

    public let type: TokenType
    public let value: String
    public let innerValue: EscapableString
    public let mode: TokenInnerValueMode
    public let prefix: String
    public let suffix: String

    // MARK: - Private vars

    public var description: String {
        """
        Token: type = '\(type)', value = '\(value)' innerValue = '\(innerValue)''
        """
    }

    public init(type: TokenType,
                value: String,
                startInnerInclusive: String.Index,
                endInnerExclusive: String.Index,
                mode: TokenInnerValueMode) throws
    {
        do {
            self.type = type
            self.mode = mode

            prefix = String(value[value.startIndex..<startInnerInclusive])
            suffix = String(value[endInnerExclusive..<value.endIndex])


            switch mode {
                case .raw:
                    innerValue = EscapableString(rawString: String(value[startInnerInclusive..<endInnerExclusive]))

                case .escaping:
                    innerValue = try EscapableString(escapedString: String(value[startInnerInclusive..<endInnerExclusive]))

                case .escapingComment:
                    innerValue = EscapableString(rawString: String(value[startInnerInclusive..<endInnerExclusive]))
            }


            self.value = Self.composeValue(mode: mode, prefix: prefix, innerValue: innerValue, suffix: suffix)
        }
        catch {
            throw TokenError.passthrough(error: error, type: type, value: value, startInnerInclusive: startInnerInclusive, endInnerExclusive: endInnerExclusive, mode: mode)
        }
    }

    public init(type: TokenType, mode: TokenInnerValueMode, prefix: String, innerValue: EscapableString, suffix: String) {
        self.type = type
        self.mode = mode
        self.prefix = prefix
        self.innerValue = innerValue
        self.suffix = suffix
        self.value = Self.composeValue(mode: mode, prefix: prefix, innerValue: innerValue, suffix: suffix)
    }

    private static func composeValue(mode: TokenInnerValueMode, prefix: String, innerValue: EscapableString, suffix: String) -> String {
        switch mode {
            case .raw:
                return prefix + innerValue.rawString + suffix

            case .escaping:
                return prefix + innerValue.escapedString + suffix

            case .escapingComment:
                return prefix + innerValue.rawString + suffix
        }
    }

    public func addingRawString(_ string: String) -> Token {
        return Token(type: type, mode: mode, prefix: prefix, innerValue: EscapableString(rawString: innerValue.rawString + string), suffix: suffix)
    }

    public func updatingInnerValue(_ innerValue: EscapableString) -> Token {
        switch type {
            case .string:
                if prefix.isEmpty
                    && suffix.isEmpty
                    && (innerValue.rawString.isEmpty || !innerValue.rawString.unicodeScalars.allSatisfy({ Self.notQuotedStringAllowedCharacterSet.contains($0) }))
                {
                    return Token(type: type, mode: mode, prefix: "\"", innerValue: innerValue, suffix: "\"")
                }
                return Token(type: type, mode: mode, prefix: prefix, innerValue: innerValue, suffix: suffix)
            default: break
        }
        return Token(type: type, mode: mode, prefix: prefix, innerValue: innerValue, suffix: suffix)
    }

    public static func == (lhs: Token, rhs: Token) -> Bool {
        return lhs.type == rhs.type
        && lhs.value == rhs.value
    }
}
