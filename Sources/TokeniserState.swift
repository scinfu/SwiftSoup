//
//  TokeniserState.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 12/10/16.
//

import Foundation

protocol TokeniserStateProtocol {
    func read(_ t: Tokeniser, _ r: CharacterReader)throws
}

public class TokeniserStateVars {
	public static let nullScalr: UnicodeScalar = "\u{0000}"
    public static let nullScalrUTF8 = "\u{0000}".utf8Array
    public static let nullScalrUTF8Slice = ArraySlice(nullScalrUTF8)
    @usableFromInline static let tabByte: UInt8 = 0x09
    @usableFromInline static let newLineByte: UInt8 = 0x0A
    @usableFromInline static let carriageReturnByte: UInt8 = 0x0D
    @usableFromInline static let formFeedByte: UInt8 = 0x0C
    @usableFromInline static let verticalTabByte: UInt8 = 0x0B
    @usableFromInline static let spaceByte: UInt8 = 0x20
    @usableFromInline static let slashByte: UInt8 = 0x2F
    @usableFromInline static let greaterThanByte: UInt8 = 0x3E
    @usableFromInline static let lessThanByte: UInt8 = 0x3C
    @usableFromInline static let equalSignByte: UInt8 = 0x3D
    @usableFromInline static let ampersandByte: UInt8 = 0x26
    @usableFromInline static let quoteByte: UInt8 = 0x22
    @usableFromInline static let apostropheByte: UInt8 = 0x27
    @usableFromInline static let backtickByte: UInt8 = 0x60
    @usableFromInline static let nullByte: UInt8 = 0x00
    @usableFromInline static let hyphenByte: UInt8 = 0x2D
    @usableFromInline static let bangByte: UInt8 = 0x21
    @usableFromInline static let questionMarkByte: UInt8 = 0x3F
    @usableFromInline static let semicolonByte: UInt8 = 0x3B
    @usableFromInline static let hashByte: UInt8 = 0x23
    @usableFromInline static let commaByte: UInt8 = 0x2C
    @usableFromInline static let plusByte: UInt8 = 0x2B
    @usableFromInline static let tildeByte: UInt8 = 0x7E
    @usableFromInline static let colonByte: UInt8 = 0x3A
    @usableFromInline static let pipeByte: UInt8 = 0x7C
    @usableFromInline static let dotByte: UInt8 = 0x2E
    @usableFromInline static let leftBracketByte: UInt8 = 0x5B
    @usableFromInline static let rightBracketByte: UInt8 = 0x5D
    @usableFromInline static let underscoreByte: UInt8 = 0x5F
    @usableFromInline static let zeroByte: UInt8 = 0x30
    @usableFromInline static let nineByte: UInt8 = 0x39
    @usableFromInline static let upperAByte: UInt8 = 0x41
    @usableFromInline static let upperZByte: UInt8 = 0x5A
    @usableFromInline static let lowerAByte: UInt8 = 0x61
    @usableFromInline static let lowerZByte: UInt8 = 0x7A
    @usableFromInline static let asciiUpperLimitByte: UInt8 = 0x80
    @usableFromInline static let asciiCaseDeltaByte: UInt8 = 0x20
    @usableFromInline static let maxByte: UInt8 = 0xFF
    @usableFromInline static let lowerBByte: UInt8 = 0x62
    @usableFromInline static let lowerCByte: UInt8 = 0x63
    @usableFromInline static let lowerDByte: UInt8 = 0x64
    @usableFromInline static let lowerEByte: UInt8 = 0x65
    @usableFromInline static let lowerGByte: UInt8 = 0x67
    @usableFromInline static let lowerLByte: UInt8 = 0x6C
    @usableFromInline static let lowerMByte: UInt8 = 0x6D
    @usableFromInline static let lowerNByte: UInt8 = 0x6E
    @usableFromInline static let lowerOByte: UInt8 = 0x6F
    @usableFromInline static let lowerPByte: UInt8 = 0x70
    @usableFromInline static let lowerQByte: UInt8 = 0x71
    @usableFromInline static let lowerRByte: UInt8 = 0x72
    @usableFromInline static let lowerSByte: UInt8 = 0x73
    @usableFromInline static let lowerTByte: UInt8 = 0x74
    @usableFromInline static let lowerUByte: UInt8 = 0x75
    @usableFromInline static let lowerYByte: UInt8 = 0x79
    @usableFromInline static let lowerXByte: UInt8 = 0x78
    @usableFromInline static let upperXByte: UInt8 = 0x58
    @inline(__always)
    static func isAsciiAlpha(_ byte: UInt8) -> Bool {
        let lower = byte | asciiCaseDeltaByte
        return lower >= lowerAByte && lower <= lowerZByte
    }

    static let attributeSingleValueChars = ParsingStrings(["'", UnicodeScalar.Ampersand, nullScalr])
    static let attributeDoubleValueChars = ParsingStrings(["\"", UnicodeScalar.Ampersand, nullScalr])
    static let attributeNameChars = ParsingStrings([UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ", "/", "=", ">", nullScalr, "\"", "'", UnicodeScalar.LessThan])
    static let attributeValueUnquoted = ParsingStrings([UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ", UnicodeScalar.Ampersand, ">", nullScalr, "\"", "'", UnicodeScalar.LessThan, "=", "`"])
    
    static let dataDefaultStopChars = ParsingStrings([UnicodeScalar.Ampersand, UnicodeScalar.LessThan, TokeniserStateVars.nullScalr])
    static let scriptDataDefaultStopChars = ParsingStrings(["-", UnicodeScalar.LessThan, TokeniserStateVars.nullScalr])
    static let commentDefaultStopChars = ParsingStrings(["-", TokeniserStateVars.nullScalr])
    static let readDataDefaultStopChars = ParsingStrings([UnicodeScalar.LessThan, TokeniserStateVars.nullScalr])


    static let replacementChar: UnicodeScalar = Tokeniser.replacementChar
    static let replacementStr: [UInt8] = Array(Tokeniser.replacementChar.utf8)
    static let eof: UnicodeScalar = CharacterReader.EOF
    static let eofUTF8 = String(CharacterReader.EOF).utf8Array
    @usableFromInline
    static let eofUTF8Storage = ByteStorage(array: eofUTF8)
    @usableFromInline
    static let eofUTF8Slice = ByteSlice(storage: eofUTF8Storage, start: 0, end: eofUTF8.count)
    static let commentStartUTF8 = "--".utf8Array
    static let doctypeUTF8 = "DOCTYPE".utf8Array
    static let cdataStartUTF8 = "[CDATA[".utf8Array
    static let cdataEndUTF8 = "]]>".utf8Array
    @usableFromInline static let quoteCodepoint: UInt32 = 0x22
    @usableFromInline static let aposCodepoint: UInt32 = 0x27
    @usableFromInline static let nbspCodepoint: UInt32 = 0xA0
    @usableFromInline static let copyCodepoint: UInt32 = 0xA9
    @usableFromInline static let regCodepoint: UInt32 = 0xAE
    @usableFromInline static let tradeCodepoint: UInt32 = 0x2122
    @usableFromInline static let utf16SurrogateMin: Int = 0xD800
    @usableFromInline static let utf16SurrogateMax: Int = 0xDFFF
    @usableFromInline static let unicodeMaxScalar: Int = 0x10FFFF
}

enum TokeniserState: TokeniserStateProtocol {
    case Data
    case CharacterReferenceInData
    case Rcdata
    case CharacterReferenceInRcdata
    case Rawtext
    case ScriptData
    case PLAINTEXT
    case TagOpen
    case EndTagOpen
    case TagName
    case RcdataLessthanSign
    case RCDATAEndTagOpen
    case RCDATAEndTagName
    case RawtextLessthanSign
    case RawtextEndTagOpen
    case RawtextEndTagName
    case ScriptDataLessthanSign
    case ScriptDataEndTagOpen
    case ScriptDataEndTagName
    case ScriptDataEscapeStart
    case ScriptDataEscapeStartDash
    case ScriptDataEscaped
    case ScriptDataEscapedDash
    case ScriptDataEscapedDashDash
    case ScriptDataEscapedLessthanSign
    case ScriptDataEscapedEndTagOpen
    case ScriptDataEscapedEndTagName
    case ScriptDataDoubleEscapeStart
    case ScriptDataDoubleEscaped
    case ScriptDataDoubleEscapedDash
    case ScriptDataDoubleEscapedDashDash
    case ScriptDataDoubleEscapedLessthanSign
    case ScriptDataDoubleEscapeEnd
    case BeforeAttributeName
    case AttributeName
    case AfterAttributeName
    case BeforeAttributeValue
    case AttributeValue_doubleQuoted
    case AttributeValue_singleQuoted
    case AttributeValue_unquoted
    case AfterAttributeValue_quoted
    case SelfClosingStartTag
    case BogusComment
    case MarkupDeclarationOpen
    case CommentStart
    case CommentStartDash
    case Comment
    case CommentEndDash
    case CommentEnd
    case CommentEndBang
    case Doctype
    case BeforeDoctypeName
    case DoctypeName
    case AfterDoctypeName
    case AfterDoctypePublicKeyword
    case BeforeDoctypePublicIdentifier
    case DoctypePublicIdentifier_doubleQuoted
    case DoctypePublicIdentifier_singleQuoted
    case AfterDoctypePublicIdentifier
    case BetweenDoctypePublicAndSystemIdentifiers
    case AfterDoctypeSystemKeyword
    case BeforeDoctypeSystemIdentifier
    case DoctypeSystemIdentifier_doubleQuoted
    case DoctypeSystemIdentifier_singleQuoted
    case AfterDoctypeSystemIdentifier
    case BogusDoctype
    case CdataSection

    private static let attrAmpersandQueryStringScanLimit: Int = 32

    @inlinable
    internal func read(_ t: Tokeniser, _ r: CharacterReader) throws {
        switch self {
        case .Data:
            if r.pos >= r.end {
                try t.emitEOF()
                break
            }
            if t.isTrackingSourceRanges() {
                let dataStart = r.pos
                let data: ByteSlice = r.consumeDataSlice()
                if !data.isEmpty {
                    t.emitRaw(data, start: dataStart, end: r.pos)
                    break
                }
            } else {
                let data: ByteSlice = r.consumeDataSlice()
                if !data.isEmpty {
                    t.emitRaw(data)
                    break
                }
            }
            if r.pos >= r.end {
                try t.emitEOF()
                break
            }
            let byte = r.input[r.pos]
            switch byte {
            case TokeniserStateVars.ampersandByte: // "&"
                t.advanceTransitionAscii(.CharacterReferenceInData)
                break
            case TokeniserStateVars.lessThanByte: // "<"
                t.markTagStart(r.pos)
                r.advanceAscii()
                if r.pos >= r.end {
                    t.error(self)
                    t.clearTagStart()
                    t.emit(UnicodeScalar.LessThan) // char that got us here
                    t.transition(.Data)
                    break
                }
                let next = r.input[r.pos]
                if next < TokeniserStateVars.asciiUpperLimitByte, TokeniserStateVars.isAsciiAlpha(next) {
                    if try TokeniserState.readTagNameFromTagOpen(t, r, true) {
                        return
                    }
                    return
                }
                switch next {
                case TokeniserStateVars.bangByte: // "!"
                    t.advanceTransitionAscii(.MarkupDeclarationOpen)
                case TokeniserStateVars.slashByte: // "/"
                    r.advanceAscii()
                    if r.isEmpty() {
                        t.eofError(self)
                        t.clearTagStart()
                        t.emit(UTF8Arrays.endTagStart)
                        t.transition(.Data)
                        break
                    }
                    let endByte = r.currentByte()!
                    if endByte < TokeniserStateVars.asciiUpperLimitByte {
                        if TokeniserStateVars.isAsciiAlpha(endByte) {
                            if try TokeniserState.readTagNameFromTagOpen(t, r, false) {
                                return
                            }
                            return
                        }
                        if endByte == TokeniserStateVars.greaterThanByte {
                            t.error(self)
                            t.clearTagStart()
                            t.advanceTransition(.Data)
                        } else {
                            t.error(self)
                            t.clearTagStart()
                            t.advanceTransition(.BogusComment)
                        }
                    } else if r.matchesLetter() {
                        t.createTagPending(false)
                        try TokeniserState.readTagName(.TagName, t, r)
                        return
                    } else {
                        t.error(self)
                        t.clearTagStart()
                        t.advanceTransition(.BogusComment)
                    }
                case TokeniserStateVars.questionMarkByte: // "?"
                    t.advanceTransitionAscii(.BogusComment)
                default:
                    if next >= TokeniserStateVars.asciiUpperLimitByte, r.matchesLetter() {
                        t.createTagPending(true)
                        try TokeniserState.readTagName(.TagName, t, r)
                        return
                    }
                    t.error(self)
                    t.emit(UnicodeScalar.LessThan) // char that got us here
                    t.transition(.Data)
                }
                break
            case TokeniserStateVars.nullByte:
                t.error(self) // NOT replacement character (oddly?)
                r.advanceAscii()
                t.emit(UnicodeScalar(TokeniserStateVars.nullByte))
                break
            default:
                break
            }
            break
        case .CharacterReferenceInData:
            try TokeniserState.readCharRef(t, .Data)
            break
        case .Rcdata:
            if r.isEmpty() {
                try t.emitEOF()
                break
            }
            let byte = r.currentByte()!
            switch byte {
            case TokeniserStateVars.ampersandByte: // "&"
                r.advanceAscii()
                try TokeniserState.readCharRef(t, .Rcdata)
                break
            case TokeniserStateVars.lessThanByte: // "<"
                t.markTagStart(r.pos)
                t.advanceTransitionAscii(.RcdataLessthanSign)
                break
            case TokeniserStateVars.nullByte:
                t.error(self)
                r.advance()
                t.emit(TokeniserStateVars.replacementStr)
                break
            default:
                let dataStart = r.pos
                let data = r.consumeToAnyOfThreeSlice(
                    TokeniserStateVars.ampersandByte,
                    TokeniserStateVars.lessThanByte,
                    TokeniserStateVars.nullByte
                )
                t.emitRaw(data, start: dataStart, end: r.pos)
                break
            }
            break
        case .CharacterReferenceInRcdata:
            try TokeniserState.readCharRef(t, .Rcdata)
            break
        case .Rawtext:
            try TokeniserState.readData(t, r, self, .RawtextLessthanSign)
            break
        case .ScriptData:
            try TokeniserState.readData(t, r, self, .ScriptDataLessthanSign)
            break
        case .PLAINTEXT:
            if r.isEmpty() {
                try t.emitEOF()
                break
            }
            let byte = r.currentByte()!
            switch byte {
            case TokeniserStateVars.nullByte:
                t.error(self)
                r.advance()
                t.emit(TokeniserStateVars.replacementStr)
                break
            default:
                let dataStart = r.pos
                let data = r.consumeToAnyOfTwoSlice(TokeniserStateVars.nullByte, TokeniserStateVars.maxByte)
                t.emitRaw(data, start: dataStart, end: r.pos)
                break
            }
            break
        case .TagOpen:
            // from < in data
            t.ensureTagStart(r.pos - 1)
            if r.isEmpty() {
                t.error(self)
                t.emit(UnicodeScalar.LessThan) // char that got us here
                t.transition(.Data)
                break
            }
            let byte = r.currentByte()!
            if byte < TokeniserStateVars.asciiUpperLimitByte, TokeniserStateVars.isAsciiAlpha(byte) {
                if try TokeniserState.readTagNameFromTagOpen(t, r, true) {
                    return
                }
                return
            }

            switch byte {
            case TokeniserStateVars.bangByte: // "!"
                t.advanceTransitionAscii(.MarkupDeclarationOpen)
            case TokeniserStateVars.slashByte: // "/"
                t.advanceTransitionAscii(.EndTagOpen)
            case TokeniserStateVars.questionMarkByte: // "?"
                t.advanceTransitionAscii(.BogusComment)
            default:
                if byte >= TokeniserStateVars.asciiUpperLimitByte, r.matchesLetter() {
                    t.createTagPending(true)
                    try TokeniserState.readTagName(.TagName, t, r)
                    return
                }
                t.error(self)
                t.clearTagStart()
                t.emit(UnicodeScalar.LessThan) // char that got us here
                t.transition(.Data)
            }
            break
        case .EndTagOpen:
            if (r.isEmpty()) {
                t.eofError(self)
                t.clearTagStart()
                t.emit(UTF8Arrays.endTagStart)
                t.transition(.Data)
            } else {
                let byte = r.currentByte()!
                if byte < TokeniserStateVars.asciiUpperLimitByte {
                    if TokeniserStateVars.isAsciiAlpha(byte) {
                        if try TokeniserState.readTagNameFromTagOpen(t, r, false) {
                            return
                        }
                        return
                    }
                    if byte == TokeniserStateVars.greaterThanByte {
                        t.error(self)
                        t.clearTagStart()
                        t.advanceTransition(.Data)
                    } else {
                        t.error(self)
                        t.clearTagStart()
                        t.advanceTransition(.BogusComment)
                    }
                } else if r.matchesLetter() {
                    t.createTagPending(false)
                    try TokeniserState.readTagName(.TagName, t, r)
                    return
                } else {
                    t.error(self)
                    t.clearTagStart()
                    t.advanceTransition(.BogusComment)
                }
            }
            break
        case .TagName:
            // from < or </ in data, will have start or end tag pending
            // previous TagOpen state did NOT consume, will have a letter char in current
            //String tagName = r.consumeToAnySorted(tagCharsSorted).toLowerCase()
            try TokeniserState.readTagName(self, t, r)
            break
        case .RcdataLessthanSign:
            if let byte = r.currentByte() {
                if byte == TokeniserStateVars.slashByte {
                    t.createTempBuffer()
                    t.advanceTransition(.RCDATAEndTagOpen)
                } else if byte < TokeniserStateVars.asciiUpperLimitByte {
                    if TokeniserStateVars.isAsciiAlpha(byte),
                       let endTagName = t.appropriateEndTagName(),
                       !r.containsIgnoreCase(prefix: UTF8Arrays.endTagStart, suffix: endTagName) {
                        // diverge from spec: got a start tag, but there's no appropriate end tag (</title>), so rather than
                        // consuming to EOF break out here
                        t.tagPending = t.createTagPending(false).name(endTagName)
                        try t.emitTagPending()
                        r.unconsume() // undo UnicodeScalar.LessThan
                        t.transition(.Data)
                    } else {
                        t.clearTagStart()
                        t.emit(UnicodeScalar.LessThan)
                        t.transition(.Rcdata)
                    }
                } else if r.matchesLetter(),
                          let endTagName = t.appropriateEndTagName(),
                          !r.containsIgnoreCase(prefix: UTF8Arrays.endTagStart, suffix: endTagName) {
                    // diverge from spec: got a start tag, but there's no appropriate end tag (</title>), so rather than
                    // consuming to EOF break out here
                    t.tagPending = t.createTagPending(false).name(endTagName)
                    try t.emitTagPending()
                    r.unconsume() // undo UnicodeScalar.LessThan
                    t.transition(.Data)
                } else {
                    t.clearTagStart()
                    t.emit(UnicodeScalar.LessThan)
                    t.transition(.Rcdata)
                }
            } else {
                t.clearTagStart()
                t.emit(UnicodeScalar.LessThan)
                t.transition(.Rcdata)
            }
            break
        case .RCDATAEndTagOpen:
            if let byte = r.currentByte(), byte < TokeniserStateVars.asciiUpperLimitByte {
                if TokeniserStateVars.isAsciiAlpha(byte) {
                    t.createTagPending(false)
                    t.tagPending.appendTagNameByte(byte)
                    t.dataBuffer.append(byte)
                    t.advanceTransition(.RCDATAEndTagName)
                    break
                }
            } else if r.matchesLetter() {
                let byte = r.currentByte()!
                t.createTagPending(false)
                t.tagPending.appendTagNameByte(byte)
                t.dataBuffer.append(byte)
                t.advanceTransition(.RCDATAEndTagName)
                break
            }
            t.emit(UTF8Arrays.endTagStart)
            t.clearTagStart()
            t.transition(.Rcdata)
            break
        case .RCDATAEndTagName:
            if let byte = r.currentByte(), byte < TokeniserStateVars.asciiUpperLimitByte {
                if TokeniserStateVars.isAsciiAlpha(byte) {
                    let name = r.consumeLetterSequenceSlice()
                    t.tagPending.appendTagName(name)
                    t.dataBuffer.append(name)
                    return
                }
            } else if (r.matchesLetter()) {
                let name = r.consumeLetterSequenceSlice()
                t.tagPending.appendTagName(name)
                t.dataBuffer.append(name)
                return
            }

            func anythingElse(_ t: Tokeniser, _ r: CharacterReader) {
                t.emit(UTF8Arrays.endTagStart)
                t.emit(t.dataBuffer.buffer)
                t.clearTagStart()
                r.unconsume()
                t.transition(.Rcdata)
            }

            if let byte = r.currentByte(), byte < TokeniserStateVars.asciiUpperLimitByte {
                r.advanceAscii()
                let appropriate = try t.isAppropriateEndTagToken()
                switch byte {
                case TokeniserStateVars.tabByte, TokeniserStateVars.newLineByte, TokeniserStateVars.carriageReturnByte, TokeniserStateVars.formFeedByte, TokeniserStateVars.spaceByte:
                    if appropriate {
                        t.transition(.BeforeAttributeName)
                    } else {
                        anythingElse(t, r)
                    }
                case TokeniserStateVars.slashByte: // "/"
                    if appropriate {
                        t.transition(.SelfClosingStartTag)
                    } else {
                        anythingElse(t, r)
                    }
                case TokeniserStateVars.greaterThanByte: // ">"
                    if appropriate {
                        try t.emitTagPending()
                        t.transition(.Data)
                    } else {
                        anythingElse(t, r)
                    }
                default:
                    anythingElse(t, r)
                }
            } else {
                let c = r.consume()
                let appropriate = try t.isAppropriateEndTagToken()
                switch (c) {
                case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ":
                    if appropriate {
                        t.transition(.BeforeAttributeName)
                    } else {
                        anythingElse(t, r)
                    }
                case "/":
                    if appropriate {
                        t.transition(.SelfClosingStartTag)
                    } else {
                        anythingElse(t, r)
                    }
                case ">":
                    if appropriate {
                        try t.emitTagPending()
                        t.transition(.Data)
                    } else {
                        anythingElse(t, r)
                    }
                default:
                    anythingElse(t, r)
                }
            }
            break
        case .RawtextLessthanSign:
            if let byte = r.currentByte(), byte == TokeniserStateVars.slashByte {
                t.createTempBuffer()
                t.advanceTransition(.RawtextEndTagOpen)
            } else {
                t.clearTagStart()
                t.emit(UnicodeScalar.LessThan)
                t.transition(.Rawtext)
            }
            break
        case .RawtextEndTagOpen:
            TokeniserState.readEndTag(t, r, .RawtextEndTagName, .Rawtext)
            break
        case .RawtextEndTagName:
            try TokeniserState.handleDataEndTag(t, r, .Rawtext)
            break
        case .ScriptDataLessthanSign:
            if r.isEmpty() {
                t.clearTagStart()
                t.emit(UnicodeScalar.LessThan)
                t.transition(.ScriptData)
                break
            }
            if let byte = r.currentByte() {
                switch byte {
                case TokeniserStateVars.slashByte: // "/"
                    r.advanceAscii()
                    t.createTempBuffer()
                    t.transition(.ScriptDataEndTagOpen)
                    break
                case TokeniserStateVars.bangByte: // "!"
                    r.advanceAscii()
                    t.clearTagStart()
                    t.emit(UTF8Arrays.tagStartBang)
                    t.transition(.ScriptDataEscapeStart)
                    break
                default:
                    t.clearTagStart()
                    t.emit(UnicodeScalar.LessThan)
                    t.transition(.ScriptData)
                }
            } else {
                t.clearTagStart()
                t.emit(UnicodeScalar.LessThan)
                t.transition(.ScriptData)
            }
            break
        case .ScriptDataEndTagOpen:
            TokeniserState.readEndTag(t, r, .ScriptDataEndTagName, .ScriptData)
            break
        case .ScriptDataEndTagName:
            try TokeniserState.handleDataEndTag(t, r, .ScriptData)
            break
        case .ScriptDataEscapeStart:
            if (r.matches(UTF8Arrays.hyphen)) {
                t.emit("-")
                t.advanceTransition(.ScriptDataEscapeStartDash)
            } else {
                t.transition(.ScriptData)
            }
            break
        case .ScriptDataEscapeStartDash:
            if (r.matches(UTF8Arrays.hyphen)) {
                t.emit("-")
                t.advanceTransition(.ScriptDataEscapedDashDash)
            } else {
                t.transition(.ScriptData)
            }
            break
        case .ScriptDataEscaped:
            if (r.isEmpty()) {
                t.eofError(self)
                t.transition(.Data)
                return
            }

            let byte = r.currentByte()!
            switch byte {
            case TokeniserStateVars.hyphenByte: // "-"
                t.emit(UTF8Arrays.hyphen)
                t.advanceTransitionAscii(.ScriptDataEscapedDash)
                break
            case TokeniserStateVars.lessThanByte: // "<"
                t.markTagStart(r.pos)
                t.advanceTransitionAscii(.ScriptDataEscapedLessthanSign)
                break
            case TokeniserStateVars.nullByte:
                t.error(self)
                r.advance()
                t.emit(TokeniserStateVars.replacementStr)
                break
            default:
                let dataStart = r.pos
                let data = r.consumeToAnyOfThreeSlice(
                    TokeniserStateVars.hyphenByte,
                    TokeniserStateVars.lessThanByte,
                    TokeniserStateVars.nullByte
                )
                t.emitRaw(data, start: dataStart, end: r.pos)
            }
            break
        case .ScriptDataEscapedDash:
            if (r.isEmpty()) {
                t.eofError(self)
                t.transition(.Data)
                return
            }

            if let byte = r.currentByte() {
                switch byte {
                case TokeniserStateVars.hyphenByte: // "-"
                    r.advanceAscii()
                    t.emit(UTF8Arrays.hyphen)
                    t.transition(.ScriptDataEscapedDashDash)
                    break
                case TokeniserStateVars.lessThanByte: // "<"
                    t.markTagStart(r.pos)
                    r.advanceAscii()
                    t.transition(.ScriptDataEscapedLessthanSign)
                    break
                case TokeniserStateVars.nullByte:
                    r.advanceAscii()
                    t.error(self)
                    t.emit(TokeniserStateVars.replacementStr)
                    t.transition(.ScriptDataEscaped)
                    break
                default:
                    if byte < TokeniserStateVars.asciiUpperLimitByte {
                        let data: ByteSlice = r.consumeToAnyOfThreeSlice(TokeniserStateVars.hyphenByte, TokeniserStateVars.lessThanByte, TokeniserStateVars.nullByte)
                        t.emit(data)
                    } else {
                        let c = r.consume()
                        t.emit(c)
                    }
                    t.transition(.ScriptDataEscaped)
                }
            } else {
                let c = r.consume()
                t.emit(c)
                t.transition(.ScriptDataEscaped)
            }
            break
        case .ScriptDataEscapedDashDash:
            if (r.isEmpty()) {
                t.eofError(self)
                t.transition(.Data)
                return
            }

            if let byte = r.currentByte() {
                switch byte {
                case TokeniserStateVars.hyphenByte: // "-"
                    r.advanceAscii()
                    t.emit(UTF8Arrays.hyphen)
                    break
                case TokeniserStateVars.lessThanByte: // "<"
                    t.markTagStart(r.pos)
                    r.advanceAscii()
                    t.transition(.ScriptDataEscapedLessthanSign)
                    break
                case TokeniserStateVars.greaterThanByte: // ">"
                    r.advanceAscii()
                    t.emit(UTF8Arrays.tagEnd)
                    t.transition(.ScriptData)
                    break
                case TokeniserStateVars.nullByte:
                    r.advanceAscii()
                    t.error(self)
                    t.emit(TokeniserStateVars.replacementStr)
                    t.transition(.ScriptDataEscaped)
                    break
                default:
                    if byte < TokeniserStateVars.asciiUpperLimitByte {
                        let data: ByteSlice = r.consumeToAnyOfFourSlice(TokeniserStateVars.hyphenByte, TokeniserStateVars.lessThanByte, TokeniserStateVars.greaterThanByte, TokeniserStateVars.nullByte)
                        t.emit(data)
                    } else {
                        let c = r.consume()
                        t.emit(c)
                    }
                    t.transition(.ScriptDataEscaped)
                }
            } else {
                let c = r.consume()
                t.emit(c)
                t.transition(.ScriptDataEscaped)
            }
            break
        case .ScriptDataEscapedLessthanSign:
            if let byte = r.currentByte() {
                if byte < TokeniserStateVars.asciiUpperLimitByte {
                    if TokeniserStateVars.isAsciiAlpha(byte) {
                        t.createTempBuffer()
                        t.dataBuffer.append(byte)
                        t.clearTagStart()
                        t.emit(UTF8Arrays.tagStart)
                        t.emitByte(byte)
                        t.advanceTransition(.ScriptDataDoubleEscapeStart)
                        break
                    }
                    if byte == TokeniserStateVars.slashByte {
                        t.createTempBuffer()
                        t.advanceTransition(.ScriptDataEscapedEndTagOpen)
                        break
                    }
                } else if r.matchesLetter() {
                    t.createTempBuffer()
                    t.dataBuffer.append(byte)
                    t.clearTagStart()
                    t.emit(UTF8Arrays.tagStart)
                    t.emitByte(byte)
                    t.advanceTransition(.ScriptDataDoubleEscapeStart)
                    break
                }
            }
            t.clearTagStart()
            t.emit(UnicodeScalar.LessThan)
            t.transition(.ScriptDataEscaped)
            break
        case .ScriptDataEscapedEndTagOpen:
            if let byte = r.currentByte(), byte < TokeniserStateVars.asciiUpperLimitByte {
                if TokeniserStateVars.isAsciiAlpha(byte) {
                    t.createTagPending(false)
                    t.tagPending.appendTagNameByte(byte)
                    t.dataBuffer.append(byte)
                    t.advanceTransition(.ScriptDataEscapedEndTagName)
                    break
                }
            } else if r.matchesLetter() {
                let byte = r.currentByte()!
                t.createTagPending(false)
                t.tagPending.appendTagNameByte(byte)
                t.dataBuffer.append(byte)
                t.advanceTransition(.ScriptDataEscapedEndTagName)
                break
            }
            t.emit(UTF8Arrays.endTagStart)
            t.transition(.ScriptDataEscaped)
            break
        case .ScriptDataEscapedEndTagName:
            try TokeniserState.handleDataEndTag(t, r, .ScriptDataEscaped)
            break
        case .ScriptDataDoubleEscapeStart:
            TokeniserState.handleDataDoubleEscapeTag(t, r, .ScriptDataDoubleEscaped, .ScriptDataEscaped)
            break
        case .ScriptDataDoubleEscaped:
            if r.isEmpty() {
                t.eofError(self)
                t.transition(.Data)
                break
            }

            let byte = r.currentByte()!
            switch byte {
            case TokeniserStateVars.hyphenByte: // "-"
                t.emit(UTF8Arrays.hyphen)
                t.advanceTransitionAscii(.ScriptDataDoubleEscapedDash)
                break
            case TokeniserStateVars.lessThanByte: // "<"
                t.emit(UTF8Arrays.tagStart)
                t.advanceTransitionAscii(.ScriptDataDoubleEscapedLessthanSign)
                break
            case TokeniserStateVars.nullByte:
                t.error(self)
                r.advance()
                t.emit(TokeniserStateVars.replacementStr)
                break
            default:
                let data: ByteSlice = r.consumeToAnyOfThreeSlice(TokeniserStateVars.hyphenByte, TokeniserStateVars.lessThanByte, TokeniserStateVars.nullByte)
                t.emit(data)
            }
            break
        case .ScriptDataDoubleEscapedDash:
            if r.isEmpty() {
                t.eofError(self)
                t.transition(.Data)
                break
            }
            if let byte = r.currentByte() {
                switch byte {
                case TokeniserStateVars.hyphenByte: // "-"
                    r.advanceAscii()
                    t.emit(UTF8Arrays.hyphen)
                    t.transition(.ScriptDataDoubleEscapedDashDash)
                    break
                case TokeniserStateVars.lessThanByte: // "<"
                    r.advanceAscii()
                    t.clearTagStart()
                    t.emit(UTF8Arrays.tagStart)
                    t.transition(.ScriptDataDoubleEscapedLessthanSign)
                    break
                case TokeniserStateVars.nullByte:
                    r.advanceAscii()
                    t.error(self)
                    t.emit(TokeniserStateVars.replacementStr)
                    t.transition(.ScriptDataDoubleEscaped)
                    break
                default:
                    if byte < TokeniserStateVars.asciiUpperLimitByte {
                        let data: ByteSlice = r.consumeToAnyOfThreeSlice(TokeniserStateVars.hyphenByte, TokeniserStateVars.lessThanByte, TokeniserStateVars.nullByte)
                        t.emit(data)
                    } else {
                        let c = r.consume()
                        t.emit(c)
                    }
                    t.transition(.ScriptDataDoubleEscaped)
                }
            } else {
                let c = r.consume()
                t.emit(c)
                t.transition(.ScriptDataDoubleEscaped)
            }
            break
        case .ScriptDataDoubleEscapedDashDash:
            if r.isEmpty() {
                t.eofError(self)
                t.transition(.Data)
                break
            }
            if let byte = r.currentByte() {
                switch byte {
                case TokeniserStateVars.hyphenByte: // "-"
                    r.advanceAscii()
                    t.emit(UTF8Arrays.hyphen)
                    break
                case TokeniserStateVars.lessThanByte: // "<"
                    r.advanceAscii()
                    t.emit(UTF8Arrays.tagStart)
                    t.transition(.ScriptDataDoubleEscapedLessthanSign)
                    break
                case TokeniserStateVars.greaterThanByte: // ">"
                    r.advanceAscii()
                    t.emit(UTF8Arrays.tagEnd)
                    t.transition(.ScriptData)
                    break
                case TokeniserStateVars.nullByte:
                    r.advanceAscii()
                    t.error(self)
                    t.emit(TokeniserStateVars.replacementStr)
                    t.transition(.ScriptDataDoubleEscaped)
                    break
                default:
                    if byte < TokeniserStateVars.asciiUpperLimitByte {
                        let data: ByteSlice = r.consumeToAnyOfFourSlice(TokeniserStateVars.hyphenByte, TokeniserStateVars.lessThanByte, TokeniserStateVars.greaterThanByte, TokeniserStateVars.nullByte)
                        t.emit(data)
                    } else {
                        let c = r.consume()
                        t.emit(c)
                    }
                    t.transition(.ScriptDataDoubleEscaped)
                }
            } else {
                let c = r.consume()
                t.emit(c)
                t.transition(.ScriptDataDoubleEscaped)
            }
            break
        case .ScriptDataDoubleEscapedLessthanSign:
            if (r.matches(UTF8Arrays.forwardSlash)) {
                t.emit("/")
                t.createTempBuffer()
                t.advanceTransition(.ScriptDataDoubleEscapeEnd)
            } else {
                t.transition(.ScriptDataDoubleEscaped)
            }
            break
        case .ScriptDataDoubleEscapeEnd:
            TokeniserState.handleDataDoubleEscapeTag(t, r, .ScriptDataEscaped, .ScriptDataDoubleEscaped)
            break
        case .BeforeAttributeName:
            // from tagname <xxx
            if try TokeniserState.consumeAttributesFast(t, r, self) {
                return
            }
            break
        case .AttributeName:
            try TokeniserState.readAttributeName(self, t, r)
            break
        case .AfterAttributeName:
            if try TokeniserState.consumeAttributesFast(t, r, self) {
                return
            }
            break
        case .BeforeAttributeValue:
            if try TokeniserState.consumeAttributeValueFast(t, r) {
                return
            }
            t.transition(.BeforeAttributeName)
            return
        case .AttributeValue_doubleQuoted:
            let value: ByteSlice = r.consumeAttributeValueDoubleQuotedSlice()
            if !value.isEmpty {
                t.tagPending.appendAttributeValue(value)
            } else if let nextByte = r.currentByte(), nextByte == TokeniserStateVars.quoteByte {
                t.tagPending.setEmptyAttributeValue()
            }

            if r.isEmpty() {
                t.eofError(self)
                t.transition(.Data)
                break
            }
            let byte = r.currentByte()!
            switch byte {
            case TokeniserStateVars.quoteByte: // "\""
                r.advanceAscii()
                t.transition(.AfterAttributeValue_quoted)
                break
            case TokeniserStateVars.ampersandByte: // "&"
                r.advanceAscii()
                if Self.isLikelyQueryStringAmpersand(r) {
                    t.tagPending.appendAttributeValue(UnicodeScalar.Ampersand)
                    break
                }
                if let ref = try t.consumeCharacterReference("\"", true) {
                    t.tagPending.appendAttributeValue(ref)
                } else {
                    t.tagPending.appendAttributeValue(UnicodeScalar.Ampersand)
                }
                break
            case TokeniserStateVars.nullByte:
                r.advanceAscii()
                t.error(self)
                t.tagPending.appendAttributeValue(TokeniserStateVars.replacementChar)
                break
            default:
                if byte < TokeniserStateVars.asciiUpperLimitByte {
                    r.advanceAscii()
                } else {
                    r.advance()
                }
                break
            }
            break
        case .AttributeValue_singleQuoted:
            let value: ByteSlice = r.consumeAttributeValueSingleQuotedSlice()
            if !value.isEmpty {
                t.tagPending.appendAttributeValue(value)
            } else if let nextByte = r.currentByte(), nextByte == TokeniserStateVars.apostropheByte {
                t.tagPending.setEmptyAttributeValue()
            }

            if r.isEmpty() {
                t.eofError(self)
                t.transition(.Data)
                break
            }
            let byte = r.currentByte()!
            switch byte {
            case TokeniserStateVars.apostropheByte: // "'"
                r.advanceAscii()
                t.transition(.AfterAttributeValue_quoted)
                break
            case TokeniserStateVars.ampersandByte: // "&"
                r.advanceAscii()
                if Self.isLikelyQueryStringAmpersand(r) {
                    t.tagPending.appendAttributeValue(UnicodeScalar.Ampersand)
                    break
                }
                if let ref = try t.consumeCharacterReference("'", true) {
                    t.tagPending.appendAttributeValue(ref)
                } else {
                    t.tagPending.appendAttributeValue(UnicodeScalar.Ampersand)
                }
                break
            case TokeniserStateVars.nullByte:
                r.advanceAscii()
                t.error(self)
                t.tagPending.appendAttributeValue(TokeniserStateVars.replacementChar)
                break
            default:
                if byte < TokeniserStateVars.asciiUpperLimitByte {
                    r.advanceAscii()
                } else {
                    r.advance()
                }
                break
            }
            break
        case .AttributeValue_unquoted:
            let value: ByteSlice = r.consumeAttributeValueUnquotedSlice()
            if !value.isEmpty {
                t.tagPending.appendAttributeValue(value)
            }

            if r.isEmpty() {
                t.eofError(self)
                t.transition(.Data)
                break
            }
            let byte = r.currentByte()!
            switch byte {
            case TokeniserStateVars.tabByte, TokeniserStateVars.newLineByte, TokeniserStateVars.carriageReturnByte, TokeniserStateVars.formFeedByte, TokeniserStateVars.spaceByte:
                r.advanceAsciiWhitespace()
                t.transition(.BeforeAttributeName)
                break
            case TokeniserStateVars.ampersandByte: // "&"
                r.advanceAscii()
                if Self.isLikelyQueryStringAmpersand(r) {
                    t.tagPending.appendAttributeValue(UnicodeScalar.Ampersand)
                    break
                }
                if let ref = try t.consumeCharacterReference(">", true) {
                    t.tagPending.appendAttributeValue(ref)
                } else {
                    t.tagPending.appendAttributeValue(UnicodeScalar.Ampersand)
                }
                break
            case TokeniserStateVars.greaterThanByte: // ">"
                r.advanceAscii()
                try t.emitTagPending()
                t.transition(.Data)
                break
            case TokeniserStateVars.nullByte:
                r.advanceAscii()
                t.error(self)
                t.tagPending.appendAttributeValue(TokeniserStateVars.replacementChar)
                break
            case TokeniserStateVars.quoteByte,
                 TokeniserStateVars.apostropheByte,
                 TokeniserStateVars.lessThanByte,
                 TokeniserStateVars.equalSignByte,
                 TokeniserStateVars.backtickByte: // "\"", "'", "<", "=", "`"
                r.advanceAscii()
                t.error(self)
                t.tagPending.appendAttributeValueByte(byte)
                break
            default:
                if byte < TokeniserStateVars.asciiUpperLimitByte {
                    r.advanceAscii()
                } else {
                    r.advance()
                }
                break
            }
            break
        case .AfterAttributeValue_quoted:
            // CharacterReferenceInAttributeValue state handled inline
            if r.isEmpty() {
                t.eofError(self)
                t.transition(.Data)
                break
            }
            let byte = r.currentByte()!
            switch byte {
            case TokeniserStateVars.tabByte, TokeniserStateVars.newLineByte, TokeniserStateVars.carriageReturnByte, TokeniserStateVars.formFeedByte, TokeniserStateVars.spaceByte:
                r.advanceAsciiWhitespace()
                t.transition(.BeforeAttributeName)
                break
            case TokeniserStateVars.slashByte: // "/"
                r.advanceAscii()
                t.transition(.SelfClosingStartTag)
                break
            case TokeniserStateVars.greaterThanByte: // ">"
                r.advanceAscii()
                try t.emitTagPending()
                t.transition(.Data)
                break
            default:
                t.error(self)
                t.transition(.BeforeAttributeName)
            }
            break
        case .SelfClosingStartTag:
            if r.isEmpty() {
                t.eofError(self)
                t.transition(.Data)
                break
            }
            let byte = r.currentByte()!
            switch byte {
            case TokeniserStateVars.greaterThanByte: // ">"
                r.advanceAscii()
                t.tagPending._selfClosing = true
                try t.emitTagPending()
                t.transition(.Data)
                break
            default:
                let c = r.consume()
                if c == TokeniserStateVars.eof {
                    t.eofError(self)
                    t.transition(.Data)
                } else {
                    t.error(self)
                    r.unconsume()
                    t.transition(.BeforeAttributeName)
                }
            }
            break
        case .BogusComment:
            // todo: handle bogus comment starting from eof. when does that trigger?
            // rewind to capture character that lead us here
            r.unconsume()
            let comment: Token.Comment = Token.Comment()
            comment.bogus = true
            comment.data.append(r.consumeToSlice(UTF8Arrays.tagEnd))
            // todo: replace nullChar with replaceChar
            try t.emit(comment)
            t.advanceTransition(.Data)
            break
        case .MarkupDeclarationOpen:
            if (r.matchConsume(TokeniserStateVars.commentStartUTF8)) {
                t.createCommentPending()
                t.transition(.CommentStart)
            } else if (r.matchConsumeIgnoreCase(TokeniserStateVars.doctypeUTF8)) {
                t.transition(.Doctype)
            } else if (r.matchConsume(TokeniserStateVars.cdataStartUTF8)) {
                // todo: should actually check current namepspace, and only non-html allows cdata. until namespace
                // is implemented properly, keep handling as cdata
                //} else if (!t.currentNodeInHtmlNS() && r.matchConsume("[CDATA[")) {
                t.transition(.CdataSection)
            } else {
                t.error(self)
                t.advanceTransition(.BogusComment) // advance so self character gets in bogus comment data's rewind
            }
            break
        case .CommentStart:
            if r.isEmpty() {
                t.eofError(self)
                try t.emitCommentPending()
                t.transition(.Data)
                break
            }
            let byte = r.currentByte()!
            switch byte {
            case TokeniserStateVars.hyphenByte: // "-"
                r.advanceAscii()
                t.transition(.CommentStartDash)
                break
            case TokeniserStateVars.nullByte:
                r.advanceAscii()
                t.error(self)
                t.commentPending.data.append(TokeniserStateVars.replacementChar)
                t.transition(.Comment)
                break
            case TokeniserStateVars.greaterThanByte: // ">"
                r.advanceAscii()
                t.error(self)
                try t.emitCommentPending()
                t.transition(.Data)
                break
            default:
                if byte < TokeniserStateVars.asciiUpperLimitByte {
                    r.advanceAscii()
                    t.commentPending.data.append(byte)
                    t.transition(.Comment)
                } else {
                    let c = r.consume()
                    if c == TokeniserStateVars.eof {
                        t.eofError(self)
                        try t.emitCommentPending()
                        t.transition(.Data)
                    } else {
                        t.commentPending.data.append(c)
                        t.transition(.Comment)
                    }
                }
            }
            break
        case .CommentStartDash:
            if r.isEmpty() {
                t.eofError(self)
                try t.emitCommentPending()
                t.transition(.Data)
                break
            }
            let byte = r.currentByte()!
            switch byte {
            case TokeniserStateVars.hyphenByte: // "-"
                r.advanceAscii()
                t.transition(.CommentStartDash)
                break
            case TokeniserStateVars.nullByte:
                r.advanceAscii()
                t.error(self)
                t.commentPending.data.append(TokeniserStateVars.replacementChar)
                t.transition(.Comment)
                break
            case TokeniserStateVars.greaterThanByte: // ">"
                r.advanceAscii()
                t.error(self)
                try t.emitCommentPending()
                t.transition(.Data)
                break
            default:
                if byte < TokeniserStateVars.asciiUpperLimitByte {
                    r.advanceAscii()
                    t.commentPending.data.append(byte)
                    t.transition(.Comment)
                } else {
                    let c = r.consume()
                    if c == TokeniserStateVars.eof {
                        t.eofError(self)
                        try t.emitCommentPending()
                        t.transition(.Data)
                    } else {
                        t.commentPending.data.append(c)
                        t.transition(.Comment)
                    }
                }
            }
            break
        case .Comment:
            if r.isEmpty() {
                t.eofError(self)
                try t.emitCommentPending()
                t.transition(.Data)
                break
            }

            let byte = r.currentByte()!
            switch byte {
            case TokeniserStateVars.hyphenByte: // "-"
                t.advanceTransitionAscii(.CommentEndDash)
                break
            case TokeniserStateVars.nullByte:
                t.error(self)
                r.advance()
                t.commentPending.data.append(TokeniserStateVars.replacementChar)
                break
            default:
                let value: ByteSlice  = r.consumeToAnyOfTwoSlice(TokeniserStateVars.hyphenByte, TokeniserStateVars.nullByte)
                t.commentPending.data.append(value)
            }
            break
        case .CommentEndDash:
            if r.isEmpty() {
                t.eofError(self)
                try t.emitCommentPending()
                t.transition(.Data)
                break
            }
            let byte = r.currentByte()!
            switch byte {
            case TokeniserStateVars.hyphenByte: // "-"
                r.advanceAscii()
                t.transition(.CommentEnd)
                break
            case TokeniserStateVars.nullByte:
                r.advanceAscii()
                t.error(self)
                t.commentPending.data.append(UTF8Arrays.hyphen).append(TokeniserStateVars.replacementChar)
                t.transition(.Comment)
                break
            default:
                if byte < TokeniserStateVars.asciiUpperLimitByte {
                    r.advanceAscii()
                    t.commentPending.data.append(UTF8Arrays.hyphen).append(byte)
                    t.transition(.Comment)
                } else {
                    let c = r.consume()
                    if c == TokeniserStateVars.eof {
                        t.eofError(self)
                        try t.emitCommentPending()
                        t.transition(.Data)
                    } else {
                        t.commentPending.data.append(UTF8Arrays.hyphen).append(c)
                        t.transition(.Comment)
                    }
                }
            }
            break
        case .CommentEnd:
            if r.isEmpty() {
                t.eofError(self)
                try t.emitCommentPending()
                t.transition(.Data)
                break
            }
            let byte = r.currentByte()!
            switch byte {
            case TokeniserStateVars.greaterThanByte: // ">"
                r.advanceAscii()
                try t.emitCommentPending()
                t.transition(.Data)
                break
            case TokeniserStateVars.nullByte:
                r.advanceAscii()
                t.error(self)
                t.commentPending.data.append(UTF8Arrays.doubleHyphen).append(TokeniserStateVars.replacementChar)
                t.transition(.Comment)
                break
            case TokeniserStateVars.bangByte: // "!"
                r.advanceAscii()
                t.error(self)
                t.transition(.CommentEndBang)
                break
            case TokeniserStateVars.hyphenByte: // "-"
                r.advanceAscii()
                t.error(self)
                t.commentPending.data.append(UTF8Arrays.hyphen)
                break
            default:
                if byte < TokeniserStateVars.asciiUpperLimitByte {
                    r.advanceAscii()
                    t.error(self)
                    t.commentPending.data.append(UTF8Arrays.doubleHyphen).append(byte)
                    t.transition(.Comment)
                } else {
                    let c = r.consume()
                    if c == TokeniserStateVars.eof {
                        t.eofError(self)
                        try t.emitCommentPending()
                        t.transition(.Data)
                    } else {
                        t.error(self)
                        t.commentPending.data.append(UTF8Arrays.doubleHyphen).append(c)
                        t.transition(.Comment)
                    }
                }
            }
            break
        case .CommentEndBang:
            if r.isEmpty() {
                t.eofError(self)
                try t.emitCommentPending()
                t.transition(.Data)
                break
            }
            let byte = r.currentByte()!
            switch byte {
            case TokeniserStateVars.hyphenByte: // "-"
                r.advanceAscii()
                t.commentPending.data.append(UTF8Arrays.doubleHyphenBang)
                t.transition(.CommentEndDash)
                break
            case TokeniserStateVars.greaterThanByte: // ">"
                r.advanceAscii()
                try t.emitCommentPending()
                t.transition(.Data)
                break
            case TokeniserStateVars.nullByte:
                r.advanceAscii()
                t.error(self)
                t.commentPending.data.append(UTF8Arrays.doubleHyphenBang).append(TokeniserStateVars.replacementChar)
                t.transition(.Comment)
                break
            default:
                if byte < TokeniserStateVars.asciiUpperLimitByte {
                    r.advanceAscii()
                    t.commentPending.data.append(UTF8Arrays.doubleHyphenBang).append(byte)
                    t.transition(.Comment)
                } else {
                    let c = r.consume()
                    if c == TokeniserStateVars.eof {
                        t.eofError(self)
                        try t.emitCommentPending()
                        t.transition(.Data)
                    } else {
                        t.commentPending.data.append(UTF8Arrays.doubleHyphenBang).append(c)
                        t.transition(.Comment)
                    }
                }
            }
            break
        case .Doctype:
            if r.isEmpty() {
                t.eofError(self)
                t.error(self)
                t.createDoctypePending()
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            }
            if let byte = r.currentByte(), byte < TokeniserStateVars.asciiUpperLimitByte {
                r.advanceAscii()
                switch byte {
                case TokeniserStateVars.tabByte, TokeniserStateVars.newLineByte, TokeniserStateVars.carriageReturnByte, TokeniserStateVars.formFeedByte, TokeniserStateVars.spaceByte:
                    t.transition(.BeforeDoctypeName)
                case TokeniserStateVars.greaterThanByte: // ">"
                    t.error(self)
                    t.createDoctypePending()
                    t.doctypePending.forceQuirks = true
                    try t.emitDoctypePending()
                    t.transition(.Data)
                default:
                    t.error(self)
                    t.transition(.BeforeDoctypeName)
                }
            } else {
                let c = r.consume()
                switch (c) {
                case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ":
                    t.transition(.BeforeDoctypeName)
                    break
                case TokeniserStateVars.eof:
                    t.eofError(self)
                    // note: fall through to > case
                    fallthrough
                case ">": // catch invalid <!DOCTYPE>
                    t.error(self)
                    t.createDoctypePending()
                    t.doctypePending.forceQuirks = true
                    try t.emitDoctypePending()
                    t.transition(.Data)
                    break
                default:
                    t.error(self)
                    t.transition(.BeforeDoctypeName)
                }
            }
            break
        case .BeforeDoctypeName:
            if let byte = r.currentByte(), byte < TokeniserStateVars.asciiUpperLimitByte {
                if TokeniserStateVars.isAsciiAlpha(byte) {
                    t.createDoctypePending()
                    t.transition(.DoctypeName)
                    return
                }
            } else if (r.matchesLetter()) {
                t.createDoctypePending()
                t.transition(.DoctypeName)
                return
            }
            if r.isEmpty() {
                t.eofError(self)
                t.createDoctypePending()
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            }
            if let byte = r.currentByte(), byte < TokeniserStateVars.asciiUpperLimitByte {
                r.advanceAscii()
                switch byte {
                case TokeniserStateVars.tabByte, TokeniserStateVars.newLineByte, TokeniserStateVars.carriageReturnByte, TokeniserStateVars.formFeedByte, TokeniserStateVars.spaceByte:
                    break // ignore whitespace
                case TokeniserStateVars.nullByte:
                    t.error(self)
                    t.createDoctypePending()
                    t.doctypePending.name.append(TokeniserStateVars.replacementChar)
                    t.transition(.DoctypeName)
                default:
                    t.createDoctypePending()
                    t.doctypePending.name.append(byte)
                    t.transition(.DoctypeName)
                }
            } else {
                let c = r.consume()
                switch (c) {
                case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ":
                    break // ignore whitespace
                case TokeniserStateVars.nullScalr:
                    t.error(self)
                    t.createDoctypePending()
                    t.doctypePending.name.append(TokeniserStateVars.replacementChar)
                    t.transition(.DoctypeName)
                    break
                case TokeniserStateVars.eof:
                    t.eofError(self)
                    t.createDoctypePending()
                    t.doctypePending.forceQuirks = true
                    try t.emitDoctypePending()
                    t.transition(.Data)
                    break
                default:
                    t.createDoctypePending()
                    t.doctypePending.name.append(c)
                    t.transition(.DoctypeName)
                }
            }
            break
        case .DoctypeName:
            if let byte = r.currentByte(), byte < TokeniserStateVars.asciiUpperLimitByte {
                if TokeniserStateVars.isAsciiAlpha(byte) {
                    let name = r.consumeLetterSequenceSlice()
                    t.doctypePending.name.append(name)
                    return
                }
            } else if (r.matchesLetter()) {
                let name = r.consumeLetterSequenceSlice()
                t.doctypePending.name.append(name)
                return
            }
            if r.isEmpty() {
                t.eofError(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            }
            if let byte = r.currentByte(), byte < TokeniserStateVars.asciiUpperLimitByte {
                r.advanceAscii()
                switch byte {
                case TokeniserStateVars.greaterThanByte: // ">"
                    try t.emitDoctypePending()
                    t.transition(.Data)
                case TokeniserStateVars.tabByte, TokeniserStateVars.newLineByte, TokeniserStateVars.carriageReturnByte, TokeniserStateVars.formFeedByte, TokeniserStateVars.spaceByte:
                    t.transition(.AfterDoctypeName)
                case TokeniserStateVars.nullByte:
                    t.error(self)
                    t.doctypePending.name.append(TokeniserStateVars.replacementChar)
                default:
                    t.doctypePending.name.append(byte)
                }
            } else {
                let c = r.consume()
                switch (c) {
                case ">":
                    try t.emitDoctypePending()
                    t.transition(.Data)
                    break
                case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ":
                    t.transition(.AfterDoctypeName)
                    break
                case TokeniserStateVars.nullScalr:
                    t.error(self)
                    t.doctypePending.name.append(TokeniserStateVars.replacementChar)
                    break
                case TokeniserStateVars.eof:
                    t.eofError(self)
                    t.doctypePending.forceQuirks = true
                    try t.emitDoctypePending()
                    t.transition(.Data)
                    break
                default:
                    t.doctypePending.name.append(c)
                }
            }
            break
        case .AfterDoctypeName:
            if (r.isEmpty()) {
                t.eofError(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
                return
            }
            if let byte = r.currentByte(), byte < TokeniserStateVars.asciiUpperLimitByte,
               (byte == TokeniserStateVars.tabByte ||
                byte == TokeniserStateVars.newLineByte ||
                byte == TokeniserStateVars.carriageReturnByte ||
                byte == TokeniserStateVars.formFeedByte ||
                byte == TokeniserStateVars.spaceByte) {
                r.advanceAscii() // ignore whitespace
            } else if (r.matches(UTF8Arrays.tagEnd)) {
                try t.emitDoctypePending()
                t.advanceTransition(.Data)
            } else if (r.matchConsumeIgnoreCase(DocumentType.PUBLIC_KEY)) {
                t.doctypePending.pubSysKey = DocumentType.PUBLIC_KEY
                t.transition(.AfterDoctypePublicKeyword)
            } else if (r.matchConsumeIgnoreCase(DocumentType.SYSTEM_KEY)) {
                t.doctypePending.pubSysKey = DocumentType.SYSTEM_KEY
                t.transition(.AfterDoctypeSystemKeyword)
            } else {
                t.error(self)
                t.doctypePending.forceQuirks = true
                t.advanceTransition(.BogusDoctype)
            }
            break
        case .AfterDoctypePublicKeyword:
            if r.isEmpty() {
                t.eofError(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            }
            if let byte = r.currentByte(), byte < TokeniserStateVars.asciiUpperLimitByte {
                r.advanceAscii()
                switch byte {
                case TokeniserStateVars.tabByte, TokeniserStateVars.newLineByte, TokeniserStateVars.carriageReturnByte, TokeniserStateVars.formFeedByte, TokeniserStateVars.spaceByte:
                    t.transition(.BeforeDoctypePublicIdentifier)
                case TokeniserStateVars.quoteByte: // "\""
                    t.error(self)
                    t.transition(.DoctypePublicIdentifier_doubleQuoted)
                case TokeniserStateVars.apostropheByte: // "'"
                    t.error(self)
                    t.transition(.DoctypePublicIdentifier_singleQuoted)
                case TokeniserStateVars.greaterThanByte: // ">"
                    t.error(self)
                    t.doctypePending.forceQuirks = true
                    try t.emitDoctypePending()
                    t.transition(.Data)
                default:
                    t.error(self)
                    t.doctypePending.forceQuirks = true
                    t.transition(.BogusDoctype)
                }
            } else {
                let c = r.consume()
                switch (c) {
                case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ":
                    t.transition(.BeforeDoctypePublicIdentifier)
                    break
                case "\"":
                    t.error(self)
                    // set public id to empty string
                    t.transition(.DoctypePublicIdentifier_doubleQuoted)
                    break
                case "'":
                    t.error(self)
                    // set public id to empty string
                    t.transition(.DoctypePublicIdentifier_singleQuoted)
                    break
                case ">":
                    t.error(self)
                    t.doctypePending.forceQuirks = true
                    try t.emitDoctypePending()
                    t.transition(.Data)
                    break
                case TokeniserStateVars.eof:
                    t.eofError(self)
                    t.doctypePending.forceQuirks = true
                    try t.emitDoctypePending()
                    t.transition(.Data)
                    break
                default:
                    t.error(self)
                    t.doctypePending.forceQuirks = true
                    t.transition(.BogusDoctype)
                }
            }
            break
        case .BeforeDoctypePublicIdentifier:
            if r.isEmpty() {
                t.eofError(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            }
            if let byte = r.currentByte(), byte < TokeniserStateVars.asciiUpperLimitByte {
                r.advanceAscii()
                switch byte {
                case TokeniserStateVars.tabByte, TokeniserStateVars.newLineByte, TokeniserStateVars.carriageReturnByte, TokeniserStateVars.formFeedByte, TokeniserStateVars.spaceByte:
                    break
                case TokeniserStateVars.quoteByte: // "\""
                    t.transition(.DoctypePublicIdentifier_doubleQuoted)
                case TokeniserStateVars.apostropheByte: // "'"
                    t.transition(.DoctypePublicIdentifier_singleQuoted)
                case TokeniserStateVars.greaterThanByte: // ">"
                    t.error(self)
                    t.doctypePending.forceQuirks = true
                    try t.emitDoctypePending()
                    t.transition(.Data)
                default:
                    t.error(self)
                    t.doctypePending.forceQuirks = true
                    t.transition(.BogusDoctype)
                }
            } else {
                let c = r.consume()
                switch (c) {
                case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ":
                    break
                case "\"":
                    // set public id to empty string
                    t.transition(.DoctypePublicIdentifier_doubleQuoted)
                    break
                case "'":
                    // set public id to empty string
                    t.transition(.DoctypePublicIdentifier_singleQuoted)
                    break
                case ">":
                    t.error(self)
                    t.doctypePending.forceQuirks = true
                    try t.emitDoctypePending()
                    t.transition(.Data)
                    break
                case TokeniserStateVars.eof:
                    t.eofError(self)
                    t.doctypePending.forceQuirks = true
                    try t.emitDoctypePending()
                    t.transition(.Data)
                    break
                default:
                    t.error(self)
                    t.doctypePending.forceQuirks = true
                    t.transition(.BogusDoctype)
                }
            }
            break
        case .DoctypePublicIdentifier_doubleQuoted:
            let value = r.consumeToAnyOfThreeSlice(
                TokeniserStateVars.quoteByte,
                TokeniserStateVars.nullByte,
                TokeniserStateVars.greaterThanByte
            )
            if !value.isEmpty {
                t.doctypePending.publicIdentifier.append(value)
            }
            if r.isEmpty() {
                t.eofError(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            }
            let byte = r.currentByte()!
            switch byte {
            case TokeniserStateVars.quoteByte: // "\""
                r.advanceAscii()
                t.transition(.AfterDoctypePublicIdentifier)
            case TokeniserStateVars.nullByte:
                r.advanceAscii()
                t.error(self)
                t.doctypePending.publicIdentifier.append(TokeniserStateVars.replacementChar)
            case TokeniserStateVars.greaterThanByte: // ">"
                r.advanceAscii()
                t.error(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
            default:
                let c = r.consume()
                if c == TokeniserStateVars.eof {
                    t.eofError(self)
                    t.doctypePending.forceQuirks = true
                    try t.emitDoctypePending()
                    t.transition(.Data)
                } else {
                    t.doctypePending.publicIdentifier.append(c)
                }
            }
            break
        case .DoctypePublicIdentifier_singleQuoted:
            let value = r.consumeToAnyOfThreeSlice(
                TokeniserStateVars.apostropheByte,
                TokeniserStateVars.nullByte,
                TokeniserStateVars.greaterThanByte
            )
            if !value.isEmpty {
                t.doctypePending.publicIdentifier.append(value)
            }
            if r.isEmpty() {
                t.eofError(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            }
            let byte = r.currentByte()!
            switch byte {
            case TokeniserStateVars.apostropheByte: // "'"
                r.advanceAscii()
                t.transition(.AfterDoctypePublicIdentifier)
            case TokeniserStateVars.nullByte:
                r.advanceAscii()
                t.error(self)
                t.doctypePending.publicIdentifier.append(TokeniserStateVars.replacementChar)
            case TokeniserStateVars.greaterThanByte: // ">"
                r.advanceAscii()
                t.error(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
            default:
                let c = r.consume()
                if c == TokeniserStateVars.eof {
                    t.eofError(self)
                    t.doctypePending.forceQuirks = true
                    try t.emitDoctypePending()
                    t.transition(.Data)
                } else {
                    t.doctypePending.publicIdentifier.append(c)
                }
            }
            break
        case .AfterDoctypePublicIdentifier:
            if r.isEmpty() {
                t.eofError(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            }
            if let byte = r.currentByte(), byte < TokeniserStateVars.asciiUpperLimitByte {
                r.advanceAscii()
                switch byte {
                case TokeniserStateVars.tabByte, TokeniserStateVars.newLineByte, TokeniserStateVars.carriageReturnByte, TokeniserStateVars.formFeedByte, TokeniserStateVars.spaceByte:
                    t.transition(.BetweenDoctypePublicAndSystemIdentifiers)
                case TokeniserStateVars.greaterThanByte: // ">"
                    try t.emitDoctypePending()
                    t.transition(.Data)
                case TokeniserStateVars.quoteByte: // "\""
                    t.error(self)
                    t.transition(.DoctypeSystemIdentifier_doubleQuoted)
                case TokeniserStateVars.apostropheByte: // "'"
                    t.error(self)
                    t.transition(.DoctypeSystemIdentifier_singleQuoted)
                default:
                    t.error(self)
                    t.doctypePending.forceQuirks = true
                    t.transition(.BogusDoctype)
                }
            } else {
                let c = r.consume()
                switch (c) {
                case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ":
                    t.transition(.BetweenDoctypePublicAndSystemIdentifiers)
                    break
                case ">":
                    try t.emitDoctypePending()
                    t.transition(.Data)
                    break
                case "\"":
                    t.error(self)
                    // system id empty
                    t.transition(.DoctypeSystemIdentifier_doubleQuoted)
                    break
                case "'":
                    t.error(self)
                    // system id empty
                    t.transition(.DoctypeSystemIdentifier_singleQuoted)
                    break
                case TokeniserStateVars.eof:
                    t.eofError(self)
                    t.doctypePending.forceQuirks = true
                    try t.emitDoctypePending()
                    t.transition(.Data)
                    break
                default:
                    t.error(self)
                    t.doctypePending.forceQuirks = true
                    t.transition(.BogusDoctype)
                }
            }
            break
        case .BetweenDoctypePublicAndSystemIdentifiers:
            if r.isEmpty() {
                t.eofError(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            }
            if let byte = r.currentByte(), byte < TokeniserStateVars.asciiUpperLimitByte {
                r.advanceAscii()
                switch byte {
                case TokeniserStateVars.tabByte, TokeniserStateVars.newLineByte, TokeniserStateVars.carriageReturnByte, TokeniserStateVars.formFeedByte, TokeniserStateVars.spaceByte:
                    break
                case TokeniserStateVars.greaterThanByte: // ">"
                    try t.emitDoctypePending()
                    t.transition(.Data)
                case TokeniserStateVars.quoteByte: // "\""
                    t.error(self)
                    t.transition(.DoctypeSystemIdentifier_doubleQuoted)
                case TokeniserStateVars.apostropheByte: // "'"
                    t.error(self)
                    t.transition(.DoctypeSystemIdentifier_singleQuoted)
                default:
                    t.error(self)
                    t.doctypePending.forceQuirks = true
                    t.transition(.BogusDoctype)
                }
            } else {
                let c = r.consume()
                switch (c) {
                case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ":
                    break
                case ">":
                    try t.emitDoctypePending()
                    t.transition(.Data)
                    break
                case "\"":
                    t.error(self)
                    // system id empty
                    t.transition(.DoctypeSystemIdentifier_doubleQuoted)
                    break
                case "'":
                    t.error(self)
                    // system id empty
                    t.transition(.DoctypeSystemIdentifier_singleQuoted)
                    break
                case TokeniserStateVars.eof:
                    t.eofError(self)
                    t.doctypePending.forceQuirks = true
                    try t.emitDoctypePending()
                    t.transition(.Data)
                    break
                default:
                    t.error(self)
                    t.doctypePending.forceQuirks = true
                    t.transition(.BogusDoctype)
                }
            }
            break
        case .AfterDoctypeSystemKeyword:
            if r.isEmpty() {
                t.eofError(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            }
            if let byte = r.currentByte(), byte < TokeniserStateVars.asciiUpperLimitByte {
                r.advanceAscii()
                switch byte {
                case TokeniserStateVars.tabByte, TokeniserStateVars.newLineByte, TokeniserStateVars.carriageReturnByte, TokeniserStateVars.formFeedByte, TokeniserStateVars.spaceByte:
                    t.transition(.BeforeDoctypeSystemIdentifier)
                case TokeniserStateVars.greaterThanByte: // ">"
                    t.error(self)
                    t.doctypePending.forceQuirks = true
                    try t.emitDoctypePending()
                    t.transition(.Data)
                case TokeniserStateVars.quoteByte: // "\""
                    t.error(self)
                    t.transition(.DoctypeSystemIdentifier_doubleQuoted)
                case TokeniserStateVars.apostropheByte: // "'"
                    t.error(self)
                    t.transition(.DoctypeSystemIdentifier_singleQuoted)
                default:
                    t.error(self)
                    t.doctypePending.forceQuirks = true
                    try t.emitDoctypePending()
                }
            } else {
                let c = r.consume()
                switch (c) {
                case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ":
                    t.transition(.BeforeDoctypeSystemIdentifier)
                    break
                case ">":
                    t.error(self)
                    t.doctypePending.forceQuirks = true
                    try t.emitDoctypePending()
                    t.transition(.Data)
                    break
                case "\"":
                    t.error(self)
                    // system id empty
                    t.transition(.DoctypeSystemIdentifier_doubleQuoted)
                    break
                case "'":
                    t.error(self)
                    // system id empty
                    t.transition(.DoctypeSystemIdentifier_singleQuoted)
                    break
                case TokeniserStateVars.eof:
                    t.eofError(self)
                    t.doctypePending.forceQuirks = true
                    try t.emitDoctypePending()
                    t.transition(.Data)
                    break
                default:
                    t.error(self)
                    t.doctypePending.forceQuirks = true
                    try t.emitDoctypePending()
                }
            }
            break
        case .BeforeDoctypeSystemIdentifier:
            if r.isEmpty() {
                t.eofError(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            }
            if let byte = r.currentByte(), byte < TokeniserStateVars.asciiUpperLimitByte {
                r.advanceAscii()
                switch byte {
                case TokeniserStateVars.tabByte, TokeniserStateVars.newLineByte, TokeniserStateVars.carriageReturnByte, TokeniserStateVars.formFeedByte, TokeniserStateVars.spaceByte:
                    break
                case TokeniserStateVars.quoteByte: // "\""
                    t.transition(.DoctypeSystemIdentifier_doubleQuoted)
                case TokeniserStateVars.apostropheByte: // "'"
                    t.transition(.DoctypeSystemIdentifier_singleQuoted)
                case TokeniserStateVars.greaterThanByte: // ">"
                    t.error(self)
                    t.doctypePending.forceQuirks = true
                    try t.emitDoctypePending()
                    t.transition(.Data)
                default:
                    t.error(self)
                    t.doctypePending.forceQuirks = true
                    t.transition(.BogusDoctype)
                }
            } else {
                let c = r.consume()
                switch (c) {
                case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ":
                    break
                case "\"":
                    // set system id to empty string
                    t.transition(.DoctypeSystemIdentifier_doubleQuoted)
                    break
                case "'":
                    // set public id to empty string
                    t.transition(.DoctypeSystemIdentifier_singleQuoted)
                    break
                case ">":
                    t.error(self)
                    t.doctypePending.forceQuirks = true
                    try t.emitDoctypePending()
                    t.transition(.Data)
                    break
                case TokeniserStateVars.eof:
                    t.eofError(self)
                    t.doctypePending.forceQuirks = true
                    try t.emitDoctypePending()
                    t.transition(.Data)
                    break
                default:
                    t.error(self)
                    t.doctypePending.forceQuirks = true
                    t.transition(.BogusDoctype)
                }
            }
            break
        case .DoctypeSystemIdentifier_doubleQuoted:
            let value = r.consumeToAnyOfThreeSlice(
                TokeniserStateVars.quoteByte,
                TokeniserStateVars.nullByte,
                TokeniserStateVars.greaterThanByte
            )
            if !value.isEmpty {
                t.doctypePending.systemIdentifier.append(value)
            }
            if r.isEmpty() {
                t.eofError(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            }
            let byte = r.currentByte()!
            switch byte {
            case TokeniserStateVars.quoteByte: // "\""
                r.advanceAscii()
                t.transition(.AfterDoctypeSystemIdentifier)
            case TokeniserStateVars.nullByte:
                r.advanceAscii()
                t.error(self)
                t.doctypePending.systemIdentifier.append(TokeniserStateVars.replacementChar)
            case TokeniserStateVars.greaterThanByte: // ">"
                r.advanceAscii()
                t.error(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
            default:
                let c = r.consume()
                if c == TokeniserStateVars.eof {
                    t.eofError(self)
                    t.doctypePending.forceQuirks = true
                    try t.emitDoctypePending()
                    t.transition(.Data)
                } else {
                    t.doctypePending.systemIdentifier.append(c)
                }
            }
            break
        case .DoctypeSystemIdentifier_singleQuoted:
            let value = r.consumeToAnyOfThreeSlice(
                TokeniserStateVars.apostropheByte,
                TokeniserStateVars.nullByte,
                TokeniserStateVars.greaterThanByte
            )
            if !value.isEmpty {
                t.doctypePending.systemIdentifier.append(value)
            }
            if r.isEmpty() {
                t.eofError(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            }
            let byte = r.currentByte()!
            switch byte {
            case TokeniserStateVars.apostropheByte: // "'"
                r.advanceAscii()
                t.transition(.AfterDoctypeSystemIdentifier)
            case TokeniserStateVars.nullByte:
                r.advanceAscii()
                t.error(self)
                t.doctypePending.systemIdentifier.append(TokeniserStateVars.replacementChar)
            case TokeniserStateVars.greaterThanByte: // ">"
                r.advanceAscii()
                t.error(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
            default:
                let c = r.consume()
                if c == TokeniserStateVars.eof {
                    t.eofError(self)
                    t.doctypePending.forceQuirks = true
                    try t.emitDoctypePending()
                    t.transition(.Data)
                } else {
                    t.doctypePending.systemIdentifier.append(c)
                }
            }
            break
        case .AfterDoctypeSystemIdentifier:
            if r.isEmpty() {
                t.eofError(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            }
            if let byte = r.currentByte(), byte < TokeniserStateVars.asciiUpperLimitByte {
                r.advanceAscii()
                switch byte {
                case TokeniserStateVars.tabByte, TokeniserStateVars.newLineByte, TokeniserStateVars.carriageReturnByte, TokeniserStateVars.formFeedByte, TokeniserStateVars.spaceByte:
                    break
                case TokeniserStateVars.greaterThanByte: // ">"
                    try t.emitDoctypePending()
                    t.transition(.Data)
                default:
                    t.error(self)
                    t.transition(.BogusDoctype)
                }
            } else {
                let c = r.consume()
                switch (c) {
                case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ":
                    break
                case ">":
                    try t.emitDoctypePending()
                    t.transition(.Data)
                    break
                case TokeniserStateVars.eof:
                    t.eofError(self)
                    t.doctypePending.forceQuirks = true
                    try t.emitDoctypePending()
                    t.transition(.Data)
                    break
                default:
                    t.error(self)
                    t.transition(.BogusDoctype)
                    // NOT force quirks
                }
            }
            break
        case .BogusDoctype:
            if r.isEmpty() {
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            }
            _ = r.consumeToSlice(UTF8Arrays.tagEnd)
            if r.matchConsume(UTF8Arrays.tagEnd) {
                try t.emitDoctypePending()
                t.transition(.Data)
            } else if r.isEmpty() {
                try t.emitDoctypePending()
                t.transition(.Data)
            }
            break
        case .CdataSection:
            let dataStart = r.pos
            let data = r.consumeToSlice(TokeniserStateVars.cdataEndUTF8)
            t.emitRaw(data, start: dataStart, end: r.pos)
            r.matchConsume(TokeniserStateVars.cdataEndUTF8)
            t.transition(.Data)
            break
        }
    }

    var description: String {return String(describing: type(of: self))}
    /**
     * Handles RawtextEndTagName, ScriptDataEndTagName, and ScriptDataEscapedEndTagName. Same body impl, just
     * different else exit transitions.
     */
    private static func handleDataEndTag(_ t: Tokeniser, _ r: CharacterReader, _ elseTransition: TokeniserState)throws {
        if let byte = r.currentByte(), byte < TokeniserStateVars.asciiUpperLimitByte {
            if TokeniserStateVars.isAsciiAlpha(byte) {
                let name: ByteSlice = r.consumeLetterSequenceSlice()
                t.tagPending.appendTagName(name)
                t.dataBuffer.append(name)
                return
            }
        } else if (r.matchesLetter()) {
            let name: ByteSlice = r.consumeLetterSequenceSlice()
            t.tagPending.appendTagName(name)
            t.dataBuffer.append(name)
            return
        }

        var needsExitTransition = false
        if (try t.isAppropriateEndTagToken() && !r.isEmpty()) {
            if let byte = r.currentByte(), byte < TokeniserStateVars.asciiUpperLimitByte {
                r.advanceAscii()
                switch byte {
                case TokeniserStateVars.tabByte, TokeniserStateVars.newLineByte, TokeniserStateVars.carriageReturnByte, TokeniserStateVars.formFeedByte, TokeniserStateVars.spaceByte: // whitespace
                    t.transition(BeforeAttributeName)
                    break
                case TokeniserStateVars.slashByte: // "/"
                    t.transition(SelfClosingStartTag)
                    break
                case TokeniserStateVars.greaterThanByte: // ">"
                    try t.emitTagPending()
                    t.transition(Data)
                    break
                default:
                    t.dataBuffer.append(byte)
                    needsExitTransition = true
                }
            } else {
                let c = r.consume()
                switch (c) {
                case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ":
                    t.transition(BeforeAttributeName)
                    break
                case "/":
                    t.transition(SelfClosingStartTag)
                    break
                case ">":
                    try t.emitTagPending()
                    t.transition(Data)
                    break
                default:
                    t.dataBuffer.append(c)
                    needsExitTransition = true
                }
            }
        } else {
            needsExitTransition = true
        }

        if (needsExitTransition) {
            t.emit(UTF8Arrays.endTagStart)
            t.emit(t.dataBuffer.buffer)
            t.clearTagStart()
            t.transition(elseTransition)
        }
    }

    private static func readData(_ t: Tokeniser, _ r: CharacterReader, _ current: TokeniserState, _ advance: TokeniserState)throws {
        if r.isEmpty() {
            try t.emitEOF()
            return
        }
        let byte = r.currentByte()!
        switch byte {
        case TokeniserStateVars.lessThanByte: // "<"
            t.markTagStart(r.pos)
            t.advanceTransition(advance)
            break
        case TokeniserStateVars.nullByte:
            t.error(current)
            r.advance()
            t.emit(TokeniserStateVars.replacementStr)
            break
        default:
            let dataStart = r.pos
            let data = r.consumeToAnyOfTwoSlice(TokeniserStateVars.lessThanByte, TokeniserStateVars.nullByte)
            t.emitRaw(data, start: dataStart, end: r.pos)
            break
        }
    }

    @inline(__always)
    internal static func readTagName(_ state: TokeniserState, _ t: Tokeniser, _ r: CharacterReader) throws {
        let (tagName, hasUppercase) = r.consumeTagNameWithUppercaseFlagSlice()
        if t.lowercaseTagNames && hasUppercase {
            t.tagPending.appendTagNameLowercased(tagName)
            if let lowered = t.tagPending.tagNameSlice() {
                t.tagPending.setTagIdFromSlice(lowered)
            }
        } else {
            t.tagPending.appendTagName(tagName, hasUppercase: hasUppercase)
            if !hasUppercase {
                t.tagPending.setTagIdFromSlice(tagName)
            } else {
                t.tagPending.tagId = .none
            }
        }
        if r.isEmpty() {
            t.eofError(state)
            t.transition(.Data)
            return
        }
        let byte = r.currentByte()!
        switch byte {
        case TokeniserStateVars.tabByte, TokeniserStateVars.newLineByte, TokeniserStateVars.carriageReturnByte, TokeniserStateVars.formFeedByte, TokeniserStateVars.spaceByte: // whitespace
            r.advanceAsciiWhitespace()
            _ = try consumeAttributesFast(t, r, .BeforeAttributeName)
            return
        case TokeniserStateVars.slashByte: // "/"
            r.advanceAscii()
            t.transition(.SelfClosingStartTag)
            return
        case TokeniserStateVars.greaterThanByte: // ">"
            r.advanceAscii()
            try t.emitTagPending()
            t.transition(.Data)
            return
        case TokeniserStateVars.nullByte:
            r.advanceAscii()
            t.tagPending.appendTagName(TokeniserStateVars.replacementStr)
            t.transition(.TagName)
            return
        default:
            if byte < TokeniserStateVars.asciiUpperLimitByte {
                r.advanceAscii()
            } else {
                r.advance()
            }
            t.transition(.TagName)
            return
        }
    }

    @inline(__always)
    internal static func readTagNameFromTagOpen(_ t: Tokeniser, _ r: CharacterReader, _ isStart: Bool) throws -> Bool {
        if r.isEmpty() {
            return false
        }
        t.createTagPending(isStart)
        let (tagName, hasUppercase) = r.consumeTagNameWithUppercaseFlagSlice()
        if t.lowercaseTagNames && hasUppercase {
            t.tagPending.appendTagNameLowercased(tagName)
            if let lowered = t.tagPending.tagNameSlice() {
                t.tagPending.setTagIdFromSlice(lowered)
            }
        } else {
            t.tagPending.appendTagName(tagName, hasUppercase: hasUppercase)
            if !hasUppercase {
                t.tagPending.setTagIdFromSlice(tagName)
            } else {
                t.tagPending.tagId = .none
            }
        }
        if t.trackAttributes {
            var i = r.pos
            while i < r.end {
                let b = r.input[i]
                if b == TokeniserStateVars.tabByte ||
                    b == TokeniserStateVars.newLineByte ||
                    b == TokeniserStateVars.carriageReturnByte ||
                    b == TokeniserStateVars.formFeedByte ||
                    b == TokeniserStateVars.spaceByte {
                    i &+= 1
                    continue
                }
                break
            }
            if i < r.end {
                let b = r.input[i]
                if b == TokeniserStateVars.greaterThanByte {
                    r.pos = i &+ 1
                    try t.emitTagPending()
                    t.transition(.Data)
                    return true
                }
                if b == TokeniserStateVars.slashByte {
                    var j = i &+ 1
                    while j < r.end {
                        let c = r.input[j]
                        if c == TokeniserStateVars.tabByte ||
                            c == TokeniserStateVars.newLineByte ||
                            c == TokeniserStateVars.carriageReturnByte ||
                            c == TokeniserStateVars.formFeedByte ||
                            c == TokeniserStateVars.spaceByte {
                            j &+= 1
                            continue
                        }
                        break
                    }
                    if j < r.end, r.input[j] == TokeniserStateVars.greaterThanByte {
                        t.tagPending._selfClosing = true
                        r.pos = j &+ 1
                        try t.emitTagPending()
                        t.transition(.Data)
                        return true
                    }
                }
            }
        }
        if !t.trackAttributes {
            var i = r.pos
            var inSingle = false
            var inDouble = false
            while i < r.end {
                let b = r.input[i]
                if inSingle {
                    if b == TokeniserStateVars.apostropheByte { // '
                        inSingle = false
                    }
                    i &+= 1
                    continue
                }
                if inDouble {
                    if b == TokeniserStateVars.quoteByte { // "
                        inDouble = false
                    }
                    i &+= 1
                    continue
                }
                switch b {
                case TokeniserStateVars.apostropheByte:
                    inSingle = true
                case TokeniserStateVars.quoteByte:
                    inDouble = true
                case TokeniserStateVars.slashByte:
                    let next = i &+ 1
                    if next < r.end, r.input[next] == TokeniserStateVars.greaterThanByte { // '/>'
                        t.tagPending._selfClosing = true
                        r.pos = next &+ 1
                        try t.emitTagPending()
                        t.transition(.Data)
                        return true
                    }
                case TokeniserStateVars.greaterThanByte: // '>'
                    r.pos = i &+ 1
                    try t.emitTagPending()
                    t.transition(.Data)
                    return true
                default:
                    break
                }
                i &+= 1
            }
            r.pos = r.end
            t.eofError(.TagName)
            t.transition(.Data)
            return true
        }
        if r.isEmpty() {
            t.eofError(.TagName)
            t.transition(.Data)
            return true
        }
        let byte = r.currentByte()!
        switch byte {
        case TokeniserStateVars.tabByte, TokeniserStateVars.newLineByte, TokeniserStateVars.carriageReturnByte, TokeniserStateVars.formFeedByte, TokeniserStateVars.spaceByte:
            r.advanceAsciiWhitespace()
            _ = try consumeAttributesFast(t, r, .BeforeAttributeName)
            return true
        case TokeniserStateVars.slashByte:
            r.advanceAscii()
            t.transition(.SelfClosingStartTag)
            return true
        case TokeniserStateVars.greaterThanByte:
            r.advanceAscii()
            try t.emitTagPending()
            t.transition(.Data)
            return true
        case TokeniserStateVars.nullByte:
            r.advanceAscii()
            t.tagPending.appendTagName(TokeniserStateVars.replacementStr)
            t.transition(.TagName)
            return true
        default:
            if byte < TokeniserStateVars.asciiUpperLimitByte {
                r.advanceAscii()
            } else {
                r.advance()
            }
            t.transition(.TagName)
            return true
        }
    }


    @inline(__always)
    private static func readAttributeName(_ state: TokeniserState, _ t: Tokeniser, _ r: CharacterReader) throws {
        let name: ByteSlice = r.consumeAttributeNameSlice()
        if !name.isEmpty {
            t.tagPending.appendAttributeName(name)
        }

        if r.isEmpty() {
            t.eofError(state)
            t.transition(.Data)
            return
        }
        let byte = r.currentByte()!
        switch byte {
        case TokeniserStateVars.tabByte, TokeniserStateVars.newLineByte, TokeniserStateVars.carriageReturnByte, TokeniserStateVars.formFeedByte, TokeniserStateVars.spaceByte:
            r.advanceAsciiWhitespace()
            t.transition(.AfterAttributeName)
            return
        case TokeniserStateVars.slashByte: // "/"
            r.advanceAscii()
            t.transition(.SelfClosingStartTag)
            return
        case TokeniserStateVars.equalSignByte: // "="
            r.advanceAscii()
            t.transition(.BeforeAttributeValue)
            return
        case TokeniserStateVars.greaterThanByte: // ">"
            r.advanceAscii()
            try t.emitTagPending()
            t.transition(.Data)
            return
        case TokeniserStateVars.nullByte:
            r.advanceAscii()
            t.error(state)
            t.tagPending.appendAttributeName(TokeniserStateVars.replacementChar)
            t.transition(.AttributeName)
            return
        case TokeniserStateVars.quoteByte, TokeniserStateVars.apostropheByte, TokeniserStateVars.lessThanByte: // "\"", "'", "<"
            r.advanceAscii()
            t.error(state)
            t.tagPending.appendAttributeNameByte(byte)
            t.transition(.AttributeName)
            return
        default:
            if byte < TokeniserStateVars.asciiUpperLimitByte {
                r.advanceAscii()
            } else {
                r.advance()
            }
            t.transition(.AttributeName)
            return
        }
    }

    @inline(__always)
    private static func consumeAttributesFast(_ t: Tokeniser, _ r: CharacterReader, _ state: TokeniserState) throws -> Bool {
        var afterName = (state == .AfterAttributeName)
        while true {
            if r.isEmpty() {
                t.eofError(state)
                t.transition(.Data)
                return true
            }
            var byte = r.currentByte()!
            if byte == TokeniserStateVars.tabByte || byte == TokeniserStateVars.newLineByte || byte == TokeniserStateVars.carriageReturnByte || byte == TokeniserStateVars.formFeedByte || byte == TokeniserStateVars.spaceByte {
                r.advanceAsciiWhitespace()
                if r.isEmpty() {
                    t.eofError(state)
                    t.transition(.Data)
                    return true
                }
                byte = r.currentByte()!
            }

            if afterName && byte == TokeniserStateVars.equalSignByte {
                r.advanceAscii()
                if try consumeAttributeValueFast(t, r) {
                    return true
                }
                afterName = false
                continue
            }

            switch byte {
            case TokeniserStateVars.slashByte: // "/"
                r.advanceAscii()
                t.transition(.SelfClosingStartTag)
                return true
            case TokeniserStateVars.greaterThanByte: // ">"
                r.advanceAscii()
                try t.emitTagPending()
                t.transition(.Data)
                return true
            case TokeniserStateVars.nullByte:
                if afterName {
                    r.advanceAscii()
                    t.error(.AfterAttributeName)
                    t.tagPending.appendAttributeName(TokeniserStateVars.replacementChar)
                    t.transition(.AttributeName)
                    return true
                } else {
                    t.error(.BeforeAttributeName)
                    if t.tagPending.hasPendingAttributeName() {
                        try t.tagPending.newAttribute()
                    }
                    t.transition(.AttributeName)
                    return true
                }
            case TokeniserStateVars.quoteByte, TokeniserStateVars.apostropheByte, TokeniserStateVars.lessThanByte, TokeniserStateVars.equalSignByte: // "\"", "'", "<", "="
                if afterName {
                    r.advanceAscii()
                    t.error(.AfterAttributeName)
                    if t.tagPending.hasPendingAttributeName() {
                        try t.tagPending.newAttribute()
                    }
                    t.tagPending.appendAttributeNameByte(byte)
                    t.transition(.AttributeName)
                    return true
                } else {
                    r.advanceAscii()
                    t.error(.BeforeAttributeName)
                    if t.tagPending.hasPendingAttributeName() {
                        try t.tagPending.newAttribute()
                    }
                    t.tagPending.appendAttributeNameByte(byte)
                    t.transition(.AttributeName)
                    return true
                }
            default:
                if t.tagPending.hasPendingAttributeName() {
                    try t.tagPending.newAttribute()
                }
                if try consumeAttributeNameAndValueFast(t, r) {
                    return true
                }
                afterName = false
            }
        }
    }

    @inline(__always)
    private static func consumeAttributeNameAndValueFast(_ t: Tokeniser, _ r: CharacterReader) throws -> Bool {
        let name: ByteSlice = r.consumeAttributeNameSlice()
        if !name.isEmpty {
            t.tagPending.appendAttributeName(name)
        }
        if r.isEmpty() {
            t.eofError(.AttributeName)
            t.transition(.Data)
            return true
        }

        var byte = r.currentByte()!
        if byte == TokeniserStateVars.tabByte || byte == TokeniserStateVars.newLineByte || byte == TokeniserStateVars.carriageReturnByte || byte == TokeniserStateVars.formFeedByte || byte == TokeniserStateVars.spaceByte {
            r.advanceAsciiWhitespace()
            if r.isEmpty() {
                t.eofError(.AfterAttributeName)
                t.transition(.Data)
                return true
            }
            byte = r.currentByte()!
        }

        switch byte {
        case TokeniserStateVars.equalSignByte: // "="
            r.advanceAscii()
            return try consumeAttributeValueFast(t, r)
        case TokeniserStateVars.slashByte: // "/"
            r.advanceAscii()
            t.transition(.SelfClosingStartTag)
            return true
        case TokeniserStateVars.greaterThanByte: // ">"
            r.advanceAscii()
            try t.emitTagPending()
            t.transition(.Data)
            return true
        case TokeniserStateVars.nullByte:
            r.advanceAscii()
            t.error(.AttributeName)
            t.tagPending.appendAttributeName(TokeniserStateVars.replacementChar)
            t.transition(.AttributeName)
            return true
        case TokeniserStateVars.quoteByte, TokeniserStateVars.apostropheByte, TokeniserStateVars.lessThanByte:
            r.advanceAscii()
            t.error(.AttributeName)
            t.tagPending.appendAttributeNameByte(byte)
            t.transition(.AttributeName)
            return true
        default:
            return false
        }
    }


    @inline(__always)
    private static func consumeAttributeValueFast(_ t: Tokeniser, _ r: CharacterReader) throws -> Bool {
        if r.isEmpty() {
            t.eofError(.BeforeAttributeValue)
            try t.emitTagPending()
            t.transition(.Data)
            return true
        }
        var byte = r.currentByte()!
        if byte == TokeniserStateVars.tabByte || byte == TokeniserStateVars.newLineByte || byte == TokeniserStateVars.carriageReturnByte || byte == TokeniserStateVars.formFeedByte || byte == TokeniserStateVars.spaceByte {
            r.advanceAsciiWhitespace()
            if r.isEmpty() {
                t.eofError(.BeforeAttributeValue)
                try t.emitTagPending()
                t.transition(.Data)
                return true
            }
            byte = r.currentByte()!
        }

        switch byte {
        case TokeniserStateVars.quoteByte: // "\""
            r.advanceAscii()
            return try consumeQuotedAttributeValueFast(t, r, TokeniserStateVars.quoteByte, .AttributeValue_doubleQuoted)
        case TokeniserStateVars.apostropheByte: // "'"
            r.advanceAscii()
            return try consumeQuotedAttributeValueFast(t, r, TokeniserStateVars.apostropheByte, .AttributeValue_singleQuoted)
        case TokeniserStateVars.ampersandByte: // "&"
            return try consumeUnquotedAttributeValueFast(t, r)
        case TokeniserStateVars.nullByte:
            r.advanceAscii()
            t.error(.BeforeAttributeValue)
            t.tagPending.appendAttributeValue(TokeniserStateVars.replacementChar)
            return try consumeUnquotedAttributeValueFast(t, r)
        case TokeniserStateVars.greaterThanByte: // ">"
            r.advanceAscii()
            t.error(.BeforeAttributeValue)
            try t.emitTagPending()
            t.transition(.Data)
            return true
        case TokeniserStateVars.lessThanByte, TokeniserStateVars.equalSignByte, TokeniserStateVars.backtickByte: // "<", "=", "`"
            r.advanceAscii()
            t.error(.BeforeAttributeValue)
            t.tagPending.appendAttributeValueByte(byte)
            return try consumeUnquotedAttributeValueFast(t, r)
        default:
            return try consumeUnquotedAttributeValueFast(t, r)
        }
    }

    @inline(__always)
    private static func consumeQuotedAttributeValueFast(_ t: Tokeniser, _ r: CharacterReader, _ quote: UInt8, _ state: TokeniserState) throws -> Bool {
        while true {
            let value: ByteSlice = (quote == TokeniserStateVars.quoteByte) ? r.consumeAttributeValueDoubleQuotedSlice() : r.consumeAttributeValueSingleQuotedSlice()
            if !value.isEmpty {
                t.tagPending.appendAttributeValue(value)
            } else if let nextByte = r.currentByte(), nextByte == quote {
                t.tagPending.setEmptyAttributeValue()
            }

            if r.isEmpty() {
                t.eofError(state)
                t.transition(.Data)
                return true
            }
            let byte = r.currentByte()!
            if byte == quote {
                r.advanceAscii()
                return try handleAfterQuotedValueFast(t, r)
            }

            switch byte {
            case TokeniserStateVars.ampersandByte: // "&"
                r.advanceAscii()
                if Self.isLikelyQueryStringAmpersand(r) {
                    t.tagPending.appendAttributeValue(UnicodeScalar.Ampersand)
                    continue
                }
                let allowed: UnicodeScalar = (quote == TokeniserStateVars.quoteByte) ? "\"" : "'"
                if let ref = try t.consumeCharacterReference(allowed, true) {
                    t.tagPending.appendAttributeValue(ref)
                } else {
                    t.tagPending.appendAttributeValue(UnicodeScalar.Ampersand)
                }
            case TokeniserStateVars.nullByte:
                r.advanceAscii()
                t.error(state)
                t.tagPending.appendAttributeValue(TokeniserStateVars.replacementChar)
            default:
                if byte < TokeniserStateVars.asciiUpperLimitByte {
                    r.advanceAscii()
                } else {
                    r.advance()
                }
            }
        }
    }

    @inline(__always)
    private static func consumeUnquotedAttributeValueFast(_ t: Tokeniser, _ r: CharacterReader) throws -> Bool {
        while true {
            let value: ByteSlice = r.consumeAttributeValueUnquotedSlice()
            if !value.isEmpty {
                t.tagPending.appendAttributeValue(value)
            }

            if r.isEmpty() {
                t.eofError(.AttributeValue_unquoted)
                t.transition(.Data)
                return true
            }
            let byte = r.currentByte()!
            switch byte {
            case TokeniserStateVars.tabByte, TokeniserStateVars.newLineByte, TokeniserStateVars.carriageReturnByte, TokeniserStateVars.formFeedByte, TokeniserStateVars.spaceByte:
                r.advanceAsciiWhitespace()
                return false
            case TokeniserStateVars.ampersandByte: // "&"
                r.advanceAscii()
                if Self.isLikelyQueryStringAmpersand(r) {
                    t.tagPending.appendAttributeValue(UnicodeScalar.Ampersand)
                    continue
                }
                if let ref = try t.consumeCharacterReference(">", true) {
                    t.tagPending.appendAttributeValue(ref)
                } else {
                    t.tagPending.appendAttributeValue(UnicodeScalar.Ampersand)
                }
            case TokeniserStateVars.greaterThanByte: // ">"
                r.advanceAscii()
                try t.emitTagPending()
                t.transition(.Data)
                return true
            case TokeniserStateVars.nullByte:
                r.advanceAscii()
                t.error(.AttributeValue_unquoted)
                t.tagPending.appendAttributeValue(TokeniserStateVars.replacementChar)
            case TokeniserStateVars.quoteByte, TokeniserStateVars.apostropheByte, TokeniserStateVars.lessThanByte, TokeniserStateVars.equalSignByte, TokeniserStateVars.backtickByte: // "\"", "'", "<", "=", "`"
                r.advanceAscii()
                t.error(.AttributeValue_unquoted)
                t.tagPending.appendAttributeValueByte(byte)
            default:
                if byte < TokeniserStateVars.asciiUpperLimitByte {
                    r.advanceAscii()
                    t.tagPending.appendAttributeValueByte(byte)
                } else {
                    let c = r.consume()
                    if c == TokeniserStateVars.eof {
                        t.eofError(.AttributeValue_unquoted)
                        t.transition(.Data)
                        return true
                    }
                    t.tagPending.appendAttributeValue(c)
                }
            }
        }
    }

    /// Fast path for attribute values that look like query strings (e.g., "a=1&b=2").
    @inline(__always)
    private static func isLikelyQueryStringAmpersand(_ r: CharacterReader) -> Bool {
        let start = r.pos
        if start >= r.end { return false }
        let input = r.input
        var i = start
        let scanLimit = min(r.end, start + Self.attrAmpersandQueryStringScanLimit)
        while i < scanLimit {
            let byte = input[i]
            switch byte {
            case TokeniserStateVars.equalSignByte:
                return true
            case TokeniserStateVars.semicolonByte:
                return false
            case TokeniserStateVars.ampersandByte:
                return true
            case TokeniserStateVars.quoteByte,
                 TokeniserStateVars.apostropheByte,
                 TokeniserStateVars.lessThanByte,
                 TokeniserStateVars.greaterThanByte,
                 TokeniserStateVars.backtickByte,
                 TokeniserStateVars.nullByte,
                 TokeniserStateVars.tabByte,
                 TokeniserStateVars.newLineByte,
                 TokeniserStateVars.carriageReturnByte,
                 TokeniserStateVars.formFeedByte,
                 TokeniserStateVars.spaceByte:
                return false
            default:
                break
            }
            i &+= 1
        }
        return false
    }

    @inline(__always)
    private static func handleAfterQuotedValueFast(_ t: Tokeniser, _ r: CharacterReader) throws -> Bool {
        if r.isEmpty() {
            t.eofError(.AfterAttributeValue_quoted)
            t.transition(.Data)
            return true
        }
        let byte = r.currentByte()!
        switch byte {
        case TokeniserStateVars.tabByte, TokeniserStateVars.newLineByte, TokeniserStateVars.carriageReturnByte, TokeniserStateVars.formFeedByte, TokeniserStateVars.spaceByte:
            r.advanceAsciiWhitespace()
            return false
        case TokeniserStateVars.slashByte: // "/"
            r.advanceAscii()
            t.transition(.SelfClosingStartTag)
            return true
        case TokeniserStateVars.greaterThanByte: // ">"
            r.advanceAscii()
            try t.emitTagPending()
            t.transition(.Data)
            return true
        default:
            t.error(.AfterAttributeValue_quoted)
            return false
        }
    }

    @inline(__always)
    static func readCharRef(_ t: Tokeniser, _ advance: TokeniserState)throws {
        if let byte = t.currentByte(), Tokeniser.isNotCharRefAscii(byte) {
            t.emit(UnicodeScalar.Ampersand)
            t.transition(advance)
            return
        }
        if let b = t.currentByte(), b != TokeniserStateVars.hashByte {
            if isLikelyQueryStringAmpersand(t.readerRef) {
                t.emit(UnicodeScalar.Ampersand)
                t.transition(advance)
                return
            }
        }
        if let entity = t.consumeBasicNamedEntityIfPresent() {
            t.emit(entity)
            t.transition(advance)
            return
        }
        let c = try t.consumeCharacterReference(nil, false)
        if (c == nil) {
            t.emit(UnicodeScalar.Ampersand)
        } else {
            t.emit(c!)
        }
        t.transition(advance)
    }

    private static func readEndTag(_ t: Tokeniser, _ r: CharacterReader, _ a: TokeniserState, _ b: TokeniserState) {
        if let byte = r.currentByte() {
            if byte < TokeniserStateVars.asciiUpperLimitByte {
                if TokeniserStateVars.isAsciiAlpha(byte) {
                    t.createTagPending(false)
                    t.transition(a)
                } else {
                    t.clearTagStart()
                    t.emit(UTF8Arrays.endTagStart)
                    t.transition(b)
                }
                return
            }
        }
        if r.matchesLetter() {
            t.createTagPending(false)
            t.transition(a)
        } else {
            t.clearTagStart()
            t.emit(UTF8Arrays.endTagStart)
            t.transition(b)
        }
    }

    private static func handleDataDoubleEscapeTag(_ t: Tokeniser, _ r: CharacterReader, _ primary: TokeniserState, _ fallback: TokeniserState) {
        @inline(__always)
        func transitionForDataBuffer(_ t: Tokeniser, _ primary: TokeniserState, _ fallback: TokeniserState) {
            if t.dataBuffer.buffer == UTF8ArraySlices.script {
                t.transition(primary)
            } else {
                t.transition(fallback)
            }
        }
        if let byte = r.currentByte() {
            if byte < TokeniserStateVars.asciiUpperLimitByte {
                if TokeniserStateVars.isAsciiAlpha(byte) {
                    let name = r.consumeLetterSequenceSlice()
                    t.dataBuffer.append(name)
                    t.emit(name)
                    return
                }
                switch byte {
                case TokeniserStateVars.tabByte, TokeniserStateVars.newLineByte, TokeniserStateVars.carriageReturnByte, TokeniserStateVars.formFeedByte, TokeniserStateVars.spaceByte, TokeniserStateVars.slashByte, TokeniserStateVars.greaterThanByte:
                    r.advanceAscii()
                    transitionForDataBuffer(t, primary, fallback)
                    t.emitByte(byte)
                    return
                default:
                    t.transition(fallback)
                    return
                }
            }
        }

        if (r.matchesLetter()) {
            let name = r.consumeLetterSequenceSlice()
            t.dataBuffer.append(name)
            t.emit(name)
            return
        }

        let c = r.consume()
        switch (c) {
        case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ", "/", ">":
            transitionForDataBuffer(t, primary, fallback)
            t.emit(c)
            break
        default:
            r.unconsume()
            t.transition(fallback)
        }
    }

}
