//
//  ValidateCommand.swift
//  
//
//  Created by Sergey Ladeiko on 26.08.21.
//

import Foundation
import SwiftCLI
import PathKit
import StringsFileParser
import Utils

public class ValidateCommand: Command {

    public let name: String = "validate"

    @VariadicKey("--filename", description: "Only files with specified filenames (without extension) will be modified")
    var filenames: [String]

    @VariadicKey("--locale", description: "Only files for specified locales will be modified")
    var locales: [String]

    @Key("--untranslated-prefix", description: "Custom prefix for unstranslated strings (default is '\(DefaultUntranslatedPrefixMarker)'")
    var untranslatedPrefix: String?

    @Param var source: String

    public init() {}

    public func execute() throws {

        let source = self.source.toPaths()
        let sourceLocalizedFiles = try LocalizedStringsFile.scan(paths: source,
                                                                 locales: (!locales.isEmpty ? Set(locales.map({ Locale(identifier: $0) })) : nil),
                                                                 filenames: (!filenames.isEmpty ? Set(filenames) : nil))

        sourceLocalizedFiles.sorted(by: { $0.filename.lowercased() < $1.filename.lowercased() }).forEach({ sourceFile in

            let absentKeys = sourceFile.absentKeys()

            if !absentKeys.isEmpty {

                stdout <<< "File '\(sourceFile.filename)' has absent keys:"

                absentKeys.keys.sorted(by: { $0.identifier < $1.identifier }).forEach({ locale in
                    stdout <<< " \(locale.identifier)"
                    absentKeys[locale]?.sorted(by: { $0.escapedString.lowercased() < $1.escapedString.lowercased() }).forEach({ key in
                        stdout <<< "   " + key.escapedString
                    })
                })

                stdout <<< ""
            }
        })

        sourceLocalizedFiles.sorted(by: { $0.filename.lowercased() < $1.filename.lowercased() }).forEach({ sourceFile in
            sourceFile.files.sorted(by: { $0.value.filename.lowercased() < $1.value.filename.lowercased() }).forEach({

                let file = $0.value

                file.keys.sorted(by: { $0.escapedString.lowercased() < $1.escapedString.lowercased() }).forEach({ key in

                    if let value = file.valueForKey(key), value.isUntranslated(untranslatedPrefix) {
                        stdout <<< "Value for key '\(key.escapedString)' in '\(file.path.string)' is untranslated"
                    }
                })

                stdout <<< ""

            })
        })
    }
}
