//
//  splitIntoLines.swift
//  Utils
//
//  Created by Siarhei Ladzeika on 8/15/21.
//

import Foundation

extension String {

    public static let wordsSet = CharacterSet.alphanumerics

    public func splitIntoLines(limit: Int) -> [String] {
        var lines: [String] = []
        var line = ""

        for c in self {
            line += String(c)
            if !c.unicodeScalars.contains(where: { Self.wordsSet.contains($0) }) {
                if line.count >= limit {
                    lines.append(line)
                    line = ""
                }
            }
        }

        if !line.isEmpty {
            lines.append(line)
        }

        return lines.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines )}).filter({ !$0.isEmpty })
    }
}
