//
//  AnyEntry.swift
//  StringsFileParser
//
//  Created by Siarhei Ladzeika on 28.07.21.
//

import Foundation
import TokenParser

class AnyEntry: Entry {

    // MARK: - Public
    
    let entities: [TextEntity]
    var tokens: [Token] {
        entities.reduce(into: []) {
            switch $1 {
            case let value as TextSpacesEntity:
                $0.append(value.token)
            case let value as TextCommentEntity:
                $0.append(contentsOf: value.tokens)
            default:
                fatalError()
            }
        }
    }

    init(entities: [TextEntity]) {
        self.entities = entities
    }
}

extension AnyEntry: CustomStringConvertible {
    var description: String {
        "<" + tokens.map({ $0.value }).joined(separator: "><") + ">"
    }
}
