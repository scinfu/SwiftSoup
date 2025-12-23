//
//  SourceRange.swift
//  SwiftSoup
//
//  Created by Codex on 23/12/2025.
//

import Foundation

@usableFromInline
internal struct SourceRange: Equatable {
    @usableFromInline
    var start: Int
    @usableFromInline
    var end: Int

    @inline(__always)
    init(start: Int, end: Int) {
        self.start = start
        self.end = end
    }

    @inline(__always)
    var isValid: Bool {
        return start >= 0 && end >= start
    }
}

@usableFromInline
internal struct SourcePatch: Equatable {
    @usableFromInline
    var range: SourceRange
    @usableFromInline
    var replacement: [UInt8]

    @inline(__always)
    init(range: SourceRange, replacement: [UInt8]) {
        self.range = range
        self.replacement = replacement
    }
}
