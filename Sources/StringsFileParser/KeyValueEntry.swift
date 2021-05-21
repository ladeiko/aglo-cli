//
//  KeyValueEntry.swift
//  StringsFileParser
//
//  Created by Siarhei Ladzeika on 7/18/21.
//  Copyright © 2021 Siarhei Ladzeika. All rights reserved.
//

import Foundation
import TokenParser
import Utils

public class KeyValueEntry: Entry {

    public let commentEntities: [TextCommentEntity]
    public let afterCommentSpacesEntity: TextSpacesEntity
    public let keyEntity: TextStringEntity
    public let afterKeySpacesEntity: TextSpacesEntity
    public let equationEntity: TextServiceEntity
    public let afterEquationSpacesEntity: TextSpacesEntity
    public let valueEntity: TextStringEntity
    public let afterValueSpacesEntity: TextSpacesEntity
    public let semicommaEntity: TextServiceEntity
    public let afterSemicommaSpacesEntity: TextSpacesEntity

    public init(commentEntities: [TextCommentEntity],
                afterCommentSpacesEntity: TextSpacesEntity,
                keyEntity: TextStringEntity,
                afterKeySpacesEntity: TextSpacesEntity,
                equationEntity: TextServiceEntity,
                afterEquationSpacesEntity: TextSpacesEntity,
                valueEntity: TextStringEntity,
                afterValueSpacesEntity: TextSpacesEntity,
                semicommaEntity: TextServiceEntity,
                afterSemicommaSpacesEntity: TextSpacesEntity)
    {
        self.commentEntities = commentEntities
        self.afterCommentSpacesEntity = afterCommentSpacesEntity
        self.keyEntity = keyEntity
        self.afterKeySpacesEntity = afterKeySpacesEntity
        self.equationEntity = equationEntity
        self.afterEquationSpacesEntity = afterEquationSpacesEntity
        self.valueEntity = valueEntity
        self.afterValueSpacesEntity = afterValueSpacesEntity
        self.semicommaEntity = semicommaEntity
        self.afterSemicommaSpacesEntity = afterSemicommaSpacesEntity
    }

    public var tokens: [Token] {
        let commentTokens = commentEntities.flatMap({ $0.tokens })
        return [
            commentTokens,
            [afterCommentSpacesEntity.token],//(commentTokens.isEmpty ? [] : [afterCommentSpacesEntity.token]),
            [keyEntity.token],
            [afterKeySpacesEntity.token],
            [equationEntity.token],
            [afterEquationSpacesEntity.token],
            [valueEntity.token],
            [afterValueSpacesEntity.token],
            [semicommaEntity.token],
            [afterSemicommaSpacesEntity.token],
        ]
        .flatMap({ $0 })
    }

    public static func newEntry(key: EscapableString, value: EscapableString, newEntriesSuffixNewLinesCount: Int = 2) throws -> KeyValueEntry {
        let equationString = Token.equation
        let semicommaString = Token.semicomma
        return KeyValueEntry(commentEntities: [],
                             afterCommentSpacesEntity: try TextSpacesEntity.zero(),// line(),
                             keyEntity: TextStringEntity(token: Token(type: .string,
                                                                          mode: .escaping,
                                                                          prefix: "\"",
                                                                          innerValue: key,
                                                                          suffix: "\"")),
                             afterKeySpacesEntity: try TextSpacesEntity.single(),
                             equationEntity: TextServiceEntity(token: try Token(type: .equation, value: equationString,
                                                                                startInnerInclusive: equationString.startIndex,
                                                                                endInnerExclusive: equationString.endIndex,
                                                                                mode: .raw)),
                             afterEquationSpacesEntity: try TextSpacesEntity.single(),
                             valueEntity: TextStringEntity(token: Token(type: .string,
                                                                            mode: .escaping,
                                                                            prefix: "\"",
                                                                            innerValue: value,
                                                                            suffix: "\"")),
                             afterValueSpacesEntity: try TextSpacesEntity.zero(),
                             semicommaEntity: TextServiceEntity(token: try Token(type: .semicomma, value: semicommaString,
                                                                                 startInnerInclusive: semicommaString.startIndex,
                                                                                 endInnerExclusive: semicommaString.endIndex,
                                                                                 mode: .raw)),
                             afterSemicommaSpacesEntity: try TextSpacesEntity.line(newEntriesSuffixNewLinesCount))
    }

    public func newEntryByUpdatingKey(to newKey: EscapableString) throws -> KeyValueEntry {

        if newKey == keyEntity.innerValue {
            return self
        }

        return KeyValueEntry(commentEntities: commentEntities,
                             afterCommentSpacesEntity: afterCommentSpacesEntity,
                             keyEntity: keyEntity.updatingValue(newKey),
                             afterKeySpacesEntity: afterKeySpacesEntity,
                             equationEntity: equationEntity,
                             afterEquationSpacesEntity: afterEquationSpacesEntity,
                             valueEntity: valueEntity,
                             afterValueSpacesEntity: afterValueSpacesEntity,
                             semicommaEntity: semicommaEntity,
                             afterSemicommaSpacesEntity: afterSemicommaSpacesEntity)
    }

    public func newEntryByUpdatingValue(to newValue: EscapableString) throws -> KeyValueEntry {

        if newValue == valueEntity.innerValue {
            return self
        }

        return KeyValueEntry(commentEntities: commentEntities,
                             afterCommentSpacesEntity: afterCommentSpacesEntity,
                             keyEntity: keyEntity,
                             afterKeySpacesEntity: afterKeySpacesEntity,
                             equationEntity: equationEntity,
                             afterEquationSpacesEntity: afterEquationSpacesEntity,
                             valueEntity: valueEntity.updatingValue(newValue),
                             afterValueSpacesEntity: afterValueSpacesEntity,
                             semicommaEntity: semicommaEntity,
                             afterSemicommaSpacesEntity: afterSemicommaSpacesEntity)
    }

    public func newEntryByUpdating(commentEntities: [TextCommentEntity]) throws -> KeyValueEntry {
        return KeyValueEntry(commentEntities: commentEntities,
                             afterCommentSpacesEntity: commentEntities.isEmpty ? try TextSpacesEntity.zero() : try TextSpacesEntity.line(1),
                             keyEntity: keyEntity,
                             afterKeySpacesEntity: afterKeySpacesEntity,
                             equationEntity: equationEntity,
                             afterEquationSpacesEntity: afterEquationSpacesEntity,
                             valueEntity: valueEntity,
                             afterValueSpacesEntity: afterValueSpacesEntity,
                             semicommaEntity: semicommaEntity,
                             afterSemicommaSpacesEntity: afterSemicommaSpacesEntity)
    }

    public func newEntryByUpdatingAfterCommentSpaces(_ afterCommentSpacesEntity: TextSpacesEntity) -> KeyValueEntry {
        return KeyValueEntry(commentEntities: commentEntities,
                             afterCommentSpacesEntity: afterCommentSpacesEntity,
                             keyEntity: keyEntity,
                             afterKeySpacesEntity: afterKeySpacesEntity,
                             equationEntity: equationEntity,
                             afterEquationSpacesEntity: afterEquationSpacesEntity,
                             valueEntity: valueEntity,
                             afterValueSpacesEntity: afterValueSpacesEntity,
                             semicommaEntity: semicommaEntity,
                             afterSemicommaSpacesEntity: afterSemicommaSpacesEntity)
    }

    public func newEntryByUpdatingAfterSemicommaSpaces(_ afterSemicommaSpacesEntity: TextSpacesEntity) -> KeyValueEntry {
        return KeyValueEntry(commentEntities: commentEntities,
                             afterCommentSpacesEntity: afterCommentSpacesEntity,
                             keyEntity: keyEntity,
                             afterKeySpacesEntity: afterKeySpacesEntity,
                             equationEntity: equationEntity,
                             afterEquationSpacesEntity: afterEquationSpacesEntity,
                             valueEntity: valueEntity,
                             afterValueSpacesEntity: afterValueSpacesEntity,
                             semicommaEntity: semicommaEntity,
                             afterSemicommaSpacesEntity: afterSemicommaSpacesEntity)
    }

    public func newEntryByNormalizingStartSpaces() throws -> KeyValueEntry {
        let afterCommentSpacesEntity: TextSpacesEntity = commentEntities.isEmpty ? try TextSpacesEntity.zero() : try TextSpacesEntity.line(1)
        return KeyValueEntry(commentEntities: commentEntities,
                             afterCommentSpacesEntity: afterCommentSpacesEntity,
                             keyEntity: keyEntity,
                             afterKeySpacesEntity: afterKeySpacesEntity,
                             equationEntity: equationEntity,
                             afterEquationSpacesEntity: afterEquationSpacesEntity,
                             valueEntity: valueEntity,
                             afterValueSpacesEntity: afterValueSpacesEntity,
                             semicommaEntity: semicommaEntity,
                             afterSemicommaSpacesEntity: afterSemicommaSpacesEntity)
    }

    public func newEntryByNormalizingFinalSpaces(afterLinesCount: Int) throws -> KeyValueEntry {
        let afterSemicommaSpacesEntity: TextSpacesEntity = try TextSpacesEntity.line(afterLinesCount)
        return KeyValueEntry(commentEntities: commentEntities,
                             afterCommentSpacesEntity: afterCommentSpacesEntity,
                             keyEntity: keyEntity,
                             afterKeySpacesEntity: afterKeySpacesEntity,
                             equationEntity: equationEntity,
                             afterEquationSpacesEntity: afterEquationSpacesEntity,
                             valueEntity: valueEntity,
                             afterValueSpacesEntity: afterValueSpacesEntity,
                             semicommaEntity: semicommaEntity,
                             afterSemicommaSpacesEntity: afterSemicommaSpacesEntity)
    }

    public func newEntryByNormalizingSpaces(afterLinesCount: Int) throws -> KeyValueEntry {
        let afterCommentSpacesEntity: TextSpacesEntity = commentEntities.isEmpty ? try TextSpacesEntity.zero() : try TextSpacesEntity.line(1)
        let afterKeySpacesEntity: TextSpacesEntity =  try TextSpacesEntity.single()
        let afterValueSpacesEntity: TextSpacesEntity =  try TextSpacesEntity.zero()
        let afterEquationSpacesEntity: TextSpacesEntity =  try TextSpacesEntity.single()
        let afterSemicommaSpacesEntity: TextSpacesEntity = try TextSpacesEntity.line(afterLinesCount)
        return KeyValueEntry(commentEntities: commentEntities,
                             afterCommentSpacesEntity: afterCommentSpacesEntity,
                             keyEntity: keyEntity,
                             afterKeySpacesEntity: afterKeySpacesEntity,
                             equationEntity: equationEntity,
                             afterEquationSpacesEntity: afterEquationSpacesEntity,
                             valueEntity: valueEntity,
                             afterValueSpacesEntity: afterValueSpacesEntity,
                             semicommaEntity: semicommaEntity,
                             afterSemicommaSpacesEntity: afterSemicommaSpacesEntity)
    }
}

extension KeyValueEntry: CustomStringConvertible {
    public var description: String {
        "<" + tokens.map({ $0.value }).joined(separator: "><") + ">"
    }
}
