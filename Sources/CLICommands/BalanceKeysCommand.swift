//
//  BalanceKeysCommand.swift
//  
//
//  Created by Sergey Ladeiko on 6.12.21.
//

import Foundation
import SwiftCLI
import PathKit
import StringsFileParser
import Rollback
import Utils

public class BalanceKeysCommand: Command {

    public let name: String = "balanceKeys"

    @VariadicKey("--filename", description: "Only files with specified filenames (without extension) will be scanned")
    var filenames: [String]

    @VariadicKey("--locale", description: "Only files for specified locales will be scanned")
    var locales: [String]

    @Key("--untranslated-prefix", description: "Custom prefix for unstranslated strings (default is '\(DefaultUntranslatedPrefixMarker)'")
    var untranslatedPrefix: String?

    @Flag("--verbose", description: "Outputs more information")
    var verbose: Bool

    @Flag("--unescape", description: "Unescape key strings")
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

            let destination = self.destination.toPaths()

            let localizedFiles = try LocalizedStringsFile.scan(paths: destination,
                                                               locales: (!locales.isEmpty ? Set(locales.map({ Locale(identifier: $0) })) : nil),
                                                               filenames: (!filenames.isEmpty ? Set(filenames) : nil))

            let placeholder = EscapableString(rawString: untranslatedPrefix ?? DefaultUntranslatedPrefixMarker)

            try localizedFiles.forEach({ localizedFile in

                let allKeys = localizedFile.allKeys()

                try localizedFile.files.forEach({ stringsFileEntry in

                    let stringsFile = stringsFileEntry.value

                    try rollback.protectFile(at: stringsFile.path)

                    for key in keys {

                        guard allKeys.contains(key) else {
                            continue
                        }

                        if !stringsFile.keyExists(key) {
                            try stringsFile.setValue(placeholder, forKey: key)
                            verboseLog("Added '\(key.escapedString)' to '\(stringsFile.path.string)'")
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
