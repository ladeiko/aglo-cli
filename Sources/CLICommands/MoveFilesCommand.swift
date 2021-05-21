//
//  MoveFilesCommand.swift
//  CLICommands
//
//  Created by Siarhei Ladzeika on 30.07.21.
//

import Foundation
import SwiftCLI
import PathKit
import StringsFileParser
import Rollback

enum MoveFileCommandError: Error, LocalizedError {

    case destinationAlreadyExists(destination: Path)

    var errorDescription: String? {
        switch self {
        case let .destinationAlreadyExists(destination: destination):
            return "MoveFileCommandError: destination item already exists '\(destination.string)'"
        }
    }
}

public class MoveFilesCommand: Command {

    public let name: String = "moveFiles"

    @VariadicKey("--filename", description: "Only files with specified filenames (without extension) will be scanned")
    var filenames: [String]

    @VariadicKey("--locale", description: "Only files for specified locales will be scanned")
    var locales: [String]

    @Flag("--force", description: "Override destination files if they exist, valid only if destination specified")
    var force: Bool

    @Flag("--verbose", description: "Outputs more information")
    var verbose: Bool

    @Param var source: String
    @Param var destination: String

    public init() {}

    public func execute() throws {

        let rollback = Rollback()

        do {

            let source = self.source.toPaths()
            let destination = Path(self.destination).absolute()

            let sourceLocalizedFiles = try LocalizedStringsFile.scan(paths: source,
                                                                     locales: (!locales.isEmpty ? Set(locales.map({ Locale(identifier: $0) })) : nil),
                                                                     filenames: (!filenames.isEmpty ? Set(filenames) : nil))
            try sourceLocalizedFiles.forEach({ sourceLocalizedFile in
                try sourceLocalizedFile.files.forEach({ stringsFileEntry in

                    let locale = stringsFileEntry.key
                    let stringsFile = stringsFileEntry.value

                    let localeFolderName = locale.identifier + "." + LocalizedStringsFile.localeFolderExtension
                    let filename = stringsFile.filename + "." + StringsFile.fileExtension
                    let target: Path = destination + localeFolderName + filename
                    try target.parent().mkpath()

                    if !force && target.exists {
                        throw MoveFileCommandError.destinationAlreadyExists(destination: target)
                    }

                    try rollback.protectFile(at: stringsFile.path)

                    if target.exists {
                        try rollback.protectFile(at: target)
                        try target.delete()
                    }
                    else {
                        try rollback.deleteFile(at: target)
                    }

                    try stringsFile.path.move(target)
                })
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
