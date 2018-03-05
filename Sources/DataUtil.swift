//
//  DataUtil.swift
//  SwifSoup
//
//  Created by Nabil Chatbi on 02/10/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import Foundation

/**
 * Internal static utilities for handling data.
 *
 */
class  DataUtil {

    static let charsetPattern = "(?i)\\bcharset=\\s*(?:\"|')?([^\\s,;\"']*)"
    static let defaultCharset = "UTF-8" // used if not found in header or meta charset
    static let bufferSize = 0x20000 // ~130K.
    static let UNICODE_BOM = 0xFEFF
    static let mimeBoundaryChars = "-_1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    static let boundaryLength = 32

}
