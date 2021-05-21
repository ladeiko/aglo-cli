//
//  RemoveDuplicateKeysCommand.swift
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

public class RemoveDuplicateKeysCommand: Command {

    public let name: String = "removeDuplicateKeys"

    @VariadicKey("--filename", description: "Only files with specified filenames (without extension) will be scanned")
    var filenames: [String]

    @VariadicKey("--locale", description: "Only files for specified locales will be scanned")
    var locales: [String]

    @Flag("--verbose", description: "Outputs more information")
    var verbose: Bool

    @Param var destination: String

    public init() {}

    public func execute() throws {

        let rollback = Rollback()

        do {

            let destination = self.destination.toPaths()

            let localizedFiles = try LocalizedStringsFile.scan(paths: destination,
                                                                     locales: (!locales.isEmpty ? Set(locales.map({ Locale(identifier: $0) })) : nil),
                                                                     filenames: (!filenames.isEmpty ? Set(filenames) : nil),
                                                                     options: [.removeDuplicateKeys])
            try localizedFiles.forEach({ localizedFile in
                try localizedFile.files.forEach({ stringsFileEntry in

                    let stringsFile = stringsFileEntry.value
                    try rollback.protectFile(at: stringsFile.path)
                })
            })

            try localizedFiles.forEach({
                try $0.save(force: true)
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


