//
//  CloneLocaleCommand.swift
//  CLICommands
//
//  Created by Sergey Ladeiko on 8.09.21.
//

import Foundation
import SwiftCLI
import PathKit
import StringsFileParser
import Rollback
import Utils

public enum CloneLocaleCommandError: Error, LocalizedError {

    case localeNotFound(locale: Locale, filename: String)
    case sourceAndDestinationLocaleShouldBeDifferent

    public var errorDescription: String? {
        switch self {
        case let .localeNotFound(locale: locale, filename: filename):
            return "CloneLocaleCommandError: locale '\(locale.identifier)' for '\(filename)' not found"
        case .sourceAndDestinationLocaleShouldBeDifferent:
            return "CloneLocaleCommandError: source and target locales are the same"
        }
    }
}


public class CloneLocaleCommand: Command {

    public let name: String = "cloneLocale"

    @VariadicKey("--filename", description: "Only files with specified filenames (without extension) will be scanned")
    var filenames: [String]

    @VariadicKey("--locale", description: "Only files for specified locales will be scanned")
    var locales: [String]

    @Flag("--verbose", description: "Outputs more information")
    var verbose: Bool

    @Param var destination: String
    @Param var fromLocale: String
    @Param var toLocale: String

    public init() {}

    public func execute() throws {

        let rollback = Rollback()

        do {

            func verboseLog(_ message: @autoclosure () -> String) {
                if verbose {
                    stdout <<< message()
                }
            }

            let fromLocale = Locale(identifier: self.fromLocale)
            let toLocale = Locale(identifier: self.toLocale)
            let destination = self.destination.toPaths()

            guard fromLocale != toLocale else {
                throw CloneLocaleCommandError.sourceAndDestinationLocaleShouldBeDifferent
            }

            let localizedFiles = try LocalizedStringsFile.scan(paths: destination,
                                                               locales: (!locales.isEmpty ? Set([locales, [self.toLocale, self.fromLocale]].flatMap({ $0 }).map({ Locale(identifier: $0) })) : nil),
                                                               filenames: (!filenames.isEmpty ? Set(filenames) : nil))

            try localizedFiles.forEach({ localizedFile in

                guard let sourceFile = localizedFile.files.first(where: { $0.key == fromLocale })?.value else {
                    throw CloneLocaleCommandError.localeNotFound(locale: toLocale, filename: localizedFile.filename)
                }

                if let destinationFile = localizedFile.files.first(where: { $0.key == toLocale })?.value  {
                    try rollback.protectFile(at: destinationFile.path)

                    verboseLog("Cloning '\(sourceFile.path.string)' to '\(destinationFile.path.string)'")

                    try? destinationFile.path.delete()
                    try sourceFile.path.copy(destinationFile.path)
                }
                else {

                    let localeFolderName = toLocale.identifier + "." + LocalizedStringsFile.localeFolderExtension
                    let filename = sourceFile.filename + "." + StringsFile.fileExtension
                    let target: Path = sourceFile.path.parent().parent() + localeFolderName + filename
                    try target.parent().mkpath()

                    try rollback.deleteFile(at: target)

                    verboseLog("Cloning '\(sourceFile.path.string)' to '\(target.string)'")

                    try sourceFile.path.copy(target)
                }

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

