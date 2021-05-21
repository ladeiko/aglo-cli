//
//  MoveKeyCommand.swift
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

enum MoveKeyCommandError: Error, LocalizedError {

    case sourceFileNotFound(filename: String, at: [Path])
    case destinationFileNotFound(filename: String, at: [Path])
    case keyAlreadyExists(key: EscapableString, at: Path)
    case localeDoesNotExist(locale: Locale, filename: String)

    var errorDescription: String? {
        switch self {
        case let .sourceFileNotFound(filename: filename, at: paths):
            return "MoveKeyCommandError: source file '\(filename)' not found at '\(paths.map({ $0.string }).joined(separator: ", "))'"

        case let .destinationFileNotFound(filename: filename, at: paths):
            return "MoveKeyCommandError: destination file '\(filename)' not found at '\(paths.map({ $0.string }).joined(separator: ", "))'"

        case let .keyAlreadyExists(key: key, at: filename):
            return "MoveKeyCommandError: file '\(filename)' already has key '\(key.escapedString)'"

        case let .localeDoesNotExist(locale: locale, filename: filename):
            return "MoveKeyCommandError: file '\(filename)' does not have '\(locale.identifier)' locale"
        }
    }
}

public class MoveKeyCommand: Command {

    public let name: String = "moveKey"

    @VariadicKey("--locale", description: "Only files for specified locales will be scanned")
    var locales: [String]

    @Flag("--force", description: "Override existing keys in destination")
    var force: Bool

    @Flag("--add-locales", description: "If set, then non existing locales will be created")
    var addLocales: Bool

    @Key("--untranslated-prefix", description: "Custom prefix for unstranslated strings (default is '\(DefaultUntranslatedPrefixMarker)'")
    var untranslatedPrefix: String?

    @Flag("--verbose", description: "Outputs more information")
    var verbose: Bool

    @Flag("--unescape", description: "Unescape key and value strings")
    var unescape: Bool

    @Param var destination: String
    @Param var sourceFilename: String
    @Param var destinationFilename: String
    @Param var key: String
    @Param var newKey: String?

    public init() {}

    public func execute() throws {

        let rollback = Rollback()

        do {

            let key: EscapableString = try {
                if unescape {
                    return try EscapableString(escapedString: self.key)
                }
                else {
                    return EscapableString(rawString: self.key)
                }
            }()

            let newKey: EscapableString = try {
                if unescape {
                    return try EscapableString(escapedString: (self.newKey ?? self.key))
                }
                else {
                    return EscapableString(rawString: self.newKey ?? self.key)
                }
            }()

            let destination = self.destination.toPaths()

            let sourceLocalizedFiles = try LocalizedStringsFile.scan(paths: destination,
                                                                     locales: (!locales.isEmpty ? Set(locales.map({ Locale(identifier: $0) })) : nil),
                                                                     filenames: nil)

            guard let from = sourceLocalizedFiles.first(where: { $0.filename == sourceFilename }) else {
                throw MoveKeyCommandError.sourceFileNotFound(filename: sourceFilename, at: destination)
            }

            guard let to = sourceLocalizedFiles.first(where: { $0.filename == destinationFilename }) else {
                throw MoveKeyCommandError.destinationFileNotFound(filename: sourceFilename, at: destination)
            }

            try from.files.forEach({

                let locale = $0.key
                let sourceStringsFile = $0.value

                if let targetFile = to.files.first(where: { $0.key == locale })?.value {

                    if !force && targetFile.keyExists(newKey) {
                        throw MoveKeyCommandError.keyAlreadyExists(key: newKey, at: targetFile.path)
                    }

                    try rollback.protectFile(at: targetFile.path)

                    try sourceStringsFile.move(key: key, to: targetFile, asKey: newKey)

                    try sourceStringsFile.save()
                    try targetFile.save()
                }
                else {

                    if !addLocales {
                        throw MoveKeyCommandError.localeDoesNotExist(locale: locale, filename: destinationFilename)
                    }

                    let root = to.files.first!.value.path.parent().parent()
                    let localeFolderName = locale.identifier + "." + LocalizedStringsFile.localeFolderExtension
                    let filename = to.files.first!.value.filename + "." + StringsFile.fileExtension

                    let target: Path = root + localeFolderName + filename

                    try rollback.deleteFile(at: target)

                    try target.write("", encoding: StringsFile.defaultEncoding)

                    let targetFile = try StringsFile(path: target)

                    try sourceStringsFile.move(key: key, to: targetFile, asKey: newKey)

                    try sourceStringsFile.save()
                    try targetFile.save()
                }

            })

            let sourceLocales = Set(from.files.keys)
            let destinationLocales = Set(to.files.keys)

            let placeholder = EscapableString(rawString: untranslatedPrefix ?? DefaultUntranslatedPrefixMarker)
            let localesNotExistingInFrom = destinationLocales.subtracting(sourceLocales)
            try localesNotExistingInFrom.forEach({ locale in

                let root = to.files.first!.value.path.parent().parent()
                let localeFolderName = locale.identifier + "." + LocalizedStringsFile.localeFolderExtension
                let filename = to.files.first!.value.filename + "." + StringsFile.fileExtension

                let target: Path = root + localeFolderName + filename

                try rollback.deleteFile(at: target)

                try target.write("", encoding: StringsFile.defaultEncoding)

                let targetFile = try StringsFile(path: target)

                try targetFile.setValue(placeholder, forKey: newKey)
                try targetFile.save()

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
