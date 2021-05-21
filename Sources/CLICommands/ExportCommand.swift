//
//  ExportCommand.swift
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

enum ExportCommandError: Error, LocalizedError {

    case destinationAlreadyExists(destination: Path)

    var errorDescription: String? {
        switch self {
        case let .destinationAlreadyExists(destination: destination):
            return "ExportCommandError: destination item already exists '\(destination.string)'"
        }
    }
}

fileprivate struct JsonEntry: Codable {
    let comment: String?
    let key: String
    let value: String
}

enum ExportCommandFormat: String, ConvertibleFromString {
    case json
    case jsonPretty
    case plist

    init?(input: String) {
        switch input {
        case "json": self = .json
        case "json-pretty": self = .jsonPretty
        case "jsonPretty": self = .jsonPretty
        case "plist": self = .plist
        default: return nil
        }
    }

    static let explanationForConversionFailure: String = "Supported values: 'json', 'json-pretty', 'plist'"

    static func messageForInvalidValue(reason: InvalidValueReason, for id: String?) -> String {
        "\(reason)"
    }
}

public class ExportCommandCommand: Command {

    public let name: String = "export"

    @VariadicKey("--filename", description: "Only files with specified filenames (without extension) will be scanned")
    var filenames: [String]

    @VariadicKey("--locale", description: "Only files for specified locales will be scanned")
    var locales: [String]

    @Flag("--force", description: "Override destination file if it exists")
    var force: Bool

    @Key("--format", description: "Export format ('jsonPretty' by default)")
    var format: ExportCommandFormat?

    @Flag("--unescape", description: "Unescape key and value strings")
    var unescape: Bool

    @Flag("--verbose", description: "Outputs more information")
    var verbose: Bool

    @Param var source: String
    @Param var destination: String
    @CollectedParam var keys: [String]

    public init() {}

    public func execute() throws {

        let rollback = Rollback()

        do {

            let keys = try self.keys.map({
                unescape ? try EscapableString(escapedString: $0) : EscapableString(rawString: $0)
            })

            let source = self.source.toPaths()
            let destination = Path(self.destination).absolute()

            if destination.exists {

                if !force {
                    throw ExportCommandError.destinationAlreadyExists(destination: destination)
                }

                try rollback.protectFile(at: destination)
            }
            else {
                try destination.parent().mkpath()
            }

            var result: [String: [String: [JsonEntry]]] = [:]

            let sourceLocalizedFiles = try LocalizedStringsFile.scan(paths: source,
                                                                     locales: (!locales.isEmpty ? Set(locales.map({ Locale(identifier: $0) })) : nil),
                                                                     filenames: (!filenames.isEmpty ? Set(filenames) : nil))

            let allowedKeys = Set(keys)

            sourceLocalizedFiles.forEach({ sourceLocalizedFile in
                sourceLocalizedFile.files.forEach({ stringsFileEntry in

                    let locale = stringsFileEntry.key
                    let stringsFile = stringsFileEntry.value

                    var fileEntries = result[stringsFile.filename] ?? [:]
                    var entries = fileEntries[locale.identifier] ?? []

                    stringsFile.keys.forEach({ key in

                        guard allowedKeys.isEmpty || allowedKeys.contains(key) else {
                            return
                        }

                        guard let value = stringsFile.valueForKey(key) else {
                            return
                        }

                        entries.append(.init(comment: nil, key: key.rawString, value: value.rawString))
                    })

                    fileEntries[locale.identifier] = entries
                    result[stringsFile.filename] = fileEntries
                })
            })

            switch format ?? .jsonPretty {
            case .json:
                let encoder = JSONEncoder()
                let jsonData = try encoder.encode(result)

                try destination.write(jsonData)

            case .jsonPretty:
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let jsonData = try encoder.encode(result)

                try destination.write(jsonData)

            case .plist:
                let encoder = PropertyListEncoder()
                let data = try encoder.encode(result)

                try destination.write(data)
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
