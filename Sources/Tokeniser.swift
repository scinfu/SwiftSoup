//
//  Tokeniser.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 19/10/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import Foundation

final class Tokeniser {
    static let replacementChar: UnicodeScalar = "\u{FFFD}" // replaces null character
    private static let notCharRefChars = ParsingStrings([UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ", "<", UnicodeScalar.Ampersand])
    private static let notNamedCharRefChars = ParsingStrings([UTF8Arrays.equalSign, UTF8Arrays.hyphen, UTF8Arrays.underscore])
    
    private let reader: CharacterReader // html input
    private let errors: ParseErrorList? // errors found while tokenising
    
    private var state: TokeniserState = TokeniserState.Data // current tokenisation state
    private var emitPending: Token?  // the token we are about to emit on next read
    private var isEmitPending: Bool = false
    private var charsSlice: ArraySlice<UInt8>? = nil // characters pending an emit. Will fall to charsBuilder if more than one
    private var pendingSlices = [ArraySlice<UInt8>]()
    private let charsBuilder: StringBuilder = StringBuilder(1024) // buffers characters to output as one token, if more than one emit per read
    let dataBuffer: StringBuilder = StringBuilder(1024) // buffers data looking for </script>
    
    var tagPending: Token.Tag = Token.Tag() // tag we are building up
    let startPending: Token.StartTag  = Token.StartTag()
    let endPending: Token.EndTag  = Token.EndTag()
    let charPending: Token.Char  = Token.Char()
    let doctypePending: Token.Doctype  = Token.Doctype() // doctype building up
    let commentPending: Token.Comment  = Token.Comment() // comment building up
    private var lastStartTag: [UInt8]?  // the last start tag emitted, to test appropriate end tag
    private var selfClosingFlagAcknowledged: Bool = true
    
    init(_ reader: CharacterReader, _ errors: ParseErrorList?) {
        self.reader = reader
        self.errors = errors
    }
    
    func read() throws -> Token {
        if (!selfClosingFlagAcknowledged) {
            error("Self closing flag not acknowledged")
            selfClosingFlagAcknowledged = true
        }
        
        while (!isEmitPending) {
            try state.read(self, reader)
        }
        
        if !charsBuilder.isEmpty {
            let str = charsBuilder.buffer
            charsBuilder.clear()
            // Clear any pending slices, as the builder takes precedence.
            pendingSlices.removeAll()
            return charPending.data(str)
        } else if !pendingSlices.isEmpty {
            // Combine all the pending slices in one allocation.
            let totalCount = pendingSlices.reduce(0) { $0 + $1.count }
            var combined = [UInt8]()
            combined.reserveCapacity(totalCount)
            for slice in pendingSlices {
                combined.append(contentsOf: slice)
            }
            pendingSlices.removeAll()
            return charPending.data(combined)
        } else {
            isEmitPending = false
            return emitPending!
        }
    }
    
    func emit(_ token: Token) throws {
        try Validate.isFalse(val: isEmitPending, msg: "There is an unread token pending!")
        
        emitPending = token
        isEmitPending = true
        
        if (token.type == Token.TokenType.StartTag) {
            let startTag: Token.StartTag  = token as! Token.StartTag
            lastStartTag = startTag._tagName!
            if (startTag._selfClosing) {
                selfClosingFlagAcknowledged = false
            }
        } else if (token.type == Token.TokenType.EndTag) {
            let endTag: Token.EndTag = token as! Token.EndTag
            if (endTag._attributes.size() != 0) {
                error("Attributes incorrectly present on end tag")
            }
        }
    }
    
    func emit(_ str: ArraySlice<UInt8>) {
        pendingSlices.append(str)
    }
    
    func emit(_ str: [UInt8]) {
        emit(str[...]) // Call the slice version with the full array as a slice
    }
    
    func emit(_ str: String) {
        emit(str.utf8Array)
    }
    
    //    func emit(_ chars: [UInt8]) {
    //        emit(String(chars.map {Character($0)}))
    //    }
    
    //    func emit(_ codepoints: [Int]) {
    //        emit(String(codepoints, 0, codepoints.length));
    //    }
    
    func emit(_ c: UnicodeScalar) {
        emit(Array(c.utf8))
    }
    
    func emit(_ c: [UnicodeScalar]) {
        emit(c.flatMap { Array($0.utf8) })
    }
    
    func getState() -> TokeniserState {
        return state
    }
    
    func transition(_ state: TokeniserState) {
        self.state = state
    }
    
    func advanceTransition(_ state: TokeniserState) {
        reader.advance()
        self.state = state
    }
    
    func acknowledgeSelfClosingFlag() {
        selfClosingFlagAcknowledged = true
    }
    
    func consumeCharacterReference(_ additionalAllowedCharacter: UnicodeScalar?, _ inAttribute: Bool) throws -> [UnicodeScalar]? {
        if (reader.isEmpty()) {
            return nil
        }
        if (additionalAllowedCharacter != nil && additionalAllowedCharacter == reader.current()) {
            return nil
        }
        if (reader.matchesAny(Tokeniser.notCharRefChars)) {
            return nil
        }
        
        reader.markPos()
        if (reader.matchConsume(UTF8Arrays.hash)) { // numbered
            let isHexMode: Bool = reader.matchConsumeIgnoreCase("X".utf8Array)
            let numRef: ArraySlice<UInt8> = isHexMode ? reader.consumeHexSequence() : reader.consumeDigitSequence()
            if (numRef.isEmpty) { // didn't match anything
                characterReferenceError("numeric reference with no numerals")
                reader.rewindToMark()
                return nil
            }
            if (!reader.matchConsume(UTF8Arrays.semicolon)) {
                characterReferenceError("missing semicolon") // missing semi
            }
            var charval: Int  = -1
            
            let base: Int = isHexMode ? 16 : 10
            if let num = numRef.toInt(radix: base) {
                charval = num
            }
            
            if (charval == -1 || (charval >= 0xD800 && charval <= 0xDFFF) || charval > 0x10FFFF) {
                characterReferenceError("character outside of valid range")
                return [Tokeniser.replacementChar]
            } else {
                // todo: implement number replacement table
                // todo: check for extra illegal unicode points as parse errors
                return [UnicodeScalar(charval)!]
            }
        } else { // named
                 // get as many letters as possible, and look for matching entities.
            let nameRef: ArraySlice<UInt8> = reader.consumeLetterThenDigitSequence()
            let looksLegit: Bool = reader.matches(";")
            // found if a base named entity without a ;, or an extended entity with the ;.
            let found: Bool = (Entities.isBaseNamedEntity(nameRef) || (Entities.isNamedEntity(nameRef) && looksLegit))
            
            if (!found) {
                reader.rewindToMark()
                if (looksLegit) { // named with semicolon
                    characterReferenceError("invalid named referenece '\(nameRef)'")
                }
                return nil
            }
            if (inAttribute && (reader.matchesLetter() || reader.matchesDigit() || reader.matchesAny(Self.notNamedCharRefChars))) {
                // don't want that to match
                reader.rewindToMark()
                return nil
            }
            if (!reader.matchConsume(UTF8Arrays.semicolon)) {
                characterReferenceError("missing semicolon") // missing semi
            }
            if let points = Entities.codepointsForName(nameRef) {
                if points.count > 2 {
                    try Validate.fail(msg: "Unexpected characters returned for \(nameRef) num: \(points.count)")
                }
                return points
            }
            try Validate.fail(msg: "Entity name not found: \(nameRef)")
            return []
        }
    }
    
    @discardableResult
    @inlinable
    func createTagPending(_ start: Bool) -> Token.Tag {
        if start {
            startPending.reset()
            tagPending = startPending
        } else {
            endPending.reset()
            tagPending = endPending
        }
        return tagPending
    }
    
    @inlinable
    func emitTagPending() throws {
        try tagPending.finaliseTag()
        try emit(tagPending)
    }
    
    func createCommentPending() {
        commentPending.reset()
    }
    
    func emitCommentPending() throws {
        try emit(commentPending)
    }
    
    func createDoctypePending() {
        doctypePending.reset()
    }
    
    func emitDoctypePending() throws {
        try emit(doctypePending)
    }
    
    func createTempBuffer() {
        Token.reset(dataBuffer)
    }
    
    func isAppropriateEndTagToken()throws->Bool {
        if(lastStartTag != nil) {
            let s = try tagPending.name()
            return s.equalsIgnoreCase(string: lastStartTag!)
        }
        return false
    }
    
    func appropriateEndTagName() -> [UInt8]? {
        if (lastStartTag == nil) {
            return nil
        }
        return lastStartTag
    }
    
    func error(_ state: TokeniserState) {
        if (errors != nil && errors!.canAddError()) {
            errors?.add(ParseError(reader.getPos(), "Unexpected character '\(String(reader.current()))' in input state [\(state.description)]"))
        }
    }
    
    func eofError(_ state: TokeniserState) {
        if (errors != nil && errors!.canAddError()) {
            errors?.add(ParseError(reader.getPos(), "Unexpectedly reached end of file (EOF) in input state [\(state.description)]"))
        }
    }
    
    private func characterReferenceError(_ message: String) {
        if (errors != nil && errors!.canAddError()) {
            errors?.add(ParseError(reader.getPos(), "Invalid character reference: \(message)"))
        }
    }
    
    private func error(_ errorMsg: String) {
        if (errors != nil && errors!.canAddError()) {
            errors?.add(ParseError(reader.getPos(), errorMsg))
        }
    }
    
    func currentNodeInHtmlNS() -> Bool {
        // todo: implement namespaces correctly
        return true
        // Element currentNode = currentNode()
        // return currentNode != null && currentNode.namespace().equals("HTML")
    }
    
    /**
     * Utility method to consume reader and unescape entities found within.
     * @param inAttribute
     * @return unescaped string from reader
     */
    func unescapeEntities(_ inAttribute: Bool) throws -> [UInt8] {
        let builder: StringBuilder = StringBuilder()
        while (!reader.isEmpty()) {
            builder.append(reader.consumeTo(UnicodeScalar.Ampersand))
            if reader.matches(UnicodeScalar.Ampersand) {
                reader.consume()
                if let c = try consumeCharacterReference(nil, inAttribute) {
                    if c.isEmpty {
                        builder.append(UnicodeScalar.Ampersand)
                    } else {
                        builder.appendCodePoint(c[0])
                        if (c.count == 2) {
                            builder.appendCodePoint(c[1])
                        }
                    }
                } else {
                    builder.append(UnicodeScalar.Ampersand)
                }
            }
        }
        return builder.buffer
    }
}
