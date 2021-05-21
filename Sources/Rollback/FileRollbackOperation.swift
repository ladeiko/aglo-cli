//
//  FileRollbackOperation.swift
//  Rollback
//
//  Created by Siarhei Ladzeika on 8/16/21.
//

import Foundation
import PathKit

class FileRollbackOperation: RollbackOperation {

    private static var instances = 0

    private static func instancesUp() throws {
        if instances == 0 {
            _tempLocation = try Path.uniqueTemporary()
        }

        instances += 1
    }

    private static func instancesDown() {
        if instances == 1 {
            try? _tempLocation?.delete()
            _tempLocation = nil
        }

        instances -= 1
    }

    private static var _tempLocation: Path?
    private let locationToProtect: Path
    private let safeLocation: Path

    deinit {
        try? safeLocation.delete()
        Self.instancesDown()
    }

    init(_ locationToProtect: Path) throws {
        try Self.instancesUp()
        self.locationToProtect = locationToProtect
        safeLocation = Self._tempLocation! + UUID().uuidString
        try locationToProtect.copy(safeLocation)
    }

    func rollback() throws {
        try? locationToProtect.delete()
        try safeLocation.copy(locationToProtect)
    }

    var description: String {
        "File rollback operation: locationToProtect = '\(locationToProtect.string)'"
    }
}
