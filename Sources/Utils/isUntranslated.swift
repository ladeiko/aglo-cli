//
//  isUntranslated.swift
//  Utils
//
//  Created by Siarhei Ladzeika on 8/21/21.
//

import Foundation

public let DefaultUntranslatedPrefixMarker = "#"

public func untranslatedPrefixMarker(_ proposedMarker: String?) -> String {
    proposedMarker ?? DefaultUntranslatedPrefixMarker
}

