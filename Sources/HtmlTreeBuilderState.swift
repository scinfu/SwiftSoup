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
    private static let useSelectTagIdFastPath: Bool =
        ProcessInfo.processInfo.environment["SWIFTSOUP_DISABLE_SELECT_TAGID_FASTPATH"] != "1"
    private static let whitespaceTable: [Bool] = {
        var table = [Bool](repeating: false, count: 256)
        table[Int(TokeniserStateVars.tabByte)] = true
        table[Int(TokeniserStateVars.newLineByte)] = true
        table[Int(TokeniserStateVars.formFeedByte)] = true
        table[Int(TokeniserStateVars.carriageReturnByte)] = true
        table[Int(TokeniserStateVars.spaceByte)] = true
        return table
    }()

    public func equals(_ s: HtmlTreeBuilderState) -> Bool {
        return self.hashValue == s.hashValue
    }

    func process(_ t: Token, _ tb: HtmlTreeBuilder) throws -> Bool {
        #if PROFILE
        let _p = Profiler.startDynamic("HtmlTreeBuilderState.\(self)")
        defer { Profiler.endDynamic("HtmlTreeBuilderState.\(self)", _p) }
        #endif
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
                    tb.settings.normalizeTag(d.getName()),
                    d.getPubSysKey(),
                    d.getPublicIdentifier(),
                    d.getSystemIdentifier(),
                    tb.getBaseUri()
                )
                    //tb.settings.normalizeTag(d.getName()), d.getPublicIdentifier(), d.getSystemIdentifier(), tb.getBaseUri())
                if let range = d.sourceRange {
                    doctype.setSourceRange(range, complete: true)
                }
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
            @inline(__always)
            func equalsSlice(_ array: [UInt8], _ slice: ArraySlice<UInt8>) -> Bool {
                if array.count != slice.count {
                    return false
                }
                var i = array.startIndex
                var j = slice.startIndex
                let end = array.endIndex
                while i < end {
                    if array[i] != slice[j] {
                        return false
                    }
                    i = array.index(after: i)
                    j = slice.index(after: j)
                }
                return true
            }

            func anyOtherEndTag(_ t: Token, _ tb: HtmlTreeBuilder) -> Bool {
                let endTag = t.asEndTag()
                let useCurrentTagIdFastPath = Constants.useCurrentTagIdFastPath
                if let tagName = endTag.tagIdName() {
                    let tagId = endTag.tagId
                    if let current = tb.currentElement(), current._tag.tagId == tagId {
                        tb.generateImpliedEndTags(tagName)
                        if Constants.InBodyEndAdoptionFormatters.containsTagId(tagId) {
                            tb.removeFromActiveFormattingElements(current)
                        }
                        tb.popStackToClose(tagName)
                        return true
                    }
                    let stack: Array<Element> = Constants.useDirectStackAccess ? tb.stack : tb.getStack()
                    if Constants.useInBodyReverseStackIndexFastPath {
                        var i = stack.count
                        while i > 0 {
                            i -= 1
                            let node = stack[i]
                            if node._tag.tagId == tagId {
                                tb.generateImpliedEndTags(tagName)
                                if useCurrentTagIdFastPath {
                                    if let currentTagId = tb.currentElement()?._tag.tagId, currentTagId != tagId {
                                        tb.error(self)
                                    }
                                } else if let currentName = tb.currentElement()?.nodeNameUTF8(),
                                          !currentName.equals(tagName) {
                                    tb.error(self)
                                }
                                if Constants.InBodyEndAdoptionFormatters.containsTagId(tagId) {
                                    tb.removeFromActiveFormattingElements(node)
                                }
                                tb.popStackToClose(tagName)
                                break
                            } else if (tb.isSpecial(node)) {
                                tb.error(self)
                                return false
                            }
                        }
                    } else {
                        for node in stack.reversed() {
                            if node._tag.tagId == tagId {
                                tb.generateImpliedEndTags(tagName)
                                if useCurrentTagIdFastPath {
                                    if let currentTagId = tb.currentElement()?._tag.tagId, currentTagId != tagId {
                                        tb.error(self)
                                    }
                                } else if let currentName = tb.currentElement()?.nodeNameUTF8(),
                                          !currentName.equals(tagName) {
                                    tb.error(self)
                                }
                                if Constants.InBodyEndAdoptionFormatters.containsTagId(tagId) {
                                    tb.removeFromActiveFormattingElements(node)
                                }
                                tb.popStackToClose(tagName)
                                break
                            } else if (tb.isSpecial(node)) {
                                tb.error(self)
                                return false
                            }
                        }
                    }
                    return true
                }
                guard let nameSlice = endTag.normalNameSlice() else { return true }
                let tagId: Token.Tag.TagId?
                if Constants.useInBodyEndTagReuseTagIdFastPath, endTag.tagId != .none {
                    tagId = endTag.tagId
                } else {
                    tagId = Token.Tag.tagIdForSlice(nameSlice)
                }
                let tagName = tagId.flatMap { Token.Tag.tagIdName($0) }
                if let tagId, let tagName, let current = tb.currentElement(),
                   current._tag.tagId == tagId {
                    tb.generateImpliedEndTags(tagName)
                    if Constants.InBodyEndAdoptionFormatters.containsTagId(tagId) {
                        tb.removeFromActiveFormattingElements(current)
                    }
                    tb.popStackToClose(tagName)
                    return true
                }
                let stack: Array<Element> = Constants.useDirectStackAccess ? tb.stack : tb.getStack()
                if Constants.useInBodyReverseStackIndexFastPath {
                    var i = stack.count
                    while i > 0 {
                        i -= 1
                        let node = stack[i]
                        if let tagId, let tagName, node._tag.tagId == tagId {
                            tb.generateImpliedEndTags(tagName)
                            if useCurrentTagIdFastPath {
                                if let currentTagId = tb.currentElement()?._tag.tagId, currentTagId != tagId {
                                    tb.error(self)
                                }
                            } else if let currentName = tb.currentElement()?.nodeNameUTF8(),
                                      !equalsSlice(currentName, nameSlice) {
                                tb.error(self)
                            }
                            if Constants.InBodyEndAdoptionFormatters.containsTagId(tagId) {
                                tb.removeFromActiveFormattingElements(node)
                            }
                            tb.popStackToClose(tagName)
                            break
                        }
                        let nodeName = node.nodeNameUTF8()
                        if equalsSlice(nodeName, nameSlice) {
                            tb.generateImpliedEndTags(nodeName)
                            if useCurrentTagIdFastPath, let tagId {
                                if let currentTagId = tb.currentElement()?._tag.tagId, currentTagId != tagId {
                                    tb.error(self)
                                }
                            } else if let currentName = tb.currentElement()?.nodeNameUTF8(),
                                      !equalsSlice(currentName, nameSlice) {
                                tb.error(self)
                            }
                            if Constants.InBodyEndAdoptionFormatters.contains(nodeName) {
                                tb.removeFromActiveFormattingElements(node)
                            }
                            tb.popStackToClose(nodeName)
                            break
                        } else if (tb.isSpecial(node)) {
                            tb.error(self)
                            return false
                        }
                    }
                } else {
                    for node in stack.reversed() {
                        if let tagId, let tagName, node._tag.tagId == tagId {
                            tb.generateImpliedEndTags(tagName)
                            if useCurrentTagIdFastPath {
                                if let currentTagId = tb.currentElement()?._tag.tagId, currentTagId != tagId {
                                    tb.error(self)
                                }
                            } else if let currentName = tb.currentElement()?.nodeNameUTF8(),
                                      !equalsSlice(currentName, nameSlice) {
                                tb.error(self)
                            }
                            if Constants.InBodyEndAdoptionFormatters.containsTagId(tagId) {
                                tb.removeFromActiveFormattingElements(node)
                            }
                            tb.popStackToClose(tagName)
                            break
                        }
                        let nodeName = node.nodeNameUTF8()
                        if equalsSlice(nodeName, nameSlice) {
                            tb.generateImpliedEndTags(nodeName)
                            if useCurrentTagIdFastPath, let tagId {
                                if let currentTagId = tb.currentElement()?._tag.tagId, currentTagId != tagId {
                                    tb.error(self)
                                }
                            } else if let currentName = tb.currentElement()?.nodeNameUTF8(),
                                      !equalsSlice(currentName, nameSlice) {
                                tb.error(self)
                            }
                            if Constants.InBodyEndAdoptionFormatters.contains(nodeName) {
                                tb.removeFromActiveFormattingElements(node)
                            }
                            tb.popStackToClose(nodeName)
                            break
                        } else if (tb.isSpecial(node)) {
                            tb.error(self)
                            return false
                        }
                    }
                }
                return true
            }

            @inline(__always)
            func anyOtherEndTagFast(_ name: [UInt8], _ tb: HtmlTreeBuilder) -> Bool {
                let tagId = Token.Tag.tagIdForBytes(name)
                let useCurrentTagIdFastPath = Constants.useCurrentTagIdFastPath
                if let tagId, let current = tb.currentElement(), current._tag.tagId == tagId {
                    tb.generateImpliedEndTags(name)
                    if Constants.InBodyEndAdoptionFormatters.containsTagId(tagId) {
                        tb.removeFromActiveFormattingElements(current)
                    }
                    tb.popStackToClose(name)
                    return true
                }
                let stack: Array<Element> = Constants.useDirectStackAccess ? tb.stack : tb.getStack()
                if Constants.useInBodyReverseStackIndexFastPath {
                    var i = stack.count
                    while i > 0 {
                        i -= 1
                        let node = stack[i]
                        if let tagId {
                            if node._tag.tagId == tagId {
                                tb.generateImpliedEndTags(name)
                                if useCurrentTagIdFastPath {
                                    if let currentTagId = tb.currentElement()?._tag.tagId, currentTagId != tagId {
                                        tb.error(self)
                                    }
                                } else if let currentName = tb.currentElement()?.nodeNameUTF8(),
                                          !currentName.equals(name) {
                                    tb.error(self)
                                }
                                if Constants.InBodyEndAdoptionFormatters.containsTagId(tagId) {
                                    tb.removeFromActiveFormattingElements(node)
                                }
                                tb.popStackToClose(name)
                                break
                            }
                        } else if node.nodeNameUTF8().equals(name) {
                            tb.generateImpliedEndTags(name)
                            if let currentName = tb.currentElement()?.nodeNameUTF8(),
                               !currentName.equals(name) {
                                tb.error(self)
                            }
                            if Constants.InBodyEndAdoptionFormatters.contains(name) {
                                tb.removeFromActiveFormattingElements(node)
                            }
                            tb.popStackToClose(name)
                            break
                        }
                        if (tb.isSpecial(node)) {
                            tb.error(self)
                            return false
                        }
                    }
                } else {
                    for node in stack.reversed() {
                        if let tagId {
                            if node._tag.tagId == tagId {
                                tb.generateImpliedEndTags(name)
                                if useCurrentTagIdFastPath {
                                    if let currentTagId = tb.currentElement()?._tag.tagId, currentTagId != tagId {
                                        tb.error(self)
                                    }
                                } else if let currentName = tb.currentElement()?.nodeNameUTF8(),
                                          !currentName.equals(name) {
                                    tb.error(self)
                                }
                                if Constants.InBodyEndAdoptionFormatters.containsTagId(tagId) {
                                    tb.removeFromActiveFormattingElements(node)
                                }
                                tb.popStackToClose(name)
                                break
                            }
                        } else if node.nodeNameUTF8().equals(name) {
                            tb.generateImpliedEndTags(name)
                            if let currentName = tb.currentElement()?.nodeNameUTF8(),
                               !currentName.equals(name) {
                                tb.error(self)
                            }
                            if Constants.InBodyEndAdoptionFormatters.contains(name) {
                                tb.removeFromActiveFormattingElements(node)
                            }
                            tb.popStackToClose(name)
                            break
                        }
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
                let data = c.getDataSlice()
                if let data, data.count == 1, data.first == 0x00 {
                    // todo confirm that check
                    tb.error(self)
                    return false
                }
                let wasFramesetOk = tb.framesetOk()
                let isWhitespace = wasFramesetOk ? HtmlTreeBuilderState.isWhitespace(data) : false
                if tb.lastFormattingElement() != nil {
                    try tb.reconstructFormattingElements()
                }
                try tb.insert(c)
                if wasFramesetOk && !isWhitespace {
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
                let useCurrentTagIdFastPath = Constants.useCurrentTagIdFastPath
                let currentTagId = useCurrentTagIdFastPath ? tb.currentElement()?._tag.tagId : nil
                var hasFormatting = false
                var hasFormattingChecked = false
                @inline(__always)
                func ensureHasFormatting() -> Bool {
                    if !hasFormattingChecked {
                        hasFormatting = tb.lastFormattingElement() != nil
                        hasFormattingChecked = true
                    }
                    return hasFormatting
                }
                if startTag.tagId == .none {
                    _ = startTag.normalNameSlice()
                }
                switch startTag.tagId {
                case .a:
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
                    if ensureHasFormatting() {
                        try tb.reconstructFormattingElements()
                    }
                    let a = try tb.insert(startTag)
                    tb.pushActiveFormattingElements(a)
                case .span:
                    // same as final else, but short circuits lots of checks
                    if ensureHasFormatting() {
                        try tb.reconstructFormattingElements()
                    }
                    try tb.insert(startTag)
                case .p, .div:
                    if (try tb.inButtonScope(UTF8Arrays.p)) {

                        try tb.processEndTag(UTF8Arrays.p)

                    }
                    try tb.insert(startTag)
                case .li:
                    tb.framesetOk(false)
                    var didCloseLi = false
                    if Constants.useInBodyStackTopCloseFastPath,
                       let currentTagId, currentTagId == .li {
                        try tb.processEndTag(UTF8Arrays.li)
                        didCloseLi = true
                    }
                    if !didCloseLi {
                        let stack: Array<Element> = Constants.useDirectStackAccess ? tb.stack : tb.getStack()
                        let useStackTagIdFastPath = Constants.useInBodyStackTagIdFastPath
                        if Constants.useInBodyReverseStackIndexFastPath {
                            var i = stack.count
                            while i > 1 {
                                i -= 1
                                let el: Element = stack[i]
                                let tagId = el._tag.tagId
                                if useStackTagIdFastPath, tagId != .none {
                                    if tagId == .li {
                                        try tb.processEndTag(UTF8Arrays.li)
                                        break
                                    }
                                    if (tb.isSpecial(el) && !Constants.InBodyStartLiBreakers.containsTagId(tagId)) {
                                        break
                                    }
                                } else {
                                    if el.nodeNameUTF8().equals(UTF8Arrays.li) {
                                        try tb.processEndTag(UTF8Arrays.li)
                                        break
                                    }
                                    if (tb.isSpecial(el) && !Constants.InBodyStartLiBreakers.contains(el.nodeNameUTF8())) {
                                        break
                                    }
                                }
                            }
                        } else {
                            for i in (1..<stack.count).reversed() {
                                let el: Element = stack[i]
                                let tagId = el._tag.tagId
                                if useStackTagIdFastPath, tagId != .none {
                                    if tagId == .li {
                                        try tb.processEndTag(UTF8Arrays.li)
                                        break
                                    }
                                    if (tb.isSpecial(el) && !Constants.InBodyStartLiBreakers.containsTagId(tagId)) {
                                        break
                                    }
                                } else {
                                    if el.nodeNameUTF8().equals(UTF8Arrays.li) {
                                        try tb.processEndTag(UTF8Arrays.li)
                                        break
                                    }
                                    if (tb.isSpecial(el) && !Constants.InBodyStartLiBreakers.contains(el.nodeNameUTF8())) {
                                        break
                                    }
                                }
                            }
                        }
                    }
                    if (try tb.inButtonScope(UTF8Arrays.p)) {

                        try tb.processEndTag(UTF8Arrays.p)

                    }
                    try tb.insert(startTag)
                case .em, .strong, .b, .i, .small:
                    if ensureHasFormatting() {
                        try tb.reconstructFormattingElements()
                    }
                    let el: Element = try tb.insert(startTag)
                    tb.pushActiveFormattingElements(el)
                case .dd, .dt:
                    tb.framesetOk(false)
                    var didCloseDdDt = false
                    if Constants.useInBodyStackTopCloseFastPath,
                       let currentTagId,
                       currentTagId == .dd || currentTagId == .dt {
                        if currentTagId == .dd {
                            try tb.processEndTag(UTF8Arrays.dd)
                        } else {
                            try tb.processEndTag(UTF8Arrays.dt)
                        }
                        didCloseDdDt = true
                    }
                    if !didCloseDdDt {
                        let stack: Array<Element> = Constants.useDirectStackAccess ? tb.stack : tb.getStack()
                        let useStackTagIdFastPath = Constants.useInBodyStackTagIdFastPath
                        if Constants.useInBodyReverseStackIndexFastPath {
                            var i = stack.count
                            while i > 1 {
                                i -= 1
                                let el: Element = stack[i]
                                let tagId = el._tag.tagId
                                if useStackTagIdFastPath, tagId != .none {
                                    if tagId == .dd || tagId == .dt {
                                        try tb.processEndTag(el.nodeNameUTF8())
                                        break
                                    }
                                    if (tb.isSpecial(el) && !Constants.InBodyStartLiBreakers.containsTagId(tagId)) {
                                        break
                                    }
                                } else {
                                    if tagId == .dd || tagId == .dt || Constants.DdDt.contains(el.nodeNameUTF8()) {
                                        try tb.processEndTag(el.nodeNameUTF8())
                                        break
                                    }
                                    if (tb.isSpecial(el) && !Constants.InBodyStartLiBreakers.contains(el.nodeNameUTF8())) {
                                        break
                                    }
                                }
                            }
                        } else {
                            for i in (1..<stack.count).reversed() {
                                let el: Element = stack[i]
                                let tagId = el._tag.tagId
                                if useStackTagIdFastPath, tagId != .none {
                                    if tagId == .dd || tagId == .dt {
                                        try tb.processEndTag(el.nodeNameUTF8())
                                        break
                                    }
                                    if (tb.isSpecial(el) && !Constants.InBodyStartLiBreakers.containsTagId(tagId)) {
                                        break
                                    }
                                } else {
                                    if tagId == .dd || tagId == .dt || Constants.DdDt.contains(el.nodeNameUTF8()) {
                                        try tb.processEndTag(el.nodeNameUTF8())
                                        break
                                    }
                                    if (tb.isSpecial(el) && !Constants.InBodyStartLiBreakers.contains(el.nodeNameUTF8())) {
                                        break
                                    }
                                }
                            }
                        }
                    }
                    if (try tb.inButtonScope(UTF8Arrays.p)) {

                        try tb.processEndTag(UTF8Arrays.p)

                    }
                    try tb.insert(startTag)
                case .ol, .ul, .address, .article, .aside, .blockquote, .center, .dir, .fieldset, .figcaption,
                     .figure, .footer, .header, .hgroup, .menu, .nav, .section, .summary:
                    if (try tb.inButtonScope(UTF8Arrays.p)) {

                        try tb.processEndTag(UTF8Arrays.p)

                    }
                    try tb.insert(startTag)
                case .h1, .h2, .h3, .h4, .h5, .h6:
                    if (try tb.inButtonScope(UTF8Arrays.p)) {

                        try tb.processEndTag(UTF8Arrays.p)

                    }
                    if useCurrentTagIdFastPath {
                        if let currentTagId, Constants.Headings.containsTagId(currentTagId) {
                            tb.error(self)
                            tb.pop()
                        }
                    } else if (tb.currentElement() != nil && Constants.Headings.contains(tb.currentElement()!.nodeNameUTF8())) {
                        tb.error(self)
                        tb.pop()
                    }
                    try tb.insert(startTag)
                case .pre, .listing:
                    if (try tb.inButtonScope(UTF8Arrays.p)) {

                        try tb.processEndTag(UTF8Arrays.p)

                    }
                    try tb.insert(startTag)
                    // todo: ignore LF if next token
                    tb.framesetOk(false)
                case .applet, .marquee, .object:
                    if ensureHasFormatting() {
                        try tb.reconstructFormattingElements()
                    }
                    try tb.insert(startTag)
                    tb.insertMarkerToFormattingElements()
                    tb.framesetOk(false)
                case .embed:
                    try tb.insertEmpty(startTag)
                    tb.framesetOk(false)
                case .rp, .rt:
                    if (try tb.inScope(UTF8Arrays.ruby)) {
                        tb.generateImpliedEndTags()
                        if useCurrentTagIdFastPath {
                            if let currentTagId, currentTagId != .ruby {
                                tb.error(self)
                                tb.popStackToBefore(UTF8Arrays.ruby) // i.e. close up to but not include name
                            }
                        } else if tb.currentElement() != nil && !(tb.currentElement()!.nodeNameUTF8() == UTF8Arrays.ruby) {
                            tb.error(self)
                            tb.popStackToBefore(UTF8Arrays.ruby) // i.e. close up to but not include name
                        }
                        try tb.insert(startTag)
                    }
                case .table:
                    if (try tb.inButtonScope(UTF8Arrays.p)) {

                        try tb.processEndTag(UTF8Arrays.p)

                    }
                    try tb.insert(startTag)
                    tb.framesetOk(false)
                    tb.transition(.InTable)
                case .form:
                    if tb.getFormElement() != nil {
                        tb.error(self)
                        return false
                    }
                    if (try tb.inButtonScope(UTF8Arrays.p)) {

                        try tb.processEndTag(UTF8Arrays.p)

                    }
                    try tb.insertForm(startTag, false)
                    tb.framesetOk(false)
                case .html:
                    tb.error(self)
                    if startTag.hasAnyAttributes() {
                        startTag.ensureAttributes()
                        if let attrs = startTag._attributes,
                           let html = tb.getFromStack(UTF8Arrays.html) {
                            let htmlAttrs = html.getAttributes()!
                            for attr in attrs.asList() where !htmlAttrs.hasKeyIgnoreCase(key: attr.getKeyUTF8()) {
                                htmlAttrs.put(attribute: attr)
                            }
                        }
                    }
                case .body:
                    tb.error(self)
                    guard let body = tb.getFromStack(UTF8Arrays.body) else { return false }
                    if startTag.hasAnyAttributes() {
                        startTag.ensureAttributes()
                        if let attrs = startTag._attributes {
                            let bodyAttrs = body.getAttributes()!
                            for attr in attrs.asList() where !bodyAttrs.hasKeyIgnoreCase(key: attr.getKeyUTF8()) {
                                bodyAttrs.put(attribute: attr)
                            }
                        }
                    }
                case .br, .img:
                    if ensureHasFormatting() {
                        try tb.reconstructFormattingElements()
                    }
                    try tb.insertEmpty(startTag)
                    tb.framesetOk(false)
                case .hr:
                    if ensureHasFormatting() {
                        try tb.reconstructFormattingElements()
                    }
                    try tb.insertEmpty(startTag)
                    tb.framesetOk(false)
                case .meta, .script, .style, .title:
                    return try tb.process(t, .InHead)
                case .select:
                    if ensureHasFormatting() {
                        try tb.reconstructFormattingElements()
                    }
                    try tb.insert(startTag)
                    tb.framesetOk(false)
                    tb.transition(.InSelect)
                case .plaintext:
                    if ensureHasFormatting() {
                        try tb.reconstructFormattingElements()
                    }
                    try tb.insert(startTag)
                    tb.tokeniser.transition(.PLAINTEXT)
                case .option, .optgroup:
                    if useCurrentTagIdFastPath {
                        if let currentTagId, currentTagId == .option {
                            try tb.processEndTag(UTF8Arrays.option)
                        }
                    } else if tb.currentElement() != nil && tb.currentElement()!.nodeNameUTF8() == UTF8Arrays.option {
                        try tb.processEndTag(UTF8Arrays.option)
                    }
                    if ensureHasFormatting() {
                        try tb.reconstructFormattingElements()
                    }
                    try tb.insert(startTag)
                default:
                    @inline(__always)
                    func handleLiStart() throws {
                        tb.framesetOk(false)
                        let stack: Array<Element> = Constants.useDirectStackAccess ? tb.stack : tb.getStack()
                        let useStackTagIdFastPath = Constants.useInBodyStackTagIdFastPath
                        if Constants.useInBodyReverseStackIndexFastPath {
                            var i = stack.count
                            while i > 1 {
                                i -= 1
                                let el: Element = stack[i]
                                let tagId = el._tag.tagId
                                if useStackTagIdFastPath, tagId != .none {
                                    if tagId == .li {
                                        try tb.processEndTag(UTF8Arrays.li)
                                        break
                                    }
                                    if (tb.isSpecial(el) && !Constants.InBodyStartLiBreakers.containsTagId(tagId)) {
                                        break
                                    }
                                } else {
                                    if el.nodeNameUTF8().equals(UTF8Arrays.li) {
                                        try tb.processEndTag(UTF8Arrays.li)
                                        break
                                    }
                                    if (tb.isSpecial(el) && !Constants.InBodyStartLiBreakers.contains(el.nodeNameUTF8())) {
                                        break
                                    }
                                }
                            }
                        } else {
                            for i in (1..<stack.count).reversed() {
                                let el: Element = stack[i]
                                let tagId = el._tag.tagId
                                if useStackTagIdFastPath, tagId != .none {
                                    if tagId == .li {
                                        try tb.processEndTag(UTF8Arrays.li)
                                        break
                                    }
                                    if (tb.isSpecial(el) && !Constants.InBodyStartLiBreakers.containsTagId(tagId)) {
                                        break
                                    }
                                } else {
                                    if el.nodeNameUTF8().equals(UTF8Arrays.li) {
                                        try tb.processEndTag(UTF8Arrays.li)
                                        break
                                    }
                                    if (tb.isSpecial(el) && !Constants.InBodyStartLiBreakers.contains(el.nodeNameUTF8())) {
                                        break
                                    }
                                }
                            }
                        }
                        if (try tb.inButtonScope(UTF8Arrays.p)) {
                            try tb.processEndTag(UTF8Arrays.p)
                        }
                        try tb.insert(startTag)
                    }

                    @inline(__always)
                    func handleTagIdStart(_ tagId: Token.Tag.TagId) throws -> Bool? {
                        if Constants.useInBodyStartStructuralTagIdFastPath {
                            if tagId == .form {
                                if tb.getFormElement() != nil {
                                    tb.error(self)
                                    return false
                                }
                                if (try tb.inButtonScope(UTF8Arrays.p)) {
                                    try tb.processEndTag(UTF8Arrays.p)
                                }
                                try tb.insertForm(startTag, false)
                                tb.framesetOk(false)
                                return true
                            }
                            if tagId == .table {
                                if (try tb.inButtonScope(UTF8Arrays.p)) {
                                    try tb.processEndTag(UTF8Arrays.p)
                                }
                                try tb.insert(startTag)
                                tb.framesetOk(false)
                                tb.transition(.InTable)
                                return true
                            }
                            if tagId == .li {
                                try handleLiStart()
                                return true
                            }
                        }
                        if Constants.Formatters.containsTagId(tagId) {
                            if ensureHasFormatting() {
                                try tb.reconstructFormattingElements()
                            }
                            let el: Element = try tb.insert(startTag)
                            tb.pushActiveFormattingElements(el)
                            return true
                        }
                        if Constants.InBodyStartEmptyFormatters.containsTagId(tagId) {
                            if ensureHasFormatting() {
                                try tb.reconstructFormattingElements()
                            }
                            try tb.insertEmpty(startTag)
                            tb.framesetOk(false)
                            return true
                        }
                        if Constants.InBodyStartPClosers.containsTagId(tagId) {
                            if (try tb.inButtonScope(UTF8Arrays.p)) {

                                try tb.processEndTag(UTF8Arrays.p)

                            }
                            try tb.insert(startTag)
                            return true
                        }
                        if Constants.InBodyStartToHead.containsTagId(tagId) {
                            return try tb.process(t, .InHead)
                        }
                        if Constants.Headings.containsTagId(tagId) {
                            if (try tb.inButtonScope(UTF8Arrays.p)) {

                                try tb.processEndTag(UTF8Arrays.p)

                            }
                            if useCurrentTagIdFastPath {
                                if let currentTagId, Constants.Headings.containsTagId(currentTagId) {
                                    tb.error(self)
                                    tb.pop()
                                }
                            } else if (tb.currentElement() != nil && Constants.Headings.contains(tb.currentElement()!.nodeNameUTF8())) {
                                tb.error(self)
                                tb.pop()
                            }
                            try tb.insert(startTag)
                            return true
                        }
                        if Constants.InBodyStartPreListing.containsTagId(tagId) {
                            if (try tb.inButtonScope(UTF8Arrays.p)) {

                                try tb.processEndTag(UTF8Arrays.p)

                            }
                            try tb.insert(startTag)
                            // todo: ignore LF if next token
                            tb.framesetOk(false)
                            return true
                        }
                        if Constants.InBodyStartApplets.containsTagId(tagId) {
                            if ensureHasFormatting() {
                                try tb.reconstructFormattingElements()
                            }
                            try tb.insert(startTag)
                            tb.insertMarkerToFormattingElements()
                            tb.framesetOk(false)
                            return true
                        }
                        if Constants.InBodyStartMedia.containsTagId(tagId) {
                            try tb.insertEmpty(startTag)
                            return true
                        }
                        if Constants.InBodyStartOptions.containsTagId(tagId) {
                            if useCurrentTagIdFastPath {
                                if let currentTagId, currentTagId == .option {
                                    try tb.processEndTag(UTF8Arrays.option)
                                }
                            } else if tb.currentElement() != nil && tb.currentElement()!.nodeNameUTF8() == UTF8Arrays.option {
                                try tb.processEndTag(UTF8Arrays.option)
                            }
                            if ensureHasFormatting() {
                                try tb.reconstructFormattingElements()
                            }
                            try tb.insert(startTag)
                            return true
                        }
                        if Constants.InBodyStartRuby.containsTagId(tagId) {
                            if (try tb.inScope(UTF8Arrays.ruby)) {
                                tb.generateImpliedEndTags()
                                if useCurrentTagIdFastPath {
                                    if let currentTagId, currentTagId != .ruby {
                                        tb.error(self)
                                        tb.popStackToBefore(UTF8Arrays.ruby) // i.e. close up to but not include name
                                    }
                                } else if tb.currentElement() != nil && !(tb.currentElement()!.nodeNameUTF8() == UTF8Arrays.ruby) {
                                    tb.error(self)
                                    tb.popStackToBefore(UTF8Arrays.ruby) // i.e. close up to but not include name
                                }
                                try tb.insert(startTag)
                            }
                            return true
                        }
                        if Constants.InBodyStartDrop.containsTagId(tagId) {
                            tb.error(self)
                            return false
                        }
                        return nil
                    }

                    var nameSlice: ArraySlice<UInt8>? = nil
                    if Constants.useInBodyTagIdFastPath {
                        if startTag.tagId == .none {
                            nameSlice = startTag.normalNameSlice()
                        }
                        if startTag.tagId != .none, let handled = try handleTagIdStart(startTag.tagId) {
                            return handled
                        }
                    }
                    if nameSlice == nil {
                        nameSlice = startTag.normalNameSlice()
                    }
                    if let nameSlice = nameSlice {
                        if Constants.Formatters.contains(nameSlice) {
                            if ensureHasFormatting() {
                                try tb.reconstructFormattingElements()
                            }
                            let el: Element = try tb.insert(startTag)
                            tb.pushActiveFormattingElements(el)
                        } else if Constants.InBodyStartEmptyFormatters.contains(nameSlice) {
                            if ensureHasFormatting() {
                                try tb.reconstructFormattingElements()
                            }
                            try tb.insertEmpty(startTag)
                            tb.framesetOk(false)
                        } else if Constants.InBodyStartPClosers.contains(nameSlice) {
                            if (try tb.inButtonScope(UTF8Arrays.p)) {

                                try tb.processEndTag(UTF8Arrays.p)

                            }
                            try tb.insert(startTag)
                        } else if Constants.InBodyStartToHead.contains(nameSlice) {
                            return try tb.process(t, .InHead)
                        } else if equalsSlice(UTF8Arrays.form, nameSlice) {
                            if tb.getFormElement() != nil {
                                tb.error(self)
                                return false
                            }
                            if (try tb.inButtonScope(UTF8Arrays.p)) {

                                try tb.processEndTag(UTF8Arrays.p)

                            }
                            try tb.insertForm(startTag, false)
                            tb.framesetOk(false)
                        } else if equalsSlice(UTF8Arrays.table, nameSlice) {
                            if (try tb.inButtonScope(UTF8Arrays.p)) {

                                try tb.processEndTag(UTF8Arrays.p)

                            }
                            try tb.insert(startTag)
                            tb.framesetOk(false)
                            tb.transition(.InTable)
                        } else if Constants.Headings.contains(nameSlice) {
                            if (try tb.inButtonScope(UTF8Arrays.p)) {

                                try tb.processEndTag(UTF8Arrays.p)

                            }
                            if useCurrentTagIdFastPath {
                                if let currentTagId, Constants.Headings.containsTagId(currentTagId) {
                                    tb.error(self)
                                    tb.pop()
                                }
                            } else if (tb.currentElement() != nil && Constants.Headings.contains(tb.currentElement()!.nodeNameUTF8())) {
                                tb.error(self)
                                tb.pop()
                            }
                            try tb.insert(startTag)
                        } else if Constants.InBodyStartPreListing.contains(nameSlice) {
                            if (try tb.inButtonScope(UTF8Arrays.p)) {

                                try tb.processEndTag(UTF8Arrays.p)

                            }
                            try tb.insert(startTag)
                            // todo: ignore LF if next token
                            tb.framesetOk(false)
                        } else if equalsSlice(UTF8Arrays.li, nameSlice) {
                            try handleLiStart()
                        } else if Constants.DdDt.contains(nameSlice) {
                            tb.framesetOk(false)
                            let stack: Array<Element> = Constants.useDirectStackAccess ? tb.stack : tb.getStack()
                            let useStackTagIdFastPath = Constants.useInBodyStackTagIdFastPath
                            if Constants.useInBodyReverseStackIndexFastPath {
                                var i = stack.count
                                while i > 1 {
                                    i -= 1
                                    let el: Element = stack[i]
                                    let tagId = el._tag.tagId
                                    if useStackTagIdFastPath, tagId != .none {
                                        if tagId == .dd || tagId == .dt {
                                            try tb.processEndTag(el.nodeNameUTF8())
                                            break
                                        }
                                        if (tb.isSpecial(el) && !Constants.InBodyStartLiBreakers.containsTagId(tagId)) {
                                            break
                                        }
                                    } else {
                                        if Constants.DdDt.contains(el.nodeNameUTF8()) {
                                            try tb.processEndTag(el.nodeNameUTF8())
                                            break
                                        }
                                        if (tb.isSpecial(el) && !Constants.InBodyStartLiBreakers.contains(el.nodeNameUTF8())) {
                                            break
                                        }
                                    }
                                }
                            } else {
                                for i in (1..<stack.count).reversed() {
                                    let el: Element = stack[i]
                                    let tagId = el._tag.tagId
                                    if useStackTagIdFastPath, tagId != .none {
                                        if tagId == .dd || tagId == .dt {
                                            try tb.processEndTag(el.nodeNameUTF8())
                                            break
                                        }
                                        if (tb.isSpecial(el) && !Constants.InBodyStartLiBreakers.containsTagId(tagId)) {
                                            break
                                        }
                                    } else {
                                        if Constants.DdDt.contains(el.nodeNameUTF8()) {
                                            try tb.processEndTag(el.nodeNameUTF8())
                                            break
                                        }
                                        if (tb.isSpecial(el) && !Constants.InBodyStartLiBreakers.contains(el.nodeNameUTF8())) {
                                            break
                                        }
                                    }
                                }
                            }
                            if (try tb.inButtonScope(UTF8Arrays.p)) {

                                try tb.processEndTag(UTF8Arrays.p)

                            }
                            try tb.insert(startTag)
                        } else if Constants.InBodyStartApplets.contains(nameSlice) {
                            if ensureHasFormatting() {
                                try tb.reconstructFormattingElements()
                            }
                            try tb.insert(startTag)
                            tb.insertMarkerToFormattingElements()
                            tb.framesetOk(false)
                        } else if Constants.InBodyStartMedia.contains(nameSlice) {
                            try tb.insertEmpty(startTag)
                        } else if Constants.InBodyStartOptions.contains(nameSlice) {
                            if useCurrentTagIdFastPath {
                                if let currentTagId, currentTagId == .option {
                                    try tb.processEndTag(UTF8Arrays.option)
                                }
                            } else if tb.currentElement() != nil && tb.currentElement()!.nodeNameUTF8() == UTF8Arrays.option {
                                try tb.processEndTag(UTF8Arrays.option)
                            }
                            if ensureHasFormatting() {
                                try tb.reconstructFormattingElements()
                            }
                            try tb.insert(startTag)
                        } else if Constants.InBodyStartRuby.contains(nameSlice) {
                            if (try tb.inScope(UTF8Arrays.ruby)) {
                                tb.generateImpliedEndTags()
                                if useCurrentTagIdFastPath {
                                    if let currentTagId, currentTagId != .ruby {
                                        tb.error(self)
                                        tb.popStackToBefore(UTF8Arrays.ruby) // i.e. close up to but not include name
                                    }
                                } else if tb.currentElement() != nil && !(tb.currentElement()!.nodeNameUTF8() == UTF8Arrays.ruby) {
                                    tb.error(self)
                                    tb.popStackToBefore(UTF8Arrays.ruby) // i.e. close up to but not include name
                                }
                                try tb.insert(startTag)
                            }
                        } else if Constants.InBodyStartDrop.contains(nameSlice) {
                            tb.error(self)
                            return false
                        } else {
                            // Fallback path (includes previously the "name == nil" case): always reconstruct and insert.
                            if ensureHasFormatting() {
                                try tb.reconstructFormattingElements()
                            }
                            try tb.insert(startTag)
                        }
                    } else {
                        // Fallback path (includes previously the "name == nil" case): always reconstruct and insert.
                        if ensureHasFormatting() {
                            try tb.reconstructFormattingElements()
                        }
                        try tb.insert(startTag)
                    }
                }
                break

            case .EndTag:
                let endTag: Token.EndTag = t.asEndTag()
                let useCurrentTagIdFastPath = Constants.useCurrentTagIdFastPath
                let currentTagId = useCurrentTagIdFastPath ? tb.currentElement()?._tag.tagId : nil
                var adoptionName: [UInt8]? = nil
                switch endTag.tagId {
                case .a:
                    adoptionName = UTF8Arrays.a
                case .em:
                    adoptionName = UTF8Arrays.em
                case .strong:
                    adoptionName = UTF8Arrays.strong
                case .b:
                    adoptionName = UTF8Arrays.b
                case .i:
                    adoptionName = UTF8Arrays.i
                case .small:
                    adoptionName = UTF8Arrays.small
                default:
                    break
                }
                if adoptionName == nil,
                   let nameSlice = endTag.normalNameSlice(),
                   Constants.InBodyEndAdoptionFormatters.contains(nameSlice) {
                    if equalsSlice(UTF8Arrays.a, nameSlice) {
                        adoptionName = UTF8Arrays.a
                    } else if equalsSlice(UTF8Arrays.em, nameSlice) {
                        adoptionName = UTF8Arrays.em
                    } else if equalsSlice(UTF8Arrays.strong, nameSlice) {
                        adoptionName = UTF8Arrays.strong
                    } else if equalsSlice(UTF8Arrays.b, nameSlice) {
                        adoptionName = UTF8Arrays.b
                    } else if equalsSlice(UTF8Arrays.i, nameSlice) {
                        adoptionName = UTF8Arrays.i
                    } else if equalsSlice(UTF8Arrays.small, nameSlice) {
                        adoptionName = UTF8Arrays.small
                    } else {
                        adoptionName = Array(nameSlice)
                    }
                }
                if let name = adoptionName {
                    // Adoption Agency Algorithm.
                    for _ in 0..<8 {
                        let formatEl: Element? = tb.getActiveFormattingElement(name)
                        if (formatEl == nil) {
                            return anyOtherEndTag(t, tb)
                        } else if (!tb.onStack(formatEl!)) {
                            tb.error(self)
                            tb.removeFromActiveFormattingElements(formatEl!)
                            return anyOtherEndTag(t, tb)
                        } else if (try !tb.inScope(formatEl!.nodeNameUTF8())) {
                            tb.error(self)
                            return false
                        } else if (tb.currentElement() != formatEl!) {
                            tb.error(self)
                        }

                        var furthestBlock: Element? = nil
                        var commonAncestor: Element? = nil
                        var seenFormattingElement: Bool = false
                        let stack: Array<Element> = Constants.useDirectStackAccess ? tb.stack : tb.getStack()
                        // the spec doesn't limit to < 64, but in degenerate cases (9000+ stack depth) self prevents
                        // run-aways
                        var stackSize = stack.count
                        if(stackSize > 64) {stackSize = 64}
                        for si in 0..<stackSize {
                            let el: Element = stack[si]
                            if (el == formatEl) {
                                commonAncestor = stack[si - 1]
                                seenFormattingElement = true
                            } else if seenFormattingElement {
                                if tb.isSpecial(el) {
                                    furthestBlock = el
                                    break
                                }
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
                } else {
                    switch endTag.tagId {
                    case .span:
                        return anyOtherEndTagFast(UTF8Arrays.span, tb)
                    case .div:
                        if (try !tb.inScope(UTF8Arrays.div)) {
                            tb.error(self)
                            return false
                        } else {
                            tb.generateImpliedEndTags()
                            if useCurrentTagIdFastPath {
                                if currentTagId != .div {
                                    tb.error(self)
                                }
                            } else if (tb.currentElement() != nil && !tb.currentElement()!.nodeNameUTF8().equals(UTF8Arrays.div)) {
                                tb.error(self)
                            }
                            tb.popStackToClose(UTF8Arrays.div)
                        }
                        return true
                    case .li:
                        if (try !tb.inListItemScope(UTF8Arrays.li)) {
                            tb.error(self)
                            return false
                        } else {
                            tb.generateImpliedEndTags(UTF8Arrays.li)
                            if useCurrentTagIdFastPath {
                                if currentTagId != .li {
                                    tb.error(self)
                                }
                            } else if (tb.currentElement() != nil && !tb.currentElement()!.nodeNameUTF8().equals(UTF8Arrays.li)) {
                                tb.error(self)
                            }
                            tb.popStackToClose(UTF8Arrays.li)
                        }
                        return true
                    case .body:
                        if try !tb.inScope(UTF8Arrays.body) {
                            tb.error(self)
                            return false
                        } else {
                            // todo: error if stack contains something not dd, dt, li, optgroup, option, p, rp, rt, tbody, td, tfoot, th, thead, tr, body, html
                            tb.transition(.AfterBody)
                        }
                        return true
                    case .html:
                        let notIgnored: Bool = try tb.processEndTag(UTF8Arrays.body)
                        if (notIgnored) {
                            return try tb.process(endTag)
                        }
                        return true
                    case .form:
                        let currentForm: Element? = tb.getFormElement()
                        tb.setFormElement(nil)
                        if (try currentForm == nil || !tb.inScope(UTF8Arrays.form)) {
                            tb.error(self)
                            return false
                        } else {
                            tb.generateImpliedEndTags()
                            if useCurrentTagIdFastPath {
                                if currentTagId != .form {
                                    tb.error(self)
                                }
                            } else if (tb.currentElement() != nil && !tb.currentElement()!.nodeNameUTF8().equals(UTF8Arrays.form)) {
                                tb.error(self)
                            }
                            // remove currentForm from stack. will shift anything under up.
                            tb.removeFromStack(currentForm!)
                        }
                        return true
                    case .p:
                        if (try !tb.inButtonScope(UTF8Arrays.p)) {
                            tb.error(self)
                            try tb.processStartTag(UTF8Arrays.p) // if no p to close, creates an empty <p></p>
                            return try tb.process(endTag)
                        } else {
                            tb.generateImpliedEndTags(UTF8Arrays.p)
                            if useCurrentTagIdFastPath {
                                if currentTagId != .p {
                                    tb.error(self)
                                }
                            } else if (tb.currentElement() != nil && !tb.currentElement()!.nodeNameUTF8().equals(UTF8Arrays.p)) {
                                tb.error(self)
                            }
                            tb.popStackToClose(UTF8Arrays.p)
                        }
                        return true
                    default:
                        break
                    }
                    if Constants.useInBodyEndTagIdFastPath, endTag.tagId != .none, let name = endTag.tagIdName() {
                        let tagId = endTag.tagId
                        if Constants.InBodyEndClosers.containsTagId(tagId) {
                            if (try !tb.inScope(name)) {
                                // nothing to close
                                tb.error(self)
                                return false
                            } else {
                                tb.generateImpliedEndTags()
                                if useCurrentTagIdFastPath {
                                    if currentTagId != tagId {
                                        tb.error(self)
                                    }
                                } else if (!tb.currentElement()!.nodeNameUTF8().equals(name)) {
                                    tb.error(self)
                                }
                                tb.popStackToClose(name)
                            }
                        } else if Constants.DdDt.containsTagId(tagId) {
                            if (try !tb.inScope(name)) {
                                tb.error(self)
                                return false
                            } else {
                                tb.generateImpliedEndTags(name)
                                if useCurrentTagIdFastPath {
                                    if currentTagId != tagId {
                                        tb.error(self)
                                    }
                                } else if (tb.currentElement() != nil && !tb.currentElement()!.nodeNameUTF8().equals(name)) {
                                    tb.error(self)
                                }
                                tb.popStackToClose(name)
                            }
                        } else if Constants.Headings.containsTagId(tagId) {
                            if (try !tb.inScope(Constants.Headings)) {
                                tb.error(self)
                                return false
                            } else {
                                tb.generateImpliedEndTags(name)
                                if useCurrentTagIdFastPath {
                                    if currentTagId != tagId {
                                        tb.error(self)
                                    }
                                } else if (tb.currentElement() != nil && !tb.currentElement()!.nodeNameUTF8().equals(name)) {
                                    tb.error(self)
                                }
                                tb.popStackToClose(Constants.Headings)
                            }
                        } else if Constants.InBodyStartApplets.containsTagId(tagId) {
                            if (try !tb.inScope(UTF8Arrays.name)) {
                                if (try !tb.inScope(name)) {
                                    tb.error(self)
                                    return false
                                }
                                tb.generateImpliedEndTags()
                                if useCurrentTagIdFastPath {
                                    if currentTagId != tagId {
                                        tb.error(self)
                                    }
                                } else if (tb.currentElement() != nil && !tb.currentElement()!.nodeNameUTF8().equals(name)) {
                                    tb.error(self)
                                }
                                tb.popStackToClose(name)
                                tb.clearFormattingElementsToLastMarker()
                            }
                        } else if tagId == .br {
                            tb.error(self)
                            try tb.processStartTag(UTF8Arrays.br)
                            return false
                        } else {
                            return anyOtherEndTag(t, tb)
                        }
                    } else if let name = endTag.normalName() {
                        if Constants.InBodyEndClosers.contains(name) {
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
                if startTag.tagId != .none {
                    switch startTag.tagId {
                    case .table:
                        tb.error(self)
                        let processed: Bool = try tb.processEndTag(UTF8Arrays.table)
                        if (processed) { return try tb.process(t) }
                        return true
                    case .tbody, .thead, .tfoot:
                        tb.clearStackToTableContext()
                        try tb.insert(startTag)
                        tb.transition(.InTableBody)
                        return true
                    case .td, .th, .tr:
                        try tb.processStartTag(UTF8Arrays.tbody)
                        return try tb.process(t)
                    case .caption:
                        tb.clearStackToTableContext()
                        tb.insertMarkerToFormattingElements()
                        try tb.insert(startTag)
                        tb.transition(.InCaption)
                        return true
                    case .colgroup:
                        tb.clearStackToTableContext()
                        try tb.insert(startTag)
                        tb.transition(.InColumnGroup)
                        return true
                    case .col:
                        try tb.processStartTag(UTF8Arrays.colgroup)
                        return try tb.process(t)
                    case .script, .style:
                        return try tb.process(t, .InHead)
                    case .input:
                        let isHidden: Bool
                        if startTag.hasAnyAttributes() {
                            startTag.ensureAttributes()
                            let typeValue = startTag._attributes?.get(key: UTF8Arrays.type) ?? []
                            isHidden = typeValue.equalsIgnoreCase(string: UTF8Arrays.hidden)
                        } else {
                            isHidden = false
                        }
                        if !isHidden {
                            return try anythingElse(t, tb)
                        } else {
                            try tb.insertEmpty(startTag)
                        }
                        return true
                    case .form:
                        tb.error(self)
                        if (tb.getFormElement() != nil) {
                            return false
                        } else {
                            try tb.insertForm(startTag, false)
                        }
                        return true
                    default:
                        break
                    }
                }
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
                        let isHidden: Bool
                        if startTag.hasAnyAttributes() {
                            startTag.ensureAttributes()
                            let typeValue = startTag._attributes?.get(key: UTF8Arrays.type) ?? []
                            isHidden = typeValue.equalsIgnoreCase(string: UTF8Arrays.hidden)
                        } else {
                            isHidden = false
                        }
                        if !isHidden {
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
                if endTag.tagId != .none {
                    switch endTag.tagId {
                    case .table:
                        if (try !tb.inTableScope(UTF8Arrays.table)) {
                            tb.error(self)
                            return false
                        } else {
                            tb.popStackToClose(UTF8Arrays.table)
                        }
                        tb.resetInsertionMode()
                        return true
                    case .body, .caption, .col, .colgroup, .html, .tbody, .td, .tfoot, .th, .thead, .tr:
                        tb.error(self)
                        return false
                    default:
                        break
                    }
                }
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
                if let data = c.getDataSlice(), data.count == 1, data.first == 0x00 {
                    tb.error(self)
                    return false
                } else {
                    if let data = c.getDataSlice() {
                        tb.appendPendingTableCharacter(.slice(data))
                    } else if let data = c.getData() {
                        tb.appendPendingTableCharacter(.bytes(data))
                    }
                }
                break
            default:
                // todo - don't really like the way these table character data lists are built
                if !tb.pendingTableCharactersIsEmpty() {
                    let tempChar = Token.Char()
                    let pending = tb.takePendingTableCharacters()
                    let inTable = tb.currentElement() != nil && TagSets.table.contains(tb.currentElement()!.nodeNameUTF8())
                    for character in pending {
                        switch character {
                        case .slice(let slice):
                            if (!HtmlTreeBuilderState.isWhitespace(slice)) {
                                // InTable anything else section:
                                tb.error(self)
                                if inTable {
                                    tb.setFosterInserts(true)
                                    try tb.process(tempChar.data(slice), .InBody)
                                    tb.setFosterInserts(false)
                                } else {
                                    try tb.process(tempChar.data(slice), .InBody)
                                }
                            } else {
                                try tb.insert(tempChar.data(slice))
                            }
                        case .bytes(let bytes):
                            if (!HtmlTreeBuilderState.isWhitespace(bytes)) {
                                // InTable anything else section:
                                tb.error(self)
                                if inTable {
                                    tb.setFosterInserts(true)
                                    try tb.process(tempChar.data(bytes), .InBody)
                                    tb.setFosterInserts(false)
                                } else {
                                    try tb.process(tempChar.data(bytes), .InBody)
                                }
                            } else {
                                try tb.insert(tempChar.data(bytes))
                            }
                        }
                    }
                }
                tb.transition(tb.originalState())
                return try tb.process(t)
            }
            return true
        case .InCaption:
            if t.isEndTag() {
                let endTag = t.asEndTag()
                if endTag.tagId == .caption {
                    let name = endTag.tagIdName()
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
                    return true
                }
                if endTag.tagId != .none {
                    switch endTag.tagId {
                    case .body, .col, .colgroup, .html, .tbody, .td, .tfoot, .th, .thead, .tr:
                        tb.error(self)
                        return false
                    default:
                        break
                    }
                }
            }
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
            } else if t.isStartTag() {
                let startTag = t.asStartTag()
                if startTag.tagId != .none {
                    switch startTag.tagId {
                    case .caption, .col, .colgroup, .tbody, .td, .tfoot, .th, .thead, .tr:
                        tb.error(self)
                        let processed: Bool = try tb.processEndTag(UTF8Arrays.caption)
                        if (processed) {
                            return try tb.process(t)
                        }
                        return true
                    default:
                        break
                    }
                }
                if TagSets.tableRowsAndCols.containsCaseInsensitive(startTag) {
                    tb.error(self)
                    let processed: Bool = try tb.processEndTag(UTF8Arrays.caption)
                    if (processed) {
                        return try tb.process(t)
                    }
                    return true
                }
                return try tb.process(t, .InBody)
            } else if t.endTagNormalNameEquals(UTF8Arrays.table) {
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
                if startTag.tagId != .none {
                    switch startTag.tagId {
                    case .tr:
                        tb.clearStackToTableBodyContext()
                        try tb.insert(startTag)
                        tb.transition(.InRow)
                        return true
                    case .td, .th:
                        tb.error(self)
                        try tb.processStartTag(UTF8Arrays.tr)
                        return try tb.process(startTag)
                    case .caption, .col, .colgroup, .tbody, .thead, .tfoot:
                        return try exitTableBody(t, tb)
                    default:
                        break
                    }
                }
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
                if endTag.tagId != .none, let name = endTag.tagIdName() {
                    switch endTag.tagId {
                    case .tbody, .thead, .tfoot:
                        if (try !tb.inTableScope(name)) {
                            tb.error(self)
                            return false
                        } else {
                            tb.clearStackToTableBodyContext()
                            tb.pop()
                            tb.transition(.InTable)
                        }
                        return true
                    case .table:
                        return try exitTableBody(t, tb)
                    case .caption, .col, .colgroup, .td, .th, .tr:
                        tb.error(self)
                        return false
                    default:
                        break
                    }
                }
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
                if startTag.tagId != .none {
                    switch startTag.tagId {
                    case .td, .th:
                        tb.clearStackToTableRowContext()
                        try tb.insert(startTag)
                        tb.transition(.InCell)
                        tb.insertMarkerToFormattingElements()
                        return true
                    case .caption, .col, .colgroup, .tbody, .tfoot, .thead, .tr:
                        return try handleMissingTr(t, tb)
                    default:
                        break
                    }
                }
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
                if endTag.tagId != .none, let name = endTag.tagIdName() {
                    switch endTag.tagId {
                    case .tr:
                        if (try !tb.inTableScope(name)) {
                            tb.error(self) // frag
                            return false
                        }
                        tb.clearStackToTableRowContext()
                        tb.pop() // tr
                        tb.transition(.InTableBody)
                        return true
                    case .table:
                        return try handleMissingTr(t, tb)
                    case .caption, .col, .colgroup, .td, .th:
                        tb.error(self)
                        return false
                    default:
                        break
                    }
                }
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
                if endTag.tagId != .none, let name = endTag.tagIdName() {
                    switch endTag.tagId {
                    case .td, .th:
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
                        return true
                    case .table:
                        if (try !tb.inTableScope(name)) {
                            tb.error(self)
                            return false
                        }
                        try closeCell(tb)
                        return try tb.process(t)
                    case .caption, .col, .colgroup:
                        tb.error(self)
                        return false
                    default:
                        break
                    }
                }
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
            } else if t.isStartTag() {
                let startTag: Token.StartTag = t.asStartTag()
                if startTag.tagId != .none {
                    switch startTag.tagId {
                    case .caption, .col, .colgroup, .tbody, .td, .tfoot, .th, .thead, .tr:
                        if (try !(tb.inTableScope(UTF8Arrays.td) || tb.inTableScope(UTF8Arrays.th))) {
                            tb.error(self)
                            return false
                        }
                        try closeCell(tb)
                        return try tb.process(t)
                    default:
                        break
                    }
                }
                if t.startTagNormalNameIn(TagSets.tableRowsAndCols) {
                    if (try !(tb.inTableScope(UTF8Arrays.td) || tb.inTableScope(UTF8Arrays.th))) {
                        tb.error(self)
                        return false
                    }
                    try closeCell(tb)
                    return try tb.process(t)
                }
                return try anythingElse(t, tb)
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
                if let data = c.getDataSlice(), data.count == 1, data.first == 0x00 {
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
                let current = tb.currentElement()
                let currentTagId = HtmlTreeBuilderState.useSelectTagIdFastPath ? (current?._tag.tagId ?? .none) : .none
                if start.tagId == .none {
                    _ = start.normalNameSlice()
                }
                if start.tagId == .none {
                    if start.normalNameEquals(UTF8Arrays.input) || start.normalNameEquals(UTF8Arrays.textarea) {
                        tb.error(self)
                        if (try !tb.inSelectScope(UTF8Arrays.select)) {
                            return false // frag
                        }
                        try tb.processEndTag(UTF8Arrays.select)
                        return try tb.process(start)
                    }
                    if start.normalNameEquals(UTF8Arrays.script) {
                        return try tb.process(t, .InHead)
                    }
                    if start.normalNameEquals(UTF8Arrays.html) {
                        return try tb.process(start, .InBody)
                    }
                    if start.normalNameEquals(UTF8Arrays.option) {
                        if currentTagId == .option {
                            try tb.processEndTag(UTF8Arrays.option)
                        } else if !HtmlTreeBuilderState.useSelectTagIdFastPath,
                                  current?.nodeNameUTF8() == UTF8Arrays.option {
                            try tb.processEndTag(UTF8Arrays.option)
                        }
                        try tb.insert(start)
                        break
                    }
                    if start.normalNameEquals(UTF8Arrays.optgroup) {
                        if currentTagId == .option ||
                            (!HtmlTreeBuilderState.useSelectTagIdFastPath && current?.nodeNameUTF8() == UTF8Arrays.option) {
                            try tb.processEndTag(UTF8Arrays.option)
                        } else if currentTagId == .optgroup ||
                                    (!HtmlTreeBuilderState.useSelectTagIdFastPath && current?.nodeNameUTF8() == UTF8Arrays.optgroup) {
                            try tb.processEndTag(UTF8Arrays.optgroup)
                        }
                        try tb.insert(start)
                        break
                    }
                    if start.normalNameEquals(UTF8Arrays.select) {
                        tb.error(self)
                        return try tb.processEndTag(UTF8Arrays.select)
                    }
                }
                switch start.tagId {
                case .input, .textarea:
                    tb.error(self)
                    if (try !tb.inSelectScope(UTF8Arrays.select)) {
                        return false // frag
                    }
                    try tb.processEndTag(UTF8Arrays.select)
                    return try tb.process(start)
                case .script:
                    return try tb.process(t, .InHead)
                case .html:
                    return try tb.process(start, .InBody)
                case .option:
                    if currentTagId == .option {
                        try tb.processEndTag(UTF8Arrays.option)
                    } else if !HtmlTreeBuilderState.useSelectTagIdFastPath,
                              current?.nodeNameUTF8() == UTF8Arrays.option {
                        try tb.processEndTag(UTF8Arrays.option)
                    }
                    try tb.insert(start)
                case .optgroup:
                    if currentTagId == .option ||
                        (!HtmlTreeBuilderState.useSelectTagIdFastPath && current?.nodeNameUTF8() == UTF8Arrays.option) {
                        try tb.processEndTag(UTF8Arrays.option)
                    } else if currentTagId == .optgroup ||
                                (!HtmlTreeBuilderState.useSelectTagIdFastPath && current?.nodeNameUTF8() == UTF8Arrays.optgroup) {
                        try tb.processEndTag(UTF8Arrays.optgroup)
                    }
                    try tb.insert(start)
                case .select:
                    tb.error(self)
                    return try tb.processEndTag(UTF8Arrays.select)
                default:
                    if let name = start.normalName(), TagSets.inputKeygenTextarea.contains(name) {
                        tb.error(self)
                        if (try !tb.inSelectScope(UTF8Arrays.select)) {
                            return false // frag
                        }
                        try tb.processEndTag(UTF8Arrays.select)
                        return try tb.process(start)
                    }
                    if let name = start.normalName(), name == UTF8Arrays.script {
                        return try tb.process(t, .InHead)
                    }
                    return anythingElse(t, tb)
                }
                break
            case .EndTag:
                let end: Token.EndTag = t.asEndTag()
                let current = tb.currentElement()
                let currentTagId = HtmlTreeBuilderState.useSelectTagIdFastPath ? (current?._tag.tagId ?? .none) : .none
                if end.tagId == .none {
                    _ = end.normalNameSlice()
                }
                if end.tagId == .none {
                    if end.normalNameEquals(UTF8Arrays.optgroup) {
                        if currentTagId == .option && current != nil && tb.aboveOnStack(current!) != nil && tb.aboveOnStack(current!)?._tag.tagId == .optgroup {
                            try tb.processEndTag(UTF8Arrays.option)
                        } else if !HtmlTreeBuilderState.useSelectTagIdFastPath,
                                  current?.nodeNameUTF8() == UTF8Arrays.option &&
                                  current != nil &&
                                  tb.aboveOnStack(current!) != nil &&
                                  tb.aboveOnStack(current!)?.nodeNameUTF8() == UTF8Arrays.optgroup {
                            try tb.processEndTag(UTF8Arrays.option)
                        }
                        if currentTagId == .optgroup ||
                            (!HtmlTreeBuilderState.useSelectTagIdFastPath && current?.nodeNameUTF8() == UTF8Arrays.optgroup) {
                            tb.pop()
                        } else {
                            tb.error(self)
                        }
                        break
                    }
                    if end.normalNameEquals(UTF8Arrays.option) {
                        if currentTagId == .option ||
                            (!HtmlTreeBuilderState.useSelectTagIdFastPath && current?.nodeNameUTF8() == UTF8Arrays.option) {
                            tb.pop()
                        } else {
                            tb.error(self)
                        }
                        break
                    }
                    if end.normalNameEquals(UTF8Arrays.select) {
                        if (try !tb.inSelectScope(UTF8Arrays.select)) {
                            tb.error(self)
                            return false
                        } else {
                            tb.popStackToClose(UTF8Arrays.select)
                            tb.resetInsertionMode()
                        }
                        break
                    }
                }
                switch end.tagId {
                case .optgroup:
                    if currentTagId == .option && current != nil && tb.aboveOnStack(current!) != nil && tb.aboveOnStack(current!)?._tag.tagId == .optgroup {
                        try tb.processEndTag(UTF8Arrays.option)
                    } else if !HtmlTreeBuilderState.useSelectTagIdFastPath,
                              current?.nodeNameUTF8() == UTF8Arrays.option &&
                              current != nil &&
                              tb.aboveOnStack(current!) != nil &&
                              tb.aboveOnStack(current!)?.nodeNameUTF8() == UTF8Arrays.optgroup {
                        try tb.processEndTag(UTF8Arrays.option)
                    }
                    if currentTagId == .optgroup ||
                        (!HtmlTreeBuilderState.useSelectTagIdFastPath && current?.nodeNameUTF8() == UTF8Arrays.optgroup) {
                        tb.pop()
                    } else {
                        tb.error(self)
                    }
                case .option:
                    if currentTagId == .option ||
                        (!HtmlTreeBuilderState.useSelectTagIdFastPath && current?.nodeNameUTF8() == UTF8Arrays.option) {
                        tb.pop()
                    } else {
                        tb.error(self)
                    }
                case .select:
                    if (try !tb.inSelectScope(UTF8Arrays.select)) {
                        tb.error(self)
                        return false
                    } else {
                        tb.popStackToClose(UTF8Arrays.select)
                        tb.resetInsertionMode()
                    }
                default:
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
            if t.isStartTag() {
                let startTag = t.asStartTag()
                switch startTag.tagId {
                case .caption, .table, .tbody, .tfoot, .thead, .tr, .td, .th:
                    tb.error(self)
                    try tb.processEndTag(UTF8Arrays.select)
                    return try tb.process(t)
                default:
                    break
                }
            }
            if t.startTagNormalNameIn(TagSets.tableMix8) {
                tb.error(self)
                try tb.processEndTag(UTF8Arrays.select)
                return try tb.process(t)
            } else if t.isEndTag() {
                let endTag = t.asEndTag()
                switch endTag.tagId {
                case .caption, .table, .tbody, .tfoot, .thead, .tr, .td, .th:
                    tb.error(self)
                    if try tb.inTableScope(t.asEndTag().normalName()!) {
                        try tb.processEndTag(UTF8Arrays.select)
                        return try (tb.process(t))
                    } else {
                        return false
                    }
                default:
                    break
                }
                if t.endTagNormalNameIn(TagSets.tableMix8) {
                    tb.error(self)
                    if try tb.inTableScope(t.asEndTag().normalName()!) {
                        try tb.processEndTag(UTF8Arrays.select)
                        return try (tb.process(t))
                    } else {
                        return false
                    }
                }
                return try tb.process(t, .InSelect)
            }
            return try tb.process(t, .InSelect)
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
            let data = t.asCharacter().getDataSlice()
            return isWhitespace(data)
        }
        return false
    }

    private static func isWhitespace(_ data: ArraySlice<UInt8>?) -> Bool {
        guard let data else { return true }
        if data.isEmpty { return true }
        let table = HtmlTreeBuilderState.whitespaceTable
        var it = data.startIndex
        while it < data.endIndex {
            if !table[Int(data[it])] {
                return false
            }
            it = data.index(after: it)
        }
        return true
    }

    private static func isWhitespace(_ data: [UInt8]?) -> Bool {
        guard let data else { return true }
        if data.isEmpty { return true }
        let table = HtmlTreeBuilderState.whitespaceTable
        var i = 0
        while i < data.count {
            if !table[Int(data[i])] {
                return false
            }
            i &+= 1
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
        fileprivate static let useInBodyTagIdFastPath: Bool =
            ProcessInfo.processInfo.environment["SWIFTSOUP_DISABLE_INBODY_TAGID_FASTPATH"] != "1"
        fileprivate static let useInBodyEndTagIdFastPath: Bool =
            ProcessInfo.processInfo.environment["SWIFTSOUP_DISABLE_INBODY_ENDTAGID_FASTPATH"] != "1"
        fileprivate static let useInBodyEndTagReuseTagIdFastPath: Bool =
            ProcessInfo.processInfo.environment["SWIFTSOUP_DISABLE_INBODY_ENDTAG_REUSE_TAGID_FASTPATH"] != "1"
        fileprivate static let useInBodyStartStructuralTagIdFastPath: Bool =
            ProcessInfo.processInfo.environment["SWIFTSOUP_DISABLE_INBODY_START_STRUCTURAL_TAGID_FASTPATH"] != "1"
        fileprivate static let useCurrentTagIdFastPath: Bool =
            ProcessInfo.processInfo.environment["SWIFTSOUP_DISABLE_CURRENT_TAGID_FASTPATH"] != "1"
        fileprivate static let useInBodyStackTagIdFastPath: Bool =
            ProcessInfo.processInfo.environment["SWIFTSOUP_DISABLE_INBODY_STACK_TAGID_FASTPATH"] != "1"
        fileprivate static let useDirectStackAccess: Bool =
            ProcessInfo.processInfo.environment["SWIFTSOUP_DISABLE_DIRECT_STACK_ACCESS"] != "1"
        fileprivate static let useInBodyReverseStackIndexFastPath: Bool =
            ProcessInfo.processInfo.environment["SWIFTSOUP_DISABLE_INBODY_STACK_REVERSE_INDEX_FASTPATH"] != "1"
        fileprivate static let useInBodyStackTopCloseFastPath: Bool =
            ProcessInfo.processInfo.environment["SWIFTSOUP_DISABLE_INBODY_STACK_TOP_CLOSE_FASTPATH"] != "1"
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
        fileprivate static let InBodyStartEmptyFormatters = ParsingStrings(["area", "br", "embed", "hr", "img", "keygen", "wbr"])
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
        if tag.tagId != .none, containsTagId(tag.tagId) {
            return true
        }
        guard let name = tag.normalName(), !name.isEmpty else { return false }
        return contains(name)
    }
}
