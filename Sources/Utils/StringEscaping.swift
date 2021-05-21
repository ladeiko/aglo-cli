//
//  StringEscaping.swift
//  Utils
//
//  Created by Siarhei Ladzeika on 8/21/21.
//

import Foundation

func escapeKeyValueString(_ s: String) -> String {
    var result = ""
    for c in s {
        switch c {
        case "\\":
            result += "\\\\"

        case "\"":
            result += "\\\""

        case "\n":
            result += "\\n"

        case "\t":
            result += "\\t"

        default:
            result += String(c)
        }
    }
    return result
}

public enum ConvertError: Error, LocalizedError {
    case unexpectedCharacter(c: Character, string: String, position: Int)
    case unexpectedEndOfString
    case invalidHexValue(value: String)
    case newlineNotAllowed(string: String, position: Int)

    public var errorDescription: String? {
        switch self {
        case let .unexpectedCharacter(c, string, position):
            return "ConvertError: unexpected character '\(c)' in '\(string)' at \(position) (1 based)"
        case .unexpectedEndOfString:
            return "ConvertError: unexpected end of file"
        case let .invalidHexValue(value):
            return "ConvertError: invalid hex value '\(value)'"
        case let .newlineNotAllowed(string, position):
            return "ConvertError: newline not allowed in '\(string)' at \(position) (1 based)"
        }
    }
}

func unescapeKeyValueString(_ s: String, allowNewLines: Bool = true) throws -> String {

    enum Mode {
        case normal
        case escape
        case unicode(length: Int, value: String)
    }

    var mode: Mode = .normal
    var result = ""
    for (position, c) in s.enumerated() {

        if c == "\n" && !allowNewLines {
            throw ConvertError.newlineNotAllowed(string: s, position: position + 1)
        }

        switch mode {
        case .normal:
            if c == "\\" {
                mode = .escape
            }
            else {
                result += String(c)
            }

        case .escape:
            switch c {
            case "n":
                result += "\n"
                mode = .normal
            case "t":
                result += "\t"
                mode = .normal
            case "u":
                mode = .unicode(length: 4, value: "")
            case "U":
                mode = .unicode(length: 8, value: "")
            case "\\":
                result += "\\"
                mode = .normal
            case "\"":
                result += "\""
                mode = .normal
            default:
                throw ConvertError.unexpectedCharacter(c: c, string: s, position: position + 1)
//                result += "\\" + String(c)
//                mode = .normal
            }

        case let .unicode(length: length, value: value):
            if value.count == length {

                let scanner = Scanner(string: value)
                var hexValue: UInt64 = 0

                guard withUnsafeMutablePointer(to: &hexValue, {
                    scanner.scanHexInt64($0)
                }) else {
                    throw ConvertError.invalidHexValue(value: value)
                }

                guard let scalarValue = UnicodeScalar(UInt32(hexValue)) else {
                    throw ConvertError.invalidHexValue(value: value)
                }

                result += String(scalarValue)
                mode = .normal
            }
            else {
                mode = .unicode(length: length, value: value + String(c))
            }
        }
    }

    switch mode {
    case .normal:
        break

    case let .unicode(length: length, value: value):

        guard value.count == length else {
            throw ConvertError.unexpectedEndOfString
        }

        let scanner = Scanner(string: value)
        var hexValue: UInt64 = 0

        guard withUnsafeMutablePointer(to: &hexValue, {
            scanner.scanHexInt64($0)
        }) else {
            throw ConvertError.invalidHexValue(value: value)
        }

        guard let scalarValue = UnicodeScalar(UInt32(hexValue)) else {
            throw ConvertError.invalidHexValue(value: value)
        }

        result += String(scalarValue)

    default:
        throw ConvertError.unexpectedEndOfString
    }

    return result

}
