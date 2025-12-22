//
//  HtmlTreeBuilderState.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 24/10/16.
//

import Foundation

protocol HtmlTreeBuilderStateProtocol {
    func process(_ t: Token, _ tb: HtmlTreeBuilder) throws -> Bool
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
    
    // TODO: Replace sets with byte masks for speed (easier done via single byte ASCII assumption, too)
    private enum TagSets {
        static let outer = ParsingStrings(["head", "body", "html", "br"])
        static let outer2 = ParsingStrings(["body", "html", "br"])
        static let outer3 = ParsingStrings(["body", "html"])
        static let baseEtc = ParsingStrings(["base", "basefont", "bgsound", "command", "link"])
        static let baseEtc2 = ParsingStrings(["basefont", "bgsound", "link", "meta", "noframes", "style"])
        static let baseEtc3 = ParsingStrings(["base", "basefont", "bgsound", "link", "meta", "noframes", "script", "style", "title"])
        static let headNoscript = ParsingStrings(["head", "noscript"])
        static let table = ParsingStrings(["table", "tbody", "tfoot", "thead", "tr"])
        static let tableSections = ParsingStrings(["tbody", "tfoot", "thead"])
        static let tableMix = ParsingStrings(["body", "caption", "col", "colgroup", "html", "tbody", "td", "tfoot", "th", "thead", "tr"])
        static let tableMix2 = ParsingStrings(["body", "col", "colgroup", "html", "tbody", "td", "tfoot", "th", "thead", "tr"])
        static let tableMix3 = ParsingStrings(["caption", "col", "colgroup", "tbody", "tfoot", "thead"])
        static let tableMix4 = ParsingStrings(["body", "caption", "col", "colgroup", "html", "td", "th", "tr"])
        static let tableMix5 = ParsingStrings(["caption", "col", "colgroup", "tbody", "tfoot", "thead", "tr"])
        static let tableMix6 = ParsingStrings(["body", "caption", "col", "colgroup", "html", "td", "th"])
        static let tableMix7 = ParsingStrings(["body", "caption", "col", "colgroup", "html"])
        static let tableMix8 = ParsingStrings(["caption", "table", "tbody", "tfoot", "thead", "tr", "td", "th"])
        static let tableRowsAndCols = ParsingStrings(["caption", "col", "colgroup", "tbody", "td", "tfoot", "th", "thead", "tr"])
        static let thTd = ParsingStrings(["th", "td"])
        static let inputKeygenTextarea = ParsingStrings(["input", "keygen", "textarea"])
    }

    private static let nullString: [UInt8] = "\u{0000}".utf8Array

    public func equals(_ s: HtmlTreeBuilderState) -> Bool {
        return self.hashValue == s.hashValue
    }

    func process(_ t: Token, _ tb: HtmlTreeBuilder) throws -> Bool {
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

            func anythingElse(_ t: Token, _ tb: HtmlTreeBuilder) throws -> Bool {
                try tb.insertStartTag(UTF8Arrays.html)
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
            } else if t.startTagNormalNameEquals(UTF8Arrays.html) {
                try tb.insert(t.asStartTag())
                tb.transition(.BeforeHead)
            } else if t.endTagNormalNameIn(TagSets.outer) {
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
            } else if t.startTagNormalNameEquals(UTF8Arrays.html) {
                return try HtmlTreeBuilderState.InBody.process(t, tb) // does not transition
            } else if t.startTagNormalNameEquals(UTF8Arrays.head) {
                let head: Element = try tb.insert(t.asStartTag())
                tb.setHeadElement(head)
                tb.transition(.InHead)
            } else if t.endTagNormalNameIn(TagSets.outer) {
                try tb.processStartTag(UTF8Arrays.head)
                return try tb.process(t)
            } else if (t.isEndTag()) {
                tb.error(self)
                return false
            } else {
                try tb.processStartTag(UTF8Arrays.head)
                return try tb.process(t)
            }
            return true
        case .InHead:
            func anythingElse(_ t: Token, _ tb: TreeBuilder)throws->Bool {
                try tb.processEndTag(UTF8Arrays.head)
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
                if start.normalNameEquals(UTF8Arrays.html) {
                    return try HtmlTreeBuilderState.InBody.process(t, tb)
                } else if TagSets.baseEtc.containsCaseInsensitive(start) {
                    let el: Element = try tb.insertEmpty(start)
                    // SwiftSoup special: update base the frist time it is seen
                    if (start.normalNameEquals(UTF8Arrays.base) && el.hasAttr("href")) {
                        try tb.maybeSetBaseUri(el)
                    }
                } else if start.normalNameEquals(UTF8Arrays.meta) {
                    let _: Element = try tb.insertEmpty(start)
                    // todo: charset switches
                } else if start.normalNameEquals(UTF8Arrays.title) {
                    try HtmlTreeBuilderState.handleRcData(start, tb)
                } else if start.normalNameEquals(UTF8Arrays.noframes) || start.normalNameEquals(UTF8Arrays.style) {
                    try HtmlTreeBuilderState.handleRawtext(start, tb)
                } else if start.normalNameEquals(UTF8Arrays.noscript) {
                    // else if noscript && scripting flag = true: rawtext (SwiftSoup doesn't run script, to handle as noscript)
                    try tb.insert(start)
                    tb.transition(.InHeadNoscript)
                } else if start.normalNameEquals(UTF8Arrays.script) {
                    // skips some script rules as won't execute them

                    tb.tokeniser.transition(TokeniserState.ScriptData)
                    tb.markInsertionMode()
                    tb.transition(.Text)
                    try tb.insert(start)
                } else if start.normalNameEquals(UTF8Arrays.head) {
                    tb.error(self)
                    return false
                } else {
                    return try anythingElse(t, tb)
                }
                break
            case .EndTag:
                let end: Token.EndTag = t.asEndTag()
                if end.normalNameEquals(UTF8Arrays.head) {
                    tb.pop()
                    tb.transition(.AfterHead)
                } else if TagSets.outer2.containsCaseInsensitive(end) {
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
            func anythingElse(_ t: Token, _ tb: HtmlTreeBuilder) throws -> Bool {
                tb.error(self)
                try tb.insert(Token.Char().data(t.toString().utf8Array))
                return true
            }
            if (t.isDoctype()) {
                tb.error(self)
            } else if t.startTagNormalNameEquals(UTF8Arrays.html) {
                return try tb.process(t, .InBody)
            } else if t.endTagNormalNameEquals(UTF8Arrays.noscript) {
                tb.pop()
                tb.transition(.InHead)
            } else if HtmlTreeBuilderState.isWhitespace(t) || t.isComment() || (t.isStartTag() && TagSets.baseEtc2.containsCaseInsensitive(t.asStartTag())) {
                return try tb.process(t, .InHead)
            } else if t.endTagNormalNameEquals(UTF8Arrays.br) {
                return try anythingElse(t, tb)
            } else if (t.isStartTag() && TagSets.headNoscript.containsCaseInsensitive(t.asStartTag())) || t.isEndTag() {
                tb.error(self)
                return false
            } else {
                return try anythingElse(t, tb)
            }
            return true
        case .AfterHead:
            @discardableResult
            func anythingElse(_ t: Token, _ tb: HtmlTreeBuilder) throws -> Bool {
                try tb.processStartTag(UTF8Arrays.body)
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
                if startTag.normalNameEquals(UTF8Arrays.html) {
                    return try tb.process(t, .InBody)
                } else if startTag.normalNameEquals(UTF8Arrays.body) {
                    try tb.insert(startTag)
                    tb.framesetOk(false)
                    tb.transition(.InBody)
                } else if startTag.normalNameEquals(UTF8Arrays.frameset) {
                    try tb.insert(startTag)
                    tb.transition(.InFrameset)
                } else if TagSets.baseEtc3.containsCaseInsensitive(startTag) {
                    tb.error(self)
                    let head: Element = tb.getHeadElement()!
                    tb.push(head)
                    try tb.process(t, .InHead)
                    tb.removeFromStack(head)
                } else if startTag.normalNameEquals(UTF8Arrays.head) {
                    tb.error(self)
                    return false
                } else {
                    try anythingElse(t, tb)
                }
            } else if (t.isEndTag()) {
                if TagSets.outer3.containsCaseInsensitive(t.asEndTag()) {
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
                for node in stack.reversed() {
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
                if startTag.normalNameEquals(UTF8Arrays.a) {
                        if (tb.getActiveFormattingElement(UTF8Arrays.a) != nil) {
                            tb.error(self)
                            try tb.processEndTag(UTF8Arrays.a)

                            // still on stack?
                            let remainingA: Element? = tb.getFromStack(UTF8Arrays.a)
                            if (remainingA != nil) {
                                tb.removeFromActiveFormattingElements(remainingA)
                                tb.removeFromStack(remainingA!)
                            }
                        }
                        try tb.reconstructFormattingElements()
                        let a = try tb.insert(startTag)
                        tb.pushActiveFormattingElements(a)
                    } else if (Constants.InBodyStartEmptyFormatters.containsCaseInsensitive(startTag)) {
                        try tb.reconstructFormattingElements()
                        try tb.insertEmpty(startTag)
                        tb.framesetOk(false)
                    } else if Constants.InBodyStartPClosers.containsCaseInsensitive(startTag) {
                        if (try tb.inButtonScope(UTF8Arrays.p)) {
                            try tb.processEndTag(UTF8Arrays.p)
                        }
                        try tb.insert(startTag)
                    } else if startTag.normalNameEquals(UTF8Arrays.span) {
                        // same as final else, but short circuits lots of checks
                        try tb.reconstructFormattingElements()
                        try tb.insert(startTag)
                    } else if startTag.normalNameEquals(UTF8Arrays.li) {
                        tb.framesetOk(false)
                        let stack: Array<Element> = tb.getStack()
                        for el in stack.reversed() {
                            if el.nodeNameUTF8() == UTF8Arrays.li {
                                try tb.processEndTag(UTF8Arrays.li)
                                break
                            }
                            if (tb.isSpecial(el) && !Constants.InBodyStartLiBreakers.contains(el.nodeNameUTF8())) {
                                break
                            }
                        }
                        if (try tb.inButtonScope(UTF8Arrays.p)) {
                            try tb.processEndTag(UTF8Arrays.p)
                        }
                        try tb.insert(startTag)
                    } else if startTag.normalNameEquals(UTF8Arrays.html) {
                        tb.error(self)
                        // merge attributes onto real html
                        let html: Element = tb.getStack()[0]
                        for attribute in startTag.getAttributes() {
                            if (!html.hasAttr(attribute.getKey())) {
                                html.getAttributes()?.put(attribute: attribute)
                            }
                        }
                    } else if Constants.InBodyStartToHead.containsCaseInsensitive(startTag) {
                        return try tb.process(t, .InHead)
                    } else if startTag.normalNameEquals(UTF8Arrays.body) {
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
                    } else if startTag.normalNameEquals(UTF8Arrays.frameset) {
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
                                stack.removeLast()
                            }
                            try tb.insert(startTag)
                            tb.transition(.InFrameset)
                        }
                    } else if Constants.Headings.containsCaseInsensitive(startTag) {
                        if (try tb.inButtonScope(UTF8Arrays.p)) {
                            try tb.processEndTag(UTF8Arrays.p)
                        }
                        if (tb.currentElement() != nil && Constants.Headings.contains(tb.currentElement()!.nodeNameUTF8())) {
                            tb.error(self)
                            tb.pop()
                        }
                        try tb.insert(startTag)
                    } else if Constants.InBodyStartPreListing.containsCaseInsensitive(startTag) {
                        if (try tb.inButtonScope(UTF8Arrays.p)) {
                            try tb.processEndTag(UTF8Arrays.p)
                        }
                        try tb.insert(startTag)
                        // todo: ignore LF if next token
                        tb.framesetOk(false)
                    } else if startTag.normalNameEquals(UTF8Arrays.form) {
                        if (tb.getFormElement() != nil) {
                            tb.error(self)
                            return false
                        }
                        if (try tb.inButtonScope(UTF8Arrays.p)) {
                            try tb.processEndTag(UTF8Arrays.p)
                        }
                        try tb.insertForm(startTag, true)
                    } else if Constants.DdDt.containsCaseInsensitive(startTag) {
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
                        if (try tb.inButtonScope(UTF8Arrays.p)) {
                            try tb.processEndTag(UTF8Arrays.p)
                        }
                        try tb.insert(startTag)
                    } else if startTag.normalNameEquals(UTF8Arrays.plaintext) {
                        if (try tb.inButtonScope(UTF8Arrays.p)) {
                            try tb.processEndTag(UTF8Arrays.p)
                        }
                        try tb.insert(startTag)
                        tb.tokeniser.transition(TokeniserState.PLAINTEXT) // once in, never gets out
                    } else if startTag.normalNameEquals(UTF8Arrays.button) {
                        if try tb.inButtonScope(UTF8Arrays.button) {
                            // close and reprocess
                            tb.error(self)
                            try tb.processEndTag(UTF8Arrays.button)
                            try tb.process(startTag)
                        } else {
                            try tb.reconstructFormattingElements()
                            try tb.insert(startTag)
                            tb.framesetOk(false)
                        }
                    } else if Constants.Formatters.containsCaseInsensitive(startTag) {
                        try tb.reconstructFormattingElements()
                        let el: Element = try tb.insert(startTag)
                        tb.pushActiveFormattingElements(el)
                    } else if startTag.normalNameEquals(UTF8Arrays.nobr) {
                        try tb.reconstructFormattingElements()
                        if try tb.inScope(UTF8Arrays.nobr) {
                            tb.error(self)
                            try tb.processEndTag(UTF8Arrays.nobr)
                            try tb.reconstructFormattingElements()
                        }
                        let el: Element = try tb.insert(startTag)
                        tb.pushActiveFormattingElements(el)
                    } else if Constants.InBodyStartApplets.containsCaseInsensitive(startTag) {
                        try tb.reconstructFormattingElements()
                        try tb.insert(startTag)
                        tb.insertMarkerToFormattingElements()
                        tb.framesetOk(false)
                    } else if startTag.normalNameEquals(UTF8Arrays.table) {
                        if try tb.getDocument().quirksMode() != Document.QuirksMode.quirks && tb.inButtonScope(UTF8Arrays.p) {
                            try tb.processEndTag(UTF8Arrays.p)
                        }
                        try tb.insert(startTag)
                        tb.framesetOk(false)
                        tb.transition(.InTable)
                    } else if startTag.normalNameEquals(UTF8Arrays.input) {
                        try tb.reconstructFormattingElements()
                        let el: Element = try tb.insertEmpty(startTag)
                        if (try !el.attr("type").equalsIgnoreCase(string: "hidden")) {
                            tb.framesetOk(false)
                        }
                    } else if Constants.InBodyStartMedia.containsCaseInsensitive(startTag) {
                        try tb.insertEmpty(startTag)
                    } else if startTag.normalNameEquals(UTF8Arrays.hr) {
                        if try tb.inButtonScope(UTF8Arrays.p) {
                            try tb.processEndTag(UTF8Arrays.p)
                        }
                        try tb.insertEmpty(startTag)
                        tb.framesetOk(false)
                    } else if startTag.normalNameEquals(UTF8Arrays.image) {
                        if tb.getFromStack(UTF8Arrays.svg) == nil {
                            return try tb.process(startTag.name(UTF8Arrays.img)) // change <image> to <img>, unless in svg
                        } else {
                            try tb.insert(startTag)
                        }
                    } else if startTag.normalNameEquals(UTF8Arrays.isindex) {
                        // how much do we care about the early 90s?
                        tb.error(self)
                        if (tb.getFormElement() != nil) {
                            return false
                        }

                        tb.tokeniser.acknowledgeSelfClosingFlag()
                        try tb.processStartTag(UTF8Arrays.form)
                        startTag.ensureAttributes()
                        if startTag._attributes?.hasKey(key: UTF8Arrays.action) ?? false {
                            if let form: Element = tb.getFormElement() {
                                try form.attr(UTF8Arrays.action, startTag._attributes?.get(key: UTF8Arrays.action) ?? [])
                            }
                        }
                        try tb.processStartTag(UTF8Arrays.hr)
                        try tb.processStartTag(UTF8Arrays.label)
                        // hope you like english.
                        let prompt: [UInt8] = (startTag._attributes?.hasKey(key: UTF8Arrays.prompt) ?? false) ?
                        startTag._attributes?.get(key: UTF8Arrays.prompt) ?? [] :
                        "self is a searchable index. Enter search keywords: ".utf8Array

                        try tb.process(Token.Char().data(prompt))

                        // input
                        let inputAttribs: Attributes = Attributes()
                        if let attributes = startTag._attributes {
                            for attr: Attribute in attributes {
                                if (!Constants.InBodyStartInputAttribs.contains(attr.getKeyUTF8())) {
                                    inputAttribs.put(attribute: attr)
                                }
                            }
                        }
                        try inputAttribs.put(UTF8Arrays.name, UTF8Arrays.isindex)
                        try tb.processStartTag(UTF8Arrays.input, inputAttribs)
                        try tb.processEndTag(UTF8Arrays.label)
                        try tb.processStartTag(UTF8Arrays.hr)
                        try tb.processEndTag(UTF8Arrays.form)
                    } else if startTag.normalNameEquals(UTF8Arrays.textarea) {
                        try tb.insert(startTag)
                        // todo: If the next token is a U+000A LINE FEED (LF) character token, then ignore that token and move on to the next one. (Newlines at the start of textarea elements are ignored as an authoring convenience.)
                        tb.tokeniser.transition(TokeniserState.Rcdata)
                        tb.markInsertionMode()
                        tb.framesetOk(false)
                        tb.transition(.Text)
                    } else if startTag.normalNameEquals(UTF8Arrays.xmp) {
                        if try tb.inButtonScope(UTF8Arrays.p) {
                            try tb.processEndTag(UTF8Arrays.p)
                        }
                        try tb.reconstructFormattingElements()
                        tb.framesetOk(false)
                        try HtmlTreeBuilderState.handleRawtext(startTag, tb)
                    } else if startTag.normalNameEquals(UTF8Arrays.iframe) {
                        tb.framesetOk(false)
                        try HtmlTreeBuilderState.handleRawtext(startTag, tb)
                    } else if startTag.normalNameEquals(UTF8Arrays.noembed) {
                        // also handle noscript if script enabled
                        try HtmlTreeBuilderState.handleRawtext(startTag, tb)
                    } else if startTag.normalNameEquals(UTF8Arrays.select) {
                        try tb.reconstructFormattingElements()
                        try tb.insert(startTag)
                        tb.framesetOk(false)

                        let state: HtmlTreeBuilderState = tb.state()
                        if (state.equals(.InTable) || state.equals(.InCaption) || state.equals(.InTableBody) || state.equals(.InRow) || state.equals(.InCell)) {
                            tb.transition(.InSelectInTable)
                        } else {
                            tb.transition(.InSelect)
                        }
                    } else if Constants.InBodyStartOptions.containsCaseInsensitive(startTag) {
                        if tb.currentElement() != nil && tb.currentElement()!.nodeNameUTF8() == UTF8Arrays.option {
                            try tb.processEndTag(UTF8Arrays.option)
                        }
                        try tb.reconstructFormattingElements()
                        try tb.insert(startTag)
                    } else if Constants.InBodyStartRuby.containsCaseInsensitive(startTag) {
                        if (try tb.inScope(UTF8Arrays.ruby)) {
                            tb.generateImpliedEndTags()
                            if tb.currentElement() != nil && !(tb.currentElement()!.nodeNameUTF8() == UTF8Arrays.ruby) {
                                tb.error(self)
                                tb.popStackToBefore(UTF8Arrays.ruby) // i.e. close up to but not include name
                            }
                            try tb.insert(startTag)
                        }
                    } else if startTag.normalNameEquals(UTF8Arrays.math) {
                        try tb.reconstructFormattingElements()
                        // todo: handle A start tag whose tag name is "math" (i.e. foreign, mathml)
                        try tb.insert(startTag)
                        tb.tokeniser.acknowledgeSelfClosingFlag()
                    } else if startTag.normalNameEquals(UTF8Arrays.svg) {
                        try tb.reconstructFormattingElements()
                        // todo: handle A start tag whose tag name is "svg" (xlink, svg)
                        try tb.insert(startTag)
                        tb.tokeniser.acknowledgeSelfClosingFlag()
                    } else if Constants.InBodyStartDrop.containsCaseInsensitive(startTag) {
                        tb.error(self)
                        return false
                    } else {
                        // Fallback path (includes previously the "name == nil" case): always reconstruct and insert.
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
                                replacement.treeBuilder = tb
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
                            adopter.treeBuilder = tb
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
                    } else if name == UTF8Arrays.span {
                        // same as final fall through, but saves short circuit
                        return anyOtherEndTag(t, tb)
                    } else if name == UTF8Arrays.li {
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
                    } else if name == UTF8Arrays.body {
                        if try !tb.inScope(UTF8Arrays.body) {
                            tb.error(self)
                            return false
                        } else {
                            // todo: error if stack contains something not dd, dt, li, optgroup, option, p, rp, rt, tbody, td, tfoot, th, thead, tr, body, html
                            tb.transition(.AfterBody)
                        }
                    } else if name == UTF8Arrays.html {
                        let notIgnored: Bool = try tb.processEndTag(UTF8Arrays.body)
                        if (notIgnored) {
                            return try tb.process(endTag)
                        }
                    } else if name == UTF8Arrays.form {
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
                    } else if name == UTF8Arrays.p {
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
                    } else if name == UTF8Arrays.sarcasm {
                        // *sigh*
                        return anyOtherEndTag(t, tb)
                    } else if Constants.InBodyStartApplets.contains(name) {
                        if (try !tb.inScope(UTF8Arrays.name)) {
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
                    } else if name == UTF8Arrays.br {
                        tb.error(self)
                        try tb.processStartTag(UTF8Arrays.br)
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
                    if name == UTF8Arrays.caption {
                        tb.clearStackToTableContext()
                        tb.insertMarkerToFormattingElements()
                        try tb.insert(startTag)
                        tb.transition(.InCaption)
                    } else if name == UTF8Arrays.colgroup {
                        tb.clearStackToTableContext()
                        try tb.insert(startTag)
                        tb.transition(.InColumnGroup)
                    } else if name == UTF8Arrays.col {
                        try tb.processStartTag(UTF8Arrays.colgroup)
                        return try tb.process(t)
                    } else if TagSets.tableSections.contains(name) {
                        tb.clearStackToTableContext()
                        try tb.insert(startTag)
                        tb.transition(.InTableBody)
                    } else if [UTF8Arrays.td, UTF8Arrays.th, UTF8Arrays.tr].contains(name) {
                        try tb.processStartTag(UTF8Arrays.tbody)
                        return try tb.process(t)
                    } else if name == UTF8Arrays.table {
                        tb.error(self)
                        let processed: Bool = try tb.processEndTag(UTF8Arrays.table)
                        if (processed) // only ignored if in fragment
                        {return try tb.process(t)}
                    } else if name == UTF8Arrays.style || name == UTF8Arrays.script {
                        return try tb.process(t, .InHead)
                    } else if name == UTF8Arrays.input {
                        startTag.ensureAttributes()
                        if !(startTag._attributes?.get(key: UTF8Arrays.type).equalsIgnoreCase(string: UTF8Arrays.hidden) ?? false) {
                            return try anythingElse(t, tb)
                        } else {
                            try tb.insertEmpty(startTag)
                        }
                    } else if name == UTF8Arrays.form {
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
                    if name == UTF8Arrays.table {
                        if (try !tb.inTableScope(name)) {
                            tb.error(self)
                            return false
                        } else {
                            tb.popStackToClose(UTF8Arrays.table)
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
                if tb.currentElement() != nil && tb.currentElement()!.nodeNameUTF8() == UTF8Arrays.html {
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
                if (!tb.getPendingTableCharacters().isEmpty) {
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
            if t.endTagNormalNameEquals(UTF8Arrays.caption) {
                let endTag: Token.EndTag = t.asEndTag()
                let name = endTag.normalName()
                if (try name != nil && !tb.inTableScope(name!)) {
                    tb.error(self)
                    return false
                } else {
                    tb.generateImpliedEndTags()
                    if tb.currentElement()!.nodeNameUTF8() != UTF8Arrays.caption {
                        tb.error(self)
                    }
                    tb.popStackToClose(UTF8Arrays.caption)
                    tb.clearFormattingElementsToLastMarker()
                    tb.transition(.InTable)
                }
            } else if (t.isStartTag() && TagSets.tableRowsAndCols.containsCaseInsensitive(t.asStartTag())) ||
                        (t.isEndTag() && t.endTagNormalNameEquals(UTF8Arrays.table))
            {
                // Note: original code relies on && precedence being higher than ||
                //
                // if ((t.isStartTag() && StringUtil.inString(t.asStartTag().normalName()!,
                //    haystack: "caption", "col", "colgroup", "tbody", "td", "tfoot", "th", "thead", "tr") ||
                //    t.isEndTag() && t.asEndTag().normalName()!.equals("table"))) {

                tb.error(self)
                let processed: Bool = try tb.processEndTag(UTF8Arrays.caption)
                if (processed) {
                    return try tb.process(t)
                }
            } else if t.endTagNormalNameIn(TagSets.tableMix2) {
                tb.error(self)
                return false
            } else {
                return try tb.process(t, .InBody)
            }
            return true
        case .InColumnGroup:
            func anythingElse(_ t: Token, _ tb: TreeBuilder)throws->Bool {
                let processed: Bool = try tb.processEndTag(UTF8Arrays.colgroup)
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
                if UTF8Arrays.html == name {
                    return try tb.process(t, .InBody)
                } else if UTF8Arrays.col == name {
                    try tb.insertEmpty(startTag)
                } else {
                    return try anythingElse(t, tb)
                }
                break
            case .EndTag:
                let endTag: Token.EndTag = t.asEndTag()
                let name = endTag.normalName()
                if UTF8Arrays.colgroup == name {
                    if UTF8Arrays.html == tb.currentElement()?.nodeNameUTF8() { // frag case
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
                if UTF8Arrays.html == tb.currentElement()?.nodeNameUTF8() {
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
                if (try !(tb.inTableScope(UTF8Arrays.tbody) || tb.inTableScope(UTF8Arrays.thead) || tb.inScope(UTF8Arrays.tfoot))) {
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
                if UTF8Arrays.tr == name {
                    tb.clearStackToTableBodyContext()
                    try tb.insert(startTag)
                    tb.transition(.InRow)
                } else if let name = name, TagSets.thTd.contains(name) {
                    tb.error(self)
                    try tb.processStartTag(UTF8Arrays.tr)
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
                } else if UTF8Arrays.table == name {
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
                let processed: Bool = try tb.processEndTag(UTF8Arrays.tr)
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

                if UTF8Arrays.tr == name {
                    if (try !tb.inTableScope(name!)) {
                        tb.error(self) // frag
                        return false
                    }
                    tb.clearStackToTableRowContext()
                    tb.pop() // tr
                    tb.transition(.InTableBody)
                } else if UTF8Arrays.table == name {
                    return try handleMissingTr(t, tb)
                } else if let name, TagSets.tableSections.contains(name) {
                    if (try !tb.inTableScope(name)) {
                        tb.error(self)
                        return false
                    }
                    try tb.processEndTag(UTF8Arrays.tr)
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
                if (try tb.inTableScope(UTF8Arrays.td)) {
                    try tb.processEndTag(UTF8Arrays.td)
                } else {
                    try tb.processEndTag(UTF8Arrays.th) // only here if th or td in scope
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
            } else if t.startTagNormalNameIn(TagSets.tableRowsAndCols) {
                if (try !(tb.inTableScope(UTF8Arrays.td) || tb.inTableScope(UTF8Arrays.th))) {
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
                if name == UTF8Arrays.html {
                    return try tb.process(start, .InBody)
                } else if name == UTF8Arrays.option {
                    try tb.processEndTag(UTF8Arrays.option)
                    try tb.insert(start)
                } else if name == UTF8Arrays.optgroup {
                    if tb.currentElement()?.nodeNameUTF8() == UTF8Arrays.option {
                        try tb.processEndTag(UTF8Arrays.option)
                    } else if tb.currentElement()?.nodeNameUTF8() == UTF8Arrays.optgroup {
                        try tb.processEndTag(UTF8Arrays.optgroup)
                    }
                    try tb.insert(start)
                } else if name == UTF8Arrays.select {
                    tb.error(self)
                    return try tb.processEndTag(UTF8Arrays.select)
                } else if let name = name, TagSets.inputKeygenTextarea.contains(name) {
                    tb.error(self)
                    if (try !tb.inSelectScope(UTF8Arrays.select)) {
                        return false // frag
                    }
                    try tb.processEndTag(UTF8Arrays.select)
                    return try tb.process(start)
                } else if name == UTF8Arrays.script {
                    return try tb.process(t, .InHead)
                } else {
                    return anythingElse(t, tb)
                }
                break
            case .EndTag:
                let end: Token.EndTag = t.asEndTag()
                let name = end.normalName()
                if name == UTF8Arrays.optgroup {
                    if tb.currentElement()?.nodeNameUTF8() == UTF8Arrays.option && tb.currentElement() != nil && tb.aboveOnStack(tb.currentElement()!) != nil && tb.aboveOnStack(tb.currentElement()!)?.nodeNameUTF8() == UTF8Arrays.optgroup {
                        try tb.processEndTag(UTF8Arrays.option)
                    }
                    if tb.currentElement()?.nodeNameUTF8() == UTF8Arrays.optgroup {
                        tb.pop()
                    } else {
                        tb.error(self)
                    }
                } else if name == UTF8Arrays.option {
                    if tb.currentElement()?.nodeNameUTF8() == UTF8Arrays.option {
                        tb.pop()
                    } else {
                        tb.error(self)
                    }
                } else if name == UTF8Arrays.select {
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
            if t.startTagNormalNameIn(TagSets.tableMix8) {
                tb.error(self)
                try tb.processEndTag(UTF8Arrays.select)
                return try tb.process(t)
            } else if t.endTagNormalNameIn(TagSets.tableMix8) {
                tb.error(self)
                if try tb.inTableScope(t.asEndTag().normalName()!) {
                    try tb.processEndTag(UTF8Arrays.select)
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
            } else if t.startTagNormalNameEquals(UTF8Arrays.html) {
                return try tb.process(t, .InBody)
            } else if t.endTagNormalNameEquals(UTF8Arrays.html) {
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
                    if start.normalNameEquals(UTF8Arrays.html) {
                        return try tb.process(start, .InBody)
                    } else if start.normalNameEquals(UTF8Arrays.frameset) {
                        try tb.insert(start)
                    } else if start.normalNameEquals(UTF8Arrays.frame) {
                        try tb.insertEmpty(start)
                    } else if start.normalNameEquals(UTF8Arrays.noframes) {
                        return try tb.process(start, .InHead)
                    } else {
                        tb.error(self)
                        return false
                    }
                } else if t.endTagNormalNameEquals(UTF8Arrays.frameset) {
                    if tb.currentElement()?.nodeNameUTF8() == UTF8Arrays.html { // frag
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
                } else if t.startTagNormalNameEquals(UTF8Arrays.html) {
                    return try tb.process(t, .InBody)
                } else if t.endTagNormalNameEquals(UTF8Arrays.html) {
                    tb.transition(.AfterAfterFrameset)
                } else if t.startTagNormalNameEquals(UTF8Arrays.noframes) {
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
                } else if (t.isDoctype() || HtmlTreeBuilderState.isWhitespace(t) || (t.isStartTag() && t.asStartTag().normalNameEquals(UTF8Arrays.html))) {
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
                } else if (t.isDoctype() || HtmlTreeBuilderState.isWhitespace(t) || (t.startTagNormalNameEquals(UTF8Arrays.html))) {
                    return try tb.process(t, .InBody)
                } else if (t.isEOF()) {
                    // nice work chuck
                } else if t.startTagNormalNameEquals(UTF8Arrays.noframes) {
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

    private static func handleRcData(_ startTag: Token.StartTag, _ tb: HtmlTreeBuilder) throws {
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
        fileprivate static let InBodyStartToHead = ParsingStrings(["base", "basefont", "bgsound", "command", "link", "meta", "noframes", "script", "style", "title"])
        fileprivate static let InBodyStartPClosers = ParsingStrings(["address", "article", "aside", "blockquote", "center", "details", "dir", "div", "dl",
                                                                "fieldset", "figcaption", "figure", "footer", "header", "hgroup", "menu", "nav", "ol",
                                                                "p", "section", "summary", "ul"])
        fileprivate static let Headings = ParsingStrings(["h1", "h2", "h3", "h4", "h5", "h6"])
        fileprivate static let InBodyStartPreListing = ParsingStrings(["pre", "listing"])
        fileprivate static let InBodyStartLiBreakers = ParsingStrings(["address", "div", "p"])
        fileprivate static let DdDt = ParsingStrings(["dd", "dt"])
        fileprivate static let Formatters = ParsingStrings(["b", "big", "code", "em", "font", "i", "s", "small", "strike", "strong", "tt", "u"])
        fileprivate static let InBodyStartApplets = ParsingStrings(["applet", "marquee", "object"])
        fileprivate static let InBodyStartEmptyFormatters = ParsingStrings(["area", "br", "embed", "img", "keygen", "wbr"])
        fileprivate static let InBodyStartMedia = ParsingStrings(["param", "source", "track"])
        fileprivate static let InBodyStartInputAttribs = ParsingStrings(["name", "action", "prompt"])
        fileprivate static let InBodyStartOptions = ParsingStrings(["optgroup", "option"])
        fileprivate static let InBodyStartRuby = ParsingStrings(["rp", "rt"])
        fileprivate static let InBodyStartDrop = ParsingStrings(["caption", "col", "colgroup", "frame", "head", "tbody", "td", "tfoot", "th", "thead", "tr"])
        fileprivate static let InBodyEndClosers = ParsingStrings(["address", "article", "aside", "blockquote", "button", "center", "details", "dir", "div",
                                                             "dl", "fieldset", "figcaption", "figure", "footer", "header", "hgroup", "listing", "menu",
                                                             "nav", "ol", "pre", "section", "summary", "ul"])
        fileprivate static let InBodyEndAdoptionFormatters = ParsingStrings(["a", "b", "big", "code", "em", "font", "i", "nobr", "s", "small", "strike", "strong", "tt", "u"])
        fileprivate static let InBodyEndTableFosters = ParsingStrings(["table", "tbody", "tfoot", "thead", "tr"])
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

    @inline(__always)
    func startTagNormalNameEquals(_ lower: [UInt8]) -> Bool {
        guard isStartTag() else { return false }
        return asStartTag().normalNameEquals(lower)
    }

    @inline(__always)
    func endTagNormalNameEquals(_ lower: [UInt8]) -> Bool {
        guard isEndTag() else { return false }
        return asEndTag().normalNameEquals(lower)
    }

    @inline(__always)
    func startTagNormalNameIn(_ set: ParsingStrings) -> Bool {
        guard isStartTag() else { return false }
        return set.containsCaseInsensitive(asStartTag())
    }

    @inline(__always)
    func endTagNormalNameIn(_ set: ParsingStrings) -> Bool {
        guard isEndTag() else { return false }
        return set.containsCaseInsensitive(asEndTag())
    }
    
}

fileprivate extension ParsingStrings {
    @inline(__always)
    func containsCaseInsensitive(_ tag: Token.Tag) -> Bool {
        guard let name = tag.tagNameSlice(), !name.isEmpty else { return false }
        let nameCount = name.count
        for candidate in multiByteSet {
            if candidate.count != nameCount {
                continue
            }
            if tag.normalNameEquals(candidate) {
                return true
            }
        }
        return false
    }
}
