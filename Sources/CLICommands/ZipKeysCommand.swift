//
//  ZipKeysCommand.swift
//  CLICommands
//
//  Created by Siarhei Ladzeika on 30.07.21.
//

import Foundation
import SwiftCLI
import PathKit
import StringsFileParser
import Utils
import Rollback

enum ZipKeysCommandError: Error, LocalizedError {
    case destinationIsNotADirectory(destination: Path)
    case destinationFileAlreadyExists(destination: Path)
    case importedKeyDoesNotExist(key: EscapableString, filename: String, locale: Locale)

    var errorDescription: String? {
        switch self {
        case let .destinationIsNotADirectory(destination: destination):
            return "ZipKeysCommandError: destination '\(destination.string)' is not a directory"
        case let .destinationFileAlreadyExists(destination: destination):
            return "ZipKeysCommandError: destination file '\(destination.string)' already exists"
        case let .importedKeyDoesNotExist(key, filename, locale):
            return "ZipKeysCommandError: import key '\(key.escapedString)' does not exist in '\(filename)' for '\(locale.identifier)'"
        }
    }
}

public class ZipKeysCommand: Command {

    public static let defaultOutput = "Localizable"

    public let name: String = "zipKeys"

    @Flag("--sort", description: "If defined, then keys will be sorted")
    var sort: Bool

    @Flag("--case-insensitive", description: "Set case insensitive sorting if sort operation")
    var caseInsensitiveSorting: Bool

    @Flag("--force", description: "Overrides destination")
    var force: Bool

    @Flag("--add-absent-keys", description: "Synchronize keys by appending absent keys")
    var addAbsentKeys: Bool

    @Flag("--merge", description: "Adds new keys to existing file")
    var merge: Bool

    @Flag("--update-comments", description: "Update comments in destination file if key already exists")
    var updateComments: Bool

    @Flag("--untranslated-only", description: "Collect values with '\(DefaultUntranslatedPrefixMarker)' at the beginning")
    var untranslatedOnly: Bool

    @Key("--untranslated-prefix", description: "Custom prefix for unstranslated strings (default is '\(DefaultUntranslatedPrefixMarker)'")
    var untranslatedPrefix: String?

    @VariadicKey("--filename", description: "Only files with specified filenames (without extension) will be scanned")
    var filenames: [String]

    @VariadicKey("--locale", description: "Only files for specified locales will be scanned")
    var locales: [String]

    @Key("--output", description: "Output filename (by default '\(ZipKeysCommand.defaultOutput)')")
    var output: String?

    @Flag("--verbose", description: "Outputs more information")
    var verbose: Bool

    @Flag("--override-keys", description: "If set, then existing keys will be overriden")
    var overrideKeys: Bool

    @Flag("--detect-tags", description: "If set, then @@link=###value### tag will be detected")
    var detectTags: Bool

    @Param var source: String
    @Param var destination: String

    public init() {}

    public func execute() throws {

        let rollback = Rollback()

        do {

            stdout <<< locales.joined(separator: ", ")

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

            if addAbsentKeys {
                try files.forEach({
                    try $0.addAbsentKeys()
                })
            }

            let targetLocales = files.reduce(Set<Locale>(), {
                $0.union($1.files.keys)
            })

            let sourceStringsFiles: [Locale: [StringsFile]] = files.reduce(into: [Locale: [StringsFile]](), { result, localizedStringsFile in
                localizedStringsFile.files.forEach({ fileEntry in
                    var files = result[fileEntry.key] ?? []
                    files.append(fileEntry.value)
                    result[fileEntry.key] = files
                })
            })

            let destFolder = destination
            if !destFolder.exists {
                try destFolder.mkpath()
            }

            var requiredLinkedKeys: [String: [Locale: Set<EscapableString>]] = [:]

            if !destFolder.isDirectory {
                throw ZipKeysCommandError.destinationIsNotADirectory(destination: destFolder)
            }

            let output = self.output ?? Self.defaultOutput

            for locale in targetLocales {
                let localeFolder = destFolder + (locale.identifier + "." + LocalizedStringsFile.localeFolderExtension)

                try localeFolder.mkpath()
                let outputFile = localeFolder + (output + "." + StringsFile.fileExtension)

                if outputFile.exists {

                    if !force && !merge {
                        throw ZipKeysCommandError.destinationFileAlreadyExists(destination: outputFile)
                    }

                    try rollback.protectFile(at: outputFile)
                }
                else {
                    try rollback.deleteFile(at: outputFile)
                }

                if !merge {
                    try outputFile.write("")
                }
                else {
                    if !outputFile.exists {
                        try outputFile.write("")
                    }
                }

                let destinationFile = try StringsFile(path: outputFile)
                let sourceFiles = sourceStringsFiles[locale]

                try sourceFiles?.forEach({ sourceFile in
                    try sourceFile.keys.sorted().forEach({ key in

                        if untranslatedOnly, let value = sourceFile.valueForKey(key), !value.isUntranslated(self.untranslatedPrefix) {
                            verboseWarn("Key '\(key.escapedString)' is translated")
                            return
                        }

                        if detectTags, let link = sourceFile.valueForTag("link",in: key) {
                            let loc = try link.parseAsStringsFilenameAndKey()
                            var locales = requiredLinkedKeys[loc.filename] ?? [:]
                            var keys = locales[locale] ?? Set()
                            keys.insert(try EscapableString(escapedString: loc.key))
                            locales[locale] = keys
                            requiredLinkedKeys[loc.filename] = locales
                            return
                        }

                        let destKey = try EscapableString(escapedString: "\(sourceFile.path.lastComponent):\(key.escapedString)")

                        if destinationFile.keyExists(destKey) {
                            if !overrideKeys {

                                verboseLog("Key '\(destKey.escapedString)' already exists in '\(destinationFile.path.string)'")

                                if updateComments {
                                    try sourceFile.copyComment(fromKey: key, toFile: destinationFile, toKey: destKey)
                                    verboseLog("Comment for key '\(destKey.escapedString)' updated in '\(destinationFile.path.string)'")
                                }

                                return
                            }

                            verboseWarn("Key '\(destKey)' will be overriden in '\(destinationFile.path.string)'")
                        }

                        try sourceFile.copy(key: key, to: destinationFile, asKey: destKey)

                        verboseLog("Key copied '\(key.escapedString)' from '\(sourceFile.path.string)' to '\(destinationFile.path.string)'")
                    })
                })

                if sort {
                    if caseInsensitiveSorting {
                        try destinationFile.sort(by: { $0.rawString.lowercased() < $1.rawString.lowercased() })
                    }
                    else {
                        try destinationFile.sort()
                    }
                }

                try destinationFile.save()
            }

            try requiredLinkedKeys.forEach({
                let filename = $0.key
                let locales = $0.value
                try locales.forEach({
                    let locale = $0.key
                    let keys = $0.value
                    try keys.forEach({
                        let key = $0
                        let files = sourceStringsFiles[locale]

                        guard let file = files?.filter({ $0.filename == filename }).first else {
                            throw ZipKeysCommandError.importedKeyDoesNotExist(key: key, filename: filename, locale: locale)
                        }

                        guard file.keyExists(key) else {
                            throw ZipKeysCommandError.importedKeyDoesNotExist(key: key, filename: filename, locale: locale)
                        }
                    })
                })
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
