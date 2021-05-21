//
//  SetValueCommand.swift
//  Utils
//
//  Created by Siarhei Ladzeika on 8/21/21.
//

import Foundation
import SwiftCLI
import PathKit
import StringsFileParser
import Utils
import Rollback

enum SetValueCommandError: Error, LocalizedError {

    case didNotFindDestinationFiles(destination: [Path])
    case keyDoesNotExist(key: EscapableString, destination: Path)
    case valueIsNotUntranslated(forKey: EscapableString, destination: Path)

    var errorDescription: String? {
        switch self {
        case let .didNotFindDestinationFiles(destination: destination):
            return "SetValueCommandError: did not find destination files at '\(destination.map({ $0.string }).joined(separator: ","))'"
        case let .keyDoesNotExist(key: key, destination: destination):
            return "SetValueCommandError: key '\(key.escapedString)' does not exist at '\(destination.string)'"
        case let .valueIsNotUntranslated(forKey: key, destination: destination):
            return "SetValueCommandError: value for key '\(key.escapedString)' is not untranslated at '\(destination.string)'"
        }
    }
}

public class SetValueCommand: Command {

    public let name: String = "setValue"

    @VariadicKey("--filename", description: "Only files with specified filenames (without extension) will be scanned")
    var filenames: [String]

    @VariadicKey("--locale", description: "Only files for specified locales will be scanned")
    var locales: [String]

    @Flag("--untranslated-only", description: "Set value only if it has '\(DefaultUntranslatedPrefixMarker)' at the beginning")
    var untranslatedOnly: Bool

    @Key("--untranslated-prefix", description: "Custom prefix for unstranslated strings (default is '\(DefaultUntranslatedPrefixMarker)'")
    var untranslatedPrefix: String?

    @Flag("--create-key", description: "Creates value if it does not exist, in another case error will be returned")
    var createKey: Bool

    @Flag("--unescape", description: "Unescape key and value strings")
    var unescape: Bool

    @Flag("--verbose", description: "Outputs more information")
    var verbose: Bool

    @Param var destination: String
    @Param var key: String
    @Param var value: String?

    public init() {}

    public func execute() throws {

        let rollback = Rollback()

        do {

            let key: EscapableString = try {
                if unescape {
                    return try EscapableString(escapedString: self.key)
                }
                else {
                    return EscapableString(rawString: self.key)
                }
            }()

            let value: EscapableString? = try {
                if unescape, let value = self.value {
                    return try EscapableString(escapedString: value)
                }
                else {
                    return self.value != nil ? EscapableString(rawString: self.value!) : nil
                }
            }()

            let destination = self.destination.toPaths()

            let files = try LocalizedStringsFile.scan(paths: destination,
                                                      locales: (!locales.isEmpty ? Set(locales.map({ Locale(identifier: $0) })) : nil),
                                                      filenames: (!filenames.isEmpty ? Set(filenames) : nil))

            if files.isEmpty {
                throw SetValueCommandError.didNotFindDestinationFiles(destination: destination)
            }

            let sourceStringsFiles: [Locale: [StringsFile]] = files.reduce(into: [Locale: [StringsFile]](), { result, localizedStringsFile in
                localizedStringsFile.files.forEach({ fileEntry in
                    var files = result[fileEntry.key] ?? []
                    files.append(fileEntry.value)
                    result[fileEntry.key] = files
                })
            })

            try sourceStringsFiles.forEach({
                try $0.value.forEach({

                    try rollback.protectFile(at: $0.path)

                    if !$0.keyExists(key) {
                        if !createKey {
                            throw SetValueCommandError.keyDoesNotExist(key: key, destination: $0.path)
                        }
                    }

                    if let value = value {
                        if untranslatedOnly {
                            if let existingValue = $0.valueForKey(key) {
                                guard existingValue.isUntranslated(untranslatedPrefix) else {
                                    throw SetValueCommandError.valueIsNotUntranslated(forKey: key, destination: $0.path)
                                }
                            }
                        }

                        try $0.setValue(value, forKey: key)
                    }
                    else {
                        try $0.removeValueForKey(key)
                    }
                })
            })

            try files.forEach({
                try $0.save()
            })

        }
        catch {

            do {
                try rollback.restore()
            }
            catch {
                stderr <<< "\(error)"
            }

            throw error
        }
    }
}
