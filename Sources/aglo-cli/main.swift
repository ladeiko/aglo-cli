//
//  main.swift
//  aglo-cli
//
//  Created by Siarhei Ladzeika on 8/15/21.
//

import SwiftCLI
import CLICommands

let tool = CLI(name: "aglo-cli",
               version: "1.0.1",
               description: "AGLO command line utility for localization ('strings') files manipulation. Created by Siarhei Ladzeika <sergey.ladeiko@gmail.com>")
tool.commands = [
    AddAbsentKeysCommand(),
    AddKeysCommand(),
    BalanceKeysCommand(),
    ClearKeysCommand(),
    CloneLocaleCommand(),
    CopyFilesCommand(),
    CopyKeyCommand(),
    CopyNewKeysCommand(),
    CopyValuesCommand(),
    DeleteKeysCommand(),
    ExportCommandCommand(),
    GetValueCommand(),
    LinkKeyCommand(),
    MakeKeysTranslatedCommand(),
    MoveFilesCommand(),
    MoveKeyCommand(),
    PrettifyCommand(),
    RemoveDuplicateKeysCommand(),
    RenameKeyCommand(),
    SetCommentCommand(),
    SetValueCommand(),
    SortKeysCommand(),
    SyncCommand(),
    UnlinkKeyCommand(),
    UnzipFromCsvCommand(),
    UnzipKeysCommand(),
    ValidateCommand(),
    ZipKeysCommand(),
    ZipToCsvCommand(),
]

tool.goAndExit()
