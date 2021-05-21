//
//  RenameKeyCommand.swift
//  CLICommands
//
//  Created by Siarhei Ladzeika on 8/5/21.
//

import Foundation
import SwiftCLI
import PathKit
import StringsFileParser
import Utils
import Rollback

enum RenameKeyCommandError: Error, LocalizedError {

    case keyNotFound(key: EscapableString, at: Path)
    case keyAlreadyExists(key: EscapableString, at: Path)

    var errorDescription: String? {
        switch self {
        case let .keyNotFound(key: key, at: location):
            return "RenameKeyCommandError: key '\(key.escapedString)' not found at '\(location.string)'"
        case let .keyAlreadyExists(key: key, at: location):
            return "RenameKeyCommandError: key '\(key.escapedString)' already exists at '\(location.string)'"
        }
    }
}

public class RenameKeyCommand: Command {

    public let name: String = "renameKey"

    @VariadicKey("--filename", description: "Only files with specified filenames (without extension) will be scanned")
    var filenames: [String]

    @VariadicKey("--locale", description: "Only files for specified locales will be scanned")
    var locales: [String]

    @Flag("--verbose", description: "Outputs more information")
    var verbose: Bool

    @Flag("--fail-if-absent", description: "Fail if source key not found in some source file locale")
    var failIfAbsent: Bool

    @Flag("--sort", description: "Sort keys")
    var sort: Bool

    @Flag("--case-insensitive", description: "Set case insensitive sorting if sort operation")
    var caseInsensitiveSorting: Bool

    @Flag("--unescape", description: "Unescape key and value strings")
    var unescape: Bool

    @Param var location: String
    @Param var oldKeyName: String
    @Param var newKeyName: String

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

            let oldKeyName: EscapableString = try {
                if unescape {
                    return try EscapableString(escapedString: self.oldKeyName)
                }
                else {
                    return EscapableString(rawString: self.oldKeyName)
                }
            }()

            let newKeyName: EscapableString = try {
                if unescape {
                    return try EscapableString(escapedString: self.newKeyName)
                }
                else {
                    return EscapableString(rawString: self.newKeyName)
                }
            }()

            let location = self.location.toPaths()

            let sourceLocalizedFiles = try LocalizedStringsFile.scan(paths: location,
                                                                     locales: (!locales.isEmpty ? Set(locales.map({ Locale(identifier: $0) })) : nil),
                                                                     filenames: (!filenames.isEmpty ? Set(filenames) : nil))
            try sourceLocalizedFiles.forEach({ sourceLocalizedFile in
                try sourceLocalizedFile.files.forEach({ stringsFileEntry in

                    let sourceStringsFile = stringsFileEntry.value

                    guard sourceStringsFile.keyExists(oldKeyName) else {

                        if failIfAbsent {
                            throw RenameKeyCommandError.keyNotFound(key: oldKeyName, at: sourceStringsFile.path)
                        }

                        verboseWarn("'\(oldKeyName.escapedString)' not found in '\(sourceStringsFile.path.string)'")
                        return
                    }

                    if sourceStringsFile.keyExists(newKeyName) {
                        throw RenameKeyCommandError.keyAlreadyExists(key: newKeyName, at: sourceStringsFile.path)
                    }

                    try rollback.protectFile(at: sourceStringsFile.path)
                    try sourceStringsFile.renameKey(oldKeyName, to: newKeyName)
                    try sourceStringsFile.save()
                })
            })

            if sort {
                try sourceLocalizedFiles.forEach({

                    try $0.files.forEach({
                        try rollback.protectFile(at: $0.value.path)
                    })

                    try $0.sort(caseInsensitive: caseInsensitiveSorting)
                    try $0.save()
                })
            }

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
