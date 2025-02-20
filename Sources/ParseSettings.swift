//
//  ParseSettings.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 14/10/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import Foundation

open class ParseSettings {
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

    /**
     * Define parse settings.
     * @param tag preserve tag case?
     * @param attribute preserve attribute name case?
     */
    public init(_ tag: Bool, _ attribute: Bool) {
        preserveTagCase = tag
        preserveAttributeCase = attribute
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
