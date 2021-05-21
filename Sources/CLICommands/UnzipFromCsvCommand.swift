//
//  UnzipFromCsvCommand.swift
//  CLICommands
//
//  Created by Siarhei Ladzeika on 3.08.21.
//

import Foundation
import SwiftCSV
import SwiftCLI
import PathKit
import StringsFileParser
import Rollback
import Utils

enum UnzipFromCsvCommandError: Error, LocalizedError {
    case didNotFindDestinationFiles(destination: [Path])
    case destinationIsNotADirectory(destination: Path)
    case destinationFileAlreadyExists(destination: Path)
    case invalidInputHeader
    case inputDoesNotExist(path: Path)
    case notFoundKeysInCsv(source: Path)

    var errorDescription: String? {
        switch self {
        case let .notFoundKeysInCsv(source: source):
            return "UnzipFromCsvCommandError: did not find keys in '\(source.string)'"
        case let .didNotFindDestinationFiles(destination: destination):
            return "UnzipFromCsvCommandError: did not find destination files at '\(destination.map({ $0.string }).joined(separator: ","))'"
        case let .destinationIsNotADirectory(destination: destination):
            return "UnzipFromCsvCommandError: destination '\(destination.string)' is not a directory"
        case let .destinationFileAlreadyExists(destination: destination):
            return "UnzipFromCsvCommandError: destination file '\(destination.string)' already exists"
        case .invalidInputHeader:
            return "UnzipFromCsvCommandError: invalid input CSV header"
        case let .inputDoesNotExist(path):
            return "UnzipFromCsvCommandError: input file '\(path.string)' does not exist"
        }
    }
}

public class UnzipFromCsvCommand: Command {

    static let defaultKeyColumnName = "key"

    public let name: String = "unzipFromCsv"

    @Flag("--add-locale", description: "Adds locale if required")
    var addLocale: Bool

    @Flag("--untranslated-only", description: "Override only values with '\(DefaultUntranslatedPrefixMarker)' at the beginning")
    var untranslatedOnly: Bool

    @Key("--untranslated-prefix", description: "Custom prefix for unstranslated strings (default is '\(DefaultUntranslatedPrefixMarker)'")
    var untranslatedPrefix: String?

    @Flag("--create-keys", description: "If source key does not exist in some localized file, then it will be created")
    var createKeys: Bool

    @Flag("--use-global-keys", description: "If key has not file reference like 'Localizable.strings:KEYNAME', then its value will be applied to all output files")
    var useGlobalKeys: Bool

    @VariadicKey("--filename", description: "Only files with specified filenames (without extension) will be modified")
    var filenames: [String]

    @VariadicKey("--locale", description: "Only files for specified locales will be modified")
    var locales: [String]

    @Key("--key-column", description: "Custom column name (by default 'KEY' is used). Case insensitive.")
    var keyColumn: String?

    @Key("--offset", description: "Offset for language columns (zero based), by default is 1. Should be greater than --key-column index", validation: [.within(0...Int.max)])
    var offset: Int?

    @Flag("--verbose", description: "If set, then will output detailed logs")
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

            let source = Path(self.source).absolute()
            let destination = self.destination.toPaths()

            guard source.exists && source.isFile else {
                throw UnzipFromCsvCommandError.inputDoesNotExist(path: source)
            }

            let files = try LocalizedStringsFile.scan(paths: destination,
                                                      locales: (!locales.isEmpty ? Set(locales.map({ Locale(identifier: $0) })) : nil),
                                                      filenames: (!filenames.isEmpty ? Set(filenames) : nil))

            if files.isEmpty {
                throw UnzipFromCsvCommandError.didNotFindDestinationFiles(destination: destination)
            }

            verboseLog({() -> String in
                var messages = ["Destination files:"]
                files.forEach({ file in
                    messages.append(" \(file.filename) (\(file.files.keys.map({ $0.identifier }).sorted().joined(separator: ",")))")
                })
                return messages.joined(separator: "\n")
            }())

            let filesByName: [String: LocalizedStringsFile] = files.reduce(into: [:], { $0[$1.filename] = $1 })

            let csv = try CSV(string: try source.read(.utf8))
            let header = csv.header

            guard let keyColumnIndex: Int = header.firstIndex(where: { $0.lowercased() == (keyColumn?.lowercased() ?? Self.defaultKeyColumnName.lowercased()) }) else {
                throw UnzipFromCsvCommandError.invalidInputHeader
            }

            let offset = max(self.offset ?? 1, keyColumnIndex + 1)

            let inputLocales: [Int: Locale] = header.enumerated().reduce(into: [:], {
                guard $1.offset != keyColumnIndex && $1.offset >= offset else {
                    return
                }
                $0[$1.offset] = Locale(identifier: $1.element)
            })

            var sourceValues: [EscapableString: [Locale: EscapableString]] = [:]

            var thrownError: Error?

            try csv.enumerateAsArray(startAt: 1) { array in

                do {

                    guard thrownError == nil else {
                        return
                    }

                    guard keyColumnIndex < array.count else {
                        return
                    }

                    let key = try EscapableString(escapedString: array[keyColumnIndex])

                    guard !key.isEmpty else {
                        return
                    }

                    var values: [Locale: EscapableString] = [:]

                    try array.map({ try EscapableString(escapedString: $0) }).enumerated().forEach({ translations in

                        guard translations.offset != keyColumnIndex && translations.offset >= (self.offset ?? 1) else {
                            return
                        }

                        guard let locale = inputLocales[translations.offset] else {
                            return
                        }

                        let value = translations.element
                        guard !value.isEmpty else {
                            verboseWarn("CSV key '\(key.escapedString)' has empty value for '\(locale.identifier)'")
                            return
                        }

                        guard !value.isUntranslated(self.untranslatedPrefix) else {
                            verboseWarn("CSV key '\(key.escapedString)' has untranslated value for '\(locale.identifier)'")
                            return
                        }

                        values[locale] = value
                    })

                    if !values.isEmpty {
                        sourceValues[key] = values
                    }
                }
                catch {
                    thrownError = error
                }
            }

            if let thrownError = thrownError {
                throw thrownError
            }

            if sourceValues.isEmpty {
                throw UnzipFromCsvCommandError.notFoundKeysInCsv(source: source)
            }

            verboseLog("Found translations for \(sourceValues.count) keys in CSV")

            try files.forEach({
                try $0.files.forEach({
                    try rollback.protectFile(at: $0.value.path)
                })
            })

            var totallyUpdated = 0

            try sourceValues.forEach({ keyPair in

                let keyWithFilename = keyPair.key
                let keyComponents = keyWithFilename.escapedString.split(separator: ":")

                let (files: files, key: key) = try { () -> (files: [LocalizedStringsFile], key: EscapableString) in

                    let fullFilename = String(keyComponents[0])

                    if keyComponents.count > 1 && fullFilename.fileExtension() == StringsFile.fileExtension {

                        let filename = fullFilename.removingFileExtension()
                        let key = String(keyComponents[1...].joined(separator: ":"))

                        guard let file = filesByName[filename] else {
                            return (files: [], key: try EscapableString(escapedString: key))
                        }

                        return (files: [file], key: try EscapableString(escapedString: key))
                    }
                    else {
                        if useGlobalKeys {
                            return (files: Array(filesByName.values), key: keyWithFilename)
                        }
                        else {
                            return (files: [], key: keyWithFilename)
                        }
                    }
                }()

                let translations = keyPair.value

                try files.forEach({ file in

                    verboseLog("Processing '\(file.filename)'")

                    try translations.forEach({ tPair in
                        let locale = tPair.key
                        let value = tPair.value

                        if !file.hasLocale(locale) {

                            if !addLocale {
                                verboseWarn("File '\(file.filename)' does not have locale '\(locale.identifier)'")
                                return
                            }

                            try file.addLocale(locale, mode: .createNew(copingContentFromLocale: nil))
                            try rollback.deleteFile(at: file.files[locale]!.path)

                            verboseLog("Just created '\(file.filename)/\(locale.identifier)'")
                        }

                        if let existing = file.value(forKey: key, in: locale) {
                            if untranslatedOnly {
                                if !existing.isUntranslated(self.untranslatedPrefix) {
                                    verboseLog("Value for '\(key.escapedString)' skipped in '\(file.filename)/\(locale.identifier)' because it already has translation")
                                    return
                                }
                            }
                        }
                        else {
                            if !createKeys {
                                verboseWarn("Value for '\(key.escapedString)' not found in '\(file.filename)/\(locale.identifier)'")
                                return
                            }
                        }

                        verboseLog("Updated value for '\(key.escapedString)' in '\(file.filename)/\(locale.identifier)'")

                        try file.setValue(value, forKey: key, in: locale)
                        totallyUpdated += 1
                    })
                })
            })

            verboseLog("Totally updated \(totallyUpdated) values")

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
