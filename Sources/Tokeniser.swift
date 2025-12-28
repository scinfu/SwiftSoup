//
//  Tokeniser.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 19/10/16.
//

import Foundation

final class Tokeniser {
    static let replacementChar: UnicodeScalar = "\u{FFFD}" // replaces null character
    // Inline "&" handling in Data/RCDATA state to avoid state transitions for character references.
    private static let notCharRefChars = ParsingStrings([UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ", "<", UnicodeScalar.Ampersand])
    private static let notNamedCharRefChars = ParsingStrings([UTF8Arrays.equalSign, UTF8Arrays.hyphen, UTF8Arrays.underscore])
    private static let ampName = "amp".utf8Array
    private static let ltName = "lt".utf8Array
    private static let gtName = "gt".utf8Array
    private static let quotName = "quot".utf8Array
    private static let aposName = "apos".utf8Array
    private static let nbspName = "nbsp".utf8Array
    private static let copyName = "copy".utf8Array
    private static let regName = "reg".utf8Array
    private static let tradeName = "trade".utf8Array
    private static let ampCodepoints: [UnicodeScalar] = [UnicodeScalar.Ampersand]
    private static let ltCodepoints: [UnicodeScalar] = [UnicodeScalar.LessThan]
    private static let gtCodepoints: [UnicodeScalar] = [UnicodeScalar.GreaterThan]
    private static let quotCodepoints: [UnicodeScalar] = [UnicodeScalar(0x22)!]
    private static let aposCodepoints: [UnicodeScalar] = [UnicodeScalar(0x27)!]
    private static let nbspCodepoints: [UnicodeScalar] = [UnicodeScalar(0xA0)!]
    private static let copyCodepoints: [UnicodeScalar] = [UnicodeScalar(0xA9)!]
    private static let regCodepoints: [UnicodeScalar] = [UnicodeScalar(0xAE)!]
    private static let tradeCodepoints: [UnicodeScalar] = [UnicodeScalar(0x2122)!]
    private static let replacementCodepoints: [UnicodeScalar] = [Tokeniser.replacementChar]
    private static let numericCharRefCache: [[UnicodeScalar]] = {
        var cache = Array(repeating: [UnicodeScalar](), count: 256)
        for i in 0..<256 {
            cache[i] = [UnicodeScalar(i)!]
        }
        return cache
    }()
    private static let notCharRefAsciiTable: [Bool] = {
        var table = [Bool](repeating: false, count: 128)
        table[Int(TokeniserStateVars.tabByte)] = true // \t
        table[Int(TokeniserStateVars.newLineByte)] = true // \n
        table[Int(TokeniserStateVars.carriageReturnByte)] = true // \r
        table[Int(TokeniserStateVars.formFeedByte)] = true // \f
        table[Int(TokeniserStateVars.spaceByte)] = true // space
        table[0x3C] = true // <
        table[0x26] = true // &
        return table
    }()

    @inline(__always)
    internal static func isNotCharRefAscii(_ byte: UInt8) -> Bool {
        return byte < 0x80 && notCharRefAsciiTable[Int(byte)]
    }

    @inline(__always)
    private static func isAsciiDigit(_ byte: UInt8) -> Bool {
        return byte >= 0x30 && byte <= 0x39
    }

    @inline(__always)
    func consumeBasicNamedEntityIfPresent() -> [UnicodeScalar]? {
        guard let b0 = reader.currentByte(), b0 < 0x80 else { return nil }
        let pos = reader.pos
        let end = reader.end
        let input = reader.input
        switch b0 {
        case 0x61: // a -> amp; / apos;
            if pos + 3 < end &&
                input[pos + 1] == 0x6D && // m
                input[pos + 2] == 0x70 && // p
                input[pos + 3] == TokeniserStateVars.semicolonByte {
                reader.pos = pos + 4
                return Self.ampCodepoints
            }
            if pos + 4 < end &&
                input[pos + 1] == 0x70 && // p
                input[pos + 2] == 0x6F && // o
                input[pos + 3] == 0x73 && // s
                input[pos + 4] == TokeniserStateVars.semicolonByte {
                reader.pos = pos + 5
                return Self.aposCodepoints
            }
        case 0x6C: // l -> lt;
            if pos + 2 < end &&
                input[pos + 1] == 0x74 && // t
                input[pos + 2] == TokeniserStateVars.semicolonByte {
                reader.pos = pos + 3
                return Self.ltCodepoints
            }
        case 0x67: // g -> gt;
            if pos + 2 < end &&
                input[pos + 1] == 0x74 && // t
                input[pos + 2] == TokeniserStateVars.semicolonByte {
                reader.pos = pos + 3
                return Self.gtCodepoints
            }
        case 0x71: // q -> quot;
            if pos + 4 < end &&
                input[pos + 1] == 0x75 && // u
                input[pos + 2] == 0x6F && // o
                input[pos + 3] == 0x74 && // t
                input[pos + 4] == TokeniserStateVars.semicolonByte {
                reader.pos = pos + 5
                return Self.quotCodepoints
            }
        case 0x6E: // n -> nbsp;
            if pos + 4 < end &&
                input[pos + 1] == 0x62 && // b
                input[pos + 2] == 0x73 && // s
                input[pos + 3] == 0x70 && // p
                input[pos + 4] == TokeniserStateVars.semicolonByte {
                reader.pos = pos + 5
                return Self.nbspCodepoints
            }
        case 0x63: // c -> copy;
            if pos + 4 < end &&
                input[pos + 1] == 0x6F && // o
                input[pos + 2] == 0x70 && // p
                input[pos + 3] == 0x79 && // y
                input[pos + 4] == TokeniserStateVars.semicolonByte {
                reader.pos = pos + 5
                return Self.copyCodepoints
            }
        case 0x72: // r -> reg;
            if pos + 3 < end &&
                input[pos + 1] == 0x65 && // e
                input[pos + 2] == 0x67 && // g
                input[pos + 3] == TokeniserStateVars.semicolonByte {
                reader.pos = pos + 4
                return Self.regCodepoints
            }
        case 0x74: // t -> trade;
            if pos + 5 < end &&
                input[pos + 1] == 0x72 && // r
                input[pos + 2] == 0x61 && // a
                input[pos + 3] == 0x64 && // d
                input[pos + 4] == 0x65 && // e
                input[pos + 5] == TokeniserStateVars.semicolonByte {
                reader.pos = pos + 6
                return Self.tradeCodepoints
            }
        default:
            break
        }
        return nil
    }

    
    private let reader: CharacterReader // html input
    private let errors: ParseErrorList? // errors found while tokenising
    
    private var state: TokeniserState = TokeniserState.Data // current tokenisation state
    private var isDataState: Bool = true
    private var isEmitPendingFast: Bool = false
    private var emitPending: Token?  // the token we are about to emit on next read
    private var isEmitPending: Bool = false
    private var charsSlice: ArraySlice<UInt8>? = nil // single pending slice to avoid array allocation
    private var charsSliceFromInput: Bool = false
    private var pendingSlices = [ArraySlice<UInt8>]()
    private var pendingSlicesCount: Int = 0
    private var pendingCharRange: SourceRange? = nil
    private var pendingTagStartPos: Int? = nil
    private let charsBuilder: StringBuilder = StringBuilder(256) // buffers characters to output as one token, if more than one emit per read
    let dataBuffer: StringBuilder = StringBuilder(4 * 1024) // buffers data looking for </script>
    
    var tagPending: Token.Tag = Token.Tag() // tag we are building up
    let startPending: Token.StartTag  = Token.StartTag()
    let endPending: Token.EndTag  = Token.EndTag()
    let charPending: Token.Char  = Token.Char()
    let doctypePending: Token.Doctype  = Token.Doctype() // doctype building up
    let commentPending: Token.Comment  = Token.Comment() // comment building up
    private let eofToken: Token.EOF = Token.EOF()
    private var lastStartTag: [UInt8]?  // the last start tag emitted, to test appropriate end tag
    private var lastStartTagId: Token.Tag.TagId = .none
    private var selfClosingFlagAcknowledged: Bool = true
    private let lowercaseAttributeNames: Bool
    private let attributesNormalizedByDefault: Bool
    let lowercaseTagNames: Bool
    private let trackSourceRanges: Bool
    private let trackErrors: Bool
    let trackAttributes: Bool
    
    init(_ reader: CharacterReader, _ errors: ParseErrorList?, _ settings: ParseSettings? = nil) {
        self.reader = reader
        self.errors = errors
        trackErrors = errors?.getMaxSize() ?? 0 > 0
        if let settings {
            lowercaseAttributeNames = !settings.preservesAttributeCase()
            attributesNormalizedByDefault = settings.preservesAttributeCase()
            lowercaseTagNames = !settings.preservesTagCase()
            trackSourceRanges = settings.tracksSourceRanges()
            trackAttributes = settings.tracksAttributes()
        } else {
            lowercaseAttributeNames = false
            attributesNormalizedByDefault = false
            lowercaseTagNames = false
            trackSourceRanges = true
            trackAttributes = true
        }
    }

    @inline(__always)
    func currentByte() -> UInt8? {
        return reader.currentByte()
    }

    @inline(__always)
    func markTagStart(_ pos: Int) {
        if trackSourceRanges {
            pendingTagStartPos = pos
        }
    }

    @inline(__always)
    func ensureTagStart(_ pos: Int) {
        if trackSourceRanges && pendingTagStartPos == nil {
            pendingTagStartPos = pos
        }
    }

    @inline(__always)
    func clearTagStart() {
        pendingTagStartPos = nil
    }
    
    func read() throws -> Token {
        #if PROFILE
        let _p = Profiler.start("Tokeniser.read")
        defer { Profiler.end("Tokeniser.read", _p) }
        #endif
        if (!selfClosingFlagAcknowledged) {
            if trackErrors {
                error("Self closing flag not acknowledged")
            }
            selfClosingFlagAcknowledged = true
        }
        
        #if PROFILE
        let _pLoop = Profiler.start("Tokeniser.read.loop")
        #endif
        while (!isEmitPendingFast) {
            if isDataState {
                if trackSourceRanges {
                    repeat {
                        try readDataStateTracked()
                    } while (!isEmitPendingFast && isDataState)
                } else {
                    repeat {
                        try readDataStateFast()
                    } while (!isEmitPendingFast && isDataState)
                }
                continue
            }
            try state.read(self, reader)
        }
        #if PROFILE
        Profiler.end("Tokeniser.read.loop", _pLoop)
        #endif
        
        if !charsBuilder.isEmpty {
            #if PROFILE
            let _pEmit = Profiler.start("Tokeniser.read.emitBuilder")
            defer { Profiler.end("Tokeniser.read.emitBuilder", _pEmit) }
            #endif
            let str = Array(charsBuilder.buffer)
            charsBuilder.clear()
            // Clear any pending slices, as the builder takes precedence.
            charsSlice = nil
            charsSliceFromInput = false
            pendingSlices.removeAll(keepingCapacity: true)
            pendingSlicesCount = 0
            charPending.sourceRange = nil
            pendingCharRange = nil
            return charPending.data(str)
        } else if let slice = charsSlice {
            #if PROFILE
            let _pEmit = Profiler.start("Tokeniser.read.emitSlice")
            defer { Profiler.end("Tokeniser.read.emitSlice", _pEmit) }
            #endif
            charsSlice = nil
            charsSliceFromInput = false
            charPending.sourceRange = pendingCharRange
            pendingCharRange = nil
            return charPending.data(slice)
        } else if !pendingSlices.isEmpty {
            #if PROFILE
            let _pEmit = Profiler.start("Tokeniser.read.emitSlices")
            defer { Profiler.end("Tokeniser.read.emitSlices", _pEmit) }
            #endif
            if pendingSlices.count == 1 {
                let slice = pendingSlices[0]
                pendingSlices.removeAll(keepingCapacity: true)
                pendingSlicesCount = 0
                charPending.sourceRange = nil
                pendingCharRange = nil
                return charPending.data(slice)
            } else {
                // Combine all the pending slices in one allocation.
                let totalCount = pendingSlicesCount
                if totalCount > 0 {
                    var combined = [UInt8](repeating: 0, count: totalCount)
                    var offset = 0
                    combined.withUnsafeMutableBufferPointer { dst in
                        guard let dstBase = dst.baseAddress else { return }
                        for slice in pendingSlices {
                            let count = slice.count
                            if count == 0 { continue }
                            slice.withUnsafeBufferPointer { src in
                                guard let srcBase = src.baseAddress else { return }
                                dstBase.advanced(by: offset).update(from: srcBase, count: count)
                            }
                            offset += count
                        }
                    }
                    pendingSlices.removeAll(keepingCapacity: true)
                    pendingSlicesCount = 0
                    charPending.sourceRange = nil
                    pendingCharRange = nil
                    return charPending.data(combined)
                } else {
                    var combined = [UInt8]()
                    combined.reserveCapacity(totalCount)
                    for slice in pendingSlices {
                        combined.append(contentsOf: slice)
                    }
                    pendingSlices.removeAll(keepingCapacity: true)
                    pendingSlicesCount = 0
                    charPending.sourceRange = nil
                    pendingCharRange = nil
                    return charPending.data(combined)
                }
            }
        } else {
            #if PROFILE
            let _pEmit = Profiler.start("Tokeniser.read.emitToken")
            defer { Profiler.end("Tokeniser.read.emitToken", _pEmit) }
            #endif
            isEmitPending = false
            isEmitPendingFast = false
            pendingCharRange = nil
            return emitPending!
        }
    }

    
    func emit(_ token: Token) throws {
        try Validate.isFalse(val: isEmitPending, msg: "There is an unread token pending!")
        
        emitPending = token
        isEmitPending = true
        isEmitPendingFast = true
        
        if (token.type == Token.TokenType.StartTag) {
            let startTag: Token.StartTag  = token as! Token.StartTag
            if startTag.tagId != .none {
                lastStartTagId = startTag.tagId
                lastStartTag = nil
            } else {
                lastStartTagId = .none
                lastStartTag = try startTag.name()
            }
            if (startTag._selfClosing) {
                selfClosingFlagAcknowledged = false
            }
        } else if trackErrors && token.type == Token.TokenType.EndTag {
            let endTag: Token.EndTag = token as! Token.EndTag
            if endTag.hasAnyAttributes() {
                endTag.ensureAttributes()
                if !(endTag._attributes?.attributes.isEmpty ?? true) {
                    error("Attributes incorrectly present on end tag")
                }
            }
        }
    }


    @inline(__always)
    func emitEOF() throws {
        try emit(eofToken.reset())
    }

    @inline(__always)
    private func consumeDataTracked() -> ArraySlice<UInt8> {
        return reader.consumeData()
    }

    @inline(__always)
    private func readDataStateTracked() throws {
        #if PROFILE
        let _p = Profiler.start("TokeniserState.Data")
        defer { Profiler.end("TokeniserState.Data", _p) }
        #endif
        let remaining = reader.end - reader.pos
        if reader.canSkipNullCheck, remaining >= 64 {
            let first = reader.input[reader.pos]
            if first == TokeniserStateVars.ampersandByte ||
                first == TokeniserStateVars.lessThanByte {
                try handleDataStateDelimiterTracked()
                return
            }
            let dataStart = reader.pos
            let data = reader.consumeData()
            if !data.isEmpty {
                let dataEnd = reader.pos
                emitRaw(data, start: dataStart, end: dataEnd)
                return
            }
            if reader.pos >= reader.end {
                try emitEOF()
                return
            }
            try handleDataStateDelimiterTracked()
            return
        } else if reader.pos < reader.end {
            let first = reader.input[reader.pos]
            if reader.canSkipNullCheck {
                if first == TokeniserStateVars.ampersandByte ||
                    first == TokeniserStateVars.lessThanByte {
                    try handleDataStateDelimiterTracked()
                    return
                }
            } else if first == TokeniserStateVars.ampersandByte ||
                        first == TokeniserStateVars.lessThanByte ||
                        first == TokeniserStateVars.nullByte {
                try handleDataStateDelimiterTracked()
                return
            }
        }
        let dataStart = reader.pos
        let data = consumeDataTracked()
        if !data.isEmpty {
            let dataEnd = reader.pos
            emitRaw(data, start: dataStart, end: dataEnd)
            return
        }
        if reader.pos >= reader.end {
            try emitEOF()
            return
        }
        try handleDataStateDelimiterTracked()
    }

    @inline(__always)
    private func handleDataStateDelimiterTracked() throws {
        let byte = reader.input[reader.pos]
        switch byte {
        case TokeniserStateVars.ampersandByte: // "&"
            reader.advanceAscii()
            try TokeniserState.readCharRef(self, .Data)
            return
        case TokeniserStateVars.lessThanByte: // "<"
            markTagStart(reader.pos)
            reader.advanceAscii()
            if reader.pos >= reader.end {
                error(.Data)
                clearTagStart()
                emit(UnicodeScalar.LessThan)
                transition(.Data)
                return
            }
            let next = reader.input[reader.pos]
            if next < 0x80, TokeniserStateVars.isAsciiAlpha(next) {
                if try TokeniserState.readTagNameFromTagOpen(self, reader, true) {
                    return
                }
                return
            }
            switch next {
            case TokeniserStateVars.bangByte: // "!"
                advanceTransitionAscii(.MarkupDeclarationOpen)
            case TokeniserStateVars.slashByte: // "/"
                reader.advanceAscii()
                if reader.isEmpty() {
                    eofError(.Data)
                    clearTagStart()
                    emit(UTF8Arrays.endTagStart)
                    transition(.Data)
                    return
                }
                let endByte = reader.currentByte()!
                if endByte < 0x80 {
                    if TokeniserStateVars.isAsciiAlpha(endByte) {
                        if try TokeniserState.readTagNameFromTagOpen(self, reader, false) {
                            return
                        }
                        return
                    }
                    if endByte == TokeniserStateVars.greaterThanByte {
                        error(.Data)
                        clearTagStart()
                        advanceTransition(.Data)
                    } else {
                        error(.Data)
                        clearTagStart()
                        advanceTransition(.BogusComment)
                    }
                } else if reader.matchesLetter() {
                    createTagPending(false)
                    try TokeniserState.readTagName(.TagName, self, reader)
                    return
                } else {
                    error(.Data)
                    clearTagStart()
                    advanceTransition(.BogusComment)
                }
            case TokeniserStateVars.questionMarkByte: // "?"
                advanceTransitionAscii(.BogusComment)
            default:
                if next >= 0x80, reader.matchesLetter() {
                    createTagPending(true)
                    try TokeniserState.readTagName(.TagName, self, reader)
                    return
                }
                error(.Data)
                emit(UnicodeScalar.LessThan)
                transition(.Data)
            }
        case TokeniserStateVars.nullByte:
            error(.Data)
            reader.advanceAscii()
            emit(UnicodeScalar(0x00))
        default:
            break
        }
    }

    @inline(__always)
    private func readDataStateFast() throws {
        if reader.pos >= reader.end {
            try emitEOF()
            return
        }
        let remaining = reader.end - reader.pos
        if reader.canSkipNullCheck, remaining >= 64 {
            let first = reader.input[reader.pos]
            if first == TokeniserStateVars.ampersandByte ||
                first == TokeniserStateVars.lessThanByte {
                try handleDataStateDelimiter()
                return
            }
            let data = reader.consumeData()
            if !data.isEmpty {
                emitInputSlice(data)
                return
            }
            if reader.pos >= reader.end {
                try emitEOF()
                return
            }
            try handleDataStateDelimiter()
            return
        } else {
            let first = reader.input[reader.pos]
            if reader.canSkipNullCheck {
                if first == TokeniserStateVars.ampersandByte ||
                    first == TokeniserStateVars.lessThanByte {
                    try handleDataStateDelimiter()
                    return
                }
            } else if first == TokeniserStateVars.ampersandByte ||
                        first == TokeniserStateVars.lessThanByte ||
                        first == TokeniserStateVars.nullByte {
                try handleDataStateDelimiter()
                return
            }
        }
        let data = reader.consumeData()
        if !data.isEmpty {
            emitInputSlice(data)
            return
        }
        if reader.pos >= reader.end {
            try emitEOF()
            return
        }
        try handleDataStateDelimiter()
    }

    @inline(__always)
    private func handleDataStateDelimiter() throws {
        let byte = reader.input[reader.pos]
        switch byte {
        case TokeniserStateVars.ampersandByte: // "&"
            reader.advanceAscii()
            try TokeniserState.readCharRef(self, .Data)
            return
        case TokeniserStateVars.lessThanByte: // "<"
            reader.advanceAscii()
            if reader.pos >= reader.end {
                error(.Data)
                emit(UnicodeScalar.LessThan)
                transition(.Data)
                return
            }
            let next = reader.input[reader.pos]
            if next < 0x80, TokeniserStateVars.isAsciiAlpha(next) {
                if try TokeniserState.readTagNameFromTagOpen(self, reader, true) {
                    return
                }
                return
            }
            switch next {
            case TokeniserStateVars.bangByte: // "!"
                advanceTransitionAscii(.MarkupDeclarationOpen)
            case TokeniserStateVars.slashByte: // "/"
                reader.advanceAscii()
                if reader.isEmpty() {
                    eofError(.Data)
                    emit(UTF8Arrays.endTagStart)
                    transition(.Data)
                    return
                }
                let endByte = reader.currentByte()!
                if endByte < 0x80 {
                    if TokeniserStateVars.isAsciiAlpha(endByte) {
                        if try TokeniserState.readTagNameFromTagOpen(self, reader, false) {
                            return
                        }
                        return
                    }
                    if endByte == TokeniserStateVars.greaterThanByte {
                        error(.Data)
                        advanceTransition(.Data)
                    } else {
                        error(.Data)
                        advanceTransition(.BogusComment)
                    }
                } else if reader.matchesLetter() {
                    createTagPending(false)
                    try TokeniserState.readTagName(.TagName, self, reader)
                    return
                } else {
                    error(.Data)
                    advanceTransition(.BogusComment)
                }
            case TokeniserStateVars.questionMarkByte: // "?"
                advanceTransitionAscii(.BogusComment)
            default:
                if next >= 0x80, reader.matchesLetter() {
                    createTagPending(true)
                    try TokeniserState.readTagName(.TagName, self, reader)
                    return
                }
                error(.Data)
                emit(UnicodeScalar.LessThan)
                transition(.Data)
            }
        case TokeniserStateVars.nullByte:
            error(.Data)
            reader.advanceAscii()
            emit(UnicodeScalar(0x00))
        default:
            break
        }
    }

    @inline(__always)
    func emitRaw(_ str: ArraySlice<UInt8>, start: Int, end: Int) {
        if trackSourceRanges {
            if charsBuilder.isEmpty && charsSlice == nil && pendingSlices.isEmpty {
                pendingCharRange = SourceRange(start: start, end: end)
            } else {
                pendingCharRange = nil
            }
        } else {
            pendingCharRange = nil
        }
        emitInputSlice(str)
    }
    
    @inline(__always)
    private func emitInputSlice(_ str: ArraySlice<UInt8>) {
        if pendingCharRange != nil, (!charsBuilder.isEmpty || charsSlice != nil || !pendingSlices.isEmpty) {
            pendingCharRange = nil
        }
        if !charsBuilder.isEmpty {
            charsBuilder.append(str)
            return
        }
        if let existing = charsSlice {
            if charsSliceFromInput, existing.endIndex == str.startIndex {
                charsSlice = reader.input[existing.startIndex..<str.endIndex]
                return
            }
            if pendingSlices.isEmpty {
                pendingSlices.append(existing)
                pendingSlicesCount = existing.count
            }
            pendingSlices.append(str)
            pendingSlicesCount &+= str.count
            charsSlice = nil
            charsSliceFromInput = false
        } else if pendingSlices.isEmpty {
            charsSlice = str
            charsSliceFromInput = true
        } else {
            pendingSlices.append(str)
            pendingSlicesCount &+= str.count
        }
    }

    func emit(_ str: ArraySlice<UInt8>) {
        if pendingCharRange != nil, (!charsBuilder.isEmpty || charsSlice != nil || !pendingSlices.isEmpty) {
            pendingCharRange = nil
        }
        if !charsBuilder.isEmpty {
            charsBuilder.append(str)
            return
        }
        if let existing = charsSlice {
            if pendingSlices.isEmpty {
                pendingSlices.append(existing)
                pendingSlicesCount = existing.count
            }
            pendingSlices.append(str)
            pendingSlicesCount &+= str.count
            charsSlice = nil
            charsSliceFromInput = false
        } else if pendingSlices.isEmpty {
            charsSlice = str
            charsSliceFromInput = false
        } else {
            pendingSlices.append(str)
            pendingSlicesCount &+= str.count
        }
    }
    
    func emit(_ str: [UInt8]) {
        emit(str[...]) // Call the slice version with the full array as a slice
    }
    
    func emit(_ str: String) {
        pendingCharRange = nil
        if !charsBuilder.isEmpty {
            charsBuilder.append(str)
            return
        }
        emit(str.utf8Array)
    }
    
    //    func emit(_ chars: [UInt8]) {
    //        emit(String(chars.map {Character($0)}))
    //    }
    
    //    func emit(_ codepoints: [Int]) {
    //        emit(String(codepoints, 0, codepoints.length));
    //    }
    
    @inline(__always)
    private func ensureCharsBuilderForAppend() {
        if let existing = charsSlice {
            charsBuilder.append(existing)
            charsSlice = nil
            charsSliceFromInput = false
        }
        if !pendingSlices.isEmpty {
            for slice in pendingSlices {
                charsBuilder.append(slice)
            }
            pendingSlices.removeAll()
            pendingSlicesCount = 0
        }
    }

    func emit(_ c: UnicodeScalar) {
        pendingCharRange = nil
        let val = c.value
        if val < 0x80 {
            emitByte(UInt8(val))
            return
        }
        ensureCharsBuilderForAppend()
        charsBuilder.appendCodePoint(c)
    }

    @inline(__always)
    func emitByte(_ byte: UInt8) {
        ensureCharsBuilderForAppend()
        charsBuilder.append(byte)
    }
    
    func emit(_ c: [UnicodeScalar]) {
        pendingCharRange = nil
        guard !c.isEmpty else { return }
        ensureCharsBuilderForAppend()
        for scalar in c {
            charsBuilder.appendCodePoint(scalar)
        }
    }
    
    func getState() -> TokeniserState {
        return state
    }
    
    func transition(_ state: TokeniserState) {
        self.state = state
        isDataState = state == .Data
    }
    
    func advanceTransition(_ state: TokeniserState) {
        reader.advance()
        self.state = state
        isDataState = state == .Data
    }
    
    @inline(__always)
    func advanceTransitionAscii(_ state: TokeniserState) {
        reader.advanceAscii()
        self.state = state
        isDataState = state == .Data
    }
    
    func acknowledgeSelfClosingFlag() {
        selfClosingFlagAcknowledged = true
    }
    
    func consumeCharacterReference(_ additionalAllowedCharacter: UnicodeScalar?, _ inAttribute: Bool) throws -> [UnicodeScalar]? {
        #if PROFILE
        let _p = Profiler.start("Tokeniser.consumeCharacterReference")
        defer { Profiler.end("Tokeniser.consumeCharacterReference", _p) }
        #endif
        if (reader.isEmpty()) {
            return nil
        }
        if let allowed = additionalAllowedCharacter, let byte = reader.currentByte(), byte < 0x80 {
            if allowed.value == UInt32(byte) {
                return nil
            }
        } else if (additionalAllowedCharacter != nil && additionalAllowedCharacter == reader.current()) {
            return nil
        }
        if let byte = reader.currentByte(), byte < 0x80 {
            if Tokeniser.isNotCharRefAscii(byte) {
                return nil
            }
        } else if (reader.matchesAny(Tokeniser.notCharRefChars)) {
            return nil
        }

        if inAttribute {
            if let b = reader.currentByte(), b < 0x80,
               (TokeniserStateVars.isAsciiAlpha(b) || Tokeniser.isAsciiDigit(b)) {
                let start = reader.pos
                var i = start
                let end = reader.end
                while i < end {
                    let c = reader.input[i]
                    if c == UTF8Arrays.semicolon[0] { // ";"
                        break
                    }
                    if c == TokeniserStateVars.equalSignByte ||
                        c == TokeniserStateVars.hyphenByte ||
                        c == UTF8Arrays.underscore[0] {
                        // Fast reject for attribute values like "&token=..." which can't form a character reference.
                        return nil
                    }
                    if !TokeniserStateVars.isAsciiAlpha(c) && !Tokeniser.isAsciiDigit(c) {
                        break
                    }
                    if i - start >= 31 {
                        break
                    }
                    i &+= 1
                }
            }
        }
        if let b = reader.currentByte(),
           b == TokeniserStateVars.hashByte {
            let start = reader.pos
            var i = start &+ 1
            let end = reader.end
            if i >= end {
                characterReferenceError("numeric reference with no numerals")
                return nil
            }
            var isHexMode = false
            let first = reader.input[i]
            if first == TokeniserStateVars.lowerXByte || first == TokeniserStateVars.upperXByte {
                isHexMode = true
                i &+= 1
            }
            let base = isHexMode ? 16 : 10
            var value = 0
            var consumed = false
            var overflow = false
            while i < end {
                let byte = reader.input[i]
                if byte >= 0x80 { break }
                let digit: Int
                if byte >= 48 && byte <= 57 {
                    digit = Int(byte - 48)
                } else if isHexMode && byte >= 65 && byte <= 70 {
                    digit = 10 + Int(byte - 65)
                } else if isHexMode && byte >= 97 && byte <= 102 {
                    digit = 10 + Int(byte - 97)
                } else {
                    break
                }
                consumed = true
                if !overflow {
                    if value > (Int.max - digit) / base {
                        overflow = true
                    } else {
                        value = value * base + digit
                    }
                }
                i &+= 1
            }
            if !consumed {
                characterReferenceError("numeric reference with no numerals")
                return nil
            }
            reader.pos = i
            if let endByte = reader.currentByte(), endByte == TokeniserStateVars.semicolonByte {
                reader.advanceAscii()
            } else {
                characterReferenceError("missing semicolon")
            }
            let charval = overflow ? -1 : value
            if (charval == -1 || (charval >= 0xD800 && charval <= 0xDFFF) || charval > 0x10FFFF) {
                characterReferenceError("character outside of valid range")
                return Self.replacementCodepoints
            }
            if charval >= 0, charval < 256 {
                return Self.numericCharRefCache[charval]
            }
            return [UnicodeScalar(charval)!]
        }

        // named
        reader.markPos()
        do {
            @inline(__always)
            func fastNamedEntity(_ name: [UInt8], _ codepoints: [UnicodeScalar]) -> [UnicodeScalar]? {
                let pos = reader.pos
                let end = reader.end
                let input = reader.input
                let count = name.count
                if pos + count > end { return nil }
                for i in 0..<count {
                    if input[pos + i] != name[i] { return nil }
                }
                let nextIndex = pos + count
                if nextIndex < end {
                    let nb = input[nextIndex]
                    if nb >= 0x80 { return nil } // let slow path handle unicode letters/digits
                    if TokeniserStateVars.isAsciiAlpha(nb) || Tokeniser.isAsciiDigit(nb) {
                        return nil // not an exact match
                    }
                if inAttribute && (nb == 0x3D || nb == 0x2D || nb == 0x5F) {
                    return nil
                }
            }
            reader.pos = nextIndex
            if nextIndex < end, input[nextIndex] == UTF8Arrays.semicolon[0] { // ";"
                reader.pos = nextIndex + 1
            } else {
                characterReferenceError("missing semicolon")
            }
            return codepoints
        }

            if let b = reader.currentByte(), b < 0x80 {
                switch b {
                case 0x61: // a
                    if let fast = fastNamedEntity(Self.ampName, Self.ampCodepoints) { return fast }
                    if let fast = fastNamedEntity(Self.aposName, Self.aposCodepoints) { return fast }
                case 0x6C: // l
                    if let fast = fastNamedEntity(Self.ltName, Self.ltCodepoints) { return fast }
                case 0x67: // g
                    if let fast = fastNamedEntity(Self.gtName, Self.gtCodepoints) { return fast }
                case 0x71: // q
                    if let fast = fastNamedEntity(Self.quotName, Self.quotCodepoints) { return fast }
                default:
                    break
                }
            }
             // get as many letters as possible, and look for matching entities.
            let nameRef: ArraySlice<UInt8>
            if let b = reader.currentByte(), b < 0x80,
               TokeniserStateVars.isAsciiAlpha(b) {
                let start = reader.pos
                var i = start
                let end = reader.end
                var hitNonAscii = false
                while i < end {
                    let c = reader.input[i]
                    if c >= 0x80 {
                        hitNonAscii = true
                        break
                    }
                    if TokeniserStateVars.isAsciiAlpha(c) {
                        i &+= 1
                        continue
                    }
                    break
                }
                var j = i
                while j < end {
                    let c = reader.input[j]
                    if c >= 0x80 {
                        hitNonAscii = true
                        break
                    }
                    if Tokeniser.isAsciiDigit(c) {
                        j &+= 1
                        continue
                    }
                    break
                }
                if hitNonAscii {
                    reader.pos = start
                    nameRef = reader.consumeLetterThenDigitSequence()
                } else {
                    reader.pos = j
                    nameRef = reader.input[start..<j]
                }
            } else {
                nameRef = reader.consumeLetterThenDigitSequence()
            }
            let looksLegit: Bool = (reader.currentByte() == UTF8Arrays.semicolon[0])
            let points = Entities.lookupNamedEntity(nameRef, allowExtended: looksLegit)
            if points == nil {
                reader.rewindToMark()
                if (looksLegit) { // named with semicolon
                    characterReferenceError("invalid named reference '\(nameRef)'")
                }
                return nil
            }
            if inAttribute {
                if let byte = reader.currentByte(), byte < 0x80 {
                    if TokeniserStateVars.isAsciiAlpha(byte) || Tokeniser.isAsciiDigit(byte) || byte == 0x3D || byte == 0x2D || byte == 0x5F {
                        // don't want that to match
                        reader.rewindToMark()
                        return nil
                    }
                } else if (reader.matchesLetter() || reader.matchesDigit() || reader.matchesAny(Self.notNamedCharRefChars)) {
                    // don't want that to match
                    reader.rewindToMark()
                    return nil
                }
            }
            if let endByte = reader.currentByte(), endByte == UTF8Arrays.semicolon[0] { // ";"
                reader.advanceAscii()
            } else {
                characterReferenceError("missing semicolon") // missing semi
            }
            if let points {
                if points.count > 2 {
                    try Validate.fail(msg: "Unexpected characters returned for \(nameRef) num: \(points.count)")
                }
                return points
            }
            try Validate.fail(msg: "Entity name not found: \(nameRef)")
            return []
        } 
    }


    
    @discardableResult
    @inlinable
    func createTagPending(_ start: Bool) -> Token.Tag {
        if start {
            startPending.reset()
            tagPending = startPending
        } else {
            endPending.reset()
            tagPending = endPending
        }
        tagPending.setLowercaseAttributeNames(lowercaseAttributeNames)
        tagPending.setAttributesNormalized(attributesNormalizedByDefault || lowercaseAttributeNames)
        return tagPending
    }
    
    @inlinable
    func emitTagPending() throws {
        try tagPending.finaliseTag()
        if trackSourceRanges, let start = pendingTagStartPos {
            tagPending.sourceRange = SourceRange(start: start, end: reader.pos)
        } else {
            tagPending.sourceRange = nil
        }
        pendingTagStartPos = nil
        try emit(tagPending)
    }
    
    func createCommentPending() {
        commentPending.reset()
    }
    
    func emitCommentPending() throws {
        if trackSourceRanges, let start = pendingTagStartPos {
            commentPending.sourceRange = SourceRange(start: start, end: reader.pos)
        } else {
            commentPending.sourceRange = nil
        }
        pendingTagStartPos = nil
        try emit(commentPending)
    }
    
    func createDoctypePending() {
        doctypePending.reset()
    }
    
    func emitDoctypePending() throws {
        if trackSourceRanges, let start = pendingTagStartPos {
            doctypePending.sourceRange = SourceRange(start: start, end: reader.pos)
        } else {
            doctypePending.sourceRange = nil
        }
        pendingTagStartPos = nil
        try emit(doctypePending)
    }
    
    func createTempBuffer() {
        Token.reset(dataBuffer)
    }
    
    func isAppropriateEndTagToken()throws->Bool {
        if lastStartTagId != .none {
            if tagPending.tagId == .none, let nameSlice = tagPending.normalNameSlice() {
                tagPending.setTagIdFromSlice(nameSlice)
            }
            if tagPending.tagId != .none {
                return tagPending.tagId == lastStartTagId
            }
            if let lastName = Token.Tag.tagIdName(lastStartTagId) {
                if let slice = tagPending.tagNameSlice() {
                    return Tokeniser.equalsIgnoreCase(slice, lastName)
                }
                let s = try tagPending.name()
                return s.equalsIgnoreCase(string: lastName)
            }
            return false
        }
        if let lastStartTag {
            if let slice = tagPending.tagNameSlice() {
                return Tokeniser.equalsIgnoreCase(slice, lastStartTag)
            }
            let s = try tagPending.name()
            return s.equalsIgnoreCase(string: lastStartTag)
        }
        return false
    }
    
    func appropriateEndTagName() -> [UInt8]? {
        if lastStartTagId != .none {
            return Token.Tag.tagIdName(lastStartTagId)
        }
        if (lastStartTag == nil) {
            return nil
        }
        return lastStartTag
    }

    @inline(__always)
    private static func equalsIgnoreCase(_ lhs: ArraySlice<UInt8>, _ rhs: [UInt8]) -> Bool {
        if lhs.count != rhs.count {
            return false
        }
        var i = lhs.startIndex
        for b in rhs {
            let l = lhs[i]
            let lowerL = (l >= 65 && l <= 90) ? l &+ 32 : l
            let lowerR = (b >= 65 && b <= 90) ? b &+ 32 : b
            if lowerL != lowerR {
                return false
            }
            i = lhs.index(after: i)
        }
        return true
    }
    
    func error(_ state: TokeniserState) {
        if !trackErrors {
            return
        }
        if (errors != nil && errors!.canAddError()) {
            errors?.add(ParseError(reader.getPos(), "Unexpected character '\(String(reader.current()))' in input state [\(state.description)]"))
        }
    }
    
    func eofError(_ state: TokeniserState) {
        if !trackErrors {
            return
        }
        if (errors != nil && errors!.canAddError()) {
            errors?.add(ParseError(reader.getPos(), "Unexpectedly reached end of file (EOF) in input state [\(state.description)]"))
        }
    }
    
    private func characterReferenceError(_ message: String) {
        if !trackErrors {
            return
        }
        if (errors != nil && errors!.canAddError()) {
            errors?.add(ParseError(reader.getPos(), "Invalid character reference: \(message)"))
        }
    }
    
    private func error(_ errorMsg: String) {
        if !trackErrors {
            return
        }
        if (errors != nil && errors!.canAddError()) {
            errors?.add(ParseError(reader.getPos(), errorMsg))
        }
    }
    
    func currentNodeInHtmlNS() -> Bool {
        // todo: implement namespaces correctly
        return true
        // Element currentNode = currentNode()
        // return currentNode != null && currentNode.namespace().equals("HTML")
    }
    
    /**
     Utility method to consume reader and unescape entities found within.
     - parameter inAttribute:
     - returns: unescaped string from reader
     */
    func unescapeEntities(_ inAttribute: Bool) throws -> [UInt8] {
        #if PROFILE
        let _p = Profiler.start("Tokeniser.unescapeEntities")
        defer { Profiler.end("Tokeniser.unescapeEntities", _p) }
        #endif
        let builder: StringBuilder = StringBuilder()
        while (!reader.isEmpty()) {
            builder.append(reader.consumeTo(UnicodeScalar.Ampersand))
            if reader.matches(UnicodeScalar.Ampersand) {
                reader.consume()
                if let c = try consumeCharacterReference(nil, inAttribute) {
                    if c.isEmpty {
                        builder.append(UnicodeScalar.Ampersand)
                    } else {
                        builder.appendCodePoint(c[0])
                        if (c.count == 2) {
                            builder.appendCodePoint(c[1])
                        }
                    }
                } else {
                    builder.append(UnicodeScalar.Ampersand)
                }
            }
        }
        return Array(builder.buffer)
    }
}
