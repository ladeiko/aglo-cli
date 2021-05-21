//
//  RemoveFileRollbackOperation.swift
//  Rollback
//
//  Created by Siarhei Ladzeika on 8/16/21.
//

import Foundation
import PathKit

class RemoveFileRollbackOperation: RollbackOperation {

    private let locationToRemove: Path

    init(_ locationToRemove: Path) {
        self.locationToRemove = locationToRemove
    }

    func rollback() throws {
        try? locationToRemove.delete()
    }

    var description: String {
        "File delete rollback operation: locationToRemove = '\(locationToRemove.string)'"
    }
}
