//
//  Rollback.swift
//  Rollback
//
//  Created by Siarhei Ladzeika on 30.07.21.
//

import Foundation
import PathKit

public class Rollback {

    private var protectedFiles = Set<Path>()
    private var deletedFiles = Set<Path>()
    private var operations: [RollbackOperation] = []

    public init() {}

    public func protectFile(at location: Path) throws {

        guard !protectedFiles.contains(location) else {
            return
        }

        protectedFiles.insert(location)
        operations.append(try FileRollbackOperation(location))
    }

    public func deleteFile(at location: Path) throws {

        guard !deletedFiles.contains(location) else {
            return
        }

        deletedFiles.insert(location)
        operations.append(RemoveFileRollbackOperation(location))
    }

    public func restore() throws {
        try operations.forEach({
            try $0.rollback()
        })
    }
}
