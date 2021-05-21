//
//  PrettifyCommand.swift
//  
//
//  Created by Sergey Ladeiko on 15.11.21.
//

import Foundation
import SwiftCLI
import PathKit
import StringsFileParser
import Rollback
import Utils

enum PrettifyCommandError: Error, LocalizedError {

    case sourceFileNotFound(filename: String, at: [Path])
    case destinationFileNotFound(filename: String, at: [Path])
    case destinationKeyAlreadyExists(key: EscapableString, destination: String)

    var errorDescription: String? {
        switch self {
            case let .sourceFileNotFound(filename, at):
                return "PrettifyCommandError: source file '\(filename)' not found at '\(at.map({ $0.string }).joined(separator: ", "))'"
            case let .destinationFileNotFound(filename, at):
                return "PrettifyCommandError: destination file '\(filename)' not found at '\(at.map({ $0.string }).joined(separator: ", "))'"
            case let .destinationKeyAlreadyExists(key: key, destination: destination):
                return "PrettifyCommandError: destination key '\(key.escapedString)' already exists in '\(destination)'"
        }
    }
}

public class PrettifyCommand: Command {

    public let name: String = "prettify"

    @VariadicKey("--filename", description: "Only files with specified filenames (without extension) will be scanned")
    var filenames: [String]

    @VariadicKey("--locale", description: "Only files for specified locales will be scanned")
    var locales: [String]

    @Flag("--verbose", description: "Outputs more information")
    var verbose: Bool

    @Param var location: String

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

            let location = self.location.toPaths()

            let sourceLocalizedFiles = try LocalizedStringsFile.scan(paths: location,
                                                                     locales: (!locales.isEmpty ? Set(locales.map({ Locale(identifier: $0) })) : nil),
                                                                     filenames: (!filenames.isEmpty ? Set(filenames) : nil))

            try sourceLocalizedFiles.forEach({
                try $0.files.forEach({

                    try rollback.protectFile(at: $0.value.path)
                    try $0.value.prettify()
                })
            })

            try sourceLocalizedFiles.forEach({
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


