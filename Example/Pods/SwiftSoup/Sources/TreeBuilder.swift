//
//  TreeBuilder.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 24/10/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import Foundation

public class TreeBuilder {
    public var reader: CharacterReader
    var tokeniser: Tokeniser
    public var doc: Document // current doc we are building into
    public var stack: Array<Element> // the stack of open elements
    public var baseUri: String // current base uri, for creating new elements
    public var currentToken: Token? // currentToken is used only for error tracking.
    public var errors: ParseErrorList // null when not tracking errors
    public var settings: ParseSettings

    private let start: Token.StartTag = Token.StartTag() // start tag to process
    private let end: Token.EndTag  = Token.EndTag()

    public func defaultSettings() -> ParseSettings {preconditionFailure("This method must be overridden")}

    public init() {
        doc =  Document("")
        reader = CharacterReader("")
        tokeniser = Tokeniser(reader, nil)
        stack = Array<Element>()
        baseUri = ""
        errors = ParseErrorList(0, 0)
        settings = ParseSettings(false, false)
    }

    public func initialiseParse(_ input: String, _ baseUri: String, _ errors: ParseErrorList, _ settings: ParseSettings) {
        doc = Document(baseUri)
        self.settings = settings
        reader = CharacterReader(input)
        self.errors = errors
        tokeniser = Tokeniser(reader, errors)
        stack = Array<Element>()
        self.baseUri = baseUri
    }

    func parse(_ input: String, _ baseUri: String, _ errors: ParseErrorList, _ settings: ParseSettings)throws->Document {
		initialiseParse(input, baseUri, errors, settings)
        try runParser()
        return doc
    }

    public func runParser()throws {
        while (true) {
            let token: Token = try tokeniser.read()
            try process(token)
            token.reset()

            if (token.type == Token.TokenType.EOF) {
                break
            }
        }
    }

    @discardableResult
    public func process(_ token: Token)throws->Bool {preconditionFailure("This method must be overridden")}

    @discardableResult
    public func processStartTag(_ name: String)throws->Bool {
        if (currentToken === start) { // don't recycle an in-use token
            return try process(Token.StartTag().name(name))
        }
        return try process(start.reset().name(name))
    }

    @discardableResult
    public func processStartTag(_ name: String, _ attrs: Attributes)throws->Bool {
        if (currentToken === start) { // don't recycle an in-use token
            return try process(Token.StartTag().nameAttr(name, attrs))
        }
        start.reset()
        start.nameAttr(name, attrs)
        return try process(start)
    }

    @discardableResult
    public func processEndTag(_ name: String)throws->Bool {
    if (currentToken === end) { // don't recycle an in-use token
    return try process(Token.EndTag().name(name))
    }

    return try process(end.reset().name(name))
    }

    public func currentElement() -> Element? {
        let size: Int = stack.count
        return size > 0 ? stack[size-1] : nil
    }
}
