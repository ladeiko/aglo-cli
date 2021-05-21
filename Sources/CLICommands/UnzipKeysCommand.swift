//
//  UnzipCommand.swift
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

enum UnzipKeysCommandError: Error, LocalizedError {
    case invalidKey(key: EscapableString)
    case linkedSourceFileNotFound(filename: String)
    case linkedSourceLocaleNotFound(filename: String, locale: Locale)
    case linkedSourceKeyNotFound(filename: String, locale: Locale, key: EscapableString)
    var errorDescription: String? {
        switch self {
        case let .invalidKey(key: key):
            return "UnzipKeysCommandError: invalid key '\(key.escapedString)'"
        case let .linkedSourceFileNotFound(filename):
            return "UnzipKeysCommandError: linked source file not found '\(filename)'"
        case let .linkedSourceLocaleNotFound(filename, locale):
            return "UnzipKeysCommandError: linked source file locale '\(locale.identifier)' not found for '\(filename)'"
        case let .linkedSourceKeyNotFound(filename, locale, key):
            return "UnzipKeysCommandError: linked source key '\(key.escapedString)' not found in locale '\(locale.identifier)' for '\(filename)'"
        }
    }
}

public class UnzipKeysCommand: Command {

    private static let defaultSource = "Localizable"

    public let name: String = "unzipKeys"

    @VariadicKey("--filename", description: "Only files with specified filenames (without extension) will be scanned")
    var filenames: [String]

    @VariadicKey("--locale", description: "Only files for specified locales will be scanned")
    var locales: [String]

    @Key("--source", description: "Source filename (by default '\(UnzipKeysCommand.defaultSource)')")
    var sourceFileName: String?

    @Flag("--translated-only", description: "Unzip only values without '\(DefaultUntranslatedPrefixMarker)' at the beginning")
    var translatedOnly: Bool

    @Key("--untranslated-prefix", description: "Custom prefix for unstranslated strings (default is '\(DefaultUntranslatedPrefixMarker)'")
    var untranslatedPrefix: String?

    @Flag("--detect-tags", description: "If set, then @@link=###value### tag will be detected")
    var detectTags: Bool

    @Flag("--ignore-invalid-source-keys", description: "Ignore source keys with invalid format")
    var ignoreInvalidSourceKeys: Bool

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
                                                                     filenames: (sourceFileName != nil ? Set([sourceFileName!]) : nil))

            let destinationLocalizedFiles = try LocalizedStringsFile.scan(paths: destination,
                                                                          locales: (!locales.isEmpty ? Set(locales.map({ Locale(identifier: $0) })) : nil),
                                                                          filenames: (!filenames.isEmpty ? Set(filenames) : nil))

            verboseLog("Source files: \(sourceLocalizedFiles.map({ $0.filename }).joined(separator: ","))")
            verboseLog("Target files: \(destinationLocalizedFiles.map({ $0.filename }).joined(separator: ","))")

            var keysUnzipped = 0
            var keysNotFound = 0
            var keysSkipped = 0
            var keysImported = 0

            struct LinkedKey: Hashable {
                let fromFile: String
                let fromKey: EscapableString
                let toKey: EscapableString
            }

            var linkedKeys: [String: [Locale: Set<LinkedKey>]] = [:]

            try sourceLocalizedFiles.forEach({ sourceLocalizedFile in
                try sourceLocalizedFile.files.forEach({ sourceLocalizedFileEntry in

                    let sourceLocale = sourceLocalizedFileEntry.key
                    let sourceStringsFile = sourceLocalizedFileEntry.value

                    struct Key {
                        let filename: String
                        let key: EscapableString
                        let fullKey: EscapableString
                    }

                    let sourceKeys: [Key] = try sourceStringsFile.keys.compactMap({ k in

                        let parts = k.rawString.split(separator: ":")
                        let filename = String(parts[0])

                        if parts.count == 1 || filename.fileExtension() != StringsFile.fileExtension {

                            if ignoreInvalidSourceKeys {
                                verboseWarn("Invalid source key '\(k.rawString)' skipped")
                                return nil
                            }

                            throw UnzipKeysCommandError.invalidKey(key: k)
                        }

                        let key = EscapableString(rawString: String(parts[1...].joined(separator: ":")))

                        return Key(filename: filename.removingFileExtension(), key: key, fullKey: k)
                    })

                    try sourceKeys.forEach({ sourceKey in

                        let destinationLocalizedFile = destinationLocalizedFiles.first(where: {
                            $0.filename == sourceKey.filename
                        })

                        if let destinationLocalizedFile = destinationLocalizedFile,
                           let value = sourceStringsFile.valueForKey(sourceKey.fullKey) {

                            if translatedOnly && value.isUntranslated(untranslatedPrefix) {
                                keysSkipped += 1
                                verboseLog("Key '\(sourceKey.filename):\(sourceKey.fullKey.escapedString)' skipped, because untranslated")
                                return
                            }

                            if detectTags, let link = destinationLocalizedFile.valueForTag("link", for: sourceKey.key, in: sourceLocale) {

                                verboseLog("Link tag detected in '\(destinationLocalizedFile.filename):\(sourceKey.key.escapedString):\(sourceLocale.identifier)'")

                                keysImported += 1

                                let loc = try link.parseAsStringsFilenameAndKey()
                                var locales = linkedKeys[destinationLocalizedFile.filename] ?? [:]
                                var keys = locales[sourceLocale] ?? Set()
                                keys.insert(.init(fromFile: loc.filename, fromKey: try EscapableString(escapedString: loc.key), toKey: sourceKey.key))
                                locales[sourceLocale] = keys
                                linkedKeys[destinationLocalizedFile.filename] = locales
                                return
                            }

                            try destinationLocalizedFile.files.values.forEach({
                                try rollback.protectFile(at: $0.path)
                            })

                            if destinationLocalizedFile.keyExists(sourceKey.key, in: sourceLocale) {

                                verboseLog("Setting key '\(destinationLocalizedFile.filename):\(sourceKey.key.escapedString):\(sourceLocale.identifier)'")

                                try destinationLocalizedFile.setValue(value, forKey: sourceKey.key, in: sourceLocale)

                                keysUnzipped += 1
                                verboseLog("Key '\(sourceKey.filename):\(sourceKey.fullKey.escapedString)' unzipped")
                            }
                            else {
                                keysNotFound += 1
                                verboseLog("Key '\(destinationLocalizedFile.filename):\(sourceKey.key.escapedString):\(sourceLocale.identifier)' skipped, because unused")
                            }
                        }
                        else {
                            keysNotFound += 1
                            verboseWarn("Key '\(sourceKey.filename):\(sourceKey.fullKey.escapedString)' not found")
                        }
                    })

                })
            })

            try linkedKeys.forEach({

                let filename = $0.key
                let locales = $0.value

                try locales.forEach({

                    let locale = $0.key
                    let keys = $0.value
                    try keys.forEach({

                        let fromFile = $0.fromFile
                        let fromKey = $0.fromKey
                        let toKey = $0.toKey

                        verboseLog("Importing key '\(filename):\(toKey.escapedString)' from '\(fromFile):\(fromKey.escapedString)'")

                        guard let sourceLocalizedFile = destinationLocalizedFiles.first(where: { $0.filename == fromFile }) else {
                            throw UnzipKeysCommandError.linkedSourceFileNotFound(filename: filename)
                        }

                        guard let sourceFile = sourceLocalizedFile.files[locale] else {
                            throw UnzipKeysCommandError.linkedSourceLocaleNotFound(filename: filename, locale: locale)
                        }

                        guard sourceFile.keyExists(fromKey) else {
                            throw UnzipKeysCommandError.linkedSourceKeyNotFound(filename: filename, locale: locale, key: fromKey)
                        }

                        let value = sourceFile.valueForKey(fromKey)!

                        if translatedOnly && value.isUntranslated(untranslatedPrefix) {
                            keysSkipped += 1
                            verboseLog("Key '\(filename):\(fromKey.escapedString)' while linking skipped, because untranslated")
                            return
                        }

                        let destinationLocalizedFile = destinationLocalizedFiles.first(where: { $0.filename == filename })!
                        try destinationLocalizedFile.setValue(value, forKey: toKey, in: locale)
                    })
                })
            })

            try destinationLocalizedFiles.forEach({
                try $0.save()
            })

            verboseLog("Keys unzipped: \(keysUnzipped)")
            verboseLog("Keys unused: \(keysNotFound)")
            verboseLog("Keys imported: \(keysImported)")
            verboseLog("Keys skipped: \(keysSkipped)")
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
