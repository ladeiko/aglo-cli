//
//  TextSpacesEntity.swift
//  StringsFileParser
//
//  Created by Siarhei Ladzeika on 7/17/21.
//

import Foundation
import TokenParser
import Utils

public class TextSpacesEntity: TextEntity {

    // MARK: - Public
    
    public private (set) var token: Token

    public var innerValue: EscapableString {
        token.innerValue
    }

    public init(token: Token) {
        self.token = token
        super.init(type: .spaces)
    }

    public static func zero() throws -> TextSpacesEntity {
        try entity(with: "")
    }

    public static func line(_ count: Int = 1) throws -> TextSpacesEntity {
        try entity(with: (0..<count).map({ _ in "\n"}).joined())
    }

    public static func single() throws -> TextSpacesEntity {
        try entity(with: " ")
    }

    static private func entity(with value: String) throws -> TextSpacesEntity {
        return TextSpacesEntity(token: try Token(type: .spaces,
                                                  value: value,
                                                  startInnerInclusive: value.startIndex,
                                                  endInnerExclusive: value.endIndex,
                                                  mode: .raw))
    }

    public func addingRawString(_ string: String) -> TextSpacesEntity {
        TextSpacesEntity(token: token.addingRawString(string))
    }

}
