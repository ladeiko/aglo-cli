//
//  SyncCommand.swift
//  
//
//  Created by Sergey Ladeiko on 23.01.23.
//

import Foundation
import SwiftCLI
import Sync
import Utils

public class SyncCommand: Command {

    public let name: String = "sync"

    @Flag("--sort", description: "If defined, then keys will be sorted")
    var sort: Bool

    @Flag("--case-insensitive", description: "Set case insensitive sorting if sort operation")
    var caseInsensitiveSorting: Bool

    @Flag("--add-absent-keys", description: "Synchronize keys by appending absent keys")
    var addAbsentKeys: Bool

    @Flag("--make-new-values-untranslated", description: "If set, then all new values will be prefixed with '\(DefaultUntranslatedPrefixMarker)'")
    var makeNewValuesUntranslated: Bool

    @Flag("--untranslated-only", description: "Collect values with '\(DefaultUntranslatedPrefixMarker)' at the beginning")
    var untranslatedOnly: Bool

    @Flag("--no-merge", description: "If set, then files will not be merged unto one output file")
    var noMerge: Bool

    @VariadicKey("--filename", description: "Only files with specified filenames (without extension) will be scanned")
    var filenames: [String]

    @Key("--untranslated-prefix", description: "Custom prefix for unstranslated strings (default is '\(DefaultUntranslatedPrefixMarker)'")
    var untranslatedPrefix: String?

    @VariadicKey("--locale", description: "Only files for specified locales will be scanned")
    var locales: [String]

    @Flag("--verbose", description: "Outputs more information")
    var verbose: Bool

    @Param var source: String
    @Param var destination: String

    public init() {}

    public func execute() throws {
        try sync(sort: sort,
             caseInsensitiveSorting: caseInsensitiveSorting,
             addAbsentKeys: addAbsentKeys,
             makeNewValuesUntranslated: makeNewValuesUntranslated,
             untranslatedOnly: untranslatedOnly,
             noMerge: noMerge,
             filenames: filenames,
             untranslatedPrefix: untranslatedPrefix,
             locales: locales,
             verbose: verbose,
             source: source,
             destination: destination)
    }
}

