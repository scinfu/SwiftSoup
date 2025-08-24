//
//  Parser.swift
//  SwifSoup
//
//  Created by Nabil Chatbi on 29/09/16.
//

import Foundation

/**
 Parses HTML into a ``Document``. Generally best to use one of the more convenient parse methods
 in ``SwiftSoup``.
*/
public class Parser {
	private static let DEFAULT_MAX_ERRORS: Int = 0 // by default, error tracking is disabled.

	private var _treeBuilder: TreeBuilder
	private var _maxErrors: Int = DEFAULT_MAX_ERRORS
	private var _errors: ParseErrorList = ParseErrorList(16, 16)
	private var _settings: ParseSettings

	/**
	 Create a new Parser, using the specified TreeBuilder
	 - parameter treeBuilder: TreeBuilder to use to parse input into Documents.
	*/
	init(_ treeBuilder: TreeBuilder) {
		self._treeBuilder = treeBuilder
		_settings = treeBuilder.defaultSettings()
	}

	public func parseInput(_ html: [UInt8], _ baseUri: [UInt8]) throws -> Document {
		_errors = isTrackErrors() ? ParseErrorList.tracking(_maxErrors) : ParseErrorList.noTracking()
		return try _treeBuilder.parse(html, baseUri, _errors, _settings)
	}
    
    public func parseInput(_ html: String, _ baseUri: String) throws -> Document {
        return try parseInput(html.utf8Array, baseUri.utf8Array)
    }
    
    public func parseInput(_ html: [UInt8], _ baseUri: String) throws -> Document {
        return try parseInput(html, baseUri.utf8Array)
    }

	// MARK: Getters & setters
	
	/**
	 Get the TreeBuilder currently in use.
	 - returns: current TreeBuilder.
	*/
	public func getTreeBuilder() -> TreeBuilder {
		return _treeBuilder
	}

	/**
	 Update the TreeBuilder used when parsing content.
	 - parameter treeBuilder: current TreeBuilder
	 - returns: this, for chaining
	*/
	@discardableResult
	public func setTreeBuilder(_ treeBuilder: TreeBuilder) -> Parser {
		self._treeBuilder = treeBuilder
		return self
	}

	/**
	 Check if parse error tracking is enabled.
	 - returns: current track error state.
	*/
	public func isTrackErrors() -> Bool {
		return _maxErrors > 0
	}

	/**
	 Enable or disable parse error tracking for the next parse.
	 - parameter maxErrors: the maximum number of errors to track. Set to 0 to disable.
	 - returns: this, for chaining
	*/
    @discardableResult
	public func setTrackErrors(_ maxErrors: Int) -> Parser {
		self._maxErrors = maxErrors
		return self
	}

	/**
	 Retrieve the parse errors, if any, from the last parse.
	 - returns: list of parse errors, up to the size of the maximum errors tracked.
	*/
	public func getErrors() -> ParseErrorList {
		return _errors
	}

	@discardableResult
	public func settings(_ settings: ParseSettings) -> Parser {
		self._settings = settings
		return self
	}

	public func settings() -> ParseSettings {
		return _settings
	}

	// MARK: Static parse functions
	
	/**
	 Parse HTML into a Document.
	 
	 - parameter html: HTML to parse
	 - parameter baseUri: base URI of document (i.e. original fetch location), for resolving relative URLs.
	 
	 - returns: parsed Document
	*/
	public static func parse(_ html: [UInt8], _ baseUri: [UInt8]) throws -> Document {
		let treeBuilder: TreeBuilder = HtmlTreeBuilder()
		return try treeBuilder.parse(html, baseUri, ParseErrorList.noTracking(), treeBuilder.defaultSettings())
	}
    
    public static func parse(_ html: String, _ baseUri: String) throws -> Document {
        return try parse(html.utf8Array, baseUri.utf8Array)
    }

    public static func parse(_ data: Data, _ baseUri: [UInt8]) throws -> Document {
        let treeBuilder: TreeBuilder = HtmlTreeBuilder()
        return try treeBuilder.parse([UInt8](data), baseUri, ParseErrorList.noTracking(), treeBuilder.defaultSettings())
    }

    public static func parse(_ data: Data, _ baseUri: String) throws -> Document {
        return try parse([UInt8](data), baseUri.utf8Array)
    }

	/**
	 Parse a fragment of HTML into a list of nodes. The context element, if supplied, supplies parsing context.
	 
	 - parameter fragmentHtml: the fragment of HTML to parse
	 - parameter context: (optional) the element that this HTML fragment is being parsed for (i.e. for inner HTML). This
	 provides stack context (for implicit element creation).
	 - parameter baseUri: base URI of document (i.e. original fetch location), for resolving relative URLs.
	 
	 - returns: list of nodes parsed from the input HTML. Note that the context element, if supplied, is not modified.
	*/
	public static func parseFragment(_ fragmentHtml: [UInt8], _ context: Element?, _ baseUri: [UInt8]) throws -> Array<Node> {
		let treeBuilder = HtmlTreeBuilder()
		return try treeBuilder.parseFragment(fragmentHtml, context, baseUri, ParseErrorList.noTracking(), treeBuilder.defaultSettings())
	}
    
    public static func parseFragment(_ fragmentHtml: String, _ context: Element?, _ baseUri: [UInt8]) throws -> Array<Node> {
        return try parseFragment(fragmentHtml.utf8Array, context, baseUri)
    }

	/**
	 Parse a fragment of XML into a list of nodes.
	 
	 - parameter fragmentXml: the fragment of XML to parse
	 - parameter baseUri: base URI of document (i.e. original fetch location), for resolving relative URLs.
	 - returns: list of nodes parsed from the input XML.
	*/
	public static func parseXmlFragment(_ fragmentXml: [UInt8], _ baseUri: [UInt8]) throws -> Array<Node> {
		let treeBuilder: XmlTreeBuilder = XmlTreeBuilder()
		return try treeBuilder.parseFragment(fragmentXml, baseUri, ParseErrorList.noTracking(), treeBuilder.defaultSettings())
	}
    
    public static func parseXmlFragment(_ fragmentXml: String, _ baseUri: String) throws -> Array<Node> {
        return try parseXmlFragment(fragmentXml.utf8Array, baseUri.utf8Array)
    }

	/**
	 Parse a fragment of HTML into the `body` of a Document.
	 
	 - parameter bodyHtml: fragment of HTML
	 - parameter baseUri: base URI of document (i.e. original fetch location), for resolving relative URLs.
	 
	 - returns: Document, with empty head, and HTML parsed into body
	*/
	public static func parseBodyFragment(_ bodyHtml: String, _ baseUri: String) throws -> Document {
		let doc: Document = Document.createShell(baseUri)
		if let body: Element = doc.body() {
            let nodeList: Array<Node> = try parseFragment(bodyHtml, body, baseUri.utf8Array)
			//var nodes: [Node] = nodeList.toArray(Node[nodeList.size()]) // the node list gets modified when re-parented
            if nodeList.count > 0 {
                for i in 1..<nodeList.count {
                    try nodeList[i].remove()
                }
            }
			for node: Node in nodeList {
				try body.appendChild(node)
			}
		}
		return doc
	}

	/**
	 Utility method to unescape HTML entities from a string
	 - parameter string: HTML escaped string
	 - parameter inAttribute: if the string is to be escaped in strict mode (as attributes are)
	 - returns: an unescaped string
	*/
	public static func unescapeEntities(_ string: [UInt8], _ inAttribute: Bool) throws -> [UInt8] {
		let tokeniser: Tokeniser = Tokeniser(CharacterReader(string), ParseErrorList.noTracking())
		return try tokeniser.unescapeEntities(inAttribute)
	}
    
    public static func unescapeEntities(_ string: String, _ inAttribute: Bool) throws -> String {
        return try String(decoding: unescapeEntities(string.utf8Array, inAttribute), as: UTF8.self)
    }

	/**
	 - parameter bodyHtml: HTML to parse
	 - parameter baseUri: baseUri base URI of document (i.e. original fetch location), for resolving relative URLs.
	 
	 - returns: parsed Document
	*/
	@available(*, deprecated, message: "Use `parseBodyFragment` or `parseFragment` instead.")
	public static func parseBodyFragmentRelaxed(_ bodyHtml: String, _ baseUri: String) throws -> Document {
        return try parse(bodyHtml.utf8Array, baseUri.utf8Array)
	}

	// builders

	/**
	 Create a new HTML parser. This parser treats input as HTML5, and enforces the creation of a normalised document,
	 based on a knowledge of the semantics of the incoming tags.
	 - returns: a new HTML parser.
	*/
	public static func htmlParser() -> Parser {
		return Parser(HtmlTreeBuilder())
	}

	/**
	 Create a new XML parser. This parser assumes no knowledge of the incoming tags and does not treat it as HTML,
	 rather creates a simple tree directly from the input.
	 - returns: a new simple XML parser.
	*/
	public static func xmlParser() -> Parser {
		return Parser(XmlTreeBuilder())
	}
}
