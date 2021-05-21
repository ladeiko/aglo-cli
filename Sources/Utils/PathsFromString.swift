//
//  PathsFromString.swift
//  
//
//  Created by Sergey Ladeiko on 26.08.21.
//

import Foundation
import PathKit

extension String {

    public func toPaths() -> [Path] {
        self.split { c in
            switch c {
            case "|", ",": return true
            default: return false
            }
        }.map({ Path(String($0)).absolute() })
    }

}
