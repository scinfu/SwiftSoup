//
//  ParseError.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 19/10/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import Foundation

/**
 * A Parse Error records an error in the input HTML that occurs in either the tokenisation or the tree building phase.
 */
open class ParseError {
    private let pos: Int
    private let errorMsg: String

    init(_ pos: Int, _ errorMsg: String) {
        self.pos = pos
        self.errorMsg = errorMsg
    }

    /**
     * Retrieve the error message.
     * @return the error message.
     */
    open func getErrorMessage() -> String {
        return errorMsg
    }

    /**
     * Retrieves the offset of the error.
     * @return error offset within input
     */
    open func getPosition() -> Int {
    return pos
    }

    open func toString() -> String {
        return "\(pos): " + errorMsg
    }
}
