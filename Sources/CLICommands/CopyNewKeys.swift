//
//  CopyValuesCommand.swift
//  
//
//  Created by Sergey Ladeiko on 26.08.21.
//

import Foundation
import SwiftCLI
import PathKit
import StringsFileParser
import Rollback

public enum CopyNewKeysCommandError: Error, LocalizedError {
    case onlyOneInputFileAllowed
    case onlyOneOutputFileAllowed

    public var errorDescription: String? {
        switch self {
        case .onlyOneInputFileAllowed:
            return "CopyNewKeysCommandError: only one input file is allowed"

        case .onlyOneOutputFileAllowed:
            return "CopyNewKeysCommandError: only one output file is allowed"
        }
    }
}

public class CopyNewKeysCommand: Command {

    public let name: String = "copyNewKeys"

    @VariadicKey("--filename", description: "Only files with specified filenames (without extension) will be modified")
    var filenames: [String]

    @VariadicKey("--locale", description: "Only files for specified locales will be modified")
    var locales: [String]

    @Flag("--add-missing-locales", description: "If defined, then locales of destination files will be syncrhonized to source files")
    var addMissingLocales: Bool

    @Flag("--sort", description: "If defined, then keys will be sorted")
    var sort: Bool

    @Flag("--case-insensitive", description: "Set case insensitive sorting if sort operation")
    var caseInsensitiveSorting: Bool

    @Flag("--verbose", description: "If set, then will output detailed logs")
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
                                                                     filenames: (!filenames.isEmpty ? Set(filenames) : nil))

            let destinationLocalizedFiles = try LocalizedStringsFile.scan(paths: destination,
                                                                     locales: (!locales.isEmpty ? Set(locales.map({ Locale(identifier: $0) })) : nil),
                                                                     filenames: (!filenames.isEmpty ? Set(filenames) : nil))

            guard sourceLocalizedFiles.count == 1 else {
                throw CopyNewKeysCommandError.onlyOneInputFileAllowed
            }

            guard destinationLocalizedFiles.count == 1 else {
                throw CopyNewKeysCommandError.onlyOneOutputFileAllowed
            }

            let sourceFile = sourceLocalizedFiles.first!
            let destinationFile = destinationLocalizedFiles.first!

            var totalCopied = 0
            var totalSkipped = 0

            try sourceFile.files.forEach({

                let locale = $0.key
                let file = $0.value

                if !destinationFile.hasLocale(locale) {

                    if !addMissingLocales {
                        verboseWarn("Destination '\(destinationFile.filename)' does not have '\(locale.identifier)' locale")
                        return
                    }

                    try destinationFile.addLocale(locale, mode: .createNew(copingContentFromLocale: nil))
                    try rollback.deleteFile(at: destinationFile.files[locale]!.path)

                    verboseWarn("Locale '\(locale.identifier)' for destination added")
                }
                else {
                    try rollback.protectFile(at: destinationFile.files[locale]!.path)
                }

                let target = destinationFile.files[locale]!

                try file.keys.forEach({ key in

                    guard !target.keyExists(key) else {
                        verboseWarn("Key '\(key.escapedString)' in '\(target.filename)' already exists")
                        totalSkipped += 1
                        return
                    }

                    try file.copy(key: key, to: target)
                    verboseLog("New key '\(key.escapedString)' copied to '\(target.filename)'")
                    totalCopied += 1
                })
            })

            if sort {
                if caseInsensitiveSorting {
                    try destinationLocalizedFiles.forEach({
                        try $0.sort(by: { $0.escapedString.lowercased() < $1.escapedString.lowercased() })
                    })
                }
                else {
                    try destinationLocalizedFiles.forEach({
                        try $0.sort()
                    })
                }
            }

            try destinationLocalizedFiles.forEach({
                try $0.save()
            })

            verboseLog("Total keys skipped: \(totalSkipped)")
            verboseLog("Total keys copied: \(totalCopied)")
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

