import Foundation

public protocol HtmlTokenReceiver: AnyObject {
    func startTag(name: ArraySlice<UInt8>, attributes: Attributes?, selfClosing: Bool)
    func endTag(name: ArraySlice<UInt8>)
    func text(_ data: ArraySlice<UInt8>)
    func comment(_ data: ArraySlice<UInt8>)
    func doctype(name: ArraySlice<UInt8>?, publicId: ArraySlice<UInt8>?, systemId: ArraySlice<UInt8>?, forceQuirks: Bool)
    func eof()
}

public extension HtmlTokenReceiver {
    func startTag(name: ArraySlice<UInt8>, attributes: Attributes?, selfClosing: Bool) {}
    func endTag(name: ArraySlice<UInt8>) {}
    func text(_ data: ArraySlice<UInt8>) {}
    func comment(_ data: ArraySlice<UInt8>) {}
    func doctype(name: ArraySlice<UInt8>?, publicId: ArraySlice<UInt8>?, systemId: ArraySlice<UInt8>?, forceQuirks: Bool) {}
    func eof() {}
}

/// Streaming/token-level HTML parser that bypasses DOM construction.
/// Note: slices and attribute instances are only valid during the callback.
public final class StreamingHtmlParser {
    private let settings: ParseSettings
    private let errors: ParseErrorList?

    public init(settings: ParseSettings = ParseSettings(false, false), trackErrors: Bool = false, maxErrors: Int = 0) {
        self.settings = settings
        if trackErrors {
            self.errors = ParseErrorList.tracking(maxErrors)
        } else {
            self.errors = nil
        }
    }

    public func parse(_ html: [UInt8], _ handler: HtmlTokenReceiver) throws {
        let reader = CharacterReader(html)
        let tokeniser = Tokeniser(reader, errors, settings)
        if ProcessInfo.processInfo.environment["SWIFTSOUP_DISABLE_FAST_STREAM"] == "1" {
            try parseSlow(tokeniser, handler)
        } else {
            let adapter = StreamingReceiverAdapter(handler)
            try tokeniser.readFast(adapter)
        }
    }
}

private final class StreamingReceiverAdapter: TokeniserEventReceiver {
    private let handler: HtmlTokenReceiver

    init(_ handler: HtmlTokenReceiver) {
        self.handler = handler
    }

    func startTag(name: ArraySlice<UInt8>, normalName: ArraySlice<UInt8>?, tagId: Token.Tag.TagId, attributes: Attributes?, selfClosing: Bool) {
        handler.startTag(name: name, attributes: attributes, selfClosing: selfClosing)
    }

    func endTag(name: ArraySlice<UInt8>, normalName: ArraySlice<UInt8>?, tagId: Token.Tag.TagId) {
        handler.endTag(name: name)
    }

    func text(_ data: ArraySlice<UInt8>) {
        handler.text(data)
    }

    func comment(_ data: ArraySlice<UInt8>) {
        handler.comment(data)
    }

    func doctype(name: ArraySlice<UInt8>?, publicId: ArraySlice<UInt8>?, systemId: ArraySlice<UInt8>?, forceQuirks: Bool) {
        handler.doctype(name: name, publicId: publicId, systemId: systemId, forceQuirks: forceQuirks)
    }

    func eof() {
        handler.eof()
    }
}

private func parseSlow(_ tokeniser: Tokeniser, _ handler: HtmlTokenReceiver) throws {
    while true {
        let token = try tokeniser.read()
        switch token.type {
        case .StartTag:
            let start = token.asStartTag()
            let name = start.tagNameSlice() ?? []
            var attrs: Attributes? = nil
            if start.hasAnyAttributes() {
                start.ensureAttributes()
                attrs = start._attributes
            }
            handler.startTag(name: name, attributes: attrs, selfClosing: start.isSelfClosing())
        case .EndTag:
            let end = token.asEndTag()
            let name = end.tagNameSlice() ?? []
            handler.endTag(name: name)
        case .Comment:
            let comment = token.asComment()
            handler.comment(comment.data.buffer)
        case .Doctype:
            let doc = token.asDoctype()
            let name = doc.name.buffer.isEmpty ? nil : doc.name.buffer
            let publicId = doc.publicIdentifier.buffer.isEmpty ? nil : doc.publicIdentifier.buffer
            let systemId = doc.systemIdentifier.buffer.isEmpty ? nil : doc.systemIdentifier.buffer
            handler.doctype(name: name, publicId: publicId, systemId: systemId, forceQuirks: doc.forceQuirks)
        case .Char:
            let char = token.asCharacter()
            if let slice = char.getDataSlice() {
                handler.text(slice)
            } else if let data = char.getData() {
                handler.text(data[...])
            }
        case .EOF:
            handler.eof()
            return
        }
    }
}
