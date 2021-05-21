//
//  TokenType.swift
//  TokenParser
//
//  Created by Siarhei Ladzeika on 7/17/21.
//

import Foundation

public enum TokenType: Equatable {
    case spaces
    case multiLineComment
    case singleLineComment
    case string
    case equation
    case semicomma

    public var isComment: Bool {
        self == .multiLineComment || self == .singleLineComment
    }
}
