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
    static let eofUTF8Slice = ArraySlice(String(CharacterReader.EOF).utf8Array)
    static let commentStartUTF8 = "--".utf8Array
    static let doctypeUTF8 = "DOCTYPE".utf8Array
    static let cdataStartUTF8 = "[CDATA[".utf8Array
    static let cdataEndUTF8 = "]]>".utf8Array
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

    @inlinable
    internal func read(_ t: Tokeniser, _ r: CharacterReader) throws {
        #if PROFILE
        let _p = Profiler.startDynamic("TokeniserState.\(self)")
        defer { Profiler.endDynamic("TokeniserState.\(self)", _p) }
        #endif
        switch self {
        case .Data:
            if r.isEmpty() {
                try t.emit(Token.EOF())
                break
            }
            let byte = r.currentByte()!
            switch byte {
            case 0x26: // "&"
                t.advanceTransitionAscii(.CharacterReferenceInData)
                break
            case 0x3C: // "<"
                t.advanceTransitionAscii(.TagOpen)
                break
            case 0x00:
                t.error(self) // NOT replacement character (oddly?)
                t.emit(r.consume())
                break
            default:
                let data: ArraySlice<UInt8> = r.consumeData()
                t.emit(data)
                break
            }
            break
        case .CharacterReferenceInData:
            try TokeniserState.readCharRef(t, .Data)
            break
        case .Rcdata:
            if r.isEmpty() {
                try t.emit(Token.EOF())
                break
            }
            let byte = r.currentByte()!
            switch byte {
            case 0x26: // "&"
                t.advanceTransitionAscii(.CharacterReferenceInRcdata)
                break
            case 0x3C: // "<"
                t.advanceTransitionAscii(.RcdataLessthanSign)
                break
            case 0x00:
                t.error(self)
                r.advance()
                t.emit(TokeniserStateVars.replacementStr)
                break
            default:
                let data: ArraySlice<UInt8> = r.consumeToAny(TokeniserStateVars.dataDefaultStopChars)
                t.emit(data)
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
                try t.emit(Token.EOF())
                break
            }
            let byte = r.currentByte()!
            switch byte {
            case 0x00:
                t.error(self)
                r.advance()
                t.emit(TokeniserStateVars.replacementStr)
                break
            default:
                let data = r.consumeToAnyOfTwo(0x00, 0xFF)
                t.emit(data)
                break
            }
            break
        case .TagOpen:
            // from < in data
            if let byte = r.currentByte() {
                switch byte {
                case 0x21: // "!"
                    t.advanceTransitionAscii(.MarkupDeclarationOpen)
                    break
                case 0x2F: // "/"
                    t.advanceTransitionAscii(.EndTagOpen)
                    break
                case 0x3F: // "?"
                    t.advanceTransitionAscii(.BogusComment)
                    break
                default:
                    if r.matchesLetter() {
                        t.createTagPending(true)
                        t.transition(.TagName)
                    } else {
                        t.error(self)
                        t.emit(UnicodeScalar.LessThan) // char that got us here
                        t.transition(.Data)
                    }
                    break
                }
            } else {
                if r.matchesLetter() {
                    t.createTagPending(true)
                    t.transition(.TagName)
                } else {
                    t.error(self)
                    t.emit(UnicodeScalar.LessThan) // char that got us here
                    t.transition(.Data)
                }
            }
            break
        case .EndTagOpen:
            if (r.isEmpty()) {
                t.eofError(self)
                t.emit(UTF8Arrays.endTagStart)
                t.transition(.Data)
            } else if (r.matchesLetter()) {
                t.createTagPending(false)
                t.transition(.TagName)
            } else if (r.matches(UTF8Arrays.tagEnd)) {
                t.error(self)
                t.advanceTransition(.Data)
            } else {
                t.error(self)
                t.advanceTransition(.BogusComment)
            }
            break
        case .TagName:
            // from < or </ in data, will have start or end tag pending
            // previous TagOpen state did NOT consume, will have a letter char in current
            //String tagName = r.consumeToAnySorted(tagCharsSorted).toLowerCase()
            let tagName: ArraySlice<UInt8> = r.consumeTagName()
            t.tagPending.appendTagName(tagName)
            if r.isEmpty() {
                t.eofError(self)
                t.transition(.Data)
                break
            }
            let byte = r.currentByte()!
            switch byte {
            case 0x09, 0x0A, 0x0D, 0x0C, 0x20: // whitespace
                r.advance()
                t.transition(.BeforeAttributeName)
                break
            case 0x2F: // "/"
                r.advance()
                t.transition(.SelfClosingStartTag)
                break
            case 0x3E: // ">"
                r.advance()
                try t.emitTagPending()
                t.transition(.Data)
                break
            case 0x00:
                r.advance()
                t.tagPending.appendTagName(TokeniserStateVars.replacementStr)
                break
            default:
                let c = r.consume()
                switch (c) {
                case TokeniserStateVars.eof:
                    t.eofError(self)
                    t.transition(.Data)
                    break
                default:
                    break
                }
            }
        case .RcdataLessthanSign:
            if (r.matches(UTF8Arrays.forwardSlash)) {
                t.createTempBuffer()
                t.advanceTransition(.RCDATAEndTagOpen)
            } else if r.matchesLetter(), let endTagName = t.appropriateEndTagName(),
                      !r.containsIgnoreCase(prefix: UTF8Arrays.endTagStart, suffix: endTagName) {
                // diverge from spec: got a start tag, but there's no appropriate end tag (</title>), so rather than
                // consuming to EOF break out here
                t.tagPending = t.createTagPending(false).name(endTagName)
                try t.emitTagPending()
                r.unconsume() // undo UnicodeScalar.LessThan
                t.transition(.Data)
            } else {
                t.emit(UnicodeScalar.LessThan)
                t.transition(.Rcdata)
            }
            break
        case .RCDATAEndTagOpen:
            if (r.matchesLetter()) {
                let byte = r.currentByte()!
                t.createTagPending(false)
                t.tagPending.appendTagNameByte(byte)
                t.dataBuffer.append(byte)
                t.advanceTransition(.RCDATAEndTagName)
            } else {
                t.emit(UTF8Arrays.endTagStart)
                t.transition(.Rcdata)
            }
            break
        case .RCDATAEndTagName:
            if (r.matchesLetter()) {
                let name = r.consumeLetterSequence()
                t.tagPending.appendTagName(name)
                t.dataBuffer.append(name)
                return
            }

            func anythingElse(_ t: Tokeniser, _ r: CharacterReader) {
                t.emit(UTF8Arrays.endTagStart)
                t.emit(t.dataBuffer.buffer)
                r.unconsume()
                t.transition(.Rcdata)
            }

            let c = r.consume()
            switch (c) {
            case UnicodeScalar.BackslashT:
                if (try t.isAppropriateEndTagToken()) {
                    t.transition(.BeforeAttributeName)
                } else {
                    anythingElse(t, r)
                }
                break
            case "\n":
                if (try t.isAppropriateEndTagToken()) {
                    t.transition(.BeforeAttributeName)
                } else {
                    anythingElse(t, r)
                }
                break
            case "\r":
                if (try t.isAppropriateEndTagToken()) {
                    t.transition(.BeforeAttributeName)
                } else {
                    anythingElse(t, r)
                }
                break
            case UnicodeScalar.BackslashF:
                if (try t.isAppropriateEndTagToken()) {
                    t.transition(.BeforeAttributeName)
                } else {
                    anythingElse(t, r)
                }
                break
            case " ":
                if (try t.isAppropriateEndTagToken()) {
                    t.transition(.BeforeAttributeName)
                } else {
                    anythingElse(t, r)
                }
                break
            case "/":
                if (try t.isAppropriateEndTagToken()) {
                    t.transition(.SelfClosingStartTag)
                } else {
                    anythingElse(t, r)
                }
                break
            case ">":
                if (try t.isAppropriateEndTagToken()) {
                    try t.emitTagPending()
                    t.transition(.Data)
                } else {anythingElse(t, r)}
                break
            default:
                anythingElse(t, r)
                break
            }
            break
        case .RawtextLessthanSign:
            if (r.matches(UTF8Arrays.forwardSlash)) {
                t.createTempBuffer()
                t.advanceTransition(.RawtextEndTagOpen)
            } else {
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
            switch (r.consume()) {
            case "/":
                t.createTempBuffer()
                t.transition(.ScriptDataEndTagOpen)
                break
            case "!":
                t.emit("<!")
                t.transition(.ScriptDataEscapeStart)
                break
            default:
                t.emit(UnicodeScalar.LessThan)
                r.unconsume()
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
            case 0x2D: // "-"
                t.emit(UTF8Arrays.hyphen)
                t.advanceTransitionAscii(.ScriptDataEscapedDash)
                break
            case 0x3C: // "<"
                t.advanceTransitionAscii(.ScriptDataEscapedLessthanSign)
                break
            case 0x00:
                t.error(self)
                r.advance()
                t.emit(TokeniserStateVars.replacementStr)
                break
            default:
                let data: ArraySlice<UInt8> = r.consumeToAnyOfTwo(0x2D, 0x3C)
                t.emit(data)
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
                case 0x2D: // "-"
                    r.advance()
                    t.emit(UTF8Arrays.hyphen)
                    t.transition(.ScriptDataEscapedDashDash)
                    break
                case 0x3C: // "<"
                    r.advance()
                    t.transition(.ScriptDataEscapedLessthanSign)
                    break
                case 0x00:
                    r.advance()
                    t.error(self)
                    t.emit(TokeniserStateVars.replacementStr)
                    t.transition(.ScriptDataEscaped)
                    break
                default:
                    let c = r.consume()
                    t.emit(c)
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
                case 0x2D: // "-"
                    r.advance()
                    t.emit(UTF8Arrays.hyphen)
                    break
                case 0x3C: // "<"
                    r.advance()
                    t.transition(.ScriptDataEscapedLessthanSign)
                    break
                case 0x3E: // ">"
                    r.advance()
                    t.emit(UTF8Arrays.tagEnd)
                    t.transition(.ScriptData)
                    break
                case 0x00:
                    r.advance()
                    t.error(self)
                    t.emit(TokeniserStateVars.replacementStr)
                    t.transition(.ScriptDataEscaped)
                    break
                default:
                    let c = r.consume()
                    t.emit(c)
                    t.transition(.ScriptDataEscaped)
                }
            } else {
                let c = r.consume()
                t.emit(c)
                t.transition(.ScriptDataEscaped)
            }
            break
        case .ScriptDataEscapedLessthanSign:
            if (r.matchesLetter()) {
                let byte = r.currentByte()!
                t.createTempBuffer()
                t.dataBuffer.append(byte)
                t.emit(UTF8Arrays.tagStart)
                t.emit([byte])
                t.advanceTransition(.ScriptDataDoubleEscapeStart)
            } else if (r.matches(UTF8Arrays.forwardSlash)) {
                t.createTempBuffer()
                t.advanceTransition(.ScriptDataEscapedEndTagOpen)
            } else {
                t.emit(UnicodeScalar.LessThan)
                t.transition(.ScriptDataEscaped)
            }
            break
        case .ScriptDataEscapedEndTagOpen:
            if (r.matchesLetter()) {
                let byte = r.currentByte()!
                t.createTagPending(false)
                t.tagPending.appendTagNameByte(byte)
                t.dataBuffer.append(byte)
                t.advanceTransition(.ScriptDataEscapedEndTagName)
            } else {
                t.emit(UTF8Arrays.endTagStart)
                t.transition(.ScriptDataEscaped)
            }
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
            case 0x2D: // "-"
                t.emit(UTF8Arrays.hyphen)
                t.advanceTransitionAscii(.ScriptDataDoubleEscapedDash)
                break
            case 0x3C: // "<"
                t.emit(UTF8Arrays.tagStart)
                t.advanceTransitionAscii(.ScriptDataDoubleEscapedLessthanSign)
                break
            case 0x00:
                t.error(self)
                r.advance()
                t.emit(TokeniserStateVars.replacementStr)
                break
            default:
                let data: ArraySlice<UInt8> = r.consumeToAnyOfTwo(0x2D, 0x3C)
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
                case 0x2D: // "-"
                    r.advance()
                    t.emit(UTF8Arrays.hyphen)
                    t.transition(.ScriptDataDoubleEscapedDashDash)
                    break
                case 0x3C: // "<"
                    r.advance()
                    t.emit(UTF8Arrays.tagStart)
                    t.transition(.ScriptDataDoubleEscapedLessthanSign)
                    break
                case 0x00:
                    r.advance()
                    t.error(self)
                    t.emit(TokeniserStateVars.replacementStr)
                    t.transition(.ScriptDataDoubleEscaped)
                    break
                default:
                    let c = r.consume()
                    t.emit(c)
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
                case 0x2D: // "-"
                    r.advance()
                    t.emit(UTF8Arrays.hyphen)
                    break
                case 0x3C: // "<"
                    r.advance()
                    t.emit(UTF8Arrays.tagStart)
                    t.transition(.ScriptDataDoubleEscapedLessthanSign)
                    break
                case 0x3E: // ">"
                    r.advance()
                    t.emit(UTF8Arrays.tagEnd)
                    t.transition(.ScriptData)
                    break
                case 0x00:
                    r.advance()
                    t.error(self)
                    t.emit(TokeniserStateVars.replacementStr)
                    t.transition(.ScriptDataDoubleEscaped)
                    break
                default:
                    let c = r.consume()
                    t.emit(c)
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
            if r.isEmpty() {
                t.eofError(self)
                t.transition(.Data)
                break
            }
            let byte = r.currentByte()!
            switch byte {
            case 0x09, 0x0A, 0x0D, 0x0C, 0x20:
                r.advanceAscii()
                break // ignore whitespace
            case 0x2F: // "/"
                r.advanceAscii()
                t.transition(.SelfClosingStartTag)
                break
            case 0x3E: // ">"
                r.advanceAscii()
                try t.emitTagPending()
                t.transition(.Data)
                break
            case 0x00:
                t.error(self)
                try t.tagPending.newAttribute()
                t.transition(.AttributeName)
                break
            case 0x22, 0x27, 0x3C, 0x3D: // "\"", "'", "<", "="
                r.advanceAscii()
                t.error(self)
                try t.tagPending.newAttribute()
                t.tagPending.appendAttributeNameByte(byte)
                t.transition(.AttributeName)
                break
            default:
                let c = r.consume()
                switch c {
                case TokeniserStateVars.eof:
                    t.eofError(self)
                    t.transition(.Data)
                    break
                default:
                    try t.tagPending.newAttribute()
                    r.unconsume()
                    t.transition(.AttributeName)
                }
            }
            break
        case .AttributeName:
            let name: ArraySlice<UInt8> = r.consumeToAny(TokeniserStateVars.attributeNameChars)
            if !name.isEmpty {
                t.tagPending.appendAttributeName(name)
            }

            if r.isEmpty() {
                t.eofError(self)
                t.transition(.Data)
                break
            }
            let byte = r.currentByte()!
            switch byte {
            case 0x09, 0x0A, 0x0D, 0x0C, 0x20:
                r.advanceAscii()
                t.transition(.AfterAttributeName)
                break
            case 0x2F: // "/"
                r.advanceAscii()
                t.transition(.SelfClosingStartTag)
                break
            case 0x3D: // "="
                r.advanceAscii()
                t.transition(.BeforeAttributeValue)
                break
            case 0x3E: // ">"
                r.advanceAscii()
                try t.emitTagPending()
                t.transition(.Data)
                break
            case 0x00:
                r.advanceAscii()
                t.error(self)
                t.tagPending.appendAttributeName(TokeniserStateVars.replacementChar)
                break
            case 0x22, 0x27, 0x3C: // "\"", "'", "<"
                r.advanceAscii()
                t.error(self)
                t.tagPending.appendAttributeNameByte(byte)
                break
            default:
                let c = r.consume()
                if c == TokeniserStateVars.eof {
                    t.eofError(self)
                    t.transition(.Data)
                }
            }
            break
        case .AfterAttributeName:
            if r.isEmpty() {
                t.eofError(self)
                t.transition(.Data)
                break
            }
            let byte = r.currentByte()!
            switch byte {
            case 0x09, 0x0A, 0x0D, 0x0C, 0x20:
                r.advanceAscii()
                break // ignore
            case 0x2F: // "/"
                r.advanceAscii()
                t.transition(.SelfClosingStartTag)
                break
            case 0x3D: // "="
                r.advanceAscii()
                t.transition(.BeforeAttributeValue)
                break
            case 0x3E: // ">"
                r.advanceAscii()
                try t.emitTagPending()
                t.transition(.Data)
                break
            case 0x00:
                r.advanceAscii()
                t.error(self)
                t.tagPending.appendAttributeName(TokeniserStateVars.replacementChar)
                t.transition(.AttributeName)
                break
            case 0x22, 0x27, 0x3C: // "\"", "'", "<"
                r.advanceAscii()
                t.error(self)
                try t.tagPending.newAttribute()
                t.tagPending.appendAttributeNameByte(byte)
                t.transition(.AttributeName)
                break
            default:
                let c = r.consume()
                switch c {
                case TokeniserStateVars.eof:
                    t.eofError(self)
                    t.transition(.Data)
                    break
                default:
                    try t.tagPending.newAttribute()
                    r.unconsume()
                    t.transition(.AttributeName)
                }
            }
            break
        case .BeforeAttributeValue:
            if r.isEmpty() {
                t.eofError(self)
                try t.emitTagPending()
                t.transition(.Data)
                break
            }
            let byte = r.currentByte()!
            switch byte {
            case 0x09, 0x0A, 0x0D, 0x0C, 0x20:
                r.advanceAscii()
                break // ignore
            case 0x22: // "\""
                r.advanceAscii()
                t.transition(.AttributeValue_doubleQuoted)
                break
            case 0x26: // "&"
                r.advanceAscii()
                r.unconsume()
                t.transition(.AttributeValue_unquoted)
                break
            case 0x27: // "'"
                r.advanceAscii()
                t.transition(.AttributeValue_singleQuoted)
                break
            case 0x00:
                r.advanceAscii()
                t.error(self)
                t.tagPending.appendAttributeValue(TokeniserStateVars.replacementChar)
                t.transition(.AttributeValue_unquoted)
                break
            case 0x3E: // ">"
                r.advanceAscii()
                t.error(self)
                try t.emitTagPending()
                t.transition(.Data)
                break
            case 0x3C, 0x3D, 0x60: // "<", "=", "`"
                r.advanceAscii()
                t.error(self)
                t.tagPending.appendAttributeValueByte(byte)
                t.transition(.AttributeValue_unquoted)
                break
            default:
                let c = r.consume()
                switch c {
                case TokeniserStateVars.eof:
                    t.eofError(self)
                    try t.emitTagPending()
                    t.transition(.Data)
                    break
                default:
                    r.unconsume()
                    t.transition(.AttributeValue_unquoted)
                }
            }
            break
        case .AttributeValue_doubleQuoted:
            let value: ArraySlice<UInt8> = r.consumeToAny(TokeniserStateVars.attributeDoubleValueChars)
            if !value.isEmpty {
                t.tagPending.appendAttributeValue(value)
            } else {
                t.tagPending.setEmptyAttributeValue()
            }

            if r.isEmpty() {
                t.eofError(self)
                t.transition(.Data)
                break
            }
            let byte = r.currentByte()!
            switch byte {
            case 0x22: // "\""
                r.advanceAscii()
                t.transition(.AfterAttributeValue_quoted)
                break
            case 0x26: // "&"
                r.advanceAscii()
                if let ref = try t.consumeCharacterReference("\"", true) {
                    t.tagPending.appendAttributeValue(ref)
                } else {
                    t.tagPending.appendAttributeValue(UnicodeScalar.Ampersand)
                }
                break
            case 0x00:
                r.advanceAscii()
                t.error(self)
                t.tagPending.appendAttributeValue(TokeniserStateVars.replacementChar)
                break
            default:
                let c = r.consume()
                if c == TokeniserStateVars.eof {
                    t.eofError(self)
                    t.transition(.Data)
                }
                break
            }
            break
        case .AttributeValue_singleQuoted:
            let value: ArraySlice<UInt8> = r.consumeToAny(TokeniserStateVars.attributeSingleValueChars)
            if !value.isEmpty {
                t.tagPending.appendAttributeValue(value)
            } else {
                t.tagPending.setEmptyAttributeValue()
            }

            if r.isEmpty() {
                t.eofError(self)
                t.transition(.Data)
                break
            }
            let byte = r.currentByte()!
            switch byte {
            case 0x27: // "'"
                r.advanceAscii()
                t.transition(.AfterAttributeValue_quoted)
                break
            case 0x26: // "&"
                r.advanceAscii()
                if let ref = try t.consumeCharacterReference("'", true) {
                    t.tagPending.appendAttributeValue(ref)
                } else {
                    t.tagPending.appendAttributeValue(UnicodeScalar.Ampersand)
                }
                break
            case 0x00:
                r.advanceAscii()
                t.error(self)
                t.tagPending.appendAttributeValue(TokeniserStateVars.replacementChar)
                break
            default:
                let c = r.consume()
                if c == TokeniserStateVars.eof {
                    t.eofError(self)
                    t.transition(.Data)
                }
                break
            }
            break
        case .AttributeValue_unquoted:
            let value: ArraySlice<UInt8> = r.consumeToAny(TokeniserStateVars.attributeValueUnquoted)
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
            case 0x09, 0x0A, 0x0D, 0x0C, 0x20:
                r.advanceAscii()
                t.transition(.BeforeAttributeName)
                break
            case 0x26: // "&"
                r.advanceAscii()
                if let ref = try t.consumeCharacterReference(">", true) {
                    t.tagPending.appendAttributeValue(ref)
                } else {
                    t.tagPending.appendAttributeValue(UnicodeScalar.Ampersand)
                }
                break
            case 0x3E: // ">"
                r.advanceAscii()
                try t.emitTagPending()
                t.transition(.Data)
                break
            case 0x00:
                r.advanceAscii()
                t.error(self)
                t.tagPending.appendAttributeValue(TokeniserStateVars.replacementChar)
                break
            case 0x22, 0x27, 0x3C, 0x3D, 0x60: // "\"", "'", "<", "=", "`"
                r.advanceAscii()
                t.error(self)
                t.tagPending.appendAttributeValueByte(byte)
                break
            default:
                let c = r.consume()
                if c == TokeniserStateVars.eof {
                    t.eofError(self)
                    t.transition(.Data)
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
            case 0x09, 0x0A, 0x0D, 0x0C, 0x20:
                r.advanceAscii()
                t.transition(.BeforeAttributeName)
                break
            case 0x2F: // "/"
                r.advanceAscii()
                t.transition(.SelfClosingStartTag)
                break
            case 0x3E: // ">"
                r.advanceAscii()
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
        case .SelfClosingStartTag:
            if r.isEmpty() {
                t.eofError(self)
                t.transition(.Data)
                break
            }
            let byte = r.currentByte()!
            switch byte {
            case 0x3E: // ">"
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
            comment.data.append(r.consumeTo(">"))
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
            case 0x2D: // "-"
                r.advanceAscii()
                t.transition(.CommentStartDash)
                break
            case 0x00:
                r.advanceAscii()
                t.error(self)
                t.commentPending.data.append(TokeniserStateVars.replacementChar)
                t.transition(.Comment)
                break
            case 0x3E: // ">"
                r.advanceAscii()
                t.error(self)
                try t.emitCommentPending()
                t.transition(.Data)
                break
            default:
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
            case 0x2D: // "-"
                r.advanceAscii()
                t.transition(.CommentStartDash)
                break
            case 0x00:
                r.advanceAscii()
                t.error(self)
                t.commentPending.data.append(TokeniserStateVars.replacementChar)
                t.transition(.Comment)
                break
            case 0x3E: // ">"
                r.advanceAscii()
                t.error(self)
                try t.emitCommentPending()
                t.transition(.Data)
                break
            default:
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
            case 0x2D: // "-"
                t.advanceTransitionAscii(.CommentEndDash)
                break
            case 0x00:
                t.error(self)
                r.advance()
                t.commentPending.data.append(TokeniserStateVars.replacementChar)
                break
            default:
                let value: ArraySlice<UInt8>  = r.consumeToAnyOfTwo(0x2D, 0x00)
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
            case 0x2D: // "-"
                r.advanceAscii()
                t.transition(.CommentEnd)
                break
            case 0x00:
                r.advanceAscii()
                t.error(self)
                t.commentPending.data.append("-").append(TokeniserStateVars.replacementChar)
                t.transition(.Comment)
                break
            default:
                let c = r.consume()
                if c == TokeniserStateVars.eof {
                    t.eofError(self)
                    try t.emitCommentPending()
                    t.transition(.Data)
                } else {
                    t.commentPending.data.append("-").append(c)
                    t.transition(.Comment)
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
            case 0x3E: // ">"
                r.advanceAscii()
                try t.emitCommentPending()
                t.transition(.Data)
                break
            case 0x00:
                r.advanceAscii()
                t.error(self)
                t.commentPending.data.append("--").append(TokeniserStateVars.replacementChar)
                t.transition(.Comment)
                break
            case 0x21: // "!"
                r.advanceAscii()
                t.error(self)
                t.transition(.CommentEndBang)
                break
            case 0x2D: // "-"
                r.advanceAscii()
                t.error(self)
                t.commentPending.data.append("-")
                break
            default:
                let c = r.consume()
                if c == TokeniserStateVars.eof {
                    t.eofError(self)
                    try t.emitCommentPending()
                    t.transition(.Data)
                } else {
                    t.error(self)
                    t.commentPending.data.append("--").append(c)
                    t.transition(.Comment)
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
            case 0x2D: // "-"
                r.advanceAscii()
                t.commentPending.data.append("--!")
                t.transition(.CommentEndDash)
                break
            case 0x3E: // ">"
                r.advanceAscii()
                try t.emitCommentPending()
                t.transition(.Data)
                break
            case 0x00:
                r.advanceAscii()
                t.error(self)
                t.commentPending.data.append("--!").append(TokeniserStateVars.replacementChar)
                t.transition(.Comment)
                break
            default:
                let c = r.consume()
                if c == TokeniserStateVars.eof {
                    t.eofError(self)
                    try t.emitCommentPending()
                    t.transition(.Data)
                } else {
                    t.commentPending.data.append("--!").append(c)
                    t.transition(.Comment)
                }
            }
            break
        case .Doctype:
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
            break
        case .BeforeDoctypeName:
            if (r.matchesLetter()) {
                t.createDoctypePending()
                t.transition(.DoctypeName)
                return
            }
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
            break
        case .DoctypeName:
            if (r.matchesLetter()) {
                let name = r.consumeLetterSequence()
                t.doctypePending.name.append(name)
                return
            }
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
            break
        case .AfterDoctypeName:
            if (r.isEmpty()) {
                t.eofError(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
                return
            }
            if (r.matchesAny(UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ")) {
            r.advance() // ignore whitespace
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
            break
        case .BeforeDoctypePublicIdentifier:
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
            break
        case .DoctypePublicIdentifier_doubleQuoted:
            let c = r.consume()
            switch (c) {
            case "\"":
                t.transition(.AfterDoctypePublicIdentifier)
                break
            case TokeniserStateVars.nullScalr:
                t.error(self)
                t.doctypePending.publicIdentifier.append(TokeniserStateVars.replacementChar)
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
                t.doctypePending.publicIdentifier.append(c)
            }
            break
        case .DoctypePublicIdentifier_singleQuoted:
            let c = r.consume()
            switch (c) {
            case "'":
                t.transition(.AfterDoctypePublicIdentifier)
                break
            case TokeniserStateVars.nullScalr:
                t.error(self)
                t.doctypePending.publicIdentifier.append(TokeniserStateVars.replacementChar)
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
                t.doctypePending.publicIdentifier.append(c)
            }
            break
        case .AfterDoctypePublicIdentifier:
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
            break
        case .BetweenDoctypePublicAndSystemIdentifiers:
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
            break
        case .AfterDoctypeSystemKeyword:
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
            break
        case .BeforeDoctypeSystemIdentifier:
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
            break
        case .DoctypeSystemIdentifier_doubleQuoted:
            let c = r.consume()
            switch (c) {
            case "\"":
                t.transition(.AfterDoctypeSystemIdentifier)
                break
            case TokeniserStateVars.nullScalr:
                t.error(self)
                t.doctypePending.systemIdentifier.append(TokeniserStateVars.replacementChar)
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
                t.doctypePending.systemIdentifier.append(c)
            }
            break
        case .DoctypeSystemIdentifier_singleQuoted:
            let c = r.consume()
            switch (c) {
            case "'":
                t.transition(.AfterDoctypeSystemIdentifier)
                break
            case TokeniserStateVars.nullScalr:
                t.error(self)
                t.doctypePending.systemIdentifier.append(TokeniserStateVars.replacementChar)
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
                t.doctypePending.systemIdentifier.append(c)
            }
            break
        case .AfterDoctypeSystemIdentifier:
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
            break
        case .BogusDoctype:
            let c = r.consume()
            switch (c) {
            case ">":
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            case TokeniserStateVars.eof:
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            default:
                // ignore char
                break
            }
            break
        case .CdataSection:
            let data = r.consumeTo(TokeniserStateVars.cdataEndUTF8)
            t.emit(data)
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
        if (r.matchesLetter()) {
            let name: ArraySlice<UInt8> = r.consumeLetterSequence()
            t.tagPending.appendTagName(name)
            t.dataBuffer.append(name)
            return
        }

        var needsExitTransition = false
        if (try t.isAppropriateEndTagToken() && !r.isEmpty()) {
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
        } else {
            needsExitTransition = true
        }

        if (needsExitTransition) {
            t.emit(UTF8Arrays.endTagStart)
            t.emit(t.dataBuffer.buffer)
            t.transition(elseTransition)
        }
    }

    private static func readData(_ t: Tokeniser, _ r: CharacterReader, _ current: TokeniserState, _ advance: TokeniserState)throws {
        if r.isEmpty() {
            try t.emit(Token.EOF())
            return
        }
        let byte = r.currentByte()!
        switch byte {
        case 0x3C: // "<"
            t.advanceTransition(advance)
            break
        case 0x00:
            t.error(current)
            r.advance()
            t.emit(TokeniserStateVars.replacementStr)
            break
        default:
            let data: ArraySlice<UInt8> = r.consumeToAny(TokeniserStateVars.readDataDefaultStopChars)
            t.emit(data)
            break
        }
    }

    private static func readCharRef(_ t: Tokeniser, _ advance: TokeniserState)throws {
        let c = try t.consumeCharacterReference(nil, false)
        if (c == nil) {
            t.emit(UnicodeScalar.Ampersand)
        } else {
            t.emit(c!)
        }
        t.transition(advance)
    }

    private static func readEndTag(_ t: Tokeniser, _ r: CharacterReader, _ a: TokeniserState, _ b: TokeniserState) {
        if (r.matchesLetter()) {
            t.createTagPending(false)
            t.transition(a)
        } else {
            t.emit(UTF8Arrays.endTagStart)
            t.transition(b)
        }
    }

    private static func handleDataDoubleEscapeTag(_ t: Tokeniser, _ r: CharacterReader, _ primary: TokeniserState, _ fallback: TokeniserState) {
        if (r.matchesLetter()) {
            let name = r.consumeLetterSequence()
            t.dataBuffer.append(name)
            t.emit(name)
            return
        }

        let c = r.consume()
        switch (c) {
        case UnicodeScalar.BackslashT, "\n", "\r", UnicodeScalar.BackslashF, " ", "/", ">":
            if (t.dataBuffer.buffer == ArraySlice(UTF8Arrays.script)) {
            t.transition(primary)
            } else {
            t.transition(fallback)
            }
            t.emit(c)
            break
        default:
            r.unconsume()
            t.transition(fallback)
        }
    }

}
