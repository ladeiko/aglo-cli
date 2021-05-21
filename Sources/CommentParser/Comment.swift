//
//  Comment.swift
//  CommentParser
//
//  Created by Siarhei Ladzeika on 7/17/21.
//

import Foundation
import Utils
import TokenParser

public class Comment {

    public static let charactersPerLine = 80
    public let lines: [CommentLine]

    public init(lines: [CommentLine]) {
        self.lines = lines
    }

    public init(tokens: [Token]) {
        lines = tokens.flatMap({ CommentLine.commentLines(from: $0.innerValue.rawString) })
    }

    public func updatingText(_ text: String, limit: Int? = nil) -> Comment {

        let limit: Int = limit ?? Self.charactersPerLine
        let lineTexts = text.splitIntoLines(limit: limit)

        var lines = self.lines
        if lineTexts.count < lines.count {
            lines.removeSubrange(lineTexts.count...)
        }
        else {
            while lineTexts.count > lines.count {
                let etalon = lines.last?.clone() ?? CommentLine(leadingSpaces: "", text: "", trailingSpaces: "")
                lines.append(etalon)
            }
        }

        lineTexts.enumerated().forEach({
            lines[$0.offset] = CommentLine(leadingSpaces: lines[$0.offset].leadingSpaces,
                                           text: lineTexts[$0.offset],
                                           trailingSpaces: lines[$0.offset].trailingSpaces)
        })

        return Comment(lines: lines)
    }

    public var text: String {
        lines.map({ $0.text }).joined(separator: " ")
    }

    public func compose() -> String {
        return lines
            .map({ "\($0.leadingSpaces)\($0.text)\($0.trailingSpaces)" })
            .joined()
    }
}
