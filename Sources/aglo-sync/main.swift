//
//  main.swift
//  aglo-cli
//
//  Created by Siarhei Ladzeika on 8/15/21.
//

import Foundation
import Sync

func getKey(_ key: String) -> String? {
    var next = false

    for k in CommandLine.arguments {

        if next {
            return k
        }

        if k.hasPrefix("-") {

            if k == key {
                next = true
                continue
            }

            if k.hasPrefix(key + "="), let v = k.split(separator: "=").last {
                return String(v)
            }
        }
    }

    return nil
}

func getKeys(_ key: String) -> [String] {

    var result: [String] = []
    var next = false

    for k in CommandLine.arguments {

        if next {
            result.append(k)
            next = false
            continue
        }

        if k.hasPrefix("-") {

            if k == key {
                next = true
                continue
            }

            if k.hasPrefix(key + "="), let v = k.split(separator: "=").last {
                result.append(String(v))
                continue
            }
        }
    }

    return result
}

enum E: Error, LocalizedError {
    case invalidArgsCount

    public var errorDescription: String? {
        switch self {
            case .invalidArgsCount:
                return "Invalid number of arguments"
        }
    }
}

func getArg(at index: Int) throws -> String {
    let args = CommandLine.arguments.filter({ !$0.hasPrefix("-") })
    guard index < args.count else {
        throw E.invalidArgsCount
    }
    return args[index]
}

try sync(sort: CommandLine.arguments.contains("--sort"),
     caseInsensitiveSorting: CommandLine.arguments.contains("--case-insensitive"),
     addAbsentKeys: CommandLine.arguments.contains("--add-absent-keys"),
     makeNewValuesUntranslated: CommandLine.arguments.contains("--make-new-values-untranslated"),
     untranslatedOnly: CommandLine.arguments.contains("--untranslated-only"),
     noMerge:  CommandLine.arguments.contains("--no-merge"),
     filenames: getKeys("--filename"),
     untranslatedPrefix: getKey("--untranslated-prefix"),
     locales: getKeys("--locale"),
     verbose: CommandLine.arguments.contains("--verbose"),
     source: try getArg(at: -2),
     destination: try getArg(at: -1))
