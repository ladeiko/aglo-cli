//
//  CopyValuesCommand.swift
//  
//
//  Created by Sergey Ladeiko on 23.08.21.
//

import Foundation
import SwiftCLI
import PathKit
import StringsFileParser
import Rollback

public class CopyValuesCommand: Command {

    public let name: String = "copyValues"

    @VariadicKey("--filename", description: "Only files with specified filenames (without extension) will be modified")
    var filenames: [String]

    @VariadicKey("--locale", description: "Only files for specified locales will be modified")
    var locales: [String]

    @Flag("--all", description: "If set, then even non existing values will be copied (with keys creation)")
    var all: Bool

    @Flag("--verbose", description: "Outputs more information")
    var verbose: Bool

    @Param var source: String
    @Param var destination: String

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

            let source = self.source.toPaths()
            let destination = self.destination.toPaths()

            let sourceLocalizedFiles = try LocalizedStringsFile.scan(paths: source,
                                                                     locales: (!locales.isEmpty ? Set(locales.map({ Locale(identifier: $0) })) : nil),
                                                                     filenames: (!filenames.isEmpty ? Set(filenames) : nil))

            let destinationLocalizedFiles = try LocalizedStringsFile.scan(paths: destination,
                                                                     locales: (!locales.isEmpty ? Set(locales.map({ Locale(identifier: $0) })) : nil),
                                                                     filenames: (!filenames.isEmpty ? Set(filenames) : nil))

            var totalCopied = 0
            var totalSkipped = 0

            try sourceLocalizedFiles.forEach({ sourceLocalizedFile in
                try sourceLocalizedFile.files.forEach({ stringsFileEntry in

                    let locale = stringsFileEntry.key
                    let source = stringsFileEntry.value

                    guard let destination = destinationLocalizedFiles.first(where: {
                        $0.filename == source.filename
                    }) else {
                        verboseWarn("Destination not found for '\(source.filename)'")
                        return
                    }

                    guard let file = destination.files[locale] else {
                        verboseWarn("Destination for '\(locale.identifier)' does not exist in '\(destination.filename)'")
                        return
                    }

                    try rollback.protectFile(at: file.path)

                    try source.keys.forEach({ key in

                        guard file.keyExists(key) || all else {
                            verboseWarn("Value for key '\(key.escapedString)' does not exist in '\(file.filename)'")
                            totalSkipped += 1
                            return
                        }

                        try file.setValue(source.valueForKey(key)!, forKey: key)
                        verboseLog("Value for key '\(key.escapedString)' copied to '\(file.filename)'")
                        totalCopied += 1
                    })
                })
            })

            verboseLog("Total values skipped: \(totalSkipped)")
            verboseLog("Total values copied: \(totalCopied)")

            try destinationLocalizedFiles.forEach({
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
