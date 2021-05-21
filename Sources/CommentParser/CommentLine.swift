//
//  CommentLine.swift
//  CommentParser
//
//  Created by Siarhei Ladzeika on 8/16/21.
//

import Foundation

public class CommentLine {
    public let leadingSpaces: String
    public let text: String
    public let trailingSpaces: String

    public init(leadingSpaces: String,
                text: String,
                trailingSpaces: String)
    {
        self.leadingSpaces = leadingSpaces
        self.text = text
        self.trailingSpaces = trailingSpaces
    }

    public func clone() -> CommentLine {
        CommentLine(leadingSpaces: leadingSpaces, text: text, trailingSpaces: trailingSpaces)
    }

    static let leadingSpacesSet = CharacterSet.whitespaces.union(CharacterSet(charactersIn: "*"))

    public static func commentLines(from string: String) -> [CommentLine] {
        let components = string.split(separator: "\n")
        return components.enumerated().map({ item -> CommentLine in

            let string = String(item.element)
            let index = item.offset
            let isLast = index == components.count - 1

            var textStartIndex: String.Index?

            for index in string.indices {
                let character = string[index]
                if !character.unicodeScalars.contains(where: { Self.leadingSpacesSet.contains($0) }) {
                    textStartIndex = index
                    break
                }
            }

            var textEndIndex: String.Index?

            for index in string.indices.reversed() {
                let character = string[index]
                if !character.unicodeScalars.contains(where: { CharacterSet.whitespaces.contains($0) }) {
                    textEndIndex = index
                    break
                }
            }

            let leadingSpaces = textStartIndex != nil ? String(string[string.startIndex..<textStartIndex!]) : string
            let trailingSpaces = textEndIndex != nil ? String(string[string.index(after: textEndIndex!)..<string.endIndex]) : ""
            let text = textStartIndex != nil ? String(string[textStartIndex!...textEndIndex!]) : ""

            return CommentLine(leadingSpaces: leadingSpaces,
                               text: text,
                               trailingSpaces: trailingSpaces + (isLast ? "" : "\n"))
        })
    }
}

extension CommentLine: Equatable {
    public static func == (lhs: CommentLine, rhs: CommentLine) -> Bool {
        lhs.leadingSpaces == rhs.leadingSpaces
            && lhs.text == rhs.text
            && lhs.trailingSpaces == rhs.trailingSpaces
    }
}

extension CommentLine: CustomStringConvertible {
    public var description: String {
        "CommentLine: leadingSpaces = '\(leadingSpaces)' text = '\(text)' trailingSpaces = '\(trailingSpaces)'"
    }
}
