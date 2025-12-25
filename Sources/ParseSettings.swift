//
//  ParseSettings.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 14/10/16.
//

import Foundation

open class ParseSettings: @unchecked Sendable {
    /**
     * HTML default settings: both tag and attribute names are lower-cased during parsing.
     */
    public static let htmlDefault: ParseSettings = ParseSettings(false, false)
    /**
     * Preserve both tag and attribute case.
     */
    public static let preserveCase: ParseSettings = ParseSettings(true, true)

    private let preserveTagCase: Bool
    private let preserveAttributeCase: Bool
    private let trackSourceRanges: Bool
    private let trackAttributes: Bool

    /**
     Define parse settings.
     - parameter tag: preserve tag case?
     - parameter attribute: preserve attribute name case?
     */
    public init(_ tag: Bool, _ attribute: Bool) {
        preserveTagCase = tag
        preserveAttributeCase = attribute
        trackSourceRanges = true
        trackAttributes = true
    }

    public init(_ tag: Bool, _ attribute: Bool, _ trackSourceRanges: Bool) {
        preserveTagCase = tag
        preserveAttributeCase = attribute
        self.trackSourceRanges = trackSourceRanges
        trackAttributes = true
    }

    public init(_ tag: Bool, _ attribute: Bool, _ trackSourceRanges: Bool, _ trackAttributes: Bool) {
        preserveTagCase = tag
        preserveAttributeCase = attribute
        self.trackSourceRanges = trackSourceRanges
        self.trackAttributes = trackAttributes
    }

    @inline(__always)
    internal func preservesTagCase() -> Bool {
        return preserveTagCase
    }

    @inline(__always)
    internal func preservesAttributeCase() -> Bool {
        return preserveAttributeCase
    }

    @inline(__always)
    internal func tracksSourceRanges() -> Bool {
        return trackSourceRanges
    }

    @inline(__always)
    internal func tracksAttributes() -> Bool {
        return trackAttributes
    }

    open func normalizeTag(_ name: [UInt8]) -> [UInt8] {
        var name = name.trim()
        if (!preserveTagCase) {
            name = name.lowercased()
        }
        return name
    }
    
    open func normalizeTag(_ name: String) -> String {
        return String(decoding: normalizeTag(name.utf8Array), as: UTF8.self)
    }

    open func normalizeAttribute(_ name: [UInt8]) -> [UInt8] {
        var name = name.trim()
        if (!preserveAttributeCase) {
            name = name.lowercased()
        }
        return name
    }
    
    open func normalizeAttribute(_ name: String) -> String {
        return String(decoding: normalizeAttribute(name.utf8Array), as: UTF8.self)
    }

    open func normalizeAttributes(_ attributes: Attributes) throws -> Attributes {
        if (!preserveAttributeCase) {
            attributes.lowercaseAllKeys()
        }
        return attributes
    }

}
