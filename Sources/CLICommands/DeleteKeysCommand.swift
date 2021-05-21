//
//  DeleteKeysCommand.swift
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

enum DeleteKeysCommandError: Error, LocalizedError {

    case destinationAlreadyExists(destination: Path)

    var errorDescription: String? {
        switch self {
        case let .destinationAlreadyExists(destination: destination):
            return "DeleteKeyCommandError: destination item already exists '\(destination.string)'"
        }
    }
}

public class DeleteKeysCommand: Command {

    public let name: String = "deleteKeys"

    @VariadicKey("--filename", description: "Only files with specified filenames (without extension) will be modified")
    var filenames: [String]

    @VariadicKey("--locale", description: "Only files with specified locales will be modified")
    var locales: [String]

    @Flag("--force", description: "Override destination files if they exist, valid only if destination specified")
    var force: Bool

    @Flag("--unescape", description: "Unescape key and value strings")
    var unescape: Bool
    
    @Flag("--verbose", description: "Outputs more information")
    var verbose: Bool

    @Param var destination: String
    @CollectedParam(minCount: 1) var keys: [String]

    public init() {}

    public func execute() throws {

        let rollback = Rollback()

        do {

            let keys: [EscapableString] = try {
                if unescape {
                    return try self.keys.map({ try EscapableString(escapedString: $0) })
                }
                else {
                    return self.keys.map({ EscapableString(rawString: $0) })
                }
            }()

            let destination: [Path] = self.destination.toPaths()

            let sourceLocalizedFiles = try LocalizedStringsFile.scan(paths: destination,
                                                                     locales: (!locales.isEmpty ? Set(locales.map({ Locale(identifier: $0) })) : nil),
                                                                     filenames: (!filenames.isEmpty ? Set(filenames) : nil))

            try sourceLocalizedFiles.forEach({ sourceLocalizedFile in

                try keys.forEach({ key in
                    try sourceLocalizedFile.removeValue(forKey: key, in: (!locales.isEmpty ? Set(locales.map({ Locale(identifier: $0) })) : nil))
                })

                try sourceLocalizedFile.save()
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
