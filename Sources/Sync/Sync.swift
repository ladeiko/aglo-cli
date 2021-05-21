//
//  Sync.swift
//
//
//  Created by Sergey Ladeiko on 23.01.23.
//

import Foundation
import PathKit
import StringsFileParser
import Utils
import Rollback

enum SyncCommandError: Error, LocalizedError {
    case invalidKey(key: EscapableString)
    case destinationIsNotADirectory(destination: Path)
    case destinationFileAlreadyExists(destination: Path)
    case importedKeyDoesNotExist(key: EscapableString, filename: String, locale: Locale)

    var errorDescription: String? {
        switch self {
            case let .destinationIsNotADirectory(destination: destination):
                return "SyncCommandError: destination '\(destination.string)' is not a directory"
            case let .destinationFileAlreadyExists(destination: destination):
                return "SyncCommandError: destination file '\(destination.string)' already exists"
            case let .importedKeyDoesNotExist(key, filename, locale):
                return "SyncCommandError: import key '\(key.escapedString)' does not exist in '\(filename)' for '\(locale.identifier)'"
            case let .invalidKey(key: key):
                return "UnzipKeysCommandError: invalid key '\(key.escapedString)'"
        }
    }
}

public func sync(sort: Bool,
                 caseInsensitiveSorting: Bool,
                 addAbsentKeys: Bool,
                 makeNewValuesUntranslated: Bool,
                 untranslatedOnly: Bool,
                 noMerge: Bool,
                 filenames: [String],
                 untranslatedPrefix: String?,
                 locales: [String],
                 verbose: Bool,
                 source: String,
                 destination: String) throws
{

    let rollback = Rollback()

    do {
        print(locales.joined(separator: ", "))
        try fromAppToContent(rollback, app: source, loc: destination)
        try fromContentToApp(rollback, app: source, loc: destination)
    }
    catch {

        do {
            try rollback.restore()
        }
        catch {
            print("\(error)")
        }

        throw error
    }

    func fromAppToContent(_ rollback: Rollback, app: String, loc: String) throws {

        verboseLog("Zippping...")

        func verboseLog(_ message: @autoclosure () -> String) {
            if verbose {
                print(message())
            }
        }

        func verboseWarn(_ message: @autoclosure () -> String) {
            if verbose {
                print("[WARNING]: " + message())
            }
        }

        let source = app.toPaths()
        let destination = Path(loc).absolute()

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

        if !destFolder.isDirectory {
            throw SyncCommandError.destinationIsNotADirectory(destination: destFolder)
        }

        for locale in targetLocales {

            let sourceFiles = sourceStringsFiles[locale]

            try sourceFiles?.forEach({ sourceFile in

                let output: String = {
                    if noMerge {
                        return sourceFile.filename
                    }
                    else {
                        return "Localizable"
                    }
                }()

                let localeFolder = destFolder + (locale.identifier + "." + LocalizedStringsFile.localeFolderExtension)

                try localeFolder.mkpath()
                let outputFile = localeFolder + (output + "." + StringsFile.fileExtension)

                if outputFile.exists {
                    try rollback.protectFile(at: outputFile)
                }
                else {
                    try rollback.deleteFile(at: outputFile)
                    try outputFile.write("")
                }

                let destinationFile = try StringsFile(path: outputFile)
                
                try sourceFile.keys.sorted().forEach({ key in

                    if untranslatedOnly, let value = sourceFile.valueForKey(key), !value.isUntranslated(untranslatedPrefix) {
                        verboseWarn("Key '\(key.escapedString)' is translated")
                        return
                    }

                    let destKey: EscapableString = try {
                        if sourceFile.path.lastComponent == "Localizable.strings" || noMerge {
                            return try EscapableString(escapedString: key.escapedString)
                        }
                        return try EscapableString(escapedString: "\(sourceFile.path.lastComponent):\(key.escapedString)")
                    }()

                    verboseLog("Checking key '\(destKey.escapedString)' in '\(destinationFile.path.string)'")

                    if destinationFile.keyExists(destKey) {
                        verboseLog("Key '\(destKey.escapedString)' already exists in '\(destinationFile.path.string)'")
                        try sourceFile.copyComment(fromKey: key, toFile: destinationFile, toKey: destKey)
                        verboseLog("Comment for key '\(destKey.escapedString)' updated in '\(destinationFile.path.string)'")
                        return
                    }

                    try sourceFile.copy(key: key, to: destinationFile, asKey: destKey)

                    if makeNewValuesUntranslated, let newValue = destinationFile.valueForKey(destKey) {
                        try destinationFile.setValue(newValue.makeUntranslated(untranslatedPrefix), forKey: destKey)
                    }

                    verboseLog("Key copied '\(key.escapedString)' from '\(sourceFile.path.string)' to '\(destinationFile.path.string)'")
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
            })
        }

    }

    func fromContentToApp(_ rollback: Rollback, app: String, loc: String) throws {

        verboseLog("Unzipping...")

        func verboseLog(_ message: @autoclosure () -> String) {
            if verbose {
                print(message())
            }
        }

        func verboseWarn(_ message: @autoclosure () -> String) {
            if verbose {
                print("[WARNING]: " + message())
            }
        }

        let source = loc.toPaths()
        let destination = app.toPaths()

        let sourceLocalizedFiles = try LocalizedStringsFile.scan(paths: source,
                                                                 locales: (!locales.isEmpty ? Set(locales.map({ Locale(identifier: $0) })) : nil),
                                                                 filenames: (!filenames.isEmpty ? Set(filenames) : (noMerge ? nil : Set(["Localizable"]))))

        let destinationLocalizedFiles = try LocalizedStringsFile.scan(paths: destination,
                                                                      locales: (!locales.isEmpty ? Set(locales.map({ Locale(identifier: $0) })) : nil),
                                                                      filenames: (!filenames.isEmpty ? Set(filenames) : nil))

        verboseLog("Source files: \(sourceLocalizedFiles.map({ $0.filename }).joined(separator: ","))")
        verboseLog("Target files: \(destinationLocalizedFiles.map({ $0.filename }).joined(separator: ","))")

        var keysUnzipped = 0
        var keysNotFound = 0
        var keysSkipped = 0

        try sourceLocalizedFiles.forEach({ sourceLocalizedFile in
            try sourceLocalizedFile.files.forEach({ sourceLocalizedFileEntry in

                let sourceLocale = sourceLocalizedFileEntry.key
                let sourceStringsFile = sourceLocalizedFileEntry.value

                struct Key {
                    let filename: String
                    let key: EscapableString
                    let fullKey: EscapableString
                }

                let sourceKeys: [Key] = sourceStringsFile.keys.compactMap({ k in

                    let parts = k.rawString.split(separator: ":")
                    let filename = String(parts[0])

                    if parts.count == 1 || filename.fileExtension() != StringsFile.fileExtension {
                        let key = EscapableString(rawString: k.rawString)
                        return Key(filename: sourceStringsFile.filename, key: key, fullKey: k)
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

                        if value.isUntranslated(untranslatedPrefix) {
                            keysSkipped += 1
                            verboseLog("Key '\(sourceKey.filename):\(sourceKey.fullKey.escapedString)' skipped, because untranslated")
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

        try destinationLocalizedFiles.forEach({
            try $0.save()
        })

        verboseLog("Keys unzipped: \(keysUnzipped)")
        verboseLog("Keys unused: \(keysNotFound)")
        verboseLog("Keys skipped: \(keysSkipped)")
    }
}

