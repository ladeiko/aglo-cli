//
//  ZipToCsvCommand.swift
//  CLICommands
//
//  Created by Siarhei Ladzeika on 3.08.21.
//

import Foundation
import SwiftCLI
import PathKit
import StringsFileParser
import Utils
import Rollback

enum ZipToCsvCommandError: Error, LocalizedError {
    case destinationIsNotADirectory(destination: Path)
    case destinationFileAlreadyExists(destination: Path)

    var errorDescription: String? {
        switch self {
        case let .destinationIsNotADirectory(destination: destination):
            return "ZipToCsvCommandError: destination '\(destination.string)' is not a directory"
        case let .destinationFileAlreadyExists(destination: destination):
            return "ZipToCsvCommandError: destination file '\(destination.string)' already exists"
        }
    }
}

func csvEscape(_ s: String) -> String {
    if s.isEmpty {
        return ""
    }
    var o = ""
    var containsQuotes = false
    for c in s {
        if c == "\"" {
            o += "\"\""
            containsQuotes = true
        }
        else if c == "\n" {
            o += "\\n"
            containsQuotes = true
        }
        else {
            if c == "," {
                containsQuotes = true
            }
            o += String(c)
        }
    }
    if containsQuotes {
        return "\"" + o + "\""
    }
    else {
        return o
    }
}

public class ZipToCsvCommand: Command {

    public let name: String = "zipToCsv"

    @Flag("--force", description: "Overrides destination")
    var force: Bool

    @VariadicKey("--filename", description: "Only files with specified filenames (without extension) will be scanned")
    var filenames: [String]

    @VariadicKey("--locale", description: "Only files for specified locales will be scanned")
    var locales: [String]

    @Flag("--untranslated-only", description: "Collect values with '\(DefaultUntranslatedPrefixMarker)' at the beginning")
    var untranslatedOnly: Bool

    @Key("--untranslated-prefix", description: "Custom prefix for unstranslated strings (default is '\(DefaultUntranslatedPrefixMarker)'")
    var untranslatedPrefix: String?

    @Key("--first-locale", description: "Sets locale to be first (default is 'en')")
    var firstLocale: String?

    @Flag("--without-filename-prefix", description: "If defined, then key will not contains filename prefix")
    var withoutFileNamePrefix: Bool

    @Flag("--escape", description: "If defined, then key and value strings will be escaped")
    var escape: Bool

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
            let destination = Path(self.destination).absolute()

            let files = try LocalizedStringsFile.scan(paths: source,
                                                      locales: (!locales.isEmpty ? Set(locales.map({ Locale(identifier: $0) })) : nil),
                                                      filenames: (!filenames.isEmpty ? Set(filenames) : nil))

            let sourceStringsFiles: [Locale: [StringsFile]] = files.reduce(into: [Locale: [StringsFile]](), { result, localizedStringsFile in
                localizedStringsFile.files.forEach({ fileEntry in
                    var files = result[fileEntry.key] ?? []
                    files.append(fileEntry.value)
                    result[fileEntry.key] = files
                })
            })

            let destFile = destination
            if !destFile.parent().exists {
                try destFile.parent().mkpath()
            }

            if destFile.exists {

                if !force {
                    throw ZipToCsvCommandError.destinationFileAlreadyExists(destination: destFile)
                }

                try rollback.protectFile(at: destFile)
            }
            else {
                try rollback.deleteFile(at: destFile)
            }

            let firstLocale = self.firstLocale ?? "en"

            let allLocales = sourceStringsFiles.keys.sorted(by: {

                if $0.identifier == firstLocale {
                    return true
                }

                if $1.identifier == firstLocale {
                    return false
                }

                return $0.identifier < $1.identifier
            })

            let localesIndexes: [Int: Locale] = allLocales.enumerated().reduce(into: [:], { $0[$1.offset] = $1.element })
            let csvHeader = "KEY," + allLocales.map({ $0.identifier }).joined(separator: ",")

            var resultingCsv = csvHeader + "\n"

            var totalExported = 0

            for file in files.sorted(by: { $0.filename.lowercased() < $1.filename.lowercased() }) {
                let allKeys = Array(file.allKeys()).sorted()
                for key in allKeys {

                    let keyPrefix = withoutFileNamePrefix ? "" : (file.filename + "." + StringsFile.fileExtension + ":")
                    var row = csvEscape(keyPrefix +  (escape ? key.escapedString : key.rawString))

                    var hasUntranslatedValues = false

                    for i in 0..<localesIndexes.count {
                        let locale = localesIndexes[i]!
                        let value = file.value(forKey: key, in: locale) ?? EscapableString(rawString: "")

                        if value.isUntranslated(self.untranslatedPrefix) {
                            hasUntranslatedValues = true
                        }

                        row += "," + csvEscape(escape ? value.escapedString : value.rawString)
                    }

                    if untranslatedOnly && !hasUntranslatedValues {
                        verboseWarn("Key '\(key.escapedString)' from '\(file.filename)' skipped, because it has no untranslated values")
                        continue
                    }

                    resultingCsv += row + "\n"
                    totalExported += 1

                    verboseLog("Key '\(key.escapedString)' from '\(file.filename)' exported")
                }
            }

            try destFile.write(resultingCsv, encoding: .utf8)

            verboseLog("Total keys exported: \(totalExported)")
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
