//
//  CopyKeyCommand.swift
//  
//
//  Created by Sergey Ladeiko on 10.11.21.
//


import Foundation
import SwiftCLI
import PathKit
import StringsFileParser
import Rollback
import Utils

enum CopyKeyCommandError: Error, LocalizedError {

    case sourceFileNotFound(filename: String, at: [Path])
    case destinationFileNotFound(filename: String, at: [Path])
    case destinationKeyAlreadyExists(key: EscapableString, destination: String)

    var errorDescription: String? {
        switch self {
            case let .sourceFileNotFound(filename, at):
                return "CopyFileCommandError: source file '\(filename)' not found at '\(at.map({ $0.string }).joined(separator: ", "))'"
            case let .destinationFileNotFound(filename, at):
                return "CopyFileCommandError: destination file '\(filename)' not found at '\(at.map({ $0.string }).joined(separator: ", "))'"
            case let .destinationKeyAlreadyExists(key: key, destination: destination):
                return "CopyFileCommandError: destination key '\(key.escapedString)' already exists in '\(destination)'"
        }
    }
}

public class CopyKeyCommand: Command {

    public let name: String = "copyKey"

    @VariadicKey("--filename", description: "Only files with specified filenames (without extension) will be scanned")
    var filenames: [String]

    @VariadicKey("--locale", description: "Only files for specified locales will be scanned")
    var locales: [String]

    @Flag("--force", description: "Override destination key if already exists")
    var force: Bool

    @Flag("--verbose", description: "Outputs more information")
    var verbose: Bool

    @Flag("--unescape", description: "Unescape key and value strings")
    var unescape: Bool

    @Param var location: String
    @Param var sourceFilename: String
    @Param var sourceKey: String
    @Param var destinationFilename: String
    @Param var destinationKey: String?

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

            let sourceKey: EscapableString = try {
                if unescape {
                    return try EscapableString(escapedString: self.sourceKey)
                }
                else {
                    return EscapableString(rawString: self.sourceKey)
                }
            }()

            let destinationKey: EscapableString? = try {
                guard let destinationKey = self.destinationKey else {
                    return nil
                }

                if unescape {
                    return try EscapableString(escapedString: destinationKey)
                }
                else {
                    return EscapableString(rawString: destinationKey)
                }
            }()

            if (sourceFilename == destinationFilename) && ((destinationKey == nil) || (sourceKey == destinationKey)) {
                return
            }

            let location = self.location.toPaths()

            let sourceLocalizedFiles = try LocalizedStringsFile.scan(paths: location,
                                                                     locales: (!locales.isEmpty ? Set(locales.map({ Locale(identifier: $0) })) : nil),
                                                                     filenames: (!filenames.isEmpty ? Set(filenames) : nil))

            guard let from = sourceLocalizedFiles.first(where: { $0.filename == sourceFilename }) else {
                throw CopyKeyCommandError.sourceFileNotFound(filename: sourceFilename, at: location)
            }

            guard let to = sourceLocalizedFiles.first(where: { $0.filename == destinationFilename }) else {
                throw CopyKeyCommandError.destinationFileNotFound(filename: destinationFilename, at: location)
            }

            try from.files.forEach({
                
                let locale = $0.key
                let fromFile = $0.value

                guard let toFile = to.files.first(where: { $0.key == locale })?.value else {
                    return
                }

                if toFile.keyExists(destinationKey ?? sourceKey) && !force {
                    throw CopyKeyCommandError.destinationKeyAlreadyExists(key: destinationKey ?? sourceKey,  destination: destinationFilename)
                }

                try rollback.protectFile(at: toFile.path)
                try fromFile.copy(key: sourceKey, to: toFile, asKey: destinationKey)
            })

            try to.save()

            let sourceLocales = Set(from.files.keys)
            let destinationLocales = Set(to.files.keys)

            let missingLocales = sourceLocales.subtracting(destinationLocales)
            let skippedLocales = destinationLocales.subtracting(sourceLocales)

            if !missingLocales.isEmpty {
                verboseWarn("File '\(destinationFilename)' does not have '\(missingLocales.map({ $0.identifier }).joined(separator: ", "))' locale(s)")
            }

            if !skippedLocales.isEmpty {
                verboseWarn("File '\(destinationFilename)' has extra locale(s): '\(skippedLocales.map({ $0.identifier }).joined(separator: ", "))'")
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

