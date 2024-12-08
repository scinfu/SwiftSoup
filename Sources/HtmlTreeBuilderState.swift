//
//  HtmlTreeBuilderState.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 24/10/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import Foundation

protocol HtmlTreeBuilderStateProtocol {
    func process(_ t: Token, _ tb: HtmlTreeBuilder)throws->Bool
}

enum HtmlTreeBuilderState: String, HtmlTreeBuilderStateProtocol {
    case Initial
    case BeforeHtml
    case BeforeHead
    case InHead
    case InHeadNoscript
    case AfterHead
    case InBody
    case Text
    case InTable
    case InTableText
    case InCaption
    case InColumnGroup
    case InTableBody
    case InRow
    case InCell
    case InSelect
    case InSelectInTable
    case AfterBody
    case InFrameset
    case AfterFrameset
    case AfterAfterBody
    case AfterAfterFrameset
    case ForeignContent
    
    private enum TagSets {
        static let outer = Set(["head", "body", "html", "br"].map { $0.utf8Array })
        static let outer2 = Set(["body", "html", "br"].map { $0.utf8Array })
        static let outer3 = Set(["body", "html"].map { $0.utf8Array })
        static let baseEtc = Set(["base", "basefont", "bgsound", "command", "link"].map { $0.utf8Array })
        static let baseEtc2 = Set(["basefont", "bgsound", "link", "meta", "noframes", "style"].map { $0.utf8Array })
        static let baseEtc3 = Set(["base", "basefont", "bgsound", "link", "meta", "noframes", "script", "style", "title"].map { $0.utf8Array })
        static let headNoscript = Set(["head", "noscript"].map { $0.utf8Array })
        static let table = Set(["table", "tbody", "tfoot", "thead", "tr"].map { $0.utf8Array })
        static let tableSections = Set(["tbody", "tfoot", "thead"].map { $0.utf8Array })
        static let tableMix = Set(["body", "caption", "col", "colgroup", "html", "tbody", "td", "tfoot", "th", "thead", "tr"].map { $0.utf8Array })
        static let tableMix2 = Set(["body", "col", "colgroup", "html", "tbody", "td", "tfoot", "th", "thead", "tr"].map { $0.utf8Array })
        static let tableMix3 = Set(["caption", "col", "colgroup", "tbody", "tfoot", "thead"].map { $0.utf8Array })
        static let tableMix4 = Set(["body", "caption", "col", "colgroup", "html", "td", "th", "tr"].map { $0.utf8Array })
        static let tableMix5 = Set(["caption", "col", "colgroup", "tbody", "tfoot", "thead", "tr"].map { $0.utf8Array })
        static let tableMix6 = Set(["body", "caption", "col", "colgroup", "html", "td", "th"].map { $0.utf8Array })
        static let tableMix7 = Set(["body", "caption", "col", "colgroup", "html"].map { $0.utf8Array })
        static let tableMix8 = Set(["caption", "table", "tbody", "tfoot", "thead", "tr", "td", "th"].map { $0.utf8Array })
        static let tableRowsAndCols = Set(["caption", "col", "colgroup", "tbody", "td", "tfoot", "th", "thead", "tr"].map { $0.utf8Array })
        static let thTd = Set(["th", "td"].map { $0.utf8Array })
        static let inputKeygenTextarea = Set(["input", "keygen", "textarea"].map { $0.utf8Array })
    }

    private static let nullString: [UInt8] = "\u{0000}".utf8Array

    public func equals(_ s: HtmlTreeBuilderState) -> Bool {
        return self.hashValue == s.hashValue
    }

    func process(_ t: Token, _ tb: HtmlTreeBuilder)throws->Bool {
        switch self {
        case .Initial:
            if (HtmlTreeBuilderState.isWhitespace(t)) {
                return true // ignore whitespace
            } else if (t.isComment()) {
                try tb.insert(t.asComment())
            } else if (t.isDoctype()) {
                // todo: parse error check on expected doctypes
                // todo: quirk state check on doctype ids
                let d: Token.Doctype = t.asDoctype()
                let doctype: DocumentType = DocumentType(
                tb.settings.normalizeTag(d.getName()), d.getPubSysKey(), d.getPublicIdentifier(), d.getSystemIdentifier(), tb.getBaseUri())
                    //tb.settings.normalizeTag(d.getName()), d.getPublicIdentifier(), d.getSystemIdentifier(), tb.getBaseUri())
                try tb.getDocument().appendChild(doctype)
                if (d.isForceQuirks()) {
                    tb.getDocument().quirksMode(Document.QuirksMode.quirks)
                }
                tb.transition(.BeforeHtml)
            } else {
                // todo: check not iframe srcdoc
                tb.transition(.BeforeHtml)
                return try tb.process(t) // re-process token
            }
            return true
        case .BeforeHtml:

            func anythingElse(_ t: Token, _ tb: HtmlTreeBuilder)throws->Bool {
                try tb.insertStartTag("html".utf8Array)
                tb.transition(.BeforeHead)
                return try tb.process(t)
            }

            if (t.isDoctype()) {
                tb.error(self)
                return false
            } else if (t.isComment()) {
                try tb.insert(t.asComment())
            } else if (HtmlTreeBuilderState.isWhitespace(t)) {
                return true // ignore whitespace
            } else if t.startTagNormalName() == "html".utf8Array {
                try tb.insert(t.asStartTag())
                tb.transition(.BeforeHead)
            } else if let nName = t.endTagNormalName(), TagSets.outer.contains(nName) {
                return try anythingElse(t, tb)
            } else if (t.isEndTag()) {
                tb.error(self)
                return false
            } else {
                return try anythingElse(t, tb)
            }
            return true
        case .BeforeHead:
            if (HtmlTreeBuilderState.isWhitespace(t)) {
                return true
            } else if (t.isComment()) {
                try tb.insert(t.asComment())
            } else if (t.isDoctype()) {
                tb.error(self)
                return false
            } else if t.startTagNormalName() == "html".utf8Array {
                return try HtmlTreeBuilderState.InBody.process(t, tb) // does not transition
            } else if t.startTagNormalName() == "head".utf8Array {
                let head: Element = try tb.insert(t.asStartTag())
                tb.setHeadElement(head)
                tb.transition(.InHead)
            } else if let nName = t.endTagNormalName(), TagSets.outer.contains(nName) {
                try tb.processStartTag("head".utf8Array)
                return try tb.process(t)
            } else if (t.isEndTag()) {
                tb.error(self)
                return false
            } else {
                try tb.processStartTag("head".utf8Array)
                return try tb.process(t)
            }
            return true
        case .InHead:
            func anythingElse(_ t: Token, _ tb: TreeBuilder)throws->Bool {
                try tb.processEndTag("head".utf8Array)
                return try tb.process(t)
            }

            if (HtmlTreeBuilderState.isWhitespace(t)) {
                try tb.insert(t.asCharacter())
                return true
            }
            switch (t.type) {
            case .Comment:
                try tb.insert(t.asComment())
                break
            case .Doctype:
                tb.error(self)
                return false
            case .StartTag:
                let start: Token.StartTag = t.asStartTag()
                let name = start.normalName()!
                if (name == "html".utf8Array) {
                    return try HtmlTreeBuilderState.InBody.process(t, tb)
                } else if TagSets.baseEtc.contains(name) {
                    let el: Element = try tb.insertEmpty(start)
                    // SwiftSoup special: update base the frist time it is seen
                    if (name == "base".utf8Array && el.hasAttr("href")) {
                        try tb.maybeSetBaseUri(el)
                    }
                } else if name == "meta".utf8Array {
                    let _: Element = try tb.insertEmpty(start)
                    // todo: charset switches
                } else if name == "title".utf8Array {
                    try HtmlTreeBuilderState.handleRcData(start, tb)
                } else if name == "noframes".utf8Array || name == "style".utf8Array {
                    try HtmlTreeBuilderState.handleRawtext(start, tb)
                } else if name == "noscript".utf8Array {
                    // else if noscript && scripting flag = true: rawtext (SwiftSoup doesn't run script, to handle as noscript)
                    try tb.insert(start)
                    tb.transition(.InHeadNoscript)
                } else if name == "script".utf8Array {
                    // skips some script rules as won't execute them

                    tb.tokeniser.transition(TokeniserState.ScriptData)
                    tb.markInsertionMode()
                    tb.transition(.Text)
                    try tb.insert(start)
                } else if name == "head".utf8Array {
                    tb.error(self)
                    return false
                } else {
                    return try anythingElse(t, tb)
                }
                break
            case .EndTag:
                let end: Token.EndTag = t.asEndTag()
                let name = end.normalName()
                if name! == "head".utf8Array {
                    tb.pop()
                    tb.transition(.AfterHead)
                } else if let name = name, TagSets.outer2.contains(name) {
                    return try anythingElse(t, tb)
                } else {
                    tb.error(self)
                    return false
                }
                break
            default:
                return try anythingElse(t, tb)
            }
            return true
        case .InHeadNoscript:
            func anythingElse(_ t: Token, _ tb: HtmlTreeBuilder)throws->Bool {
                tb.error(self)
                try tb.insert(Token.Char().data(t.toString().utf8Array))
                return true
            }
            if (t.isDoctype()) {
                tb.error(self)
            } else if t.startTagNormalName() == "html".utf8Array {
                return try tb.process(t, .InBody)
            } else if t.endTagNormalName() == "noscript".utf8Array {
                tb.pop()
                tb.transition(.InHead)
            } else if HtmlTreeBuilderState.isWhitespace(t) || t.isComment() || (t.isStartTag() && TagSets.baseEtc2.contains(t.asStartTag().normalName()!)) {
                return try tb.process(t, .InHead)
            } else if t.endTagNormalName() == "br".utf8Array {
                return try anythingElse(t, tb)
            } else if (t.isStartTag() && TagSets.headNoscript.contains(t.asStartTag().normalName()!)) || t.isEndTag() {
                tb.error(self)
                return false
            } else {
                return try anythingElse(t, tb)
            }
            return true
        case .AfterHead:
            @discardableResult
            func anythingElse(_ t: Token, _ tb: HtmlTreeBuilder)throws->Bool {
                try tb.processStartTag("body".utf8Array)
                tb.framesetOk(true)
                return try tb.process(t)
            }

            if (HtmlTreeBuilderState.isWhitespace(t)) {
                try tb.insert(t.asCharacter())
            } else if (t.isComment()) {
                try tb.insert(t.asComment())
            } else if (t.isDoctype()) {
                tb.error(self)
            } else if (t.isStartTag()) {
                let startTag: Token.StartTag = t.asStartTag()
                let name = startTag.normalName()!
                if name == "html".utf8Array {
                    return try tb.process(t, .InBody)
                } else if name == "body".utf8Array {
                    try tb.insert(startTag)
                    tb.framesetOk(false)
                    tb.transition(.InBody)
                } else if name == "frameset".utf8Array {
                    try tb.insert(startTag)
                    tb.transition(.InFrameset)
                } else if TagSets.baseEtc3.contains(name) {
                    tb.error(self)
                    let head: Element = tb.getHeadElement()!
                    tb.push(head)
                    try tb.process(t, .InHead)
                    tb.removeFromStack(head)
                } else if name == "head".utf8Array {
                    tb.error(self)
                    return false
                } else {
                    try anythingElse(t, tb)
                }
            } else if (t.isEndTag()) {
                if TagSets.outer3.contains(t.asEndTag().normalName()!) {
                    try anythingElse(t, tb)
                } else {
                    tb.error(self)
                    return false
                }
            } else {
                try anythingElse(t, tb)
            }
            return true
        case .InBody:
            func anyOtherEndTag(_ t: Token, _ tb: HtmlTreeBuilder) -> Bool {
                let name = t.asEndTag().normalName()
                let stack: Array<Element> = tb.getStack()
                for pos in (0..<stack.count).reversed() {
                    let node: Element = stack[pos]
                    if (name != nil && node.nodeNameUTF8() == name!) {
                        tb.generateImpliedEndTags(name)
                        if (name! != (tb.currentElement()?.nodeNameUTF8())!) {
                            tb.error(self)
                        }
                        tb.popStackToClose(name!)
                        break
                    } else {
                        if (tb.isSpecial(node)) {
                            tb.error(self)
                            return false
                        }
                    }
                }
                return true
            }

            switch (t.type) {
            case Token.TokenType.Char:
                let c: Token.Char = t.asCharacter()
                if (c.getData() != nil && c.getData()! == HtmlTreeBuilderState.nullString) {
                    // todo confirm that check
                    tb.error(self)
                    return false
                } else if (tb.framesetOk() && HtmlTreeBuilderState.isWhitespace(c)) { // don't check if whitespace if frames already closed
                    try tb.reconstructFormattingElements()
                    try tb.insert(c)
                } else {
                    try tb.reconstructFormattingElements()
                    try tb.insert(c)
                    tb.framesetOk(false)
                }
                break
            case Token.TokenType.Comment:
                try tb.insert(t.asComment())
                break
            case Token.TokenType.Doctype:
                tb.error(self)
                return false
            case Token.TokenType.StartTag:
                let startTag: Token.StartTag = t.asStartTag()
                if let name = startTag.normalName() {
                    if name == "a".utf8Array {
                        if (tb.getActiveFormattingElement("a".utf8Array) != nil) {
                            tb.error(self)
                            try tb.processEndTag("a".utf8Array)

                            // still on stack?
                            let remainingA: Element? = tb.getFromStack("a".utf8Array)
                            if (remainingA != nil) {
                                tb.removeFromActiveFormattingElements(remainingA)
                                tb.removeFromStack(remainingA!)
                            }
                        }
                        try tb.reconstructFormattingElements()
                        let a = try tb.insert(startTag)
                        tb.pushActiveFormattingElements(a)
                    } else if (Constants.InBodyStartEmptyFormatters.contains(name)) {
                        try tb.reconstructFormattingElements()
                        try tb.insertEmpty(startTag)
                        tb.framesetOk(false)
                    } else if Constants.InBodyStartPClosers.contains(name) {
                        if (try tb.inButtonScope("p".utf8Array)) {
                            try tb.processEndTag("p".utf8Array)
                        }
                        try tb.insert(startTag)
                    } else if name == "span".utf8Array {
                        // same as final else, but short circuits lots of checks
                        try tb.reconstructFormattingElements()
                        try tb.insert(startTag)
                    } else if name == "li".utf8Array {
                        tb.framesetOk(false)
                        let stack: Array<Element> = tb.getStack()
                        for i in (0..<stack.count).reversed() {
                            let el: Element = stack[i]
                            if el.nodeNameUTF8() == "li".utf8Array {
                                try tb.processEndTag("li".utf8Array)
                                break
                            }
                            if (tb.isSpecial(el) && !Constants.InBodyStartLiBreakers.contains(el.nodeNameUTF8())) {
                                break
                            }
                        }
                        if (try tb.inButtonScope("p".utf8Array)) {
                            try tb.processEndTag("p".utf8Array)
                        }
                        try tb.insert(startTag)
                    } else if name == "html".utf8Array {
                        tb.error(self)
                        // merge attributes onto real html
                        let html: Element = tb.getStack()[0]
                        for attribute in startTag.getAttributes() {
                            if (!html.hasAttr(attribute.getKey())) {
                                html.getAttributes()?.put(attribute: attribute)
                            }
                        }
                    } else if Constants.InBodyStartToHead.contains(name) {
                        return try tb.process(t, .InHead)
                    } else if name == "body".utf8Array {
                        tb.error(self)
                        let stack: Array<Element> = tb.getStack()
                        if stack.count == 1 || (stack.count > 2 && stack[1].nodeName() != "body") {
                            // only in fragment case
                            return false // ignore
                        } else {
                            tb.framesetOk(false)
                            let body: Element = stack[1]
                            for attribute: Attribute in startTag.getAttributes() {
                                if (!body.hasAttr(attribute.getKey())) {
                                    body.getAttributes()?.put(attribute: attribute)
                                }
                            }
                        }
                    } else if name == "frameset".utf8Array {
                        tb.error(self)
                        var stack: Array<Element> = tb.getStack()
                        if (stack.count == 1 || (stack.count > 2 && stack[1].nodeName() != "body")) {
                            // only in fragment case
                            return false // ignore
                        } else if (!tb.framesetOk()) {
                            return false // ignore frameset
                        } else {
                            let second: Element = stack[1]
                            if (second.parent() != nil) {
                                try second.remove()
                            }
                            // pop up to html element
                            while (stack.count > 1) {
                                stack.remove(at: stack.count-1)
                            }
                            try tb.insert(startTag)
                            tb.transition(.InFrameset)
                        }
                    } else if Constants.Headings.contains(name) {
                        if (try tb.inButtonScope("p".utf8Array)) {
                            try tb.processEndTag("p".utf8Array)
                        }
                        if (tb.currentElement() != nil && Constants.Headings.contains(tb.currentElement()!.nodeNameUTF8())) {
                            tb.error(self)
                            tb.pop()
                        }
                        try tb.insert(startTag)
                    } else if Constants.InBodyStartPreListing.contains(name) {
                        if (try tb.inButtonScope("p".utf8Array)) {
                            try tb.processEndTag("p".utf8Array)
                        }
                        try tb.insert(startTag)
                        // todo: ignore LF if next token
                        tb.framesetOk(false)
                    } else if name == "form".utf8Array {
                        if (tb.getFormElement() != nil) {
                            tb.error(self)
                            return false
                        }
                        if (try tb.inButtonScope("p")) {
                            try tb.processEndTag("p")
                        }
                        try tb.insertForm(startTag, true)
                    } else if Constants.DdDt.contains(name) {
                        tb.framesetOk(false)
                        let stack: Array<Element> = tb.getStack()
                        for i in (1..<stack.count).reversed() {
                            let el: Element = stack[i]
                            if Constants.DdDt.contains(el.nodeNameUTF8()) {
                                try tb.processEndTag(el.nodeNameUTF8())
                                break
                            }
                            if (tb.isSpecial(el) && !Constants.InBodyStartLiBreakers.contains(el.nodeNameUTF8())) {
                                break
                            }
                        }
                        if (try tb.inButtonScope("p")) {
                            try tb.processEndTag("p")
                        }
                        try tb.insert(startTag)
                    } else if (name.equals("plaintext")) {
                        if (try tb.inButtonScope("p")) {
                            try tb.processEndTag("p")
                        }
                        try tb.insert(startTag)
                        tb.tokeniser.transition(TokeniserState.PLAINTEXT) // once in, never gets out
                    } else if (name.equals("button")) {
                        if (try tb.inButtonScope("button")) {
                            // close and reprocess
                            tb.error(self)
                            try tb.processEndTag("button")
                            try tb.process(startTag)
                        } else {
                            try tb.reconstructFormattingElements()
                            try tb.insert(startTag)
                            tb.framesetOk(false)
                        }
                    } else if Constants.Formatters.contains(name) {
                        try tb.reconstructFormattingElements()
                        let el: Element = try tb.insert(startTag)
                        tb.pushActiveFormattingElements(el)
                    } else if (name.equals("nobr")) {
                        try tb.reconstructFormattingElements()
                        if (try tb.inScope("nobr")) {
                            tb.error(self)
                            try tb.processEndTag("nobr")
                            try tb.reconstructFormattingElements()
                        }
                        let el: Element = try tb.insert(startTag)
                        tb.pushActiveFormattingElements(el)
                    } else if Constants.InBodyStartApplets.contains(name) {
                        try tb.reconstructFormattingElements()
                        try tb.insert(startTag)
                        tb.insertMarkerToFormattingElements()
                        tb.framesetOk(false)
                    } else if (name.equals("table")) {
                        if (try tb.getDocument().quirksMode() != Document.QuirksMode.quirks && tb.inButtonScope("p")) {
                            try tb.processEndTag("p")
                        }
                        try tb.insert(startTag)
                        tb.framesetOk(false)
                        tb.transition(.InTable)
                    } else if (name.equals("input")) {
                        try tb.reconstructFormattingElements()
                        let el: Element = try tb.insertEmpty(startTag)
                        if (try !el.attr("type").equalsIgnoreCase(string: "hidden")) {
                            tb.framesetOk(false)
                        }
                    } else if Constants.InBodyStartMedia.contains(name) {
                        try tb.insertEmpty(startTag)
                    } else if (name.equals("hr")) {
                        if (try tb.inButtonScope("p")) {
                            try tb.processEndTag("p")
                        }
                        try tb.insertEmpty(startTag)
                        tb.framesetOk(false)
                    } else if (name.equals("image")) {
                        if (tb.getFromStack("svg") == nil) {
                            return try tb.process(startTag.name("img".utf8Array)) // change <image> to <img>, unless in svg
                        } else {
                            try tb.insert(startTag)
                        }
                    } else if (name.equals("isindex")) {
                        // how much do we care about the early 90s?
                        tb.error(self)
                        if (tb.getFormElement() != nil) {
                            return false
                        }

                        tb.tokeniser.acknowledgeSelfClosingFlag()
                        try tb.processStartTag("form")
                        if (startTag._attributes.hasKey(key: "action".utf8Array)) {
                            if let form: Element = tb.getFormElement() {
                                try form.attr("action".utf8Array, startTag._attributes.get(key: "action".utf8Array))
                            }
                        }
                        try tb.processStartTag("hr")
                        try tb.processStartTag("label")
                        // hope you like english.
                        let prompt: [UInt8] = startTag._attributes.hasKey(key: "prompt".utf8Array) ?
                        startTag._attributes.get(key: "prompt".utf8Array) :
                        "self is a searchable index. Enter search keywords: ".utf8Array

                        try tb.process(Token.Char().data(prompt))

                        // input
                        let inputAttribs: Attributes = Attributes()
                        for attr: Attribute in startTag._attributes {
                            if (!Constants.InBodyStartInputAttribs.contains(attr.getKeyUTF8())) {
                                inputAttribs.put(attribute: attr)
                            }
                        }
                        try inputAttribs.put("name", "isindex")
                        try tb.processStartTag("input", inputAttribs)
                        try tb.processEndTag("label")
                        try tb.processStartTag("hr")
                        try tb.processEndTag("form")
                    } else if (name.equals("textarea")) {
                        try tb.insert(startTag)
                        // todo: If the next token is a U+000A LINE FEED (LF) character token, then ignore that token and move on to the next one. (Newlines at the start of textarea elements are ignored as an authoring convenience.)
                        tb.tokeniser.transition(TokeniserState.Rcdata)
                        tb.markInsertionMode()
                        tb.framesetOk(false)
                        tb.transition(.Text)
                    } else if (name.equals("xmp")) {
                        if (try tb.inButtonScope("p")) {
                            try tb.processEndTag("p")
                        }
                        try tb.reconstructFormattingElements()
                        tb.framesetOk(false)
                        try HtmlTreeBuilderState.handleRawtext(startTag, tb)
                    } else if (name.equals("iframe")) {
                        tb.framesetOk(false)
                        try HtmlTreeBuilderState.handleRawtext(startTag, tb)
                    } else if (name.equals("noembed")) {
                        // also handle noscript if script enabled
                        try HtmlTreeBuilderState.handleRawtext(startTag, tb)
                    } else if (name.equals("select")) {
                        try tb.reconstructFormattingElements()
                        try tb.insert(startTag)
                        tb.framesetOk(false)

                        let state: HtmlTreeBuilderState = tb.state()
                        if (state.equals(.InTable) || state.equals(.InCaption) || state.equals(.InTableBody) || state.equals(.InRow) || state.equals(.InCell)) {
                            tb.transition(.InSelectInTable)
                        } else {
                            tb.transition(.InSelect)
                        }
                    } else if Constants.InBodyStartOptions.contains(name) {
                        if (tb.currentElement() != nil && tb.currentElement()!.nodeNameUTF8().equals("option")) {
                            try tb.processEndTag("option")
                        }
                        try tb.reconstructFormattingElements()
                        try tb.insert(startTag)
                    } else if Constants.InBodyStartRuby.contains(name) {
                        if (try tb.inScope("ruby")) {
                            tb.generateImpliedEndTags()
                            if (tb.currentElement() != nil && !tb.currentElement()!.nodeNameUTF8().equals("ruby")) {
                                tb.error(self)
                                tb.popStackToBefore("ruby".utf8Array) // i.e. close up to but not include name
                            }
                            try tb.insert(startTag)
                        }
                    } else if (name.equals("math")) {
                        try tb.reconstructFormattingElements()
                        // todo: handle A start tag whose tag name is "math" (i.e. foreign, mathml)
                        try tb.insert(startTag)
                        tb.tokeniser.acknowledgeSelfClosingFlag()
                    } else if (name.equals("svg")) {
                        try tb.reconstructFormattingElements()
                        // todo: handle A start tag whose tag name is "svg" (xlink, svg)
                        try tb.insert(startTag)
                        tb.tokeniser.acknowledgeSelfClosingFlag()
                    } else if Constants.InBodyStartDrop.contains(name) {
                        tb.error(self)
                        return false
                    } else {
                        try tb.reconstructFormattingElements()
                        try tb.insert(startTag)
                    }
                } else {
                    try tb.reconstructFormattingElements()
                    try tb.insert(startTag)
                }
                break

            case .EndTag:
                let endTag: Token.EndTag = t.asEndTag()
                if let name = endTag.normalName() {
                    if Constants.InBodyEndAdoptionFormatters.contains(name) {
                        // Adoption Agency Algorithm.
                        for _ in 0..<8 {
                            let formatEl: Element? = tb.getActiveFormattingElement(name)
                            if (formatEl == nil) {
                                return anyOtherEndTag(t, tb)
                            } else if (!tb.onStack(formatEl!)) {
                                tb.error(self)
                                tb.removeFromActiveFormattingElements(formatEl!)
                                return true
                            } else if (try !tb.inScope(formatEl!.nodeNameUTF8())) {
                                tb.error(self)
                                return false
                            } else if (tb.currentElement() != formatEl!) {
                                tb.error(self)
                            }

                            var furthestBlock: Element? = nil
                            var commonAncestor: Element? = nil
                            var seenFormattingElement: Bool = false
                            let stack: Array<Element> = tb.getStack()
                            // the spec doesn't limit to < 64, but in degenerate cases (9000+ stack depth) self prevents
                            // run-aways
                            var stackSize = stack.count
                            if(stackSize > 64) {stackSize = 64}
                            for si in 0..<stackSize {
                                let el: Element = stack[si]
                                if (el == formatEl) {
                                    commonAncestor = stack[si - 1]
                                    seenFormattingElement = true
                                } else if (seenFormattingElement && tb.isSpecial(el)) {
                                    furthestBlock = el
                                    break
                                }
                            }
                            if (furthestBlock == nil) {
                                tb.popStackToClose(formatEl!.nodeNameUTF8())
                                tb.removeFromActiveFormattingElements(formatEl)
                                return true
                            }

                            // todo: Let a bookmark note the position of the formatting element in the list of active formatting elements relative to the elements on either side of it in the list.
                            // does that mean: int pos of format el in list?
                            var node: Element? = furthestBlock
                            var lastNode: Element? = furthestBlock
                            for _ in 0..<3 {
                                if (node != nil && tb.onStack(node!)) {
                                    node = tb.aboveOnStack(node!)
                                }
                                // note no bookmark check
                                if (node != nil && !tb.isInActiveFormattingElements(node!)) {
                                    tb.removeFromStack(node!)
                                    continue
                                } else if (node == formatEl) {
                                    break
                                }

                                let replacement: Element = try Element(Tag.valueOf(node!.nodeNameUTF8(), ParseSettings.preserveCase), tb.getBaseUri())
                                // case will follow the original node (so honours ParseSettings)
                                try tb.replaceActiveFormattingElement(node!, replacement)
                                try tb.replaceOnStack(node!, replacement)
                                node = replacement

                                if (lastNode == furthestBlock) {
                                    // todo: move the aforementioned bookmark to be immediately after the node in the list of active formatting elements.
                                    // not getting how self bookmark both straddles the element above, but is inbetween here...
                                }
                                if (lastNode!.parent() != nil) {
                                    try lastNode?.remove()
                                }
                                try node!.appendChild(lastNode!)

                                lastNode = node
                            }

                            if Constants.InBodyEndTableFosters.contains(commonAncestor!.nodeNameUTF8()) {
                                if (lastNode!.parent() != nil) {
                                    try lastNode!.remove()
                                }
                                try tb.insertInFosterParent(lastNode!)
                            } else {
                                if (lastNode!.parent() != nil) {
                                    try lastNode!.remove()
                                }
                                try commonAncestor!.appendChild(lastNode!)
                            }

                            let adopter: Element = Element(formatEl!.tag(), tb.getBaseUri())
                            adopter.getAttributes()?.addAll(incoming: formatEl!.getAttributes())
                            let childNodes: [Node] = furthestBlock!.getChildNodes()
                            for childNode: Node in childNodes {
                                try adopter.appendChild(childNode) // append will reparent. thus the clone to avoid concurrent mod.
                            }
                            try furthestBlock?.appendChild(adopter)
                            tb.removeFromActiveFormattingElements(formatEl)
                            // todo: insert the element into the list of active formatting elements at the position of the aforementioned bookmark.
                            tb.removeFromStack(formatEl!)
                            try tb.insertOnStackAfter(furthestBlock!, adopter)
                        }
                    } else if Constants.InBodyEndClosers.contains(name) {
                        if (try !tb.inScope(name)) {
                            // nothing to close
                            tb.error(self)
                            return false
                        } else {
                            tb.generateImpliedEndTags()
                            if (!tb.currentElement()!.nodeNameUTF8().equals(name)) {
                                tb.error(self)
                            }
                            tb.popStackToClose(name)
                        }
                    } else if (name.equals("span")) {
                        // same as final fall through, but saves short circuit
                        return anyOtherEndTag(t, tb)
                    } else if (name.equals("li")) {
                        if (try !tb.inListItemScope(name)) {
                            tb.error(self)
                            return false
                        } else {
                            tb.generateImpliedEndTags(name)
                            if (tb.currentElement() != nil && !tb.currentElement()!.nodeNameUTF8().equals(name)) {
                                tb.error(self)
                            }
                            tb.popStackToClose(name)
                        }
                    } else if (name.equals("body")) {
                        if (try !tb.inScope("body")) {
                            tb.error(self)
                            return false
                        } else {
                            // todo: error if stack contains something not dd, dt, li, optgroup, option, p, rp, rt, tbody, td, tfoot, th, thead, tr, body, html
                            tb.transition(.AfterBody)
                        }
                    } else if (name.equals("html")) {
                        let notIgnored: Bool = try tb.processEndTag("body")
                        if (notIgnored) {
                            return try tb.process(endTag)
                        }
                    } else if (name.equals("form")) {
                        let currentForm: Element? = tb.getFormElement()
                        tb.setFormElement(nil)
                        if (try currentForm == nil || !tb.inScope(name)) {
                            tb.error(self)
                            return false
                        } else {
                            tb.generateImpliedEndTags()
                            if (tb.currentElement() != nil && !tb.currentElement()!.nodeNameUTF8().equals(name)) {
                                tb.error(self)
                            }
                            // remove currentForm from stack. will shift anything under up.
                            tb.removeFromStack(currentForm!)
                        }
                    } else if (name.equals("p")) {
                        if (try !tb.inButtonScope(name)) {
                            tb.error(self)
                            try tb.processStartTag(name) // if no p to close, creates an empty <p></p>
                            return try tb.process(endTag)
                        } else {
                            tb.generateImpliedEndTags(name)
                            if (tb.currentElement() != nil && !tb.currentElement()!.nodeNameUTF8().equals(name)) {
                                tb.error(self)
                            }
                            tb.popStackToClose(name)
                        }
                    } else if Constants.DdDt.contains(name) {
                        if (try !tb.inScope(name)) {
                            tb.error(self)
                            return false
                        } else {
                            tb.generateImpliedEndTags(name)
                            if (tb.currentElement() != nil && !tb.currentElement()!.nodeNameUTF8().equals(name)) {
                                tb.error(self)
                            }
                            tb.popStackToClose(name)
                        }
                    } else if Constants.Headings.contains(name) {
                        if (try !tb.inScope(Constants.Headings)) {
                            tb.error(self)
                            return false
                        } else {
                            tb.generateImpliedEndTags(name)
                            if (tb.currentElement() != nil && !tb.currentElement()!.nodeNameUTF8().equals(name)) {
                                tb.error(self)
                            }
                            tb.popStackToClose(Constants.Headings)
                        }
                    } else if (name.equals("sarcasm")) {
                        // *sigh*
                        return anyOtherEndTag(t, tb)
                    } else if Constants.InBodyStartApplets.contains(name) {
                        if (try !tb.inScope("name")) {
                            if (try !tb.inScope(name)) {
                                tb.error(self)
                                return false
                            }
                            tb.generateImpliedEndTags()
                            if (tb.currentElement() != nil && !tb.currentElement()!.nodeNameUTF8().equals(name)) {
                                tb.error(self)
                            }
                            tb.popStackToClose(name)
                            tb.clearFormattingElementsToLastMarker()
                        }
                    } else if (name.equals("br")) {
                        tb.error(self)
                        try tb.processStartTag("br")
                        return false
                    } else {
                        return anyOtherEndTag(t, tb)
                    }
                } else {
                    return anyOtherEndTag(t, tb)
                }

                break
            case .EOF:
                // todo: error if stack contains something not dd, dt, li, p, tbody, td, tfoot, th, thead, tr, body, html
                // stop parsing
                break
            }
            return true
        case .Text:
            if (t.isCharacter()) {
                try tb.insert(t.asCharacter())
            } else if (t.isEOF()) {
                tb.error(self)
                // if current node is script: already started
                tb.pop()
                tb.transition(tb.originalState())
                return try tb.process(t)
            } else if (t.isEndTag()) {
                // if: An end tag whose tag name is "script" -- scripting nesting level, if evaluating scripts
                tb.pop()
                tb.transition(tb.originalState())
            }
            return true
        case .InTable:
            func anythingElse(_ t: Token, _ tb: HtmlTreeBuilder)throws->Bool {
                tb.error(self)
                var processed: Bool
                if let cur = tb.currentElement(), TagSets.table.contains(cur.nodeNameUTF8()) {
                    tb.setFosterInserts(true)
                    processed = try tb.process(t, .InBody)
                    tb.setFosterInserts(false)
                } else {
                    processed = try tb.process(t, .InBody)
                }
                return processed
            }

            if (t.isCharacter()) {
                tb.newPendingTableCharacters()
                tb.markInsertionMode()
                tb.transition(.InTableText)
                return try tb.process(t)
            } else if (t.isComment()) {
                try tb.insert(t.asComment())
                return true
            } else if (t.isDoctype()) {
                tb.error(self)
                return false
            } else if (t.isStartTag()) {
                let startTag: Token.StartTag = t.asStartTag()
                if let name = startTag.normalName() {
                    if (name.equals("caption")) {
                        tb.clearStackToTableContext()
                        tb.insertMarkerToFormattingElements()
                        try tb.insert(startTag)
                        tb.transition(.InCaption)
                    } else if (name.equals("colgroup")) {
                        tb.clearStackToTableContext()
                        try tb.insert(startTag)
                        tb.transition(.InColumnGroup)
                    } else if (name.equals("col")) {
                        try tb.processStartTag("colgroup")
                        return try tb.process(t)
                    } else if TagSets.tableSections.contains(name) {
                        tb.clearStackToTableContext()
                        try tb.insert(startTag)
                        tb.transition(.InTableBody)
                    } else if ["td".utf8Array, "th".utf8Array, "tr".utf8Array].contains(name) {
                        try tb.processStartTag("tbody")
                        return try tb.process(t)
                    } else if (name.equals("table")) {
                        tb.error(self)
                        let processed: Bool = try tb.processEndTag("table")
                        if (processed) // only ignored if in fragment
                        {return try tb.process(t)}
                    } else if ["style".utf8Array, "script".utf8Array].contains(name) {
                        return try tb.process(t, .InHead)
                    } else if (name.equals("input")) {
                        if (!startTag._attributes.get(key: "type".utf8Array).equalsIgnoreCase(string: "hidden".utf8Array)) {
                            return try anythingElse(t, tb)
                        } else {
                            try tb.insertEmpty(startTag)
                        }
                    } else if (name.equals("form")) {
                        tb.error(self)
                        if (tb.getFormElement() != nil) {
                            return false
                        } else {
                            try tb.insertForm(startTag, false)
                        }
                    } else {
                        return try anythingElse(t, tb)
                    }
                }
                return true // todo: check if should return processed http://www.whatwg.org/specs/web-apps/current-work/multipage/tree-construction.html#parsing-main-intable
            } else if (t.isEndTag()) {
                let endTag: Token.EndTag = t.asEndTag()
                if let name = endTag.normalName() {
                    if (name.equals("table")) {
                        if (try !tb.inTableScope(name)) {
                            tb.error(self)
                            return false
                        } else {
                            tb.popStackToClose("table".utf8Array)
                        }
                        tb.resetInsertionMode()
                    } else if TagSets.tableMix.contains(name) {
                        tb.error(self)
                        return false
                    } else {
                        return try anythingElse(t, tb)
                    }
                } else {
                    return try anythingElse(t, tb)
                }
                return true // todo: as above todo
            } else if (t.isEOF()) {
                if (tb.currentElement() != nil && tb.currentElement()!.nodeNameUTF8().equals("html")) {
                    tb.error(self)
                }
                return true // stops parsing
            }
            return try anythingElse(t, tb)
        case .InTableText:
            switch (t.type) {
            case .Char:
                let c: Token.Char = t.asCharacter()
                if (c.getData() != nil && c.getData()!.equals(HtmlTreeBuilderState.nullString)) {
                    tb.error(self)
                    return false
                } else {
                    var a = tb.getPendingTableCharacters()
                    a.append(c.getData()!)
                    tb.setPendingTableCharacters(a)
                }
                break
            default:
                // todo - don't really like the way these table character data lists are built
                if (tb.getPendingTableCharacters().count > 0) {
                    for character in tb.getPendingTableCharacters() {
                        if (!HtmlTreeBuilderState.isWhitespace(character)) {
                            // InTable anything else section:
                            tb.error(self)
                            if tb.currentElement() != nil && TagSets.table.contains(tb.currentElement()!.nodeNameUTF8()) {
                                tb.setFosterInserts(true)
                                try tb.process(Token.Char().data(character), .InBody)
                                tb.setFosterInserts(false)
                            } else {
                                try tb.process(Token.Char().data(character), .InBody)
                            }
                        } else {
                            try tb.insert(Token.Char().data(character))
                        }
                    }
                    tb.newPendingTableCharacters()
                }
                tb.transition(tb.originalState())
                return try tb.process(t)
            }
            return true
        case .InCaption:
            if t.endTagNormalName() == "caption".utf8Array {
                let endTag: Token.EndTag = t.asEndTag()
                let name = endTag.normalName()
                if (try name != nil && !tb.inTableScope(name!)) {
                    tb.error(self)
                    return false
                } else {
                    tb.generateImpliedEndTags()
                    if (!tb.currentElement()!.nodeNameUTF8().equals("caption")) {
                        tb.error(self)
                    }
                    tb.popStackToClose("caption".utf8Array)
                    tb.clearFormattingElementsToLastMarker()
                    tb.transition(.InTable)
                }
            } else if (t.isStartTag() && TagSets.tableRowsAndCols.contains(t.asStartTag().normalName()!)) ||
                (t.isEndTag() && t.asEndTag().normalName()!.equals("table"))
            {
                // Note: original code relies on && precedence being higher than ||
                //
                // if ((t.isStartTag() && StringUtil.inString(t.asStartTag().normalName()!,
                //    haystack: "caption", "col", "colgroup", "tbody", "td", "tfoot", "th", "thead", "tr") ||
                //    t.isEndTag() && t.asEndTag().normalName()!.equals("table"))) {

                tb.error(self)
                let processed: Bool = try tb.processEndTag("caption")
                if (processed) {
                    return try tb.process(t)
                }
            } else if let nName = t.endTagNormalName(), TagSets.tableMix2.contains(nName) {
                tb.error(self)
                return false
            } else {
                return try tb.process(t, .InBody)
            }
            return true
        case .InColumnGroup:
            func anythingElse(_ t: Token, _ tb: TreeBuilder)throws->Bool {
                let processed: Bool = try tb.processEndTag("colgroup")
                if (processed) { // only ignored in frag case
                    return try tb.process(t)
                }
                return true
            }

            if (HtmlTreeBuilderState.isWhitespace(t)) {
                try tb.insert(t.asCharacter())
                return true
            }
            switch (t.type) {
            case .Comment:
                try tb.insert(t.asComment())
                break
            case .Doctype:
                tb.error(self)
                break
            case .StartTag:
                let startTag: Token.StartTag = t.asStartTag()
                let name = startTag.normalName()
                if "html".utf8Array == name {
                    return try tb.process(t, .InBody)
                } else if "col".utf8Array == name {
                    try tb.insertEmpty(startTag)
                } else {
                    return try anythingElse(t, tb)
                }
                break
            case .EndTag:
                let endTag: Token.EndTag = t.asEndTag()
                let name = endTag.normalName()
                if "colgroup".utf8Array == name {
                    if "html".utf8Array == tb.currentElement()?.nodeNameUTF8() { // frag case
                        tb.error(self)
                        return false
                    } else {
                        tb.pop()
                        tb.transition(.InTable)
                    }
                } else {
                    return try anythingElse(t, tb)
                }
                break
            case .EOF:
                if "html".utf8Array == tb.currentElement()?.nodeNameUTF8() {
                    return true // stop parsing; frag case
                } else {
                    return try anythingElse(t, tb)
                }
            default:
                return try anythingElse(t, tb)
            }
            return true
        case .InTableBody:
            @discardableResult
            func exitTableBody(_ t: Token, _ tb: HtmlTreeBuilder)throws->Bool {
                if (try !(tb.inTableScope("tbody") || tb.inTableScope("thead") || tb.inScope("tfoot"))) {
                    // frag case
                    tb.error(self)
                    return false
                }
                tb.clearStackToTableBodyContext()
                try tb.processEndTag(tb.currentElement()!.nodeNameUTF8()) // tbody, tfoot, thead
                return try tb.process(t)
            }

            func anythingElse(_ t: Token, _ tb: HtmlTreeBuilder)throws->Bool {
                return try tb.process(t, .InTable)
            }

            switch (t.type) {
            case .StartTag:
                let startTag: Token.StartTag = t.asStartTag()
                let name = startTag.normalName()
                if "tr".utf8Array == name {
                    tb.clearStackToTableBodyContext()
                    try tb.insert(startTag)
                    tb.transition(.InRow)
                } else if let name = name, TagSets.thTd.contains(name) {
                    tb.error(self)
                    try tb.processStartTag("tr")
                    return try tb.process(startTag)
                } else if let name = name, TagSets.tableMix3.contains(name) {
                    return try exitTableBody(t, tb)
                } else {
                    return try anythingElse(t, tb)
                }
                break
            case .EndTag:
                let endTag: Token.EndTag = t.asEndTag()
                let name = endTag.normalName()
                if let name = name, TagSets.tableSections.contains(name) {
                    if (try !tb.inTableScope(name)) {
                        tb.error(self)
                        return false
                    } else {
                        tb.clearStackToTableBodyContext()
                        tb.pop()
                        tb.transition(.InTable)
                    }
                } else if "table".utf8Array == name {
                    return try exitTableBody(t, tb)
                } else if let name = name, TagSets.tableMix4.contains(name) {
                    tb.error(self)
                    return false
                } else {
                    return try anythingElse(t, tb)
                }
                break
            default:
                return try anythingElse(t, tb)
            }
            return true
        case .InRow:
            func anythingElse(_ t: Token, _ tb: HtmlTreeBuilder)throws->Bool {
                return try tb.process(t, .InTable)
            }

            func handleMissingTr(_ t: Token, _ tb: TreeBuilder)throws->Bool {
                let processed: Bool = try tb.processEndTag("tr")
                if (processed) {
                    return try tb.process(t)
                } else {
                    return false
                }
            }

            if (t.isStartTag()) {
                let startTag: Token.StartTag = t.asStartTag()
                let name = startTag.normalName()

                if let name = name, TagSets.thTd.contains(name) {
                    tb.clearStackToTableRowContext()
                    try tb.insert(startTag)
                    tb.transition(.InCell)
                    tb.insertMarkerToFormattingElements()
                } else if let name = name, TagSets.tableMix5.contains(name) {
                    return try handleMissingTr(t, tb)
                } else {
                    return try anythingElse(t, tb)
                }
            } else if (t.isEndTag()) {
                let endTag: Token.EndTag = t.asEndTag()
                let name = endTag.normalName()

                if "tr".utf8Array == name {
                    if (try !tb.inTableScope(name!)) {
                        tb.error(self) // frag
                        return false
                    }
                    tb.clearStackToTableRowContext()
                    tb.pop() // tr
                    tb.transition(.InTableBody)
                } else if "table".utf8Array == name {
                    return try handleMissingTr(t, tb)
                } else if let name, TagSets.tableSections.contains(name) {
                    if (try !tb.inTableScope(name)) {
                        tb.error(self)
                        return false
                    }
                    try tb.processEndTag("tr")
                    return try tb.process(t)
                } else if let name = name, TagSets.tableMix6.contains(name) {
                    tb.error(self)
                    return false
                } else {
                    return try anythingElse(t, tb)
                }
            } else {
                return try anythingElse(t, tb)
            }
            return true
        case .InCell:
            func anythingElse(_ t: Token, _ tb: HtmlTreeBuilder)throws->Bool {
                return try  tb.process(t, .InBody)
            }

            func closeCell(_ tb: HtmlTreeBuilder)throws {
                if (try tb.inTableScope("td")) {
                    try tb.processEndTag("td")
                } else {
                    try tb.processEndTag("th") // only here if th or td in scope
                }
            }

            if (t.isEndTag()) {
                let endTag: Token.EndTag = t.asEndTag()
                let name = endTag.normalName()

                if let name = name, TagSets.thTd.contains(name) {
                    if (try !tb.inTableScope(name)) {
                        tb.error(self)
                        tb.transition(.InRow) // might not be in scope if empty: <td /> and processing fake end tag
                        return false
                    }
                    tb.generateImpliedEndTags()
                    if name != tb.currentElement()?.nodeNameUTF8() {
                        tb.error(self)
                    }
                    tb.popStackToClose(name)
                    tb.clearFormattingElementsToLastMarker()
                    tb.transition(.InRow)
                } else if let name = name, TagSets.tableMix7.contains(name) {
                    tb.error(self)
                    return false
                } else if let name = name, TagSets.table.contains(name) {
                    if (try !tb.inTableScope(name)) {
                        tb.error(self)
                        return false
                    }
                    try closeCell(tb)
                    return try tb.process(t)
                } else {
                    return try anythingElse(t, tb)
                }
            } else if let nName = t.startTagNormalName(), TagSets.tableRowsAndCols.contains(nName) {
                if (try !(tb.inTableScope("td") || tb.inTableScope("th"))) {
                    tb.error(self)
                    return false
                }
                try closeCell(tb)
                return try tb.process(t)
            } else {
                return try anythingElse(t, tb)
            }
            return true
        case .InSelect:
            func anythingElse(_ t: Token, _ tb: HtmlTreeBuilder) -> Bool {
                tb.error(self)
                return false
            }

            switch (t.type) {
            case .Char:
                let c: Token.Char = t.asCharacter()
                if HtmlTreeBuilderState.nullString == c.getData() {
                    tb.error(self)
                    return false
                } else {
                    try tb.insert(c)
                }
                break
            case .Comment:
                try tb.insert(t.asComment())
                break
            case .Doctype:
                tb.error(self)
                return false
            case .StartTag:
                let start: Token.StartTag = t.asStartTag()
                let name = start.normalName()
                if ("html".equals(name)) {
                    return try tb.process(start, .InBody)
                } else if ("option".equals(name)) {
                    try tb.processEndTag("option")
                    try tb.insert(start)
                } else if ("optgroup".equals(name)) {
                    if ("option".equals(tb.currentElement()?.nodeNameUTF8())) {
                        try tb.processEndTag("option")
                    } else if ("optgroup".equals(tb.currentElement()?.nodeNameUTF8())) {
                        try tb.processEndTag("optgroup")
                    }
                    try tb.insert(start)
                } else if ("select".equals(name)) {
                    tb.error(self)
                    return try tb.processEndTag("select")
                } else if let name = name, TagSets.inputKeygenTextarea.contains(name) {
                    tb.error(self)
                    if (try !tb.inSelectScope("select".utf8Array)) {
                        return false // frag
                    }
                    try tb.processEndTag("select")
                    return try tb.process(start)
                } else if ("script".equals(name)) {
                    return try tb.process(t, .InHead)
                } else {
                    return anythingElse(t, tb)
                }
                break
            case .EndTag:
                let end: Token.EndTag = t.asEndTag()
                let name = end.normalName()
                if ("optgroup".equals(name)) {
                    if ("option".equals(tb.currentElement()?.nodeNameUTF8()) && tb.currentElement() != nil && tb.aboveOnStack(tb.currentElement()!) != nil && "optgroup".equals(tb.aboveOnStack(tb.currentElement()!)?.nodeNameUTF8())) {
                        try tb.processEndTag("option")
                    }
                    if ("optgroup".equals(tb.currentElement()?.nodeNameUTF8())) {
                        tb.pop()
                    } else {
                        tb.error(self)
                    }
                } else if ("option".equals(name)) {
                    if ("option".equals(tb.currentElement()?.nodeNameUTF8())) {
                        tb.pop()
                    } else {
                        tb.error(self)
                    }
                } else if ("select".equals(name)) {
                    if (try !tb.inSelectScope(name!)) {
                        tb.error(self)
                        return false
                    } else {
                        tb.popStackToClose(name!)
                        tb.resetInsertionMode()
                    }
                } else {
                    return anythingElse(t, tb)
                }
                break
            case .EOF:
                if (!"html".equals(tb.currentElement()?.nodeNameUTF8())) {
                    tb.error(self)
                }
                break
//            default:
//                return anythingElse(t, tb)
            }
            return true
        case .InSelectInTable:
            if let nName = t.startTagNormalName(), TagSets.tableMix8.contains(nName) {
                tb.error(self)
                try tb.processEndTag("select")
                return try tb.process(t)
            } else if let nName = t.endTagNormalName(), TagSets.tableMix8.contains(nName) {
                tb.error(self)
                if try tb.inTableScope(nName) {
                    try tb.processEndTag("select")
                    return try (tb.process(t))
                } else {
                    return false
                }
            } else {
                return try tb.process(t, .InSelect)
            }
        case .AfterBody:
            if (HtmlTreeBuilderState.isWhitespace(t)) {
                return try tb.process(t, .InBody)
            } else if (t.isComment()) {
                try tb.insert(t.asComment()) // into html node
            } else if (t.isDoctype()) {
                tb.error(self)
                return false
            } else if t.startTagNormalName() == "html".utf8Array {
                return try tb.process(t, .InBody)
            } else if t.endTagNormalName() == "html".utf8Array {
                if (tb.isFragmentParsing()) {
                    tb.error(self)
                    return false
                } else {
                    tb.transition(.AfterAfterBody)
                }
            } else if (t.isEOF()) {
                // chillax! we're done
            } else {
                tb.error(self)
                tb.transition(.InBody)
                return try tb.process(t)
            }
            return true
        case .InFrameset:
                if (HtmlTreeBuilderState.isWhitespace(t)) {
                    try tb.insert(t.asCharacter())
                } else if (t.isComment()) {
                    try tb.insert(t.asComment())
                } else if (t.isDoctype()) {
                    tb.error(self)
                    return false
                } else if (t.isStartTag()) {
                    let start: Token.StartTag = t.asStartTag()
                    let name = start.normalName()
                    if ("html".equals(name)) {
                        return try tb.process(start, .InBody)
                    } else if ("frameset".equals(name)) {
                        try tb.insert(start)
                    } else if ("frame".equals(name)) {
                        try tb.insertEmpty(start)
                    } else if ("noframes".equals(name)) {
                        return try tb.process(start, .InHead)
                    } else {
                        tb.error(self)
                        return false
                    }
                } else if t.endTagNormalName() == "frameset".utf8Array {
                    if ("html".equals(tb.currentElement()?.nodeNameUTF8())) { // frag
                        tb.error(self)
                        return false
                    } else {
                        tb.pop()
                        if (!tb.isFragmentParsing() && !"frameset".equals(tb.currentElement()?.nodeNameUTF8())) {
                            tb.transition(.AfterFrameset)
                        }
                    }
                } else if (t.isEOF()) {
                    if (!"html".equals(tb.currentElement()?.nodeNameUTF8())) {
                        tb.error(self)
                        return true
                    }
                } else {
                    tb.error(self)
                    return false
                }
                return true
        case .AfterFrameset:
                if (HtmlTreeBuilderState.isWhitespace(t)) {
                    try tb.insert(t.asCharacter())
                } else if (t.isComment()) {
                    try tb.insert(t.asComment())
                } else if (t.isDoctype()) {
                    tb.error(self)
                    return false
                } else if t.startTagNormalName() == "html".utf8Array {
                    return try tb.process(t, .InBody)
                } else if t.endTagNormalName() == "html".utf8Array {
                    tb.transition(.AfterAfterFrameset)
                } else if t.startTagNormalName() == "noframes".utf8Array {
                    return try tb.process(t, .InHead)
                } else if (t.isEOF()) {
                    // cool your heels, we're complete
                } else {
                    tb.error(self)
                    return false
                }
                return true
        case .AfterAfterBody:
                if (t.isComment()) {
                    try tb.insert(t.asComment())
                } else if (t.isDoctype() || HtmlTreeBuilderState.isWhitespace(t) || (t.isStartTag() && "html".equals(t.asStartTag().normalName()))) {
                    return try tb.process(t, .InBody)
                } else if (t.isEOF()) {
                    // nice work chuck
                } else {
                    tb.error(self)
                    tb.transition(.InBody)
                    return try tb.process(t)
                }
                return true
        case .AfterAfterFrameset:
                if (t.isComment()) {
                    try tb.insert(t.asComment())
                } else if (t.isDoctype() || HtmlTreeBuilderState.isWhitespace(t) || (t.startTagNormalName() == "html".utf8Array)) {
                    return try tb.process(t, .InBody)
                } else if (t.isEOF()) {
                    // nice work chuck
                } else if t.startTagNormalName() == "noframes".utf8Array {
                    return try tb.process(t, .InHead)
                } else {
                    tb.error(self)
                    return false
                }
                return true
        case .ForeignContent:
            return true
            // todo: implement. Also how do we get here?
        }

    }

    private static func isWhitespace(_ t: Token) -> Bool {
        if (t.isCharacter()) {
            let data = t.asCharacter().getData()
            return isWhitespace(data)
        }
        return false
    }

    private static func isWhitespace(_ data: [UInt8]?) -> Bool {
        // todo: self checks more than spec - UnicodeScalar.BackslashT, "\n", "\f", "\r", " "
        if let data {
            let dataString = String(decoding: data, as: UTF8.self)
            for c in dataString {
                if (!StringUtil.isWhitespace(c)) {
                    return false}
            }
        }
        return true
    }

    private static func handleRcData(_ startTag: Token.StartTag, _ tb: HtmlTreeBuilder)throws {
        tb.tokeniser.transition(TokeniserState.Rcdata)
        tb.markInsertionMode()
        tb.transition(.Text)
        try tb.insert(startTag)
    }

    private static func handleRawtext(_ startTag: Token.StartTag, _ tb: HtmlTreeBuilder)throws {
        tb.tokeniser.transition(TokeniserState.Rawtext)
        tb.markInsertionMode()
        tb.transition(.Text)
        try tb.insert(startTag)
    }

    // lists of tags to search through. A little harder to read here, but causes less GC than dynamic varargs.
    // was contributing around 10% of parse GC load.
    fileprivate final class Constants {
        fileprivate static let InBodyStartToHead: Set = Set(["base", "basefont", "bgsound", "command", "link", "meta", "noframes", "script", "style", "title"].map { $0.utf8Array })
        fileprivate static let InBodyStartPClosers: Set = Set(["address", "article", "aside", "blockquote", "center", "details", "dir", "div", "dl",
                                                                "fieldset", "figcaption", "figure", "footer", "header", "hgroup", "menu", "nav", "ol",
                                                                "p", "section", "summary", "ul"].map { $0.utf8Array })
        fileprivate static let Headings: Set = Set(["h1", "h2", "h3", "h4", "h5", "h6"].map { $0.utf8Array })
        fileprivate static let InBodyStartPreListing: Set = Set(["pre", "listing"].map { $0.utf8Array })
        fileprivate static let InBodyStartLiBreakers: Set = Set(["address", "div", "p"].map { $0.utf8Array })
        fileprivate static let DdDt: Set = Set(["dd", "dt"].map { $0.utf8Array })
        fileprivate static let Formatters: Set = Set(["b", "big", "code", "em", "font", "i", "s", "small", "strike", "strong", "tt", "u"].map { $0.utf8Array })
        fileprivate static let InBodyStartApplets: Set = Set(["applet", "marquee", "object"].map { $0.utf8Array })
        fileprivate static let InBodyStartEmptyFormatters: Set = Set(["area", "br", "embed", "img", "keygen", "wbr"].map { $0.utf8Array })
        fileprivate static let InBodyStartMedia: Set = Set(["param", "source", "track"].map { $0.utf8Array })
        fileprivate static let InBodyStartInputAttribs: Set = Set(["name", "action", "prompt"].map { $0.utf8Array })
        fileprivate static let InBodyStartOptions: Set = Set(["optgroup", "option"].map { $0.utf8Array })
        fileprivate static let InBodyStartRuby: Set = Set(["rp", "rt"].map { $0.utf8Array })
        fileprivate static let InBodyStartDrop: Set = Set(["caption", "col", "colgroup", "frame", "head", "tbody", "td", "tfoot", "th", "thead", "tr"].map { $0.utf8Array })
        fileprivate static let InBodyEndClosers: Set = Set(["address", "article", "aside", "blockquote", "button", "center", "details", "dir", "div",
                                                             "dl", "fieldset", "figcaption", "figure", "footer", "header", "hgroup", "listing", "menu",
                                                             "nav", "ol", "pre", "section", "summary", "ul"].map { $0.utf8Array })
        fileprivate static let InBodyEndAdoptionFormatters: Set = Set(["a", "b", "big", "code", "em", "font", "i", "nobr", "s", "small", "strike", "strong", "tt", "u"].map { $0.utf8Array })
        fileprivate static let InBodyEndTableFosters: Set = Set(["table", "tbody", "tfoot", "thead", "tr"].map { $0.utf8Array })
    }
}

fileprivate extension Token {
    
    func endTagNormalName() -> [UInt8]? {
        guard isEndTag() else { return nil }
        return asEndTag().normalName()
    }
    
    func startTagNormalName() -> [UInt8]? {
        guard isStartTag() else { return nil }
        return asStartTag().normalName()
    }
    
}
