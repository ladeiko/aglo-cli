//
//  ClearKeysCommand.swift
//  CLICommands
//
//  Created by Sergey Ladeiko on 2.09.21.
//

import Foundation
import SwiftCLI
import PathKit
import StringsFileParser
import Rollback
import Utils

enum ClearKeysCommandError: Error, LocalizedError {

    case keyNotFound(key: EscapableString, at: Path)

    var errorDescription: String? {
        switch self {
        case let .keyNotFound(key: key, at: location):
            return "ClearKeysCommand: key '\(key.escapedString)' not found at '\(location.string)'"
        }
    }
}

public class ClearKeysCommand: Command {

    public let name: String = "clearKeys"

    @VariadicKey("--filename", description: "Only files with specified filenames (without extension) will be scanned")
    var filenames: [String]

    @VariadicKey("--locale", description: "Only files for specified locales will be scanned")
    var locales: [String]

    @Key("--untranslated-prefix", description: "Custom prefix for unstranslated strings (default is '\(DefaultUntranslatedPrefixMarker)'")
    var untranslatedPrefix: String?

    @Flag("--add-prefix-only", description: "If set, then just untranslated prefix will be added to key value")
    var addPrefixOnly: Bool

    @Flag("--verbose", description: "Outputs more information")
    var verbose: Bool

    @Flag("--unescape", description: "Unescape key and value strings")
    var unescape: Bool

    @Param var destination: String
    @CollectedParam(minCount: 1) var keys: [String]

    public init() {}

    public func execute() throws {

        let rollback = Rollback()

        do {

            let keys: [EscapableString] = try {
                if unescape {
                    return try self.keys.map({ try EscapableString(escapedString: $0) })
                }
                else {
                    return self.keys.map({ EscapableString(rawString: $0) })
                }
            }()

            let destination = self.destination.toPaths()

            let localizedFiles = try LocalizedStringsFile.scan(paths: destination,
                                                                     locales: (!locales.isEmpty ? Set(locales.map({ Locale(identifier: $0) })) : nil),
                                                                     filenames: (!filenames.isEmpty ? Set(filenames) : nil))

            let placeholder = EscapableString(rawString: untranslatedPrefix ?? DefaultUntranslatedPrefixMarker)

            try localizedFiles.forEach({ localizedFile in
                try localizedFile.files.forEach({ stringsFileEntry in

                    let stringsFile = stringsFileEntry.value

                    try rollback.protectFile(at: stringsFile.path)

                    for key in keys {

                        guard stringsFile.keyExists(key) else {
                            throw ClearKeysCommandError.keyNotFound(key: key, at: stringsFile.path)
                        }

                        if addPrefixOnly {
                            if let value = stringsFile.valueForKey(key) {

                                if value.isUntranslated(untranslatedPrefix) {
                                    continue
                                }

                                try stringsFile.setValue(EscapableString(escapedString: placeholder.escapedString + value.escapedString), forKey: key)
                                continue
                            }
                        }
                        
                        try stringsFile.setValue(placeholder, forKey: key)
                    }
                })
            })

            try localizedFiles.forEach({
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
