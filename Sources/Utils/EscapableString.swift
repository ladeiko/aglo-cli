//
//  EscapableString.swift
//  
//
//  Created by Sergey Ladeiko on 18.10.21.
//

import Foundation

fileprivate enum EscapableStringSource {
    case raw
    case escaped
}

public enum EscapableStringError: Error, LocalizedError {
    case stringIsNotValidFilenameKeyValue(string: String)
    case filenameIsEmpty(string: String)
    case keyIsEmpty(string: String)
    public var errorDescription: String? {
        switch self {
        case let .stringIsNotValidFilenameKeyValue(string):
            return "EscapableStringError: string is not valid filename/key value '\(string)'"
        case let .filenameIsEmpty(string):
            return "EscapableStringError: filename is empty '\(string)'"
        case let .keyIsEmpty(string):
            return "EscapableStringError: key is empty '\(string)'"
        }
    }
}

public class EscapableString {

    private let source: EscapableStringSource

    public var isEmpty: Bool {
        rawString.isEmpty
    }
    
    public init(rawString: String) {
        self.source = .raw
        self.rawString = rawString
        self.escapedString = escapeKeyValueString(rawString)
    }

    public init(escapedString: String, allowNewLines: Bool = true) throws {
        self.source = .escaped
        self.rawString = try unescapeKeyValueString(escapedString, allowNewLines: allowNewLines)
        self.escapedString = escapedString
    }

    public let escapedString: String
    public let rawString: String
}

extension String {
    public func parseAsStringsFilenameAndKey() throws -> (filename: String, key: String) {
        let ext = ".strings"
        let components = split(separator: ":")
        guard components.count > 1 else {
            throw EscapableStringError.stringIsNotValidFilenameKeyValue(string: self)
        }
        let filename = components.first!.hasSuffix(ext) ? String(components.first![components.first!.startIndex..<components.first!.index(components.first!.endIndex, offsetBy: -ext.count)]) : String(components.first!)
        if filename.isEmpty {
            throw EscapableStringError.filenameIsEmpty(string: self)
        }
        let key: String = String(components[1...].joined(separator: ":"))
        if key.isEmpty {
            throw EscapableStringError.keyIsEmpty(string: self)
        }
        return (filename: filename, key: key)
    }
}

extension EscapableString {
    public func parseAsStringsFilenameAndKey() throws -> (filename: String, key: String) {
        try rawString.parseAsStringsFilenameAndKey()
    }
}

fileprivate struct Char {
    let idx: Int
    let character: Character?
}

fileprivate extension Array where Element == Char {

    func string(at: Int, length: Int) -> String? {
        if at >= count {
            return nil
        }

        let maxIndex = Swift.min(count, at + length)
        if maxIndex < at {
            return nil
        }

        return self[at..<maxIndex].compactMap({ $0.character }).map({ String($0) }).joined()
    }

    func locate(_ string: String, starting: Int = 0) -> Int? {

        if isEmpty || string.isEmpty {
            return nil
        }

        let upperBound = count - string.count
        if starting <= upperBound {
            for i in starting...upperBound {

                guard let s = self.string(at: i, length: string.count) else {
                    return nil
                }

                if s == string {
                    return i
                }
            }
        }

        return nil
    }

    mutating func replace(_ range: Range<Int>, with replacement: String) {
        let deleted = Array(self[range])
        removeSubrange(range)
        insert(contentsOf: replacement.enumerated().map({
            let dl = Double($0.offset + 1) / Double(replacement.count) - 1 / (2 * Double(replacement.count))
            let ph = Int(round(dl  * Double(deleted.count - 1)))
            return Char(idx: deleted[ph].idx, character: $0.element)
        }), at: range.lowerBound)
    }

    func replacing(_ range: Range<Int>, with replacement: String) -> [Char] {
        var result = self
        let deleted = Array(result[range])
        result.removeSubrange(range)
        result.insert(contentsOf: replacement.enumerated().map({
            let dl = Double($0.offset + 1) / Double(replacement.count) - 1 / (2 * Double(replacement.count))
            let ph = Int(round(dl  * Double(deleted.count - 1)))
            return Char(idx: deleted[ph].idx, character: $0.element)
        }), at: range.lowerBound)
        return result
    }

    func replacing(_ target: String, with replacement: String) -> [Char] {

        var result = self

        if target.isEmpty {
            return self
        }

        var i = 0
        while i <= self.count - target.count {

            guard let found = result.locate(target, starting: i) else {
                break
            }

            let deleted = Array(self[found..<(found + target.count)])
            result.removeSubrange(found..<(found + target.count))
            result.insert(contentsOf: replacement.enumerated().map({
                let dl = Double($0.offset + 1) / Double(replacement.count) - 1 / (2 * Double(replacement.count))
                let ph = Int(round(dl  * Double(deleted.count - 1)))
                return Char(idx: deleted[ph].idx, character: $0.element)
            }), at: found)

            let zombies = deleted.count - replacement.count
            if zombies > 0 {
                for i in 0..<zombies {
                    result.insert(Char(idx: deleted[replacement.count + i].idx, character: nil), at: found + replacement.count + i)
                }
            }

            i += found + Swift.max(deleted.count, replacement.count)
        }

        return result
    }

    func toStrings() -> [String] {
        var last: Int = 0
        let t: [String] = reduce(into: [String](), {
            if $0.isEmpty {
                last = $1.idx
                if let character = $1.character {
                    $0.append(String(character))
                }
                else {
                    $0.append("")
                }
            }
            else {
                if last == $1.idx {
                    if let character = $1.character {
                        $0[$0.count - 1] = $0[$0.count - 1] + String(character)
                    }
                }
                else {
                    last = $1.idx
                    if let character = $1.character {
                        $0.append(String(character))
                    }
                    else {
                        $0.append("")
                    }
                }
            }
        })
        return t
    }

    func matches(_ string: String, at index: Int) -> Bool {

        guard index <= count - string.count else {
            return false
        }

        for i in 0..<string.count {
            if self[index + i].character != string[string.index(string.startIndex, offsetBy: i)] {
                return false
            }
        }

        return true
    }
}

extension Character {
    fileprivate var isTagValue: Bool {
        !isWhitespace && self != "," && self != "."
    }
}

extension EscapableString {
    static let tagNamePrefix = "@@"
    static let tagValueDelimiter = "###"
}

extension Array where Element == EscapableString {

    fileprivate struct EscapableStringRange {
        let elementIndex: Int
        let rangeInRawStringOfElement: Range<String>
    }

    fileprivate struct I {
        let s: Int
        let d: String.IndexDistance
    }

    fileprivate func charRepresentaion() -> [Char] {
        let chars: [Char] = enumerated().map({
            let index = $0
            let str = $1.rawString
            let c: [Char] = str.indices.map({
                Char(idx: index, character: str[$0])
            })
            return c
        }).reduce([], +)
        return chars
    }

    public func contains(_ string: String) -> Bool {
        map({ $0.rawString }).joined().contains(string)
    }

    public func containsTag(_ tagName: String) -> Bool {
        map({ $0.rawString }).joined().contains(EscapableString.tagNamePrefix + tagName + "=\(EscapableString.tagValueDelimiter)")
    }

    public func valueForTag(_ tagName: String) -> String? {
        let chars: [Char] = charRepresentaion()
        let marker = "\(EscapableString.tagNamePrefix)\(tagName)=\(EscapableString.tagValueDelimiter)"
        guard let match = chars.locate(marker) else {
            return nil
        }

        var result = ""
        for i in (match + marker.count)...(chars.count - EscapableString.tagValueDelimiter.count) {

            if chars.matches(EscapableString.tagValueDelimiter, at: i) {
                return result
            }

            if let character = chars[i].character {
                result += String(character)
            }
        }

        return nil
    }

    public func deletingTag(_ tagName: String) -> [Element] {
        var chars: [Char] = charRepresentaion()
        let marker = "\(EscapableString.tagNamePrefix)\(tagName)=\(EscapableString.tagValueDelimiter)"

        guard let match = chars.locate(marker) else {
            return self
        }

        var result = ""
        for i in match + marker.count...(chars.count - EscapableString.tagValueDelimiter.count) {
            if chars.matches(EscapableString.tagValueDelimiter, at: i) {
                let deleted = chars[match..<(i + EscapableString.tagValueDelimiter.count)]
                chars.removeSubrange(match..<(i + EscapableString.tagValueDelimiter.count))
                chars.insert(Char(idx: deleted.first!.idx, character: nil), at: match)
                let t: [String] = chars.toStrings()
                return t.map({ EscapableString(rawString: $0) })
            }

            if let character = chars[i].character {
                result += String(character)
            }
        }

        return self
    }

    public func updatingTag(_ tagName: String, to value: String) -> [Element] {
        var chars: [Char] = charRepresentaion()
        let marker = "\(EscapableString.tagNamePrefix)\(tagName)=\(EscapableString.tagValueDelimiter)"

        guard let match = chars.locate(marker) else {
            let existing = chars.compactMap({ $0.character })
            let shouldAddSpace = !existing.isEmpty && !existing[0].isWhitespace
            chars.insert(contentsOf: (marker + value + EscapableString.tagValueDelimiter + (shouldAddSpace ? " " : "")).map({ Char(idx: 0, character: $0) }), at: 0)
            let t: [String] = chars.toStrings()
            return t.map({ EscapableString(rawString: $0) })
        }

        var result = ""
        for i in match + marker.count..<chars.count {

            if chars.matches(EscapableString.tagValueDelimiter, at: i) {
                chars.replace((match + marker.count)..<(match + marker.count + result.count), with: value)
                let t: [String] = chars.toStrings()
                return t.map({ EscapableString(rawString: $0) })
            }

            if let character = chars[i].character {
                result += String(character)
            }
        }

        let existing = chars.compactMap({ $0.character })
        let shouldAddSpace = !existing.isEmpty && !existing[0].isWhitespace
        chars.insert(contentsOf: (marker + value + EscapableString.tagValueDelimiter + (shouldAddSpace ? " " : "")).map({ Char(idx: 0, character: $0) }), at: 0)
        let t: [String] = chars.toStrings()
        return t.map({ EscapableString(rawString: $0) })
    }

    public func replacing(_ string: String, with replacement: String) -> [Element] {

        if string.isEmpty {
            return self
        }

        let chars: [Char] = charRepresentaion()

        let result = chars.replacing(string, with: replacement)

        let t: [String] = result.toStrings()
        return t.map({ EscapableString(rawString: $0) })
    }
}

extension EscapableString: Equatable {
    public static func == (lhs: EscapableString, rhs: EscapableString) -> Bool {
        lhs.rawString == rhs.rawString
        && lhs.escapedString == rhs.escapedString
    }
}

extension EscapableString: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(rawString)
        hasher.combine(escapedString)
    }
}

extension EscapableString: Comparable {
    public static func < (lhs: EscapableString, rhs: EscapableString) -> Bool {
        lhs.rawString < rhs.rawString
//            && lhs.escapedString < rhs.escapedString
    }
}

extension EscapableString: CustomStringConvertible {
    public var description: String {
        "<EscapableString: rawString = '\(rawString)', escapedString = '\(escapedString)'>"
    }
}

extension EscapableString {

    public func isUntranslated(_ proposedMarker: String?) -> Bool {
        escapedString.hasPrefix(untranslatedPrefixMarker(proposedMarker))
    }

    public func makeTranslated(_ proposedMarker: String?) -> EscapableString {

        if !isUntranslated(proposedMarker) {
            switch source {
            case .escaped:
                return try! EscapableString(escapedString: escapedString)
            case .raw:
                return EscapableString(rawString: rawString)
            }
        }

        let prefix = untranslatedPrefixMarker(proposedMarker)

        switch source {
        case .escaped:
            return try! EscapableString(escapedString: String(escapedString[escapedString.index(escapedString.startIndex, offsetBy: prefix.count)...]))
        case .raw:
            return EscapableString(rawString: String(rawString[rawString.index(rawString.startIndex, offsetBy: prefix.count)...]))
        }
    }

    public func makeUntranslated(_ proposedMarker: String?) -> EscapableString {

        if isUntranslated(proposedMarker) {
            switch source {
            case .escaped:
                return try! EscapableString(escapedString: escapedString)
            case .raw:
                return EscapableString(rawString: rawString)
            }
        }

        let prefix = untranslatedPrefixMarker(proposedMarker)

        switch source {
        case .escaped:
            return try! EscapableString(escapedString: prefix + escapedString)
        case .raw:
            return EscapableString(rawString: prefix + rawString)
        }
    }
}
