//
//  TextStringEntity.swift
//  StringsFileParser
//
//  Created by Siarhei Ladzeika on 21.05.21.
//

import Foundation
import TokenParser
import Utils

public class TextStringEntity: TextEntity {

    // MARK: - Public
    
    public private (set) var token: Token

    public init(token: Token) {
        self.token = token
        super.init(type: .value)
    }

    public var innerValue: EscapableString {
        token.innerValue
    }

    public func updatingValue(_ value: EscapableString) -> TextStringEntity {
        TextStringEntity(token: token.updatingInnerValue(value))
    }
}

extension TextStringEntity: Hashable {

    public static func == (lhs: TextStringEntity, rhs: TextStringEntity) -> Bool {
        return lhs.innerValue == rhs.innerValue
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(innerValue)
    }
}
