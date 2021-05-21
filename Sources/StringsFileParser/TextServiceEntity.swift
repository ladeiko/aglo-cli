//
//  TextServiceEntity.swift
//  StringsFileParser
//
//  Created by Siarhei Ladzeika on 7/17/21.
//  Copyright © 2021 Siarhei Ladzeika. All rights reserved.
//

import Foundation
import TokenParser
import Utils

public class TextServiceEntity: TextEntity {

    // MARK: - Public
    
    public private (set) var token: Token

    public init(token: Token) {
        self.token = token
        super.init(type: .service)
    }

    public var innerValue: EscapableString {
        token.innerValue
    }

    public var isEquation: Bool { innerValue.rawString == Token.equation }
    public var isSemicomma: Bool { innerValue.rawString == Token.semicomma }
}

extension TextServiceEntity: Hashable {

    public static func == (lhs: TextServiceEntity, rhs: TextServiceEntity) -> Bool {
        return lhs.innerValue == rhs.innerValue
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(innerValue)
    }
}
