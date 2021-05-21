//
//  GetValueCommand.swift
//  CLICommandsTests
//
//  Created by Siarhei Ladzeika on 8/22/21.
//

import Foundation
import SwiftCLI
import PathKit
import StringsFileParser
import Utils

enum GetValueCommandError: Error, LocalizedError {

    case didNotFindDestinationFiles(source: [Path])
    case onlyOneInputFileAllowed(source: [Path])
    case keyDoesNotExist(key: EscapableString, source: Path)
    case valueIsUntranslated(forKey: EscapableString, source: Path)
    case valueDoesNotExist(forKey: EscapableString, at: Path)

    var errorDescription: String? {
        switch self {
        case let .didNotFindDestinationFiles(source: source):
            return "GetValueCommandError: did not find destination files at '\(source.map({ $0.string }).joined(separator: ","))'"
        case let .onlyOneInputFileAllowed(source: source):
            return "GetValueCommandError: only one input file allowed at '\(source.map({ $0.string }).joined(separator: ","))'"
        case let .keyDoesNotExist(key: key, source: source):
            return "GetValueCommandError: key '\(key.escapedString)' does not exist at '\(source.string)'"
        case let .valueIsUntranslated(forKey: key, source: source):
            return "GetValueCommandError: value for key '\(key.escapedString)' is untranslated at '\(source.string)'"
        case let .valueDoesNotExist(forKey: key, at: path):
            return "GetValueCommandError: value for key '\(key.escapedString)' does not exist at '\(path.string)'"
        }
    }
}

public class GetValueCommand: Command {

    public let name: String = "getValue"

    @Key("--filename", description: "Sets filename to read value (without extension)")
    var filename: String?

    @Key("--locale", description: "Sets locale of file to read (if many of them are located in specified folder)")
    var locale: String?

    @Flag("--untranslated-as-error", description: "If set, then error is returned if value has '\(DefaultUntranslatedPrefixMarker)' at the beginning")
    var untranslatedAsError: Bool

    @Key("--untranslated-prefix", description: "Custom prefix for unstranslated strings (default is '\(DefaultUntranslatedPrefixMarker)'")
    var untranslatedPrefix: String?

    @Flag("--fail-on-nil", description: "If set, then command fails if value does not exist")
    var failOnNil: Bool

    @Flag("--unescape", description: "Unescape key and value strings")
    var unescape: Bool

    @Flag("--escape-result", description: "Escape resulting value")
    var escapeResult: Bool

    @Param var source: String
    @Param var key: String

    public init() {}

    public func execute() throws {

        let key: EscapableString = try {
            if unescape {
                return try EscapableString(escapedString: self.key)
            }
            else {
                return EscapableString(rawString: self.key)
            }
        }()

        let source = self.source.toPaths()

        let files = try LocalizedStringsFile.scan(paths: source,
                                                  locales: (locale != nil ? Set([locale!].map({ Locale(identifier: $0) })) : nil),
                                                  filenames: (filename != nil ? Set([filename!]) : nil))

        if files.isEmpty {
            throw GetValueCommandError.didNotFindDestinationFiles(source: source)
        }

        guard files.count == 1 && files.first!.files.count == 1 else {
            throw GetValueCommandError.onlyOneInputFileAllowed(source: source)
        }

        let sourceStringsFile = files.first!.files.first!.value

        if let value = sourceStringsFile.valueForKey(key) {

            if value.isUntranslated(untranslatedPrefix) && untranslatedAsError {
                throw GetValueCommandError.valueIsUntranslated(forKey: key, source: sourceStringsFile.path)
            }

            stdout <<< (escapeResult ? value.escapedString : value.rawString)
        }
        else {
            if failOnNil {
                throw GetValueCommandError.valueDoesNotExist(forKey: key, at: sourceStringsFile.path)
            }
        }

    }
}
