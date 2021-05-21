//
//  LinkKeyCommand.swift
//  
//
//  Created by Sergey Ladeiko on 8.11.21.
//

import Foundation
import SwiftCLI
import PathKit
import StringsFileParser
import Utils
import Rollback

enum LinkKeyCommandError: Error, LocalizedError {

    case sourceFileNotFound(filename: String, at: [Path])
    case destinationFileNotFound(filename: String, at: [Path])
    case localeDoesNotExist(locale: Locale, filename: String)
    case targetKeyDoesNotExist(key: EscapableString, locale: Locale, filename: String)

    var errorDescription: String? {
        switch self {
            case let .sourceFileNotFound(filename: filename, at: paths):
                return "LinkKeyCommandError: source file '\(filename)' not found at '\(paths.map({ $0.string }).joined(separator: ", "))'"

            case let .destinationFileNotFound(filename: filename, at: paths):
                return "LinkKeyCommandError: destination file '\(filename)' not found at '\(paths.map({ $0.string }).joined(separator: ", "))'"

            case let .localeDoesNotExist(locale: locale, filename: filename):
                return "LinkKeyCommandError: file '\(filename)' does not have '\(locale.identifier)' locale"

            case let .targetKeyDoesNotExist(key: key, locale: locale, filename: filename):
                return "LinkKeyCommandError: file '\(filename)' does not have key '\(key.escapedString)' for '\(locale.identifier)' locale"
        }
    }
}

public class LinkKeyCommand: Command {

    public let name: String = "linkKey"

    @VariadicKey("--locale", description: "Only files for specified locales will be scanned")
    var locales: [String]

    @Flag("--verbose", description: "Outputs more information")
    var verbose: Bool

    @Flag("--unescape", description: "Unescape key")
    var unescape: Bool

    @Param var destination: String
    @Param var filename: String
    @Param var key: String
    @Param var linkFile: String
    @Param var linkKey: String

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

            let linkKey: EscapableString = try {
                if unescape {
                    return try EscapableString(escapedString: self.linkKey)
                }
                else {
                    return EscapableString(rawString: self.linkKey)
                }
            }()

            let destination = self.destination.toPaths()

            let sourceLocalizedFiles = try LocalizedStringsFile.scan(paths: destination,
                                                                     locales: (!locales.isEmpty ? Set(locales.map({ Locale(identifier: $0) })) : nil),
                                                                     filenames: Set([filename, linkFile]))

            guard let from = sourceLocalizedFiles.first else {
                throw LinkKeyCommandError.sourceFileNotFound(filename: filename, at: destination)
            }

            guard let to = sourceLocalizedFiles.first(where: { $0.filename == linkFile }) else {
                throw LinkKeyCommandError.destinationFileNotFound(filename: linkFile, at: destination)
            }

            try from.files.forEach({

                let locale = $0.key
                let sourceStringsFile = $0.value

                try rollback.protectFile(at: sourceStringsFile.path)

                guard let targetFile = to.files.first(where: { $0.key == locale })?.value else {
                    throw LinkKeyCommandError.localeDoesNotExist(locale: locale, filename: linkFile)
                }

                guard targetFile.keyExists(linkKey) else {
                    throw LinkKeyCommandError.targetKeyDoesNotExist(key: linkKey, locale: locale, filename: linkFile)
                }

                try sourceStringsFile.setValueForTag("link", forKey: key, to: .init(rawString: "\(linkFile):\(linkKey.escapedString)"))
            })

            try from.save()

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

