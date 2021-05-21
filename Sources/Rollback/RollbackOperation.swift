//
//  RollbackOperation.swift
//  Rollback
//
//  Created by Siarhei Ladzeika on 30.07.21.
//

import Foundation

protocol RollbackOperation: CustomStringConvertible {
    func rollback() throws
}
