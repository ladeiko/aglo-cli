//
//  LocalizedStringsFile.swift
//  StringsFileParser
//
//  Created by Siarhei Ladzeika on 29.07.21.
//

import Foundation
import PathKit
import Utils

public enum LocalizedStringsFileError: Error, LocalizedError {
    case localeAlreadyExists(locale: Locale)
    case fileIsNotLocalized(path: Path)
    case failedToDeleteFile(path: Path)
    case fileAlreadyExists(path: Path)
    case fileNotFound(path: Path)
    case localeNotFound(locale: Locale, filename: String)
    case localeNotFoundForKey(locale: Locale, filename: String, key: EscapableString)
    case duplicateFilenames(filenames: [String])

    public var errorDescription: String? {
        switch self {
        case let .localeAlreadyExists(locale):
            return "LocalizedStringsFileError: locale '\(locale.identifier)' already exists"
        case let .fileIsNotLocalized(path):
            return "LocalizedStringsFileError: file '\(path.string)' is not localized"
        case let .failedToDeleteFile(path):
            return "LocalizedStringsFileError: failed to delete file '\(path.string)'"
        case let .fileAlreadyExists(path):
            return "LocalizedStringsFileError: file '\(path.string)' already exists"
        case let .fileNotFound(path):
            return "LocalizedStringsFileError: file '\(path.string)' not found"
        case let .localeNotFound(locale, filename):
            return "LocalizedStringsFileError: locale '\(locale.identifier)' not found in '\(filename)'"
        case let .localeNotFoundForKey(locale, filename, key):
            return "LocalizedStringsFileError: locale '\(locale.identifier)' not found in '\(filename)' for key '\(key.escapedString)'"
        case let .duplicateFilenames(filenames: filenames):
            return "LocalizedStringsFileError: duplicate filenames '\(filenames.joined(separator: ", "))'"
        }
    }
}

public class LocalizedStringsFile {

    // MARK: - Public

    public enum AddLocaleMode {
        case createNew(copingContentFromLocale: Locale?)
        case addExisting
    }

    public static let localeFolderExtension = "lproj"
    public static let defaultLocale = Locale(identifier: "en")

    public static func scan(paths: [Path], locales: Set<Locale>? = nil, filenames: Set<String>? = nil, options: LogicalParserOptions = []) throws -> [LocalizedStringsFile]  {

        let allFiles: [Path] = try paths.flatMap({ path -> [Path] in
            if path.isFile {
                if path.extension == StringsFile.fileExtension,
                   path.parent().extension == LocalizedStringsFile.localeFolderExtension {
                    return (try path.parent().parent().recursiveChildren()).filter({
                        $0.lastComponentWithoutExtension == path.lastComponentWithoutExtension
                    })
                }
                else {
                    return [path]
                }
            }
            return try path.recursiveChildren()
        })
        .unique()
        .filter({ child in

            guard child.isFile else {
                return false
            }

            guard child.extension == StringsFile.fileExtension else {
                return false
            }

            guard filenames == nil || filenames!.contains(child.lastComponentWithoutExtension) else {
                return false
            }

            return filter(child, locales: locales)
        })
        .sorted(by: { $0.string.lowercased() < $1.string.lowercased() })

        var used = Set<Path>()
        let result: [LocalizedStringsFile] = try allFiles.reduce(into: [LocalizedStringsFile]()) { result, path in

            guard !used.contains(path) else {
                return
            }

            let file = try LocalizedStringsFile(path: path, defaultLocale: defaultLocale, locales: locales, options: options)
            result.append(file)
            file.files.values.forEach({
                used.insert($0.path)
            })
        }.sorted(by: { $0.filename.lowercased() < $1.filename.lowercased() })

        var usedFilenames = Set<String>()
        let duplicates = result.reduce(into: [String](), {
            if usedFilenames.contains($1.filename.lowercased()) {
                $0.append($1.filename)
            }
            else {
                usedFilenames.insert($1.filename.lowercased())
            }
        })

        if !duplicates.isEmpty {
            throw LocalizedStringsFileError.duplicateFilenames(filenames: duplicates)
        }

        return result
    }

    public init(path: Path, defaultLocale: Locale, locales: Set<Locale>?, options: LogicalParserOptions = []) throws {
        if path.parent().extension == Self.localeFolderExtension {

            let name = path.lastComponent
            let folder = path.parent().lastComponent
            let locale = Locale(identifier: path.parent().lastComponentWithoutExtension)
            files = [locale: try StringsFile(path: path, options: options)]

            try path.parent().parent().children().forEach { child in

                guard child.lastComponent != folder else {
                    return
                }

                guard child.extension == Self.localeFolderExtension else {
                    return
                }

                let location = (path.parent().parent() + child + name)

                guard location.isFile else {
                    return
                }

                guard Self.filter(location, locales: locales) else {
                    return
                }

                let locale = Locale(identifier: child.lastComponentWithoutExtension)
                let file = try StringsFile(path: location, options: options)
                files[locale] = file
            }
        }
        else {

            if let locales = locales, !locales.isEmpty, !locales.contains(defaultLocale) {
                files = [:]
                return
            }

            files = [defaultLocale: try StringsFile(path: path, options: options)]
        }
    }

    public var filename: String {
        files.first!.value.path.lastComponentWithoutExtension
    }

    public func addLocale(_ locale: Locale, mode: AddLocaleMode, options: LogicalParserOptions = []) throws {

        guard files[locale] == nil else {
            throw LocalizedStringsFileError.localeAlreadyExists(locale: locale)
        }

        guard isLocalized else {
            throw LocalizedStringsFileError.fileIsNotLocalized(path: files.first!.value.path)
        }

        let folder = files.first!.value.path.parent().parent() + (locale.identifier + "." + Self.localeFolderExtension)
        let location = folder + (filename + "." + StringsFile.fileExtension)

        switch mode {
        case let .createNew(copingContentFromLocale: sourceLocale):

            try folder.mkpath()
            let sourceContent: String
            if let sourceLocale = sourceLocale {
                sourceContent = files[sourceLocale]!.string
            }
            else {
                sourceContent = ""
            }

            try location.write(sourceContent, encoding: StringsFile.defaultEncoding)
            files[locale] = try StringsFile(path: location, options: options)

        case .addExisting:

            if !location.exists {
                throw LocalizedStringsFileError.fileNotFound(path: location)
            }

            files[locale] = try StringsFile(path: location, options: options)
        }
    }

    public func save(force: Bool = false) throws {
        try files.values.forEach({
            try $0.save(force: force)
        })
    }

    public func load() throws {
        try files.values.forEach({
            try $0.load()
        })
    }

    public func hasLocale(_ locale: Locale) -> Bool {
        files[locale] != nil
    }

    public func removeLocale(_ locale: Locale) throws {

        guard let file = files[locale] else {
            return
        }

        do {
            try file.path.delete()
        }
        catch {
            if file.path.exists {
                throw LocalizedStringsFileError.failedToDeleteFile(path: file.path)
            }
        }

        files.removeValue(forKey: locale)
    }

    public func removeValue(forKey key: EscapableString, in locales: Set<Locale>? = nil) throws {

        let targetFiles = files.filter({
            if let locales = locales {
                return locales.contains($0.key)
            }
            else {
                return true
            }
        })

        try targetFiles.forEach({
            try $0.value.removeValueForKey(key)
        })
    }

    public func keyExists(_ key: EscapableString, in locale: Locale) -> Bool {
        guard let file = files[locale] else {
            return false
        }

        return file.keyExists(key)
    }

    public func setValue(_ value: EscapableString, forKey key: EscapableString, in locale: Locale) throws {
        guard let file = files[locale] else {
            throw LocalizedStringsFileError.localeNotFoundForKey(locale: locale, filename: filename, key: key)
        }

        try file.setValue(value, forKey: key)
    }

    public func value(forKey key: EscapableString, in locale: Locale) -> EscapableString? {
        guard let file = files[locale] else {
            return nil
        }

        return file.valueForKey(key)
    }

    public func comment(forKey key: EscapableString, in locale: Locale) -> EscapableString? {
        guard let file = files[locale] else {
            return nil
        }

        return file.commentForKey(key)
    }

    public func valueForTag(_ tag: String, for key: EscapableString, in locale: Locale) -> String? {
        guard let file = files[locale] else {
            return nil
        }

        return file.valueForTag(tag, in: key)
    }

    public func sort(caseInsensitive: Bool) throws {
        if caseInsensitive {
            try files.values.forEach({
                try $0.sort(by: { $0.escapedString.lowercased() < $1.escapedString.lowercased() })
            })
        }
        else {
            try files.values.forEach({
                try $0.sort()
            })
        }
    }

    public func sort(by: ((_ key1: EscapableString, _ key2: EscapableString) -> Bool)? = nil) throws {
        try files.values.forEach({
            try $0.sort(by: by)
        })
    }

    public func allKeys() -> Set<EscapableString> {
        files.values.map({ $0.keys }).reduce(Set<EscapableString>(), { $0.union($1) })
    }

    public func absentKeys() -> [Locale: Set<EscapableString>] {
        let allKeys = files.values.map({ $0.keys }).reduce(Set<EscapableString>(), { $0.union($1) })
        return files.reduce(into: [Locale: Set<EscapableString>]()) { result, fileEntry in
            let absentKeys = allKeys.subtracting(fileEntry.value.keys)
            if !absentKeys.isEmpty {
                result[fileEntry.key] = absentKeys
            }
        }
    }

    public static let defaultAbsentValue = DefaultUntranslatedPrefixMarker

    public func addAbsentKeys(fillAbsentValuesWith absentValue: EscapableString = EscapableString(rawString: LocalizedStringsFile.defaultAbsentValue), to locales: Set<Locale>? = nil) throws {
        let allKeys = files.values.map({ $0.keys }).reduce(Set<EscapableString>(), { $0.union($1) })
        try files.forEach({ fileEntry in

            let locale = fileEntry.key
            if let locales = locales, !locales.contains(locale) {
                return
            }

            let file = fileEntry.value
            let absentKeys = allKeys.subtracting(file.keys)
            try absentKeys.forEach({ key in
                try file.setValue(absentValue, forKey: key)
            })
        })
    }

    public func syncKeys(from sourceLocale: Locale, to locales: Set<Locale>? = nil,
                         fillAbsentValuesWith absentValue: EscapableString = EscapableString(rawString: LocalizedStringsFile.defaultAbsentValue)) throws {

        guard let source = files[sourceLocale] else {
            throw LocalizedStringsFileError.localeNotFound(locale: sourceLocale,filename: filename)
        }

        let sourceKeys = source.keys
        try files.forEach({ fileEntry in

            let locale = fileEntry.key
            guard locale != sourceLocale else {
                return
            }

            if let locales = locales, !locales.contains(locale) {
                return
            }

            let file = fileEntry.value
            let absentKeys = sourceKeys.subtracting(file.keys)
            let extraKeys = file.keys.subtracting(sourceKeys)

            try absentKeys.forEach({ key in
                try file.setValue(absentValue, forKey: key)
            })

            try extraKeys.forEach({ key in
                try file.removeValueForKey(key)
            })
        })
    }

    public func setComment(_ comment: EscapableString, forKey key: EscapableString, in locale: Locale) throws {
        guard let file = files[locale] else {
            throw LocalizedStringsFileError.localeNotFoundForKey(locale: locale, filename: filename, key: key)
        }

        try file.setComment(comment, forKey: key)
    }

    public var isLocalized: Bool {
        files.count > 1 || files.first!.value.path.parent().lastComponentWithoutExtension == files.first!.key.identifier
    }

    public private(set) var files: [Locale: StringsFile]

    // MARK: - Private

    private static func filter(_ path: Path, locales: Set<Locale>? = nil) -> Bool {

        guard let locales = locales, !locales.isEmpty else {
            return true
        }

        let localeFolderName = path.parent().lastComponent

        if !localeFolderName.hasSuffix(".\(Self.localeFolderExtension)") {
            return false
        }

        let childLocale = Locale(identifier: String(localeFolderName[localeFolderName.startIndex..<localeFolderName.lastIndex(of: ".")!]))

        return locales.contains(childLocale)
    }
}
