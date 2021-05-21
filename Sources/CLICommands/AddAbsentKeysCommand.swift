//
//  AddAbsentKeysCommand.swift
//  CLICommands
//
//  Created by Sergey Ladeiko on 8.09.21.
//

import Foundation
import SwiftCLI
import PathKit
import StringsFileParser
import Rollback
import Utils

public class AddAbsentKeysCommand: Command {

    public let name: String = "addAbsentKeys"

    @VariadicKey("--filename", description: "Only files with specified filenames (without extension) will be modified")
    var filenames: [String]

    @VariadicKey("--locale", description: "Only files for specified locales will be modified")
    var locales: [String]

    @Key("--untranslated-prefix", description: "Custom prefix for unstranslated strings (default is '\(DefaultUntranslatedPrefixMarker)'")
    var untranslatedPrefix: String?

    @Flag("--verbose", description: "Outputs more information")
    var verbose: Bool

    @Param var source: String

    public init() {}

    public func execute() throws {

        let rollback = Rollback()

        do {

            let placeholder = EscapableString(rawString: untranslatedPrefix ?? DefaultUntranslatedPrefixMarker)
            let source = self.source.toPaths()
            let sourceLocalizedFiles = try LocalizedStringsFile.scan(paths: source,
                                                                     locales: (!locales.isEmpty ? Set(locales.map({ Locale(identifier: $0) })) : nil),
                                                                     filenames: (!filenames.isEmpty ? Set(filenames) : nil))

            try sourceLocalizedFiles.forEach({

                try $0.files.forEach({
                    try rollback.protectFile(at: $0.value.path)
                })

                try $0.addAbsentKeys(fillAbsentValuesWith: placeholder)
            })

            try sourceLocalizedFiles.forEach({
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

