//
//  SortKeysCommand.swift
//  CLICommands
//
//  Created by Siarhei Ladzeika on 30.07.21.
//

import Foundation
import SwiftCLI
import PathKit
import StringsFileParser
import Rollback

enum SortKeysCommandError: Error, LocalizedError {

    case destinationAlreadyExists(destination: Path)

    var errorDescription: String? {
        switch self {
        case let .destinationAlreadyExists(destination: destination):
            return "SortKeysCommandError: destination item already exists '\(destination.string)'"
        }
    }
}

public class SortKeysCommand: Command {

    public let name: String = "sortKeys"

    @VariadicKey("--filename", description: "Only files with specified filenames (without extension) will be modified")
    var filenames: [String]

    @VariadicKey("--locale", description: "Only files for specified locales will be modified")
    var locales: [String]

    @Flag("--case-insensitive", description: "Set case insensitive sorting if sort operation")
    var caseInsensitiveSorting: Bool

    @Flag("--verbose", description: "Outputs more information")
    var verbose: Bool

    @Param var source: String

    public init() {}

    public func execute() throws {

        let rollback = Rollback()

        do {

            let source = self.source.toPaths()
            let sourceLocalizedFiles = try LocalizedStringsFile.scan(paths: source,
                                                                     locales: (!locales.isEmpty ? Set(locales.map({ Locale(identifier: $0) })) : nil),
                                                                     filenames: (!filenames.isEmpty ? Set(filenames) : nil))

            if caseInsensitiveSorting {
                try sourceLocalizedFiles.forEach({

                    try $0.files.values.forEach({
                        try rollback.protectFile(at: $0.path)
                    })

                    try $0.sort(by: { $0.escapedString.lowercased() < $1.escapedString.lowercased() })
                    try $0.save()
                })
            }
            else {
                try sourceLocalizedFiles.forEach({

                    try $0.files.values.forEach({
                        try rollback.protectFile(at: $0.path)
                    })

                    try $0.sort()
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
