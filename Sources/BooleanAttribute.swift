//
//  BooleanAttribute.swift
//  SwifSoup
//
//  Created by Nabil Chatbi on 29/09/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import Foundation

/**
 * A boolean attribute that is written out without any value.
 */
open class BooleanAttribute: Attribute {
    /**
     * Create a new boolean attribute from unencoded (raw) key.
     * @param key attribute key
     */
    init(key: [UInt8]) throws {
        try super.init(key: key, value: "".utf8Array)
    }

    override public func isBooleanAttribute() -> Bool {
        return true
    }
}
