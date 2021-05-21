//
//  ArrayUtils.swift
//  Utils
//
//  Created by Siarhei Ladzeika on 7/18/21.
//  Copyright © 2021 Siarhei Ladzeika. All rights reserved.
//

import Foundation

extension Array {

    public func removingLastElements(_ numberOfElementsToRemove: Int = 1) -> Array {
        return Array(self[0..<count - numberOfElementsToRemove])
    }

    public func lastElements(where block: (_ e: Element) -> Bool) -> Array {

        var result: [Element] = []

        for i in (0...count - 1).reversed() {
            if !block(self[i]) {
                break
            }
            result.append(self[i])
        }

        return result.reversed()
    }

    public func appending(_ element: Element) -> Array {
        var a = self
        a.append(element)
        return a
    }
}
