//
//  UnlinkKeyCommand.swift
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

enum UnlinkKeyCommandError: Error, LocalizedError {

    case sourceFileNotFound(filename: String, at: [Path])

    var errorDescription: String? {
        switch self {
            case let .sourceFileNotFound(filename: filename, at: paths):
                return "UnlinkKeyCommandError: source file '\(filename)' not found at '\(paths.map({ $0.string }).joined(separator: ", "))'"
        }
    }
}

public class UnlinkKeyCommand: Command {

    public let name: String = "unlinkKey"

    @VariadicKey("--locale", description: "Only files for specified locales will be scanned")
    var locales: [String]

    @Flag("--verbose", description: "Outputs more information")
    var verbose: Bool

    @Flag("--unescape", description: "Unescape key")
    var unescape: Bool

    @Param var destination: String
    @Param var filename: String
    @Param var key: String

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

            let destination = self.destination.toPaths()

            let sourceLocalizedFiles = try LocalizedStringsFile.scan(paths: destination,
                                                                     locales: (!locales.isEmpty ? Set(locales.map({ Locale(identifier: $0) })) : nil),
                                                                     filenames: Set([filename]))

            guard let from = sourceLocalizedFiles.first else {
                throw UnlinkKeyCommandError.sourceFileNotFound(filename: filename, at: destination)
            }

            try from.files.forEach({

                let sourceStringsFile = $0.value

                try rollback.protectFile(at: sourceStringsFile.path)

                try sourceStringsFile.removeValueForTag("link", forKey: key)
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

