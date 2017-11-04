//
//  XmlTreeBuilder.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 14/10/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import Foundation

/**
 * Use the {@code XmlTreeBuilder} when you want to parse XML without any of the HTML DOM rules being applied to the
 * document.
 * <p>Usage example: {@code Document xmlDoc = Jsoup.parse(html, baseUrl, Parser.xmlParser())}</p>
 *
 */
public class XmlTreeBuilder: TreeBuilder {

    public override init() {
		super.init()
	}

    public override func defaultSettings() -> ParseSettings {
        return ParseSettings.preserveCase
    }

    public func parse(_ input: String, _ baseUri: String)throws->Document {
        return try parse(input, baseUri, ParseErrorList.noTracking(), ParseSettings.preserveCase)
    }

    override public func initialiseParse(_ input: String, _ baseUri: String, _ errors: ParseErrorList, _ settings: ParseSettings) {
		super.initialiseParse(input, baseUri, errors, settings)
        stack.append(doc) // place the document onto the stack. differs from HtmlTreeBuilder (not on stack)
        doc.outputSettings().syntax(syntax: OutputSettings.Syntax.xml)
    }

    override public func process(_ token: Token)throws->Bool {
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

    private func insertNode(_ node: Node)throws {
        try currentElement()?.appendChild(node)
    }

    @discardableResult
    func insert(_ startTag: Token.StartTag)throws->Element {
        let tag: Tag = try Tag.valueOf(startTag.name(), settings)
        // todo: wonder if for xml parsing, should treat all tags as unknown? because it's not html.
        let el: Element = try Element(tag, baseUri, settings.normalizeAttributes(startTag._attributes))
        try insertNode(el)
        if (startTag.isSelfClosing()) {
            tokeniser.acknowledgeSelfClosingFlag()
            if (!tag.isKnownTag()) // unknown tag, remember this is self closing for output. see above.
            {
                tag.setSelfClosing()
            }
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
                let doc: Document = try SwiftSoup.parse("<" + data.substring(1, data.count - 2) + ">", baseUri, Parser.xmlParser())
                let el: Element = doc.child(0)
                insert = XmlDeclaration(settings.normalizeTag(el.tagName()), comment.getBaseUri(), data.startsWith("!"))
                insert.getAttributes()?.addAll(incoming: el.getAttributes())
            }
        }
        try insertNode(insert)
    }

    func insert(_ characterToken: Token.Char)throws {
        let node: Node = TextNode(characterToken.getData()!, baseUri)
        try insertNode(node)
    }

    func insert(_ d: Token.Doctype)throws {
        let doctypeNode = DocumentType(settings.normalizeTag(d.getName()), d.getPubSysKey(), d.getPublicIdentifier(), d.getSystemIdentifier(), baseUri)
        try insertNode(doctypeNode)
    }

    /**
     * If the stack contains an element with this tag's name, pop up the stack to remove the first occurrence. If not
     * found, skips.
     *
     * @param endTag
     */
    private func popStackToClose(_ endTag: Token.EndTag)throws {
        let elName: String = try endTag.name()
        var firstFound: Element? = nil

        for pos in (0..<stack.count).reversed() {
            let next: Element = stack[pos]
            if (next.nodeName().equals(elName)) {
                firstFound = next
                break
            }
        }
        if (firstFound == nil) {
        return // not found, skip
        }

        for pos in (0..<stack.count).reversed() {
            let next: Element = stack[pos]
            stack.remove(at: pos)
            if (next == firstFound!) {
            break
            }
        }
    }

    func parseFragment(_ inputFragment: String, _ baseUri: String, _ errors: ParseErrorList, _ settings: ParseSettings)throws->Array<Node> {
		initialiseParse(inputFragment, baseUri, errors, settings)
        try runParser()
        return doc.getChildNodes()
    }
}
