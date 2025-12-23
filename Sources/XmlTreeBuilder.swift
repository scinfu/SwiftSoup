//
//  XmlTreeBuilder.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 14/10/16.
//

import Foundation

/**
 Use the `XmlTreeBuilder` when you want to parse XML without any of the HTML DOM rules being applied to the
 document.
 
 Usage example:
 ```swift
 let xmlDoc = SwiftSoup.parse(html, baseUrl, Parser.xmlParser())
 ```
 */
public class XmlTreeBuilder: TreeBuilder {
    
    public override init() {
        super.init()
    }
    
    public override func defaultSettings() -> ParseSettings {
        return ParseSettings.preserveCase
    }
    
    public func parse(_ input: [UInt8], _ baseUri: [UInt8]) throws -> Document {
        return try parse(input, baseUri, ParseErrorList.noTracking(), ParseSettings.preserveCase)
    }
    
    public func parse(_ input: String, _ baseUri: String) throws -> Document {
        return try parse(input.utf8Array, baseUri.utf8Array, ParseErrorList.noTracking(), ParseSettings.preserveCase)
    }
    
    override public func initialiseParse(_ input: [UInt8], _ baseUri: [UInt8], _ errors: ParseErrorList, _ settings: ParseSettings) {
        super.initialiseParse(input, baseUri, errors, settings)
        stack.append(doc) // place the document onto the stack. differs from HtmlTreeBuilder (not on stack)
        doc.outputSettings().syntax(syntax: OutputSettings.Syntax.xml)
        doc.parsedAsXml = true
    }
    
    override public func process(_ token: Token) throws -> Bool {
        // start tag, end tag, doctype, comment, character, eof
        switch (token.type) {
        case .StartTag:
            try insert(token.asStartTag())
            break
        case .EndTag:
            try popStackToClose(token.asEndTag())
            break
        case .Comment:
            try insert(token.asComment())
            break
        case .Char:
            try insert(token.asCharacter())
            break
        case .Doctype:
            try insert(token.asDoctype())
            break
        case .EOF: // could put some normalisation here if desired
            break
            //        default:
            //            try Validate.fail(msg: "Unexpected token type: " + token.tokenType())
        }
        return true
    }
    
    @inline(__always)
    private func insertNode(_ node: Node)throws {
        if stack.isEmpty {
            try doc.appendChild(node)
        } else {
            try currentElement()?.appendChild(node)
        }
        node.treeBuilder = self
        if node.sourceBuffer == nil {
            node.sourceBuffer = doc.sourceBuffer
        }
    }
    
    @discardableResult
    func insert(_ startTag: Token.StartTag) throws -> Element {
        startTag.ensureAttributes()
        // For unknown tags, remember this is self closing for output
        let tag: Tag = try Tag.valueOf(startTag.name(), settings, isSelfClosing: startTag.isSelfClosing())
        // todo: wonder if for xml parsing, should treat all tags as unknown? because it's not html.
        let skipChildReserve = startTag.isSelfClosing()
        let el: Element
        if let attributes = startTag._attributes {
            el = try Element(tag, baseUri, settings.normalizeAttributes(attributes), skipChildReserve: skipChildReserve)
        } else {
            el = Element(tag, baseUri, skipChildReserve: skipChildReserve)
        }
        el.treeBuilder = self
        if let range = startTag.sourceRange {
            if startTag.isSelfClosing() {
                el.setSourceRange(range, complete: true)
            } else {
                el.setSourceRange(range, complete: false)
            }
        }
        try insertNode(el)
        if (startTag.isSelfClosing()) {
            tokeniser.acknowledgeSelfClosingFlag()
        } else {
            stack.append(el)
        }
        return el
    }
    
    func insert(_ commentToken: Token.Comment)throws {
        let comment: Comment = Comment(commentToken.getData(), baseUri)
        var insert: Node = comment
        if (commentToken.bogus) { // xml declarations are emitted as bogus comments (which is right for html, but not xml)
                                  // so we do a bit of a hack and parse the data as an element to pull the attributes out
            let data: String = comment.getData()
            if (data.count > 1 && (data.startsWith("!") || data.startsWith("?"))) {
                let doc: Document = try SwiftSoup.parse("<" + data.substring(1, data.count - 2) + ">", String(decoding: baseUri, as: UTF8.self), Parser.xmlParser())
                let el: Element = doc.child(0)
                insert = XmlDeclaration(settings.normalizeTag(el.tagNameUTF8()), comment.getBaseUriUTF8(), data.startsWith("!"))
                insert.getAttributes()?.addAll(incoming: el.getAttributes())
            }
        }
        if let range = commentToken.sourceRange {
            insert.setSourceRange(range, complete: true)
        }
        try insertNode(insert)
    }
    
    @inline(__always)
    func insert(_ characterToken: Token.Char)throws {
        let node: Node = {
            if let range = characterToken.sourceRange,
               let source = doc.sourceBuffer?.bytes,
               range.isValid,
               range.end <= source.count {
                return TextNode(slice: source[range.start..<range.end], baseUri: baseUri)
            }
            return TextNode(characterToken.getData()!, baseUri)
        }()
        if let range = characterToken.sourceRange {
            node.setSourceRange(range, complete: true)
        }
        try insertNode(node)
    }
    
    @inline(__always)
    func insert(_ d: Token.Doctype)throws {
        let doctypeNode = DocumentType(
            settings.normalizeTag(d.getName()),
            d.getPubSysKey(),
            d.getPublicIdentifier(),
            d.getSystemIdentifier(),
            baseUri
        )
        if let range = d.sourceRange {
            doctypeNode.setSourceRange(range, complete: true)
        }
        try insertNode(doctypeNode)
    }
    
    /**
     If the stack contains an element with this tag's name, pop up the stack to remove the first occurrence. If not
     found, skips.
     
     - parameter endTag:
     */
    @inline(__always)
    private func popStackToClose(_ endTag: Token.EndTag) throws {
        let elName = try endTag.name()
        
        // Find the index of the first matching tag from the top
        let targetIndex = stack.lastIndex {
            $0.nodeNameUTF8() == elName
        }
        
        // If found, remove everything from that element upward
        if let index = targetIndex {
            if let endRange = endTag.sourceRange {
                stack[index].setSourceRangeEnd(endRange.end)
            }
            stack.removeSubrange(index..<stack.count)
        }
    }
    
    func parseFragment(_ inputFragment: [UInt8], _ baseUri: [UInt8], _ errors: ParseErrorList, _ settings: ParseSettings) throws -> Array<Node> {
        initialiseParse(inputFragment, baseUri, errors, settings)
        try runParser()
        return doc.getChildNodes()
    }
}
