//
//  HeaderEntry.swift
//  StringsFileParser
//
//  Created by Siarhei Ladzeika on 28.07.21.
//

import Foundation
import TokenParser

public class HeaderEntry: Entry {

    // MARK: - Public
    
    public let commentEntities: [TextCommentEntity]
    public let spaceEntity: TextSpacesEntity?

    public var tokens: [Token] {
        [
            commentEntities.flatMap({ $0.tokens }),
            [spaceEntity?.token].compactMap({ $0 }),
        ].flatMap({ $0 })
    }

    public init(commentEntities: [TextCommentEntity], spaceEntity: TextSpacesEntity?) {
        self.commentEntities = commentEntities
        self.spaceEntity = spaceEntity
    }
}

extension HeaderEntry: CustomStringConvertible {
    public var description: String {
        "<" + tokens.map({ $0.value }).joined(separator: "><") + ">"
    }
}
