//
//  Token.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 18/10/16.
//

import Foundation

open class Token {
    var type: TokenType = TokenType.Doctype
    @usableFromInline
    internal var sourceRange: SourceRange? = nil
    
    private init() {
    }
    
    @inline(__always)
    func tokenType() -> String {
        return String(describing: Swift.type(of: self))
    }
    
    /**
     * Reset the data represent by this token, for reuse. Prevents the need to create transfer objects for every
     * piece of data, which immediately get GCed.
     */
    @discardableResult
    @inline(__always)
    public func reset() -> Token {
        preconditionFailure("This method must be overridden")
    }
    
    @inline(__always)
    static func reset(_ sb: StringBuilder) {
        sb.clear()
    }
    
    @inline(__always)
    open func toString() throws -> String {
        return String(describing: Swift.type(of: self))
    }
    
    final class Doctype: Token {
        let name: StringBuilder = StringBuilder()
        var pubSysKey: [UInt8]?
        let publicIdentifier: StringBuilder = StringBuilder()
        let systemIdentifier: StringBuilder = StringBuilder()
        var forceQuirks: Bool  = false
        
        override init() {
            super.init()
            type = TokenType.Doctype
        }
        
        @discardableResult
        override func reset() -> Token {
            sourceRange = nil
            Token.reset(name)
            pubSysKey = nil
            Token.reset(publicIdentifier)
            Token.reset(systemIdentifier)
            forceQuirks = false
            return self
        }
        
        @inline(__always)
        func getName() -> [UInt8] {
            return Array(name.buffer)
        }
        
        @inline(__always)
        func getPubSysKey() -> [UInt8]? {
            return pubSysKey
        }
        
        @inline(__always)
        func getPublicIdentifier() -> [UInt8] {
            return Array(publicIdentifier.buffer)
        }
        
        @inline(__always)
        public func getSystemIdentifier() -> [UInt8] {
            return Array(systemIdentifier.buffer)
        }
        
        @inline(__always)
        public func isForceQuirks() -> Bool {
            return forceQuirks
        }
    }
    
    class Tag: Token {
        enum TagId: UInt8 {
            case none = 0
            case a
            case span
            case p
            case div
            case em
            case strong
            case b
            case i
            case small
            case li
            case body
            case html
            case head
            case title
            case form
            case br
            case meta
            case img
            case script
            case style
            case caption
            case col
            case colgroup
            case table
            case tbody
            case thead
            case tfoot
            case tr
            case td
            case th
            case input
            case hr
            case select
            case option
            case optgroup
            case textarea
            case noscript
            case noframes
            case plaintext
            case button
            case base
            case frame
            case frameset
            case iframe
            case noembed
            case embed
            case dd
            case dt
            case dl
            case ol
            case ul
            case pre
            case listing
            case address
            case article
            case aside
            case blockquote
            case center
            case dir
            case fieldset
            case figcaption
            case figure
            case footer
            case header
            case hgroup
            case menu
            case nav
            case section
            case summary
            case h1
            case h2
            case h3
            case h4
            case h5
            case h6
            case applet
            case marquee
            case object
            case ruby
            case rp
            case rt

        }


        private struct TagIdEntry {
            let bytes: [UInt8]
            let id: TagId
        }


        private static let tagIdEntriesByLength: [[TagIdEntry]] = {
            var entries = Array(repeating: [TagIdEntry](), count: 11)
            entries[1] = [
                TagIdEntry(bytes: UTF8Arrays.a, id: .a),
                TagIdEntry(bytes: UTF8Arrays.p, id: .p),
                TagIdEntry(bytes: UTF8Arrays.b, id: .b),
                TagIdEntry(bytes: UTF8Arrays.i, id: .i)
            ]
            entries[2] = [
                TagIdEntry(bytes: UTF8Arrays.em, id: .em),
                TagIdEntry(bytes: UTF8Arrays.br, id: .br),
                TagIdEntry(bytes: UTF8Arrays.tr, id: .tr),
                TagIdEntry(bytes: UTF8Arrays.td, id: .td),
                TagIdEntry(bytes: UTF8Arrays.th, id: .th),
                TagIdEntry(bytes: UTF8Arrays.hr, id: .hr),
                TagIdEntry(bytes: UTF8Arrays.dd, id: .dd),
                TagIdEntry(bytes: UTF8Arrays.dt, id: .dt),
                TagIdEntry(bytes: UTF8Arrays.dl, id: .dl),
                TagIdEntry(bytes: UTF8Arrays.ol, id: .ol),
                TagIdEntry(bytes: UTF8Arrays.ul, id: .ul),
                TagIdEntry(bytes: UTF8Arrays.rp, id: .rp),
                TagIdEntry(bytes: UTF8Arrays.rt, id: .rt),
                TagIdEntry(bytes: UTF8Arrays.h1, id: .h1),
                TagIdEntry(bytes: UTF8Arrays.h2, id: .h2),
                TagIdEntry(bytes: UTF8Arrays.h3, id: .h3),
                TagIdEntry(bytes: UTF8Arrays.h4, id: .h4),
                TagIdEntry(bytes: UTF8Arrays.h5, id: .h5),
                TagIdEntry(bytes: UTF8Arrays.h6, id: .h6)
            ]
            entries[3] = [
                TagIdEntry(bytes: UTF8Arrays.div, id: .div),
                TagIdEntry(bytes: UTF8Arrays.li, id: .li),
                TagIdEntry(bytes: UTF8Arrays.img, id: .img),
                TagIdEntry(bytes: UTF8Arrays.col, id: .col),
                TagIdEntry(bytes: UTF8Arrays.pre, id: .pre),
                TagIdEntry(bytes: UTF8Arrays.nav, id: .nav),
                TagIdEntry(bytes: UTF8Arrays.dir, id: .dir)
            ]
            entries[4] = [
                TagIdEntry(bytes: UTF8Arrays.span, id: .span),
                TagIdEntry(bytes: UTF8Arrays.body, id: .body),
                TagIdEntry(bytes: UTF8Arrays.html, id: .html),
                TagIdEntry(bytes: UTF8Arrays.head, id: .head),
                TagIdEntry(bytes: UTF8Arrays.form, id: .form),
                TagIdEntry(bytes: UTF8Arrays.meta, id: .meta),
                TagIdEntry(bytes: UTF8Arrays.base, id: .base),
                TagIdEntry(bytes: UTF8Arrays.menu, id: .menu),
                TagIdEntry(bytes: UTF8Arrays.ruby, id: .ruby)
            ]
            entries[5] = [
                TagIdEntry(bytes: UTF8Arrays.small, id: .small),
                TagIdEntry(bytes: UTF8Arrays.style, id: .style),
                TagIdEntry(bytes: UTF8Arrays.table, id: .table),
                TagIdEntry(bytes: UTF8Arrays.title, id: .title),
                TagIdEntry(bytes: UTF8Arrays.tbody, id: .tbody),
                TagIdEntry(bytes: UTF8Arrays.thead, id: .thead),
                TagIdEntry(bytes: UTF8Arrays.tfoot, id: .tfoot),
                TagIdEntry(bytes: UTF8Arrays.input, id: .input),
                TagIdEntry(bytes: UTF8Arrays.frame, id: .frame),
                TagIdEntry(bytes: UTF8Arrays.embed, id: .embed),
                TagIdEntry(bytes: UTF8Arrays.aside, id: .aside)
            ]
            entries[6] = [
                TagIdEntry(bytes: UTF8Arrays.strong, id: .strong),
                TagIdEntry(bytes: UTF8Arrays.script, id: .script),
                TagIdEntry(bytes: UTF8Arrays.select, id: .select),
                TagIdEntry(bytes: UTF8Arrays.option, id: .option),
                TagIdEntry(bytes: UTF8Arrays.button, id: .button),
                TagIdEntry(bytes: UTF8Arrays.iframe, id: .iframe),
                TagIdEntry(bytes: UTF8Arrays.object, id: .object),
                TagIdEntry(bytes: UTF8Arrays.header, id: .header),
                TagIdEntry(bytes: UTF8Arrays.footer, id: .footer),
                TagIdEntry(bytes: UTF8Arrays.figure, id: .figure),
                TagIdEntry(bytes: UTF8Arrays.center, id: .center),
                TagIdEntry(bytes: UTF8Arrays.hgroup, id: .hgroup),
                TagIdEntry(bytes: UTF8Arrays.applet, id: .applet)
            ]
            entries[7] = [
                TagIdEntry(bytes: UTF8Arrays.caption, id: .caption),
                TagIdEntry(bytes: UTF8Arrays.noembed, id: .noembed),
                TagIdEntry(bytes: UTF8Arrays.article, id: .article),
                TagIdEntry(bytes: UTF8Arrays.summary, id: .summary),
                TagIdEntry(bytes: UTF8Arrays.section, id: .section),
                TagIdEntry(bytes: UTF8Arrays.listing, id: .listing),
                TagIdEntry(bytes: UTF8Arrays.address, id: .address),
                TagIdEntry(bytes: UTF8Arrays.marquee, id: .marquee)
            ]
            entries[8] = [
                TagIdEntry(bytes: UTF8Arrays.colgroup, id: .colgroup),
                TagIdEntry(bytes: UTF8Arrays.optgroup, id: .optgroup),
                TagIdEntry(bytes: UTF8Arrays.textarea, id: .textarea),
                TagIdEntry(bytes: UTF8Arrays.noscript, id: .noscript),
                TagIdEntry(bytes: UTF8Arrays.noframes, id: .noframes),
                TagIdEntry(bytes: UTF8Arrays.frameset, id: .frameset),
                TagIdEntry(bytes: UTF8Arrays.fieldset, id: .fieldset)
            ]
            entries[9] = [
                TagIdEntry(bytes: UTF8Arrays.plaintext, id: .plaintext)
            ]
            entries[10] = [
                TagIdEntry(bytes: UTF8Arrays.figcaption, id: .figcaption),
                TagIdEntry(bytes: UTF8Arrays.blockquote, id: .blockquote)
            ]
            return entries
        }()

        private static let packedTagIdEntriesByLength: [Dictionary<UInt64, TagId>] = {
            var entries = Array(repeating: Dictionary<UInt64, TagId>(), count: 9)
            for entryList in tagIdEntriesByLength {
                for entry in entryList {
                    if let packed = packBytes(entry.bytes) {
                        entries[entry.bytes.count][packed] = entry.id
                    }
                }
            }
            return entries
        }()

        public var _tagName: [UInt8]?
        private var _tagNameS: ArraySlice<UInt8>?
        public var _normalName: [UInt8]? // lc version of tag name, for case insensitive tree build
        private var _tagNameHasUppercase: Bool = false
        private var _pendingAttributeNameHasUppercase: Bool = false
        private var _pendingAttributeName: [UInt8]? // attribute names are generally caught in one hop, not accumulated
        private var _pendingAttributeNameS: ArraySlice<UInt8>? // fast path to avoid copying name slices
        private let _pendingAttributeValue: StringBuilder = StringBuilder() // but values are accumulated, from e.g. & in hrefs
        private var _pendingAttributeValueS: ArraySlice<UInt8>? // try to get attr vals in one shot, vs Builder
        private var _pendingAttributeValueSlices: [ArraySlice<UInt8>]? // multiple slices before materializing
        private var _pendingAttributeValueSlicesCount: Int = 0
        private var _hasEmptyAttributeValue: Bool = false // distinguish boolean attribute from empty string value
        private var _hasPendingAttributeValue: Bool = false
        fileprivate var _pendingAttributes: [PendingAttribute]? // lazily materialized into Attributes
        public var _selfClosing: Bool = false
        private var _lowercaseAttributeNames: Bool = false
        fileprivate var _attributesAreNormalized: Bool = false
        fileprivate var _hasUppercaseAttributeNames: Bool = false
        // start tags get attributes on construction. End tags get attributes on first new attribute (but only for parser convenience, not used).
        public var _attributes: Attributes?
        var tagId: TagId = .none

        fileprivate typealias PendingAttrValue = Attributes.PendingAttrValue
        fileprivate typealias PendingAttribute = Attributes.PendingAttribute

        override init() {
            super.init()
        }
        
        @discardableResult
        @inline(__always)
        override func reset() -> Tag {
            sourceRange = nil
            if _tagName != nil {
                _tagName!.removeAll(keepingCapacity: true)
            } else {
                _tagName = nil
            }
            _tagNameS = nil
            _normalName = nil
            _tagNameHasUppercase = false
            _pendingAttributeNameHasUppercase = false
            _pendingAttributeName = nil
            _pendingAttributeNameS = nil
            Token.reset(_pendingAttributeValue)
            _pendingAttributeValueS = nil
            _pendingAttributeValueSlices = nil
            _pendingAttributeValueSlicesCount = 0
            _hasEmptyAttributeValue = false
            _hasPendingAttributeValue = false
            _pendingAttributes?.removeAll(keepingCapacity: true)
            _selfClosing = false
            _lowercaseAttributeNames = false
            _attributesAreNormalized = false
            _hasUppercaseAttributeNames = false
            _attributes = nil
            tagId = .none
            return self
        }
        
        func newAttribute() throws {
            let pendingNameSlice = _pendingAttributeNameS
            let pendingNameBytes = _pendingAttributeName
            let hasNameSlice = pendingNameSlice != nil && !(pendingNameSlice?.isEmpty ?? true)
            let hasNameBytes = pendingNameBytes != nil && !(pendingNameBytes?.isEmpty ?? true)
            if hasNameSlice || hasNameBytes {
                let value: PendingAttrValue
                if _hasPendingAttributeValue {
                    if !_pendingAttributeValue.isEmpty {
                        value = .bytes(Array(_pendingAttributeValue.buffer))
                    } else if let slices = _pendingAttributeValueSlices {
                        value = .slices(slices, _pendingAttributeValueSlicesCount)
                    } else if let pendingSlice = _pendingAttributeValueS {
                        value = .slice(pendingSlice)
                    } else {
                        value = .bytes([])
                    }
                } else if _hasEmptyAttributeValue {
                    value = .empty
                } else {
                    value = .none
                }
                let pending = PendingAttribute(
                    nameSlice: hasNameSlice ? pendingNameSlice : nil,
                    nameBytes: hasNameBytes ? pendingNameBytes : nil,
                    hasUppercase: _pendingAttributeNameHasUppercase,
                    value: value
                )
                if _pendingAttributes == nil {
                    _pendingAttributes = []
                    _pendingAttributes!.reserveCapacity(8)
                    _pendingAttributes!.append(pending)
                } else {
                    _pendingAttributes!.append(pending)
                }
                if _pendingAttributeNameHasUppercase {
                    _hasUppercaseAttributeNames = true
                }
            }
            _pendingAttributeName = nil
            _pendingAttributeNameS = nil
            _pendingAttributeNameHasUppercase = false
            _hasEmptyAttributeValue = false
            _hasPendingAttributeValue = false
            Token.reset(_pendingAttributeValue)
            _pendingAttributeValueS = nil
            _pendingAttributeValueSlices = nil
            _pendingAttributeValueSlicesCount = 0
        }
        
        @inline(__always)
        func finaliseTag() throws {
            // finalises for emit
            if (_pendingAttributeName != nil || _pendingAttributeNameS != nil) {
                // todo: check if attribute name exists; if so, drop and error
                try newAttribute()
            }
        }
        
        @inline(__always)
        func name() throws -> [UInt8] { // preserves case, for input into Tag.valueOf (which may drop case)
            if _tagName == nil, let tagNameSlice = _tagNameS, !tagNameSlice.isEmpty {
                _tagName = Array(tagNameSlice)
                _tagNameS = nil
            }
            try Validate.isFalse(val: (_tagName == nil || _tagName!.isEmpty) && (_tagNameS == nil || _tagNameS!.isEmpty))
            return _tagName!
        }
        
        @inline(__always)
        func normalName() -> [UInt8]? { // loses case, used in tree building for working out where in tree it should go
            if tagId != .none {
                if _normalName == nil {
                    _normalName = tagIdName()
                }
                return _normalName
            }
            if _normalName == nil {
                if let name = _tagName, !name.isEmpty {
                    _normalName = _tagNameHasUppercase ? name.lowercased() : name
                } else if let nameSlice = _tagNameS, !nameSlice.isEmpty {
                    _normalName = _tagNameHasUppercase ? Array(nameSlice.lowercased()) : Array(nameSlice)
                }
            }
            if tagId == .none, let normal = _normalName, !normal.isEmpty {
                setTagIdFromSlice(normal[...])
            }
            return _normalName
        }

        @inline(__always)
        func tagNameSlice() -> ArraySlice<UInt8>? {
            if let name = _tagName {
                if tagId == .none, !name.isEmpty {
                    setTagIdFromSlice(name[...])
                }
                return name[...]
            }
            if let nameSlice = _tagNameS, tagId == .none, !nameSlice.isEmpty {
                setTagIdFromSlice(nameSlice)
            }
            return _tagNameS
        }


        @inline(__always)
        func normalNameSlice() -> ArraySlice<UInt8>? {
            if tagId != .none {
                if _normalName == nil {
                    _normalName = tagIdName()
                }
                return _normalName?[...]
            }
            if let normal = _normalName {
                return normal[...]
            }
            if _tagNameHasUppercase {
                if let name = _tagName, !name.isEmpty {
                    let lowered = name.lowercased()
                    _normalName = lowered
                    if tagId == .none, !lowered.isEmpty {
                        setTagIdFromSlice(lowered[...])
                    }
                    return lowered[...]
                }
                if let nameSlice = _tagNameS, !nameSlice.isEmpty {
                    let lowered = Array(nameSlice.lowercased())
                    _normalName = lowered
                    if tagId == .none, !lowered.isEmpty {
                        setTagIdFromSlice(lowered[...])
                    }
                    return lowered[...]
                }
                return nil
            }
            if let name = _tagName {
                return name[...]
            }
            return _tagNameS
        }

        @inline(__always)
        func normalNameEquals(_ lower: [UInt8]) -> Bool {
            return normalNameEquals(lower[...])
        }

        @inline(__always)
        func normalNameEquals(_ lower: ArraySlice<UInt8>) -> Bool {
            @inline(__always)
            func equalsArraySlice(_ array: [UInt8], _ slice: ArraySlice<UInt8>) -> Bool {
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

            if let normal = _normalName {
                return equalsArraySlice(normal, lower)
            }
            if let name = _tagName, !name.isEmpty {
                if _tagNameHasUppercase {
                    let lowered = name.lowercased()
                    _normalName = lowered
                    return equalsArraySlice(lowered, lower)
                }
                return equalsArraySlice(name, lower)
            }
            if let nameSlice = _tagNameS, !nameSlice.isEmpty {
                if _tagNameHasUppercase {
                    let lowered = Array(nameSlice.lowercased())
                    _normalName = lowered
                    return equalsArraySlice(lowered, lower)
                }
                if nameSlice.count != lower.count {
                    return false
                }
                var nameIndex = nameSlice.startIndex
                var lowerIndex = lower.startIndex
                let nameEnd = nameSlice.endIndex
                while nameIndex < nameEnd {
                    if nameSlice[nameIndex] != lower[lowerIndex] {
                        return false
                    }
                    nameIndex = nameSlice.index(after: nameIndex)
                    lowerIndex = lower.index(after: lowerIndex)
                }
                return true
            }
            return false
        }
        
        @discardableResult
        func name(_ name: [UInt8]) -> Tag {
            _tagName = name
            _tagNameS = nil
            _normalName = nil
            _tagNameHasUppercase = Attributes.containsAsciiUppercase(name)
            tagId = .none
            return self
        }


        @inline(__always)
        func attributesAreNormalized() -> Bool {
            return _attributesAreNormalized
        }

        @inline(__always)
        func hasUppercaseAttributeNames() -> Bool {
            return _hasUppercaseAttributeNames
        }
        
        @inline(__always)
        func isSelfClosing() -> Bool {
            return _selfClosing
        }
        
        @inline(__always)
        func getAttributes() -> Attributes {
            ensureAttributes()
            if _attributes == nil {
                _attributes = Attributes()
            }
            return _attributes!
        }

        @inline(__always)
        func ensureAttributes() {
            guard let pendingAttributes = _pendingAttributes, !pendingAttributes.isEmpty else { return }
            if _attributes == nil {
                _attributes = Attributes()
            }
            for pending in pendingAttributes {
                _attributes?.appendPending(pending)
            }
            _pendingAttributes?.removeAll(keepingCapacity: true)
        }
        
        // these appenders are rarely hit in not null state-- caused by null chars.
        @inline(__always)
        func appendTagName(_ append: [UInt8]) {
            appendTagName(append[...])
        }
        
        // these appenders are rarely hit in not null state-- caused by null chars.
        @inline(__always)
        func appendTagName(_ append: ArraySlice<UInt8>) {
            appendTagName(append, hasUppercase: Attributes.containsAsciiUppercase(append))
        }

        @inline(__always)
        func appendTagName(_ append: ArraySlice<UInt8>, hasUppercase: Bool) {
            guard !append.isEmpty else { return }
            tagId = .none
            if _tagName == nil {
                if _tagNameS == nil {
                    _tagNameS = append
                } else {
                    ensureTagName()
                    _tagName!.append(contentsOf: append)
                }
            } else {
                _tagName!.append(contentsOf: append)
            }
            if !_tagNameHasUppercase && hasUppercase {
                _tagNameHasUppercase = true
            }
            _normalName = nil
        }
        
        @inline(__always)
        func appendTagName(_ append: UnicodeScalar) {
            appendTagName(ArraySlice(append.utf8))
        }

        @inline(__always)
        func appendTagNameByte(_ byte: UInt8) {
            tagId = .none
            ensureTagName()
            _tagName!.append(byte)
            if !_tagNameHasUppercase, byte >= 65 && byte <= 90 {
                _tagNameHasUppercase = true
            }
            _normalName = nil
        }

        @inline(__always)
        func appendTagNameLowercased(_ append: ArraySlice<UInt8>) {
            tagId = .none
            if _tagName == nil {
                if _tagNameS != nil {
                    ensureTagName()
                } else {
                    _tagName = []
                }
            }
            _tagName!.reserveCapacity(_tagName!.count + append.count)
            for b in append {
                if b >= 65 && b <= 90 {
                    _tagName!.append(b &+ 32)
                } else {
                    _tagName!.append(b)
                }
            }
            _tagNameS = nil
            _tagNameHasUppercase = false
            _normalName = nil
        }

        @inline(__always)
        static func tagIdForSlice(_ slice: ArraySlice<UInt8>) -> TagId? {
            let count = slice.count
            if count < packedTagIdEntriesByLength.count,
               let packed = packSlice(slice),
               let id = packedTagIdEntriesByLength[count][packed] {
                return id
            }
            if count < tagIdEntriesByLength.count {
                for entry in tagIdEntriesByLength[count] {
                    if equalsSlice(entry.bytes, slice) {
                        return entry.id
                    }
                }
            }
            return nil
        }

        @inline(__always)
        private static func packBytes(_ bytes: [UInt8]) -> UInt64? {
            let count = bytes.count
            if count == 0 || count > 8 {
                return nil
            }
            var value: UInt64 = 0
            var shift: UInt64 = 0
            for b in bytes {
                value |= (UInt64(b) << shift)
                shift &+= 8
            }
            return value
        }

        @inline(__always)
        private static func packSlice(_ slice: ArraySlice<UInt8>) -> UInt64? {
            let count = slice.count
            if count == 0 || count > 8 {
                return nil
            }
            var value: UInt64 = 0
            var shift: UInt64 = 0
            for b in slice {
                value |= (UInt64(b) << shift)
                shift &+= 8
            }
            return value
        }

        @inline(__always)
        static func tagIdForBytes(_ bytes: [UInt8]) -> TagId? {
            return tagIdForSlice(bytes[...])
        }

        @inline(__always)
        func setTagIdFromSlice(_ slice: ArraySlice<UInt8>) {
            tagId = Self.tagIdForSlice(slice) ?? .none
        }

        @inline(__always)
        private static func equalsSlice(_ array: [UInt8], _ slice: ArraySlice<UInt8>) -> Bool {
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


        @inline(__always)
        func tagIdName() -> [UInt8]? {
            return Self.tagIdName(tagId)
        }

        @inline(__always)
        static func tagIdName(_ tagId: TagId) -> [UInt8]? {
            return tagIdNameLookup[Int(tagId.rawValue)]
        }

        private static let tagIdNameLookup: [[UInt8]?] = {
            var lookup = [[UInt8]?](repeating: nil, count: Int(TagId.rt.rawValue) + 1)
            lookup[Int(TagId.a.rawValue)] = UTF8Arrays.a
            lookup[Int(TagId.span.rawValue)] = UTF8Arrays.span
            lookup[Int(TagId.p.rawValue)] = UTF8Arrays.p
            lookup[Int(TagId.div.rawValue)] = UTF8Arrays.div
            lookup[Int(TagId.em.rawValue)] = UTF8Arrays.em
            lookup[Int(TagId.strong.rawValue)] = UTF8Arrays.strong
            lookup[Int(TagId.b.rawValue)] = UTF8Arrays.b
            lookup[Int(TagId.i.rawValue)] = UTF8Arrays.i
            lookup[Int(TagId.small.rawValue)] = UTF8Arrays.small
            lookup[Int(TagId.li.rawValue)] = UTF8Arrays.li
            lookup[Int(TagId.body.rawValue)] = UTF8Arrays.body
            lookup[Int(TagId.html.rawValue)] = UTF8Arrays.html
            lookup[Int(TagId.head.rawValue)] = UTF8Arrays.head
            lookup[Int(TagId.title.rawValue)] = UTF8Arrays.title
            lookup[Int(TagId.form.rawValue)] = UTF8Arrays.form
            lookup[Int(TagId.br.rawValue)] = UTF8Arrays.br
            lookup[Int(TagId.meta.rawValue)] = UTF8Arrays.meta
            lookup[Int(TagId.img.rawValue)] = UTF8Arrays.img
            lookup[Int(TagId.script.rawValue)] = UTF8Arrays.script
            lookup[Int(TagId.style.rawValue)] = UTF8Arrays.style
            lookup[Int(TagId.caption.rawValue)] = UTF8Arrays.caption
            lookup[Int(TagId.col.rawValue)] = UTF8Arrays.col
            lookup[Int(TagId.colgroup.rawValue)] = UTF8Arrays.colgroup
            lookup[Int(TagId.table.rawValue)] = UTF8Arrays.table
            lookup[Int(TagId.tbody.rawValue)] = UTF8Arrays.tbody
            lookup[Int(TagId.thead.rawValue)] = UTF8Arrays.thead
            lookup[Int(TagId.tfoot.rawValue)] = UTF8Arrays.tfoot
            lookup[Int(TagId.tr.rawValue)] = UTF8Arrays.tr
            lookup[Int(TagId.td.rawValue)] = UTF8Arrays.td
            lookup[Int(TagId.th.rawValue)] = UTF8Arrays.th
            lookup[Int(TagId.input.rawValue)] = UTF8Arrays.input
            lookup[Int(TagId.hr.rawValue)] = UTF8Arrays.hr
            lookup[Int(TagId.select.rawValue)] = UTF8Arrays.select
            lookup[Int(TagId.option.rawValue)] = UTF8Arrays.option
            lookup[Int(TagId.optgroup.rawValue)] = UTF8Arrays.optgroup
            lookup[Int(TagId.textarea.rawValue)] = UTF8Arrays.textarea
            lookup[Int(TagId.noscript.rawValue)] = UTF8Arrays.noscript
            lookup[Int(TagId.noframes.rawValue)] = UTF8Arrays.noframes
            lookup[Int(TagId.plaintext.rawValue)] = UTF8Arrays.plaintext
            lookup[Int(TagId.button.rawValue)] = UTF8Arrays.button
            lookup[Int(TagId.base.rawValue)] = UTF8Arrays.base
            lookup[Int(TagId.frame.rawValue)] = UTF8Arrays.frame
            lookup[Int(TagId.frameset.rawValue)] = UTF8Arrays.frameset
            lookup[Int(TagId.iframe.rawValue)] = UTF8Arrays.iframe
            lookup[Int(TagId.noembed.rawValue)] = UTF8Arrays.noembed
            lookup[Int(TagId.embed.rawValue)] = UTF8Arrays.embed
            lookup[Int(TagId.dd.rawValue)] = UTF8Arrays.dd
            lookup[Int(TagId.dt.rawValue)] = UTF8Arrays.dt
            lookup[Int(TagId.dl.rawValue)] = UTF8Arrays.dl
            lookup[Int(TagId.ol.rawValue)] = UTF8Arrays.ol
            lookup[Int(TagId.ul.rawValue)] = UTF8Arrays.ul
            lookup[Int(TagId.pre.rawValue)] = UTF8Arrays.pre
            lookup[Int(TagId.listing.rawValue)] = UTF8Arrays.listing
            lookup[Int(TagId.address.rawValue)] = UTF8Arrays.address
            lookup[Int(TagId.article.rawValue)] = UTF8Arrays.article
            lookup[Int(TagId.aside.rawValue)] = UTF8Arrays.aside
            lookup[Int(TagId.blockquote.rawValue)] = UTF8Arrays.blockquote
            lookup[Int(TagId.center.rawValue)] = UTF8Arrays.center
            lookup[Int(TagId.dir.rawValue)] = UTF8Arrays.dir
            lookup[Int(TagId.fieldset.rawValue)] = UTF8Arrays.fieldset
            lookup[Int(TagId.figcaption.rawValue)] = UTF8Arrays.figcaption
            lookup[Int(TagId.figure.rawValue)] = UTF8Arrays.figure
            lookup[Int(TagId.footer.rawValue)] = UTF8Arrays.footer
            lookup[Int(TagId.header.rawValue)] = UTF8Arrays.header
            lookup[Int(TagId.hgroup.rawValue)] = UTF8Arrays.hgroup
            lookup[Int(TagId.menu.rawValue)] = UTF8Arrays.menu
            lookup[Int(TagId.nav.rawValue)] = UTF8Arrays.nav
            lookup[Int(TagId.section.rawValue)] = UTF8Arrays.section
            lookup[Int(TagId.summary.rawValue)] = UTF8Arrays.summary
            lookup[Int(TagId.h1.rawValue)] = UTF8Arrays.h1
            lookup[Int(TagId.h2.rawValue)] = UTF8Arrays.h2
            lookup[Int(TagId.h3.rawValue)] = UTF8Arrays.h3
            lookup[Int(TagId.h4.rawValue)] = UTF8Arrays.h4
            lookup[Int(TagId.h5.rawValue)] = UTF8Arrays.h5
            lookup[Int(TagId.h6.rawValue)] = UTF8Arrays.h6
            lookup[Int(TagId.applet.rawValue)] = UTF8Arrays.applet
            lookup[Int(TagId.marquee.rawValue)] = UTF8Arrays.marquee
            lookup[Int(TagId.object.rawValue)] = UTF8Arrays.object
            lookup[Int(TagId.ruby.rawValue)] = UTF8Arrays.ruby
            lookup[Int(TagId.rp.rawValue)] = UTF8Arrays.rp
            lookup[Int(TagId.rt.rawValue)] = UTF8Arrays.rt
            return lookup
        }()

        @inline(__always)
        private func ensureTagName() {
            if _tagName == nil {
                if let tagNameSlice = _tagNameS {
                    _tagName = Array(tagNameSlice)
                    _tagNameS = nil
                } else {
                    _tagName = []
                }
            }
        }

        @inline(__always)
        private static func equalsLowercased(_ name: ArraySlice<UInt8>, _ lower: ArraySlice<UInt8>) -> Bool {
            if name.count != lower.count {
                return false
            }
            var nameIndex = name.startIndex
            var lowerIndex = lower.startIndex
            let nameEnd = name.endIndex
            while nameIndex < nameEnd {
                let b = name[nameIndex]
                let lowerByte = lower[lowerIndex]
                let normalized = (b >= 0x41 && b <= 0x5A) ? (b &+ 0x20) : b
                if normalized != lowerByte {
                    return false
                }
                nameIndex = name.index(after: nameIndex)
                lowerIndex = lower.index(after: lowerIndex)
            }
            return true
        }

        
        @inline(__always)
        func appendAttributeName(_ append: [UInt8]) {
            appendAttributeName(append[...])
        }
        
        @inline(__always)
        func appendAttributeName(_ append: ArraySlice<UInt8>) {
            guard !append.isEmpty else { return }
            if _pendingAttributeName == nil && _pendingAttributeNameS == nil {
                if _lowercaseAttributeNames {
                    var hasUppercase = false
                    for b in append {
                        if b >= 65 && b <= 90 {
                            hasUppercase = true
                            break
                        }
                    }
                    if !hasUppercase {
                        _pendingAttributeNameS = append
                        _pendingAttributeNameHasUppercase = false
                        return
                    }
                } else {
                    _pendingAttributeNameS = append
                    _pendingAttributeNameHasUppercase = Attributes.containsAsciiUppercase(append)
                    if _pendingAttributeNameHasUppercase {
                        _hasUppercaseAttributeNames = true
                    }
                    return
                }
            }
            ensureAttributeName()
            if _lowercaseAttributeNames {
                for b in append {
                    let normalized = (b >= 65 && b <= 90) ? (b &+ 32) : b
                    _pendingAttributeName!.append(normalized)
                }
                _pendingAttributeNameHasUppercase = false
            } else {
                _pendingAttributeName!.append(contentsOf: append)
                if !_pendingAttributeNameHasUppercase {
                    _pendingAttributeNameHasUppercase = Attributes.containsAsciiUppercase(append)
                }
                if _pendingAttributeNameHasUppercase {
                    _hasUppercaseAttributeNames = true
                }
            }
        }
        
        @inline(__always)
        func appendAttributeName(_ append: UnicodeScalar) {
            appendAttributeName(Array(append.utf8))
        }

        @inline(__always)
        func appendAttributeNameByte(_ byte: UInt8) {
            ensureAttributeName()
            if _lowercaseAttributeNames {
                let normalized = (byte >= 65 && byte <= 90) ? (byte &+ 32) : byte
                _pendingAttributeName!.append(normalized)
                _pendingAttributeNameHasUppercase = false
            } else {
                _pendingAttributeName!.append(byte)
                if !_pendingAttributeNameHasUppercase && byte >= 65 && byte <= 90 {
                    _pendingAttributeNameHasUppercase = true
                    _hasUppercaseAttributeNames = true
                }
            }
        }

        @inline(__always)
        func setLowercaseAttributeNames(_ lowercase: Bool) {
            _lowercaseAttributeNames = lowercase
        }

        @inline(__always)
        func setAttributesNormalized(_ normalized: Bool) {
            _attributesAreNormalized = normalized
            if normalized {
                _hasUppercaseAttributeNames = false
            }
        }

        @inline(__always)
        func hasPendingAttributes() -> Bool {
            if let pending = _pendingAttributes {
                return !pending.isEmpty
            }
            return false
        }

        @inline(__always)
        func hasAnyAttributes() -> Bool {
            if let pending = _pendingAttributes, !pending.isEmpty {
                return true
            }
            if let attrs = _attributes {
                return !attrs.attributes.isEmpty || attrs.pendingAttributesCount > 0
            }
            return false
        }
        
        @inline(__always)
        func appendAttributeValue(_ append: ArraySlice<UInt8>) {
            if _pendingAttributeValue.isEmpty {
                if let existing = _pendingAttributeValueS {
                    _pendingAttributeValueSlices = [existing, append]
                    _pendingAttributeValueSlicesCount = existing.count + append.count
                    _pendingAttributeValueS = nil
                    _hasPendingAttributeValue = true
                    return
                }
                if _pendingAttributeValueSlices != nil {
                    _pendingAttributeValueSlices!.append(append)
                    _pendingAttributeValueSlicesCount += append.count
                    _hasPendingAttributeValue = true
                    return
                }
                _pendingAttributeValueS = append
                _hasPendingAttributeValue = true
                return
            }
            ensureAttributeValue()
            _pendingAttributeValue.append(append)
        }
        
        @inline(__always)
        func appendAttributeValue(_ append: UnicodeScalar) {
            ensureAttributeValue()
            _pendingAttributeValue.appendCodePoint(append)
        }

        @inline(__always)
        func appendAttributeValueByte(_ byte: UInt8) {
            ensureAttributeValue()
            _pendingAttributeValue.append(byte)
        }
        
        @inline(__always)
        func appendAttributeValue(_ append: [UnicodeScalar]) {
            ensureAttributeValue()
            _pendingAttributeValue.appendCodePoints(append)
        }
        
        @inline(__always)
        func appendAttributeValue(_ appendCodepoints: [Int]) {
            ensureAttributeValue()
            for codepoint in appendCodepoints {
                _pendingAttributeValue.appendCodePoint(UnicodeScalar(codepoint)!)
            }
        }

        @inline(__always)
        func hasPendingAttributeName() -> Bool {
            if let nameSlice = _pendingAttributeNameS, !nameSlice.isEmpty {
                return true
            }
            if let nameBytes = _pendingAttributeName, !nameBytes.isEmpty {
                return true
            }
            return false
        }
        
        @inline(__always)
        func setEmptyAttributeValue() {
            _hasEmptyAttributeValue = true
        }

        @inline(__always)
        private func ensureAttributeName() {
            if _pendingAttributeName == nil {
                if let pendingSlice = _pendingAttributeNameS {
                    if _lowercaseAttributeNames {
                        var lowercased: [UInt8] = []
                        lowercased.reserveCapacity(pendingSlice.count)
                        for b in pendingSlice {
                            let normalized = (b >= 65 && b <= 90) ? (b &+ 32) : b
                            lowercased.append(normalized)
                        }
                        _pendingAttributeName = lowercased
                        _pendingAttributeNameHasUppercase = false
                    } else {
                        _pendingAttributeName = Array(pendingSlice)
                        _pendingAttributeNameHasUppercase = Attributes.containsAsciiUppercase(pendingSlice)
                    }
                    _pendingAttributeNameS = nil
                } else {
                    _pendingAttributeName = []
                    _pendingAttributeNameHasUppercase = false
                }
            }
        }
        
        @inline(__always)
        private func ensureAttributeValue() {
            _hasPendingAttributeValue = true
            if let slices = _pendingAttributeValueSlices {
                for slice in slices {
                    _pendingAttributeValue.append(slice)
                }
                _pendingAttributeValueSlices = nil
                _pendingAttributeValueSlicesCount = 0
            }
            // if on second hit, we'll need to move to the builder
            if (_pendingAttributeValueS != nil) {
                _pendingAttributeValue.append(_pendingAttributeValueS!)
                _pendingAttributeValueS = nil
            }
        }
    }
    
    final class StartTag: Tag {
        override init() {
            super.init()
            type = TokenType.StartTag
        }
        
        @discardableResult
        @inline(__always)
        override func reset() -> Tag {
            super.reset()
            return self
        }
        
        @discardableResult
        @inline(__always)
        func nameAttr(_ name: [UInt8], _ attributes: Attributes) -> StartTag {
            self._tagName = name
            self._attributes = attributes
            _pendingAttributes = nil
            _normalName = _tagName?.lowercased()
            _attributesAreNormalized = false
            return self
        }
        
        @inline(__always)
        public override func toString() throws -> String {
            ensureAttributes()
            if let _attributes, (!_attributes.attributes.isEmpty || _attributes.pendingAttributesCount > 0) {
                return "<" + String(decoding: try name(), as: UTF8.self) + " " + (try _attributes.toString()) + ">"
            } else {
                return "<" + String(decoding: try name(), as: UTF8.self) + ">"
            }
        }
    }
    
    final class EndTag: Tag {
        override init() {
            super.init()
            type = TokenType.EndTag
        }
        
        @inline(__always)
        public override func toString() throws -> String {
            return "</" + String(decoding: try name(), as: UTF8.self) + ">"
        }
    }
    
    final class Comment: Token {
        let data: StringBuilder = StringBuilder()
        var bogus: Bool = false
        
        @discardableResult
        @inline(__always)
        override func reset() -> Token {
            sourceRange = nil
            Token.reset(data)
            bogus = false
            return self
        }
        
        override init() {
            super.init()
            type = TokenType.Comment
        }
        
        @inline(__always)
        func getData() -> [UInt8] {
            return Array(data.buffer)
        }
        
        @inline(__always)
        public override func toString() throws -> String {
            return "<!--" + String(decoding: getData(), as: UTF8.self) + "-->"
        }
    }
    
    final class Char: Token {
        public var data: [UInt8]?
        public var dataSlice: ArraySlice<UInt8>?
        
        override init() {
            super.init()
            type = TokenType.Char
        }
        
        @discardableResult
        @inline(__always)
        override func reset() -> Token {
            sourceRange = nil
            data = nil
            dataSlice = nil
            return self
        }
        
        @discardableResult
        @inline(__always)
        func data(_ data: [UInt8]) -> Char {
            self.data = data
            self.dataSlice = nil
            return self
        }

        @inline(__always)
        func data(_ dataSlice: ArraySlice<UInt8>) -> Char {
            self.data = nil
            self.dataSlice = dataSlice
            return self
        }

        @inline(__always)
        func getData() -> [UInt8]? {
            if let data {
                return data
            }
            if let dataSlice {
                let materialized = Array(dataSlice)
                self.data = materialized
                self.dataSlice = nil
                return materialized
            }
            return nil
        }

        @inline(__always)
        func getDataSlice() -> ArraySlice<UInt8>? {
            if let dataSlice {
                return dataSlice
            }
            if let data {
                return data[...]
            }
            return nil
        }

        
        @inline(__always)
        public override func toString() throws -> String {
            try Validate.notNull(obj: getData())
            return String(decoding: getData()!, as: UTF8.self)
        }
    }
    
    final class EOF: Token {
        override init() {
            super.init()
            type = Token.TokenType.EOF
        }
        
        @discardableResult
        @inline(__always)
        override func reset() -> Token {
            sourceRange = nil
            return self
        }
    }
    
    @inline(__always)
    func isDoctype() -> Bool {
        return type == TokenType.Doctype
    }
    
    @inline(__always)
    func asDoctype() -> Doctype {
        return self as! Doctype
    }
    
    @inline(__always)
    func isStartTag() -> Bool {
        return type == TokenType.StartTag
    }
    
    @inline(__always)
    func asStartTag() -> StartTag {
        return self as! StartTag
    }
    
    @inline(__always)
    func isEndTag() -> Bool {
        return type == TokenType.EndTag
    }
    
    @inline(__always)
    func asEndTag() -> EndTag {
        return self as! EndTag
    }
    
    @inline(__always)
    func isComment() -> Bool {
        return type == TokenType.Comment
    }
    
    @inline(__always)
    func asComment() -> Comment {
        return self as! Comment
    }
    
    @inline(__always)
    func isCharacter() -> Bool {
        return type == TokenType.Char
    }
    
    @inline(__always)
    func asCharacter() -> Char {
        return self as! Char
    }
    
    @inline(__always)
    func isEOF() -> Bool {
        return type == TokenType.EOF
    }
    
    public enum TokenType {
        case Doctype
        case StartTag
        case EndTag
        case Comment
        case Char
        case EOF
    }
}

extension Token: CustomDebugStringConvertible {
    public var debugDescription: String {
        do {
            return try self.toString()
        } catch {
            return "Error while get string debug"
        }
    }
}
