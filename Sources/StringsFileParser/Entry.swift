//
//  Entry.swift
//  StringsFileParser
//
//  Created by Siarhei Ladzeika on 28.07.21.
//

import Foundation
import TokenParser

public protocol Entry {
    var tokens: [Token] { get }
}
