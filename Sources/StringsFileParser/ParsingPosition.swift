//
//  ParsingPosition.swift
//  StringsFileParser
//
//  Created by Siarhei Ladzeika on 7/17/21.
//

import Foundation

struct ParsingPosition: CustomStringConvertible, Equatable {

    // MARK: - Public

    let line: Int
    let column: Int

    var description: String {
        return "Position: \(line):\(column)"
    }
}
