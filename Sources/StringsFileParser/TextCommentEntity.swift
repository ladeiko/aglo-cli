//
//  TextCommentEntity.swift
//  StringsFileParser
//
//  Created by Siarhei Ladzeika on 21.05.21.
//

import Foundation
import TokenParser
import Utils

public class TextCommentEntity: TextEntity {

    // MARK: - Public
    
    public let tokens: [Token]

    public init(tokens: [Token]) {
        self.tokens = tokens
        super.init(type: .comments)
    }

    public var values: [String] {
        tokens.map({ $0.value })
    }

    public var innerValues: [EscapableString] {
        tokens.map({ $0.innerValue })
    }

    public var isHeaderCandidate: Bool {
        innerValues.map({ $0.rawString }).contains(where: {
            $0.range(of: "[a-zA-Z0-9]+\\.\(StringsFile.fileExtension)", options: .regularExpression) != nil
                || $0.range(of: "Created\\s+by\\s+.+?\\s+on\\s+[0-9]{1,2}/[0-9]{1,2}/[0-9]{2,4}\\.?", options: [.regularExpression, .caseInsensitive]) != nil
        })
    }

    public func valueForTag(for key: String) -> EscapableString? {

        guard let value = tokens.map({ $0.innerValue }).valueForTag(key) else {
            return nil
        }

        return .init(rawString: value)
    }

    public func deletingTag(_ tagName: String) -> TextCommentEntity {
        let s = tokens.map({ $0.innerValue }).deletingTag(tagName)
        return TextCommentEntity(tokens: tokens.enumerated().map({ $0.element.updatingInnerValue(s[$0.offset]) }))
    }

    public func updatingTag(_ key: String, to value: EscapableString) -> TextCommentEntity {
        let s = tokens.map({ $0.innerValue }).updatingTag(key, to: value.rawString)
        return TextCommentEntity(tokens: tokens.enumerated().map({ $0.element.updatingInnerValue(s[$0.offset]) }))
    }
}
