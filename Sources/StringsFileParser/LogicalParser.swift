//
//  LogicalParser.swift
//  StringsFileParser
//
//  Created by Siarhei Ladzeika on 7/18/21.
//  Copyright © 2021 Siarhei Ladzeika. All rights reserved.
//

import Foundation
import TokenParser
import Utils

fileprivate class LogicalParserToken: Token {
    var lineNumber: Int!
}

public enum LogicalParserError: Error, LocalizedError {
    case unexpectedToken(token: Token)
    case unexpectedEntity(entity: TextEntity)
    case unexpectedEndOfFile(expectedValue: String)
    case duplicateKeyEntries(keys: Set<EscapableString>)
    case keyNotFound(key: EscapableString)

    public var errorDescription: String? {
        switch self {
        case let .unexpectedToken(token):
            if let t = token as? LogicalParserToken {
                return "LogicalParserError: unexpected token '\(token)' at \(t.lineNumber!)"
            }
            return "LogicalParserError: unexpected token '\(token)'"

        case let .unexpectedEntity(entity):
                switch entity {
                    case let e as TextSpacesEntity:
                        if let t = e.token as? LogicalParserToken {
                            return "LogicalParserError: unexpected entity '\(entity)' at line \(t.lineNumber!)"
                        }
                    case let e as TextCommentEntity:
                        if let t = e.tokens as? [LogicalParserToken] {
                            return "LogicalParserError: unexpected entity '\(entity)' at line(s) \(t.map({ String($0.lineNumber!) }).joined(separator: ", "))"
                        }
                    case let e as TextStringEntity:
                        if let t = e.token as? LogicalParserToken {
                            return "LogicalParserError: unexpected entity '\(entity)' at line \(t.lineNumber!)"
                        }
                    case let e as TextServiceEntity:
                        if let t = e.token as? LogicalParserToken {
                            return "LogicalParserError: unexpected entity '\(entity)' at line \(t.lineNumber!)"
                        }
                    default:
                        break
                }
                return "LogicalParserError: unexpected entity '\(entity)'"

        case let .unexpectedEndOfFile(expectedValue):
            return "LogicalParserError: unexpected end of file '\(expectedValue)'"

        case let .duplicateKeyEntries(keys):
            return "LogicalParserError: duplicate key entries \(Array(keys).map({ "\"\($0.escapedString)\"" }).sorted().joined(separator: ", "))"

        case let .keyNotFound(key):
            return "LogicalParserError: key not found '\(key.escapedString)'"
        }
    }
}

public struct LogicalParserOptions: OptionSet {

    public let rawValue: UInt
    public init(rawValue: UInt) {
      self.rawValue = rawValue
    }

    public static let removeDuplicateKeys = LogicalParserOptions(rawValue: 1 << 0)
}

public class LogicalParser {

    public var headerEntry: HeaderEntry? {
        allEntries.first(where: { ($0 as? HeaderEntry) != nil }) as? HeaderEntry
    }

    public private (set) var allEntries: [Entry] = [] {
        didSet {
            entries = allEntries.compactMap({ $0 as? KeyValueEntry })
            sorted = allEntries.enumerated().reduce(into: [:], {
                if let entry = $1.element as? KeyValueEntry {
                    $0[entry.keyEntity.innerValue] = $1.offset
                }
            })
        }
    }

    public static var newEntriesSuffixNewLinesCount: Int = 2

    public private (set) var entries: [KeyValueEntry] = []
    public private (set) var keys: Set<EscapableString>!
    private var sorted: [EscapableString: Int] = [:] {
        didSet {
            keys = Set(sorted.keys)
        }
    }

    public func compose() -> String {
        return allEntries.map({ $0.tokens.map({ $0.value }).joined() }).joined()
    }

    public func valueForKey(_ key: EscapableString) -> EscapableString? {
        guard let entryIndex = sorted[key], let entry = allEntries[entryIndex] as? KeyValueEntry else {
            return nil
        }
        return entry.valueEntity.innerValue
    }

    public func commentForKey(_ key: EscapableString) -> EscapableString? {
        guard let entryIndex = sorted[key], let entry = allEntries[entryIndex] as? KeyValueEntry else {
            return nil
        }
        return EscapableString(rawString: entry.commentEntities.map({
            $0.innerValues.map({ $0.rawString }).joined(separator: " ")
        }).joined(separator: " "))
    }

    public func valueForTag(_ tag: String, in key: EscapableString) -> String? {
        guard let entryIndex = sorted[key], let entry = allEntries[entryIndex] as? KeyValueEntry else {
            return nil
        }
        return entry.commentEntities.flatMap({ $0.innerValues }).valueForTag(tag)
    }

    public func removeValueForTag(_ tag: String, forKey key: EscapableString) throws {
        guard let entryIndex = sorted[key], let entry = allEntries[entryIndex] as? KeyValueEntry else {
            return
        }

        allEntries[entryIndex] = try entry.newEntryByUpdating(commentEntities: entry.commentEntities.map({ $0.deletingTag(tag) }))
    }

    public func setValueForTag(_ tag: String, forKey key: EscapableString, to value: EscapableString) throws {

        guard let entryIndex = sorted[key], let entry = allEntries[entryIndex] as? KeyValueEntry else {
            throw LogicalParserError.keyNotFound(key: key)
        }

        var comments = entry.commentEntities.map({ $0.deletingTag(tag) })
        if comments.isEmpty {
            comments.append(.init(tokens: [.init(type: .singleLineComment, mode: .escapingComment,
                                                 prefix: "//",
                                                 innerValue: [EscapableString(rawString: " ")].updatingTag(tag, to: value.rawString).first!,
                                                 suffix: "")]))
        }
        else {
            comments[0] = comments[0].updatingTag(tag, to: value)
        }

        allEntries[entryIndex] = try entry.newEntryByUpdating(commentEntities: comments)
    }

    public func setEntry(_ entry: KeyValueEntry, forKey key: EscapableString) throws {
        let entry = key == entry.keyEntity.innerValue ? entry : try entry.newEntryByUpdatingKey(to: key)

        if let entryIndex = sorted[key] {

            if entryIndex > 0, let prev = allEntries[entryIndex - 1] as? KeyValueEntry {
                allEntries[entryIndex - 1] = try prev.newEntryByNormalizingFinalSpaces(afterLinesCount: Self.newEntriesSuffixNewLinesCount)
            }

            if entryIndex < allEntries.count - 1, let prev = allEntries[entryIndex + 1] as? KeyValueEntry {
                allEntries[entryIndex + 1] = try prev.newEntryByNormalizingStartSpaces()
            }

            allEntries[entryIndex] = try entry.newEntryByNormalizingSpaces(afterLinesCount: Self.newEntriesSuffixNewLinesCount)
        }
        else {

            if !allEntries.isEmpty, let prev = allEntries[allEntries.count - 1] as? KeyValueEntry {
                allEntries[allEntries.count - 1] = try prev.newEntryByNormalizingFinalSpaces(afterLinesCount: Self.newEntriesSuffixNewLinesCount)
            }

            allEntries.append(try entry.newEntryByNormalizingSpaces(afterLinesCount: Self.newEntriesSuffixNewLinesCount))
        }
    }

    public func keyValueEntry(forKey key: EscapableString) -> KeyValueEntry? {
        guard let entryIndex = sorted[key] else {
            return nil
        }

        return allEntries[entryIndex] as? KeyValueEntry
    }

    public func keyExists(_ key: EscapableString) -> Bool {
        return keys.contains(key)
    }

    public func renameKey(_ key: EscapableString, to newKey: EscapableString) throws {

        guard key != newKey else {
            return
        }

        guard let entryIndex = sorted[key], let entry = allEntries[entryIndex] as? KeyValueEntry else {
            return
        }

        allEntries[entryIndex] = try entry.newEntryByUpdatingKey(to: newKey)
    }

    public func setValue(_ value: EscapableString, forKey key: EscapableString) throws {
        if let entryIndex = sorted[key], let entry = allEntries[entryIndex] as? KeyValueEntry {
            allEntries[entryIndex] = try entry.newEntryByUpdatingValue(to: value)
        }
        else {
            allEntries.append(try KeyValueEntry.newEntry(key: key, value: value,
                                                         newEntriesSuffixNewLinesCount: Self.newEntriesSuffixNewLinesCount)
                                .newEntryByNormalizingSpaces(afterLinesCount: Self.newEntriesSuffixNewLinesCount))
            if allEntries.count > 1, let prev = allEntries[allEntries.count - 2] as? KeyValueEntry {
                allEntries[allEntries.count - 2] = try prev.newEntryByNormalizingFinalSpaces(afterLinesCount: Self.newEntriesSuffixNewLinesCount)
            }
        }
    }

    public func set(commentEntities: [TextCommentEntity], forKey key: EscapableString) throws {
        guard let entryIndex = sorted[key], let entry = allEntries[entryIndex] as? KeyValueEntry else {
            throw LogicalParserError.keyNotFound(key: key)
        }

        allEntries[entryIndex] = try entry.newEntryByUpdating(commentEntities: commentEntities)
    }

    public func setComment(_ comment: EscapableString, forKey key: EscapableString) throws {
        guard let entryIndex = sorted[key], let entry = allEntries[entryIndex] as? KeyValueEntry else {
            throw LogicalParserError.keyNotFound(key: key)
        }

        let commentEntities: [TextCommentEntity] = [
            .init(tokens: [.init(type: .multiLineComment, mode: .escapingComment, prefix: "/*",
                                 innerValue: EscapableString(rawString: " " + comment.rawString + " "), suffix: "*/")])
        ]

        allEntries[entryIndex] = try entry.newEntryByUpdating(commentEntities: commentEntities).newEntryByNormalizingStartSpaces()
    }

    public func removeValueForKey(_ key: EscapableString) throws {

        guard let entryIndex = sorted[key] else {
            return
        }

        if entryIndex > 0, let prev = allEntries[entryIndex - 1] as? KeyValueEntry {
            allEntries[entryIndex - 1] = try prev.newEntryByNormalizingFinalSpaces(afterLinesCount: Self.newEntriesSuffixNewLinesCount)
        }

        if entryIndex < allEntries.count - 1, let next = allEntries[entryIndex + 1] as? KeyValueEntry {
            allEntries[entryIndex + 1] = try next.newEntryByNormalizingStartSpaces()
        }

        allEntries.remove(at: entryIndex)
    }

    public func prettify() throws {
        allEntries = try allEntries.map({
            if let entry = $0 as? KeyValueEntry {
                return try entry.newEntryByNormalizingSpaces(afterLinesCount: Self.newEntriesSuffixNewLinesCount)
            }
            else {
                return $0
            }
        })
    }

    public func sort(by: ((_ key1: EscapableString, _ key2: EscapableString) -> Bool)? = nil) throws {

        struct EntryInfo {
            let index: Int
            let entry: KeyValueEntry
        }

        var afterSemicommaSpaces: [Int: TextSpacesEntity] = [:]

        let keyValueEntries = allEntries.enumerated().reduce(into: [EscapableString: EntryInfo](), {
            guard let keyValueEntry = $1.element as? KeyValueEntry else {
                return
            }

            afterSemicommaSpaces[$1.offset] = keyValueEntry.afterSemicommaSpacesEntity
            $0[keyValueEntry.keyEntity.innerValue] = .init(index: $1.offset, entry: keyValueEntry)
        })

        let keys = keyValueEntries.keys.sorted()
        var allEntries = self.allEntries

        try keys.enumerated().forEach({
            allEntries[$0.offset] = keyValueEntries[$0.element]!.entry.newEntryByUpdatingAfterSemicommaSpaces(try (afterSemicommaSpaces[$0.offset] ?? (try TextSpacesEntity.line(Self.newEntriesSuffixNewLinesCount))))
        })

        self.allEntries = allEntries
    }

    public func parse(string: String, options: LogicalParserOptions = []) throws {

        do {

            let lineSeparator: Character = "\n"
            var lineNumber = 1
            let tokens: [LogicalParserToken] = (try TokenParser.parse(string)).map({
                let t = LogicalParserToken(type: $0.type,
                               mode: $0.mode,
                               prefix: $0.prefix,
                               innerValue: $0.innerValue,
                               suffix: $0.suffix)
                t.lineNumber = lineNumber
                lineNumber += $0.value.reduce(0) {
                    ($1 == lineSeparator) ? ($0 + 1) : $0
                }
                return t
            })

            let groupedByTypes = tokens.reduce(into: [[LogicalParserToken]](), { (r, token) in
                if !r.isEmpty && r.last!.last!.type.isComment && token.type.isComment {
                    var x = r.last!
                    x.append(token)
                    r[r.count - 1] = x
                }
                else {
                    r.append([token])
                }
            })

            let entities: [TextEntity] = try groupedByTypes.reduce(into: [TextEntity](), { result, tokens in
                switch tokens.first!.type {
                case .spaces:
                    result.append(contentsOf: tokens.map({ TextSpacesEntity(token: $0) }))

                case .multiLineComment, .singleLineComment:

                    // Special case to split file comments the very beginning of
                    // string into header comment and key value pair comment
                    if result.isEmpty { // we are at the beginning
                        if tokens.count > 1 {

                            // We stick last multiline comment to key value pair
                            // If key value pair has single line comments before, then we stick all
                            // this lines with comments to key value pair
                            let type = tokens.last!.type
                            let last = type == .singleLineComment ? tokens.lastElements(where: { $0.type == type }) : [tokens.last!]

                            result.append(TextCommentEntity(tokens: tokens.removingLastElements(last.count)))
                            result.append(TextCommentEntity(tokens: last))
                            break
                        }
                    }

                    result.append(TextCommentEntity(tokens: tokens))

                case .string:
                    if tokens.count > 1 {
                        throw LogicalParserError.unexpectedToken(token: tokens[1])
                    }
                    result.append(TextStringEntity(token: tokens.first!))

                case .equation:
                    if tokens.count > 1 {
                        throw LogicalParserError.unexpectedToken(token: tokens[1])
                    }
                    result.append(TextServiceEntity(token: tokens.first!))

                case .semicomma:
                    if tokens.count > 1 {
                        throw LogicalParserError.unexpectedToken(token: tokens[1])
                    }
                    result.append(TextServiceEntity(token: tokens.first!))
                }
            })

            enum Mode {
                case `default`

                case comment(commentEntities: [TextCommentEntity],
                             afterCommentSpacesEntity: TextSpacesEntity?)

                case key(commentEntities: [TextCommentEntity],
                         afterCommentSpacesEntity: TextSpacesEntity?,
                         keyEntity: TextStringEntity,
                         afterKeySpacesEntity: TextSpacesEntity?)

                case equation(commentEntities: [TextCommentEntity],
                              afterCommentSpacesEntity: TextSpacesEntity?,
                              keyEntity: TextStringEntity,
                              afterKeySpacesEntity: TextSpacesEntity?,
                              equationEntity: TextServiceEntity,
                              afterEquationSpacesEntity: TextSpacesEntity?)

                case value(commentEntities: [TextCommentEntity],
                           afterCommentSpacesEntity: TextSpacesEntity?,
                           keyEntity: TextStringEntity,
                           afterKeySpacesEntity: TextSpacesEntity?,
                           equationEntity: TextServiceEntity,
                           afterEquationSpacesEntity: TextSpacesEntity?,
                           valueEntity: TextStringEntity,
                           afterValueSpacesEntity: TextSpacesEntity?)

                case semicomma(commentEntities: [TextCommentEntity],
                               afterCommentSpacesEntity: TextSpacesEntity?,
                               keyEntity: TextStringEntity,
                               afterKeySpacesEntity: TextSpacesEntity?,
                               equationEntity: TextServiceEntity,
                               afterEquationSpacesEntity: TextSpacesEntity?,
                               valueEntity: TextStringEntity,
                               afterValueSpacesEntity: TextSpacesEntity?,
                               semicommaEntity: TextServiceEntity,
                               afterSemicommaSpacesEntity: TextSpacesEntity?)
            }

            var mode: Mode = .default
            var headerEntryCreated = false
            var keyValueEntriesCount = 0

            allEntries = try entities.reduce(into: [Entry](), { result, entity in

                var reparse = false
                repeat {
                    reparse = false

                    switch mode {
                    case .default:
                        switch entity {
                        case let value as TextCommentEntity:
                            mode = .comment(commentEntities: [value], afterCommentSpacesEntity: nil)
                        case let value as TextStringEntity:
                            mode = .key(commentEntities: [], afterCommentSpacesEntity: nil, keyEntity: value, afterKeySpacesEntity: nil)
                        case _ as TextSpacesEntity:
                            result.append(AnyEntry(entities: [entity]))
                        default:
                            throw LogicalParserError.unexpectedEntity(entity: entity)
                        }

                    case let .comment(commentEntities: commentEntities, afterCommentSpacesEntity: afterCommentSpacesEntity):
                        switch entity {
                        case let value as TextCommentEntity:
                            if afterCommentSpacesEntity == nil {
                                mode = .comment(commentEntities: commentEntities.appending(value), afterCommentSpacesEntity: afterCommentSpacesEntity)
                            }
                            else {

                                if headerEntryCreated || keyValueEntriesCount > 0 {
                                    result.append(AnyEntry(entities: [commentEntities as [TextEntity], [afterCommentSpacesEntity!] as [TextEntity]].flatMap({ $0 })))
                                    mode = .comment(commentEntities: [value], afterCommentSpacesEntity: nil)
                                }
                                else {

                                    headerEntryCreated = true
                                    result.append(HeaderEntry(commentEntities: [commentEntities.first!], spaceEntity: nil))

                                    if !commentEntities[1...].isEmpty {
                                        result.append(AnyEntry(entities: Array(commentEntities[1...])))
                                    }

                                    result.append(AnyEntry(entities: [afterCommentSpacesEntity!] as [TextEntity]))

                                    mode = .comment(commentEntities: [value], afterCommentSpacesEntity: nil)
                                }
                            }
                        case let value as TextStringEntity:
                            if headerEntryCreated || keyValueEntriesCount > 0 {
                                mode = .key(commentEntities: commentEntities, afterCommentSpacesEntity: afterCommentSpacesEntity, keyEntity: value, afterKeySpacesEntity: nil)
                            }
                            else {
                                if !commentEntities.isEmpty, commentEntities.first!.isHeaderCandidate {
                                    if commentEntities.count > 1 {
                                        headerEntryCreated = true
                                        result.append(HeaderEntry(commentEntities: [commentEntities.first!], spaceEntity: nil))
                                        mode = .key(commentEntities: Array(commentEntities[1...]), afterCommentSpacesEntity: afterCommentSpacesEntity, keyEntity: value, afterKeySpacesEntity: nil)
                                    }
                                    else {
                                        headerEntryCreated = true
                                        result.append(HeaderEntry(commentEntities: [commentEntities.first!], spaceEntity: afterCommentSpacesEntity))
                                        mode = .key(commentEntities: [], afterCommentSpacesEntity: nil, keyEntity: value, afterKeySpacesEntity: nil)
                                    }
                                }
                                else {
                                    mode = .key(commentEntities: commentEntities, afterCommentSpacesEntity: afterCommentSpacesEntity, keyEntity: value, afterKeySpacesEntity: nil)
                                }
                            }
                        case let value as TextSpacesEntity:
                            if afterCommentSpacesEntity == nil {
                                mode = .comment(commentEntities: commentEntities, afterCommentSpacesEntity: value)
                            }
                            else {
                                fatalError("Inconsistent parsing: comment after comment!!!")
                            }
                        default:
                            throw LogicalParserError.unexpectedEntity(entity: entity)
                        }

                    case let .key(commentEntities: commentEntities,
                                  afterCommentSpacesEntity: afterCommentSpacesEntity,
                                  keyEntity: keyEntity,
                                  afterKeySpacesEntity: afterKeySpacesEntity):
                        switch entity {
                        case let value as TextServiceEntity:
                            if value.isEquation {
                                mode = .equation(commentEntities: commentEntities,
                                                 afterCommentSpacesEntity: afterCommentSpacesEntity,
                                                 keyEntity: keyEntity,
                                                 afterKeySpacesEntity: afterKeySpacesEntity,
                                                 equationEntity: value,
                                                 afterEquationSpacesEntity: nil)
                            }
                            else {
                                throw LogicalParserError.unexpectedEntity(entity: entity)
                            }

                        case let value as TextSpacesEntity:
                            mode = .key(commentEntities: commentEntities, afterCommentSpacesEntity: afterCommentSpacesEntity, keyEntity: keyEntity, afterKeySpacesEntity: value)

                        default:
                            throw LogicalParserError.unexpectedEntity(entity: entity)
                        }

                    case let .equation(commentEntities: commentEntities, afterCommentSpacesEntity: afterCommentSpacesEntity,
                                       keyEntity: keyEntity, afterKeySpacesEntity: afterKeySpacesEntity,
                                       equationEntity: equationEntity,
                                       afterEquationSpacesEntity: afterEquationSpacesEntity):
                        switch entity {
                        case let value as TextStringEntity:
                            mode = .value(commentEntities: commentEntities,
                                          afterCommentSpacesEntity: afterCommentSpacesEntity,
                                          keyEntity: keyEntity,
                                          afterKeySpacesEntity: afterKeySpacesEntity,
                                          equationEntity: equationEntity,
                                          afterEquationSpacesEntity: afterEquationSpacesEntity,
                                          valueEntity: value,
                                          afterValueSpacesEntity: nil)
                        case let value as TextSpacesEntity:
                            mode = .equation(commentEntities: commentEntities,
                                             afterCommentSpacesEntity: afterCommentSpacesEntity,
                                             keyEntity: keyEntity,
                                             afterKeySpacesEntity: afterKeySpacesEntity,
                                             equationEntity: equationEntity,
                                             afterEquationSpacesEntity: value)
                        default:
                            throw LogicalParserError.unexpectedEntity(entity: entity)
                        }

                    case let .value(commentEntities: commentEntities,
                                    afterCommentSpacesEntity: afterCommentSpacesEntity,
                                    keyEntity: keyEntity,
                                    afterKeySpacesEntity: afterKeySpacesEntity,
                                    equationEntity: equationEntity,
                                    afterEquationSpacesEntity: afterEquationSpacesEntity,
                                    valueEntity: valueEntity,
                                    afterValueSpacesEntity: afterValueSpacesEntity):
                        switch entity {
                        case let value as TextServiceEntity:
                            if value.isSemicomma {
                                mode = .semicomma(commentEntities: commentEntities,
                                                  afterCommentSpacesEntity: afterCommentSpacesEntity,
                                                  keyEntity: keyEntity,
                                                  afterKeySpacesEntity: afterKeySpacesEntity,
                                                  equationEntity: equationEntity,
                                                  afterEquationSpacesEntity: afterEquationSpacesEntity,
                                                  valueEntity: valueEntity,
                                                  afterValueSpacesEntity: afterValueSpacesEntity,
                                                  semicommaEntity: value,
                                                  afterSemicommaSpacesEntity: nil)
                            }
                            else {
                                throw LogicalParserError.unexpectedEntity(entity: entity)
                            }
                        case _ as TextSpacesEntity: break
                        default:
                            throw LogicalParserError.unexpectedEntity(entity: entity)
                        }

                    case let .semicomma(commentEntities: commentEntities,
                                        afterCommentSpacesEntity: afterCommentSpacesEntity,
                                        keyEntity: keyEntity,
                                        afterKeySpacesEntity: afterKeySpacesEntity,
                                        equationEntity: equationEntity,
                                        afterEquationSpacesEntity: afterEquationSpacesEntity,
                                        valueEntity: valueEntity,
                                        afterValueSpacesEntity: afterValueSpacesEntity,
                                        semicommaEntity: semicommaEntity,
                                        afterSemicommaSpacesEntity: afterSemicommaSpacesEntity):

                        switch entity {
                        case let value as TextSpacesEntity:
                            result.append(KeyValueEntry(commentEntities: commentEntities,
                                                        afterCommentSpacesEntity: try (afterCommentSpacesEntity ?? (try TextSpacesEntity.zero())),
                                                        keyEntity: keyEntity,
                                                        afterKeySpacesEntity: try (afterKeySpacesEntity ?? (try TextSpacesEntity.zero())),
                                                        equationEntity: equationEntity,
                                                        afterEquationSpacesEntity: try (afterEquationSpacesEntity ?? (try TextSpacesEntity.zero())),
                                                        valueEntity: valueEntity,
                                                        afterValueSpacesEntity: try (afterValueSpacesEntity ?? (try TextSpacesEntity.zero())),
                                                        semicommaEntity: semicommaEntity,
                                                        afterSemicommaSpacesEntity: value))
                            keyValueEntriesCount += 1
                            mode = .default

                        default:
                            reparse = true
                            result.append(KeyValueEntry(commentEntities: commentEntities,
                                                        afterCommentSpacesEntity: try (afterCommentSpacesEntity ?? (try TextSpacesEntity.zero())),
                                                        keyEntity: keyEntity,
                                                        afterKeySpacesEntity: try (afterKeySpacesEntity ?? (try TextSpacesEntity.zero())),
                                                        equationEntity: equationEntity,
                                                        afterEquationSpacesEntity: try (afterEquationSpacesEntity ?? (try TextSpacesEntity.zero())),
                                                        valueEntity: valueEntity,
                                                        afterValueSpacesEntity: try (afterValueSpacesEntity ?? (try TextSpacesEntity.zero())),
                                                        semicommaEntity: semicommaEntity,
                                                        afterSemicommaSpacesEntity: try (afterSemicommaSpacesEntity ?? (try TextSpacesEntity.zero()))))
                            keyValueEntriesCount += 1
                            mode = .default
                        }
                    }

                } while reparse
            })

            switch mode {
            case .default:
                break

            case .comment:
                break

            case .key:
                throw LogicalParserError.unexpectedEndOfFile(expectedValue: "=")

            case .equation:
                throw LogicalParserError.unexpectedEndOfFile(expectedValue: "Key value")

            case .value:
                throw LogicalParserError.unexpectedEndOfFile(expectedValue: ";")

            case let .semicomma(commentEntities: commentEntities, afterCommentSpacesEntity: afterCommentSpacesEntity,
                                keyEntity: keyEntity, afterKeySpacesEntity: afterKeySpacesEntity,
                                equationEntity: equationEntity, afterEquationSpacesEntity: afterEquationSpacesEntity,
                                valueEntity: valueEntity, afterValueSpacesEntity: afterValueSpacesEntity,
                                semicommaEntity: semicommaEntity, afterSemicommaSpacesEntity: afterSemicommaSpacesEntity):
                allEntries.append(KeyValueEntry(commentEntities: commentEntities,
                                                afterCommentSpacesEntity: try (afterCommentSpacesEntity ?? (try TextSpacesEntity.zero())),
                                                keyEntity: keyEntity,
                                                afterKeySpacesEntity: try (afterKeySpacesEntity ?? (try TextSpacesEntity.zero())),
                                                equationEntity: equationEntity,
                                                afterEquationSpacesEntity: try (afterEquationSpacesEntity ?? (try TextSpacesEntity.zero())),
                                                valueEntity: valueEntity,
                                                afterValueSpacesEntity: try (afterValueSpacesEntity ?? (try TextSpacesEntity.zero())),
                                                semicommaEntity: semicommaEntity,
                                                afterSemicommaSpacesEntity: try (afterSemicommaSpacesEntity ?? (try TextSpacesEntity.zero()))))
                keyValueEntriesCount += 1
            }

            if options.contains(.removeDuplicateKeys) {
                var uniqueKeys = Set<EscapableString>()
                allEntries = allEntries.filter({

                    guard let entry = $0 as? KeyValueEntry else {
                        return true
                    }

                    let key = entry.keyEntity.innerValue
                    if uniqueKeys.contains(key) {
                        return false
                    }

                    uniqueKeys.insert(key)
                    return true
                })
            }
            else {
                var uniqueKeys = Set<EscapableString>()
                let duplicateEntries: Set<EscapableString> = Set(allEntries.compactMap({
                    if let entry = $0 as? KeyValueEntry {
                        let key = entry.keyEntity.innerValue
                        if uniqueKeys.contains(key) {
                            return key
                        }
                        uniqueKeys.insert(key)
                    }
                    return nil
                }))

                if !duplicateEntries.isEmpty {
                    throw LogicalParserError.duplicateKeyEntries(keys: duplicateEntries)
                }
            }
        }
        catch {
            throw error
        }
    }
}
