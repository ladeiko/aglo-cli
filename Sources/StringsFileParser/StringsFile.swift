//
//  StringsFile.swift
//  StringsFileParser
//
//  Created by Siarhei Ladzeika on 21.05.21.
//

import Foundation
import PathKit
import Utils

public enum StringsFileError: Error, LocalizedError {
    case keyNotFound(key: EscapableString)
    case passthrough(error: Error, at: StringsFile)

    public var errorDescription: String? {
        switch self {
            case let .keyNotFound(key):
                return "StringsFileError: '\(key.escapedString)' key not found"
            case let .passthrough(error, at):
                if let error = error as? LocalizedError, let errorDescription = error.errorDescription {
                    return "\(errorDescription) in \(at.path.string)'"
                }
                else {
                    return "\(error) in \(at.path.string)'"
                }
        }
    }
}

public class StringsFile {

    // MARK: - Public

    public static let fileExtension = "strings"
    public static let defaultEncoding: String.Encoding = .utf8

    public init(path: Path, options: LogicalParserOptions = []) throws {
        self.path = path
        try load(options: options)
    }

    public var string: String {
        parser.compose()
    }

    public func load(options: LogicalParserOptions = []) throws {
        do {
            hasChanges = false
            let string = try String(contentsOf: path.url, usedEncoding: &encoding)
            try parser.parse(string: string, options: options)
        }
        catch {
            throw StringsFileError.passthrough(error: error, at: self)
        }
    }

    public func save(force: Bool = false) throws {
        do {
            guard hasChanges || force else { return }
            let string = parser.compose()
            try path.write(string, encoding: encoding)
            hasChanges = false
        }
        catch {
            throw StringsFileError.passthrough(error: error, at: self)
        }
    }

    public func valueForKey(_ key: EscapableString) -> EscapableString? {
        parser.valueForKey(key)
    }

    public func commentForKey(_ key: EscapableString) -> EscapableString? {
        parser.commentForKey(key)
    }

    public func valueForTag(_ tag: String, in key: EscapableString) -> String? {
        parser.valueForTag(tag, in: key)
    }

    public func keyExists(_ key: EscapableString) -> Bool {
        parser.keyExists(key)
    }

    public func renameKey(_ key: EscapableString, to newKey: EscapableString) throws {
        do {
            hasChanges = true
            try parser.renameKey(key, to: newKey)
        }
        catch {
            throw StringsFileError.passthrough(error: error, at: self)
        }
    }

    public func setValue(_ value: EscapableString, forKey key: EscapableString) throws {
        do {
            hasChanges = true
            try parser.setValue(value, forKey: key)
        }
        catch {
            throw StringsFileError.passthrough(error: error, at: self)
        }
    }

    public func removeValueForKey(_ key: EscapableString) throws {
        do { hasChanges = true
            try parser.removeValueForKey(key)
        }
        catch {
            throw StringsFileError.passthrough(error: error, at: self)
        }
    }

    public func removeValueForTag(_ tag: String, forKey key: EscapableString) throws {
        do {
            hasChanges = true
            try parser.removeValueForTag(tag, forKey: key)

        }
        catch {
            throw StringsFileError.passthrough(error: error, at: self)
        }
    }

    public func setValueForTag(_ tag: String, forKey key: EscapableString, to value: EscapableString) throws {
        do {
            hasChanges = true
            try parser.setValueForTag(tag, forKey: key, to: value)
        }
        catch {
            throw StringsFileError.passthrough(error: error, at: self)
        }
    }

    public func sort(by: ((_ key1: EscapableString, _ key2: EscapableString) -> Bool)? = nil) throws {
        do {
            hasChanges = true
            try parser.sort(by: by)
        }
        catch {
            throw StringsFileError.passthrough(error: error, at: self)
        }
    }

    public func copy(key: EscapableString, to destinationFile: StringsFile, asKey destinationKey: EscapableString? = nil) throws {
        do {
            guard let entry = parser.keyValueEntry(forKey: key) else {
                throw StringsFileError.keyNotFound(key: key)
            }

            let newKey = destinationKey ?? key

            destinationFile.hasChanges = true
            try destinationFile.parser.setEntry(entry, forKey: newKey)
        }
        catch {
            throw StringsFileError.passthrough(error: error, at: self)
        }
    }

    public func setComment(_ comment: EscapableString, forKey key: EscapableString) throws {
        do {
            hasChanges = true
            try parser.setComment(comment, forKey: key)
        }
        catch {
            throw StringsFileError.passthrough(error: error, at: self)
        }
    }

    public func copyComment(fromKey sourceKey: EscapableString, toFile destinationFile: StringsFile, toKey destinationKey: EscapableString? = nil) throws {
        do {
            guard let entry = parser.keyValueEntry(forKey: sourceKey) else {
                throw StringsFileError.keyNotFound(key: sourceKey)
            }

            let newKey = destinationKey ?? sourceKey

            destinationFile.hasChanges = true
            try destinationFile.parser.set(commentEntities: entry.commentEntities, forKey: newKey)
        }
        catch {
            throw StringsFileError.passthrough(error: error, at: self)
        }
    }

    public func move(key: EscapableString, to destinationFile: StringsFile, asKey destinationKey: EscapableString? = nil) throws {
        do {
            try copy(key: key, to: destinationFile, asKey: destinationKey)
            try removeValueForKey(key)
        }
        catch {
            throw StringsFileError.passthrough(error: error, at: self)
        }
    }

    public func prettify() throws {
        do {
            hasChanges = true
            try parser.prettify()
        }
        catch {
            throw StringsFileError.passthrough(error: error, at: self)
        }
    }

    public let path: Path

    public var filename: String {
        path.lastComponentWithoutExtension
    }

    public private (set) var encoding: String.Encoding = StringsFile.defaultEncoding
    public private (set) var hasChanges = false

    public var keys: Set<EscapableString> {
        parser.keys
    }

    public var entries: [KeyValueEntry] {
        parser.entries
    }

    // MARK: - Private

    private let parser: LogicalParser = LogicalParser()
}
