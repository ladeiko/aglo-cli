//
//  fileExtension.swift
//  Utils
//
//  Created by Siarhei Ladzeika on 30.07.21.
//

import Foundation

extension String {

    public func removingFileExtension() -> String {
        guard let dotIndex = self.lastIndex(of: ".") else {
            return self
        }
        return String(self[startIndex..<dotIndex])
    }

    public func fileExtension() -> String? {

        guard let dotIndex = self.lastIndex(of: ".") else {
            return nil
        }

        return String(self[self.index(after: dotIndex)...])
    }
}
