//
//  MakeKeysTranslatedCommand.swift
//  CLICommands
//
//  Created by Sergey Ladeiko on 3.09.21.
//

import Foundation
import SwiftCLI
import PathKit
import StringsFileParser
import Rollback
import Utils

public enum MakeKeysTranslatedCommandError: Error, LocalizedError {
    case valueIsEmpty(key: EscapableString, at: Path)

    public var errorDescription: String? {
        switch self {
        case let .valueIsEmpty(key: key, at: path):
            return "MakeKeysTranslatedCommandError: value for '\(key.escapedString)' is empty at '\(path.string)'"
        }
    }
}

public class MakeKeysTranslatedCommand: Command {

    public let name: String = "makeKeysTranslated"

    @VariadicKey("--filename", description: "Only files with specified filenames (without extension) will be scanned")
    var filenames: [String]

    @VariadicKey("--locale", description: "Only files for specified locales will be scanned")
    var locales: [String]

    @Key("--untranslated-prefix", description: "Custom prefix for unstranslated strings (default is '\(DefaultUntranslatedPrefixMarker)'")
    var untranslatedPrefix: String?

    @Flag("--ignore-empty", description: "If set, then empty values will be treated as OK")
    var ignoreEmpty: Bool

    @Flag("--unescape", description: "Unescape key and value strings")
    var unescape: Bool

    @Flag("--verbose", description: "Outputs more information")
    var verbose: Bool

    @Param var destination: String
    @CollectedParam(minCount: 1) var keys: [String]

    public init() {}

    public func execute() throws {

        let rollback = Rollback()

        do {

            func verboseLog(_ message: @autoclosure () -> String) {
                if verbose {
                    stdout <<< message()
                }
            }

            func verboseWarn(_ message: @autoclosure () -> String) {
                if verbose {
                    stdout <<< "[WARNING]: " + message()
                }
            }

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
            try localizedFiles.forEach({ localizedFile in
                try localizedFile.files.forEach({ stringsFileEntry in

                    let stringsFile = stringsFileEntry.value

                    try rollback.protectFile(at: stringsFile.path)

                    for key in keys {

                        verboseLog("Locating \(stringsFile.filename):\(key.escapedString)")

                        if let value = stringsFile.valueForKey(key) {

                            verboseLog("Processing \(stringsFile.filename):\(key.escapedString)")

                            guard value.isUntranslated(untranslatedPrefix) else {
                                continue
                            }

                            let prefix = untranslatedPrefix ?? DefaultUntranslatedPrefixMarker

                            if value.rawString.hasPrefix(prefix) {

                                let rawValue = value.rawString
                                let newValue = EscapableString(rawString: String(rawValue[rawValue.index(rawValue.startIndex, offsetBy: prefix.count)...]))

                                if newValue.isEmpty {
                                    if !ignoreEmpty {
                                        throw MakeKeysTranslatedCommandError.valueIsEmpty(key: key, at: stringsFile.path)
                                    }
                                }

                                verboseLog("New value for '\(stringsFile.filename):\(key.escapedString)' is '\(newValue)'")

                                try stringsFile.setValue(newValue, forKey: key)
                            }

                        }
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

