//
//  TreeBuilder.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 24/10/16.
//

import Foundation

public class TreeBuilder {
    public var reader: CharacterReader
    var tokeniser: Tokeniser
    public var doc: Document // current doc we are building into
    public var stack: Array<Element> // the stack of open elements
    public var baseUri: [UInt8] // current base uri, for creating new elements
    public var currentToken: Token? // currentToken is used only for error tracking.
    public var errors: ParseErrorList // null when not tracking errors
    public var settings: ParseSettings
    
    private let start: Token.StartTag = Token.StartTag() // start tag to process
    private let end: Token.EndTag  = Token.EndTag()
    
    /// Bulk-build suppression flag
    @usableFromInline
    var isBulkBuilding: Bool = false
    
    public func defaultSettings() -> ParseSettings {preconditionFailure("This method must be overridden")}
    
    public init() {
        doc =  Document([])
        reader = CharacterReader([])
        stack = Array<Element>()
        baseUri = []
        errors = ParseErrorList(0, 0)
        settings = ParseSettings(false, false)
        tokeniser = Tokeniser(reader, nil, settings)
    }
    
    @inline(__always)
    func beginBulkAppend() {
        isBulkBuilding = true
    }
    
    @inline(__always)
    func endBulkAppend() {
        isBulkBuilding = false
    }
    
    public func initialiseParse(_ input: [UInt8], _ baseUri: [UInt8], _ errors: ParseErrorList, _ settings: ParseSettings) {
        doc = Document(baseUri)
        doc.sourceInput = input
        self.settings = settings
        reader = CharacterReader(input)
        self.errors = errors
        tokeniser = Tokeniser(reader, errors, settings)
        stack = Array<Element>()
        self.baseUri = baseUri
    }
    
    func parse(_ input: [UInt8], _ baseUri: [UInt8],
               _ errors: ParseErrorList,
               _ settings: ParseSettings) throws -> Document {
        // Associate builder for node-level checks
        doc.treeBuilder = self
        
        // Suppress per-append index invalidation; rebuild once at end
        beginBulkAppend()
        defer { endBulkAppend() }
        
        initialiseParse(input, baseUri, errors, settings)
        try runParser()
        return doc
    }
    
    public func runParser() throws {
        #if PROFILE
        let _p = Profiler.start("TreeBuilder.runParser")
        defer { Profiler.end("TreeBuilder.runParser", _p) }
        #endif
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
    @inline(__always)
    public func process(_ token: Token)throws->Bool {preconditionFailure("This method must be overridden")}
    
    @discardableResult
    @inline(__always)
    public func processStartTag(_ name: [UInt8]) throws -> Bool {
        if (currentToken === start) { // don't recycle an in-use token
            return try process(Token.StartTag().name(name))
        }
        return try process(start.reset().name(name))
    }
    
    @discardableResult
    @inline(__always)
    public func processStartTag(_ name: String) throws -> Bool {
        return try processStartTag(name.utf8Array)
    }
    
    @discardableResult
    @inline(__always)
    public func processStartTag(_ name: [UInt8], _ attrs: Attributes) throws -> Bool {
        if (currentToken === start) { // don't recycle an in-use token
            return try process(Token.StartTag().nameAttr(name, attrs))
        }
        start.reset()
        start.nameAttr(name, attrs)
        return try process(start)
    }
    
    @discardableResult
    @inline(__always)
    public func processStartTag(_ name: String, _ attrs: Attributes) throws -> Bool {
        return try processStartTag(name.utf8Array, attrs)
    }
    
    @discardableResult
    @inline(__always)
    public func processEndTag(_ name: [UInt8]) throws -> Bool {
        if (currentToken === end) { // don't recycle an in-use token
            return try process(Token.EndTag().name(name))
        }
        
        return try process(end.reset().name(name))
    }
    
    @discardableResult
    @inline(__always)
    public func processEndTag(_ name: String) throws -> Bool {
        return try processEndTag(name.utf8Array)
    }
    
    @inline(__always)
    public func currentElement() -> Element? {
        return stack.last
    }
}
