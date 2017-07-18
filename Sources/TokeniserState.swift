//
//  TokeniserState.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 12/10/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import Foundation

protocol TokeniserStateProtocol {
    func read(_ t: Tokeniser, _ r: CharacterReader)throws
}

public class TokeniserStateVars {
    static let attributeSingleValueCharsSorted = [Byte.apostrophe, Byte.ampersand, Byte.null].sorted()
    static let attributeDoubleValueCharsSorted = [Byte.quote, Byte.ampersand, Byte.null].sorted()
    static let attributeNameCharsSorted = [Byte.horizontalTab, Byte.newLine, Byte.carriageReturn, Byte.formfeed, Byte.space, Byte.forwardSlash, Byte.equals, Byte.greaterThan, Byte.null, Byte.backSlash, Byte.apostrophe, Byte.lessThan].sorted()
    static let attributeValueUnquoted = [Byte.horizontalTab, Byte.newLine, Byte.carriageReturn, Byte.formfeed, Byte.space, Byte.ampersand, Byte.greaterThan, Byte.null, Byte.quote, Byte.apostrophe, Byte.lessThan, Byte.equals, Byte.backquote].sorted()

    static let replacementChar: Byte = Byte.replacementChar
    static let replacementStr: String = String(Byte.replacementChar)
    static let eof: Byte = Byte.EOF
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

    internal func read(_ t: Tokeniser, _ r: CharacterReader)throws {
        switch self {
        case .Data:
            switch (r.current()) {
            case Byte.ampersand:
                t.advanceTransition(.CharacterReferenceInData)
                break
            case Byte.lessThan:
                t.advanceTransition(.TagOpen)
                break
            case Byte.null:
                t.error(self) // NOT replacement character (oddly?)
                t.emit(r.consume())
                break
            case TokeniserStateVars.eof:
                try t.emit(Token.EOF())
                break
            default:
                let data: String = r.consumeData()
                t.emit(data)
                break
            }
            break
        case .CharacterReferenceInData:
            try TokeniserState.readCharRef(t, .Data)
            break
        case .Rcdata:
            switch (r.current()) {
            case Byte.ampersand:
                t.advanceTransition(.CharacterReferenceInRcdata)
                break
            case Byte.lessThan:
                t.advanceTransition(.RcdataLessthanSign)
                break
            case Byte.null:
                t.error(self)
                r.advance()
                t.emit(TokeniserStateVars.replacementChar)
                break
            case TokeniserStateVars.eof:
                try t.emit(Token.EOF())
                break
            default:
                let data = r.consumeToAny(Byte.ampersand, Byte.lessThan, Byte.null)
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
            switch (r.current()) {
            case Byte.null:
                t.error(self)
                r.advance()
                t.emit(TokeniserStateVars.replacementChar)
                break
            case TokeniserStateVars.eof:
                try t.emit(Token.EOF())
                break
            default:
                let data = r.consumeTo(Byte.null)
                t.emit(data)
                break
            }
            break
        case .TagOpen:
            // from < in data
            switch (r.current()) {
            case Byte.exclamation:
                t.advanceTransition(.MarkupDeclarationOpen)
                break
            case Byte.forwardSlash:
                t.advanceTransition(.EndTagOpen)
                break
            case Byte.questionMark:
                t.advanceTransition(.BogusComment)
                break
            default:
                if (r.matchesLetter()) {
                    t.createTagPending(true)
                    t.transition(.TagName)
                } else {
                    t.error(self)
                    t.emit(Byte.lessThan) // char that got us here
                    t.transition(.Data)
                }
                break
            }
            break
        case .EndTagOpen:
            if (r.isEmpty()) {
                t.eofError(self)
                t.emit("</")
                t.transition(.Data)
            } else if (r.matchesLetter()) {
                t.createTagPending(false)
                t.transition(.TagName)
            } else if (r.matches(Byte.greaterThan)) {
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
            let tagName = r.consumeTagName()
            t.tagPending.appendTagName(tagName)

            switch (r.consume()) {
            case Byte.horizontalTab:
                t.transition(.BeforeAttributeName)
                break
            case Byte.newLine:
                t.transition(.BeforeAttributeName)
                break
            case Byte.carriageReturn:
                t.transition(.BeforeAttributeName)
                break
            case Byte.formfeed:
                t.transition(.BeforeAttributeName)
                break
            case Byte.space:
                t.transition(.BeforeAttributeName)
                break
            case Byte.forwardSlash:
                t.transition(.SelfClosingStartTag)
                break
            case Byte.greaterThan:
                try t.emitTagPending()
                t.transition(.Data)
                break
            case Byte.null: // replacement
                t.tagPending.appendTagName(TokeniserStateVars.replacementStr)
                break
            case TokeniserStateVars.eof: // should emit pending tag?
                t.eofError(self)
                t.transition(.Data)
            // no default, as covered with above consumeToAny
            default:
                break
            }
        case .RcdataLessthanSign:
            if (r.matches(Byte.forwardSlash)) {
                t.createTempBuffer()
                t.advanceTransition(.RCDATAEndTagOpen)
            } else if (r.matchesLetter() && t.appropriateEndTagName() != nil && !r.containsIgnoreCase("</" + t.appropriateEndTagName()!)) {
                // diverge from spec: got a start tag, but there's no appropriate end tag (</title>), so rather than
                // consuming to EOF break out here
                t.tagPending = t.createTagPending(false).name(t.appropriateEndTagName()!)
                try t.emitTagPending()
                r.unconsume() // undo Byte.lessThan
                t.transition(.Data)
            } else {
                t.emit(Byte.lessThan)
                t.transition(.Rcdata)
            }
            break
        case .RCDATAEndTagOpen:
            if (r.matchesLetter()) {
                t.createTagPending(false)
                t.tagPending.appendTagName(r.current())
                t.dataBuffer.append(r.current())
                t.advanceTransition(.RCDATAEndTagName)
            } else {
                t.emit("</")
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
                t.emit("</" + t.dataBuffer.toString())
                r.unconsume()
                t.transition(.Rcdata)
            }

            let c = r.consume()
            switch (c) {
            case Byte.horizontalTab:
                if (try t.isAppropriateEndTagToken()) {
                    t.transition(.BeforeAttributeName)
                } else {
                    anythingElse(t, r)
                }
                break
            case Byte.newLine:
                if (try t.isAppropriateEndTagToken()) {
                    t.transition(.BeforeAttributeName)
                } else {
                    anythingElse(t, r)
                }
                break
            case Byte.carriageReturn:
                if (try t.isAppropriateEndTagToken()) {
                    t.transition(.BeforeAttributeName)
                } else {
                    anythingElse(t, r)
                }
                break
            case Byte.formfeed:
                if (try t.isAppropriateEndTagToken()) {
                    t.transition(.BeforeAttributeName)
                } else {
                    anythingElse(t, r)
                }
                break
            case Byte.space:
                if (try t.isAppropriateEndTagToken()) {
                    t.transition(.BeforeAttributeName)
                } else {
                    anythingElse(t, r)
                }
                break
            case Byte.forwardSlash:
                if (try t.isAppropriateEndTagToken()) {
                    t.transition(.SelfClosingStartTag)
                } else {
                    anythingElse(t, r)
                }
                break
            case Byte.greaterThan:
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
            if (r.matches(Byte.forwardSlash)) {
                t.createTempBuffer()
                t.advanceTransition(.RawtextEndTagOpen)
            } else {
                t.emit(Byte.lessThan)
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
            case Byte.forwardSlash:
                t.createTempBuffer()
                t.transition(.ScriptDataEndTagOpen)
                break
            case Byte.exclamation:
                t.emit("<!")
                t.transition(.ScriptDataEscapeStart)
                break
            default:
                t.emit(Byte.lessThan)
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
            if (r.matches(Byte.hyphen)) {
                t.emit(Byte.hyphen)
                t.advanceTransition(.ScriptDataEscapeStartDash)
            } else {
                t.transition(.ScriptData)
            }
            break
        case .ScriptDataEscapeStartDash:
            if (r.matches(Byte.hyphen)) {
                t.emit(Byte.hyphen)
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

            switch (r.current()) {
            case Byte.hyphen:
                t.emit(Byte.hyphen)
                t.advanceTransition(.ScriptDataEscapedDash)
                break
            case Byte.lessThan:
                t.advanceTransition(.ScriptDataEscapedLessthanSign)
                break
            case Byte.null:
                t.error(self)
                r.advance()
                t.emit(TokeniserStateVars.replacementChar)
                break
            default:
                let data = r.consumeToAny(Byte.hyphen, Byte.lessThan, Byte.null)
                t.emit(data)
            }
            break
        case .ScriptDataEscapedDash:
            if (r.isEmpty()) {
                t.eofError(self)
                t.transition(.Data)
                return
            }

            let c = r.consume()
            switch (c) {
            case Byte.hyphen:
                t.emit(c)
                t.transition(.ScriptDataEscapedDashDash)
                break
            case Byte.lessThan:
                t.transition(.ScriptDataEscapedLessthanSign)
                break
            case Byte.null:
                t.error(self)
                t.emit(TokeniserStateVars.replacementChar)
                t.transition(.ScriptDataEscaped)
                break
            default:
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

            let c = r.consume()
            switch (c) {
            case Byte.hyphen:
                t.emit(c)
                break
            case Byte.lessThan:
                t.transition(.ScriptDataEscapedLessthanSign)
                break
            case Byte.greaterThan:
                t.emit(c)
                t.transition(.ScriptData)
                break
            case Byte.null:
                t.error(self)
                t.emit(TokeniserStateVars.replacementChar)
                t.transition(.ScriptDataEscaped)
                break
            default:
                t.emit(c)
                t.transition(.ScriptDataEscaped)
            }
            break
        case .ScriptDataEscapedLessthanSign:
            if (r.matchesLetter()) {
                t.createTempBuffer()
                t.dataBuffer.append(r.current())
                t.emit("<" + String(r.current()))
                t.advanceTransition(.ScriptDataDoubleEscapeStart)
            } else if (r.matches(Byte.forwardSlash)) {
                t.createTempBuffer()
                t.advanceTransition(.ScriptDataEscapedEndTagOpen)
            } else {
                t.emit(Byte.lessThan)
                t.transition(.ScriptDataEscaped)
            }
            break
        case .ScriptDataEscapedEndTagOpen:
            if (r.matchesLetter()) {
                t.createTagPending(false)
                t.tagPending.appendTagName(r.current())
                t.dataBuffer.append(r.current())
                t.advanceTransition(.ScriptDataEscapedEndTagName)
            } else {
                t.emit("</")
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
            let c = r.current()
            switch (c) {
            case Byte.hyphen:
                t.emit(c)
                t.advanceTransition(.ScriptDataDoubleEscapedDash)
                break
            case Byte.lessThan:
                t.emit(c)
                t.advanceTransition(.ScriptDataDoubleEscapedLessthanSign)
                break
            case Byte.null:
                t.error(self)
                r.advance()
                t.emit(TokeniserStateVars.replacementChar)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.transition(.Data)
                break
            default:
                let data = r.consumeToAny(Byte.hyphen, Byte.lessThan, Byte.null)
                t.emit(data)
            }
            break
        case .ScriptDataDoubleEscapedDash:
            let c = r.consume()
            switch (c) {
            case Byte.hyphen:
                t.emit(c)
                t.transition(.ScriptDataDoubleEscapedDashDash)
                break
            case Byte.lessThan:
                t.emit(c)
                t.transition(.ScriptDataDoubleEscapedLessthanSign)
                break
            case Byte.null:
                t.error(self)
                t.emit(TokeniserStateVars.replacementChar)
                t.transition(.ScriptDataDoubleEscaped)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.transition(.Data)
                break
            default:
                t.emit(c)
                t.transition(.ScriptDataDoubleEscaped)
            }
            break
        case .ScriptDataDoubleEscapedDashDash:
            let c = r.consume()
            switch (c) {
            case Byte.hyphen:
                t.emit(c)
                break
            case Byte.lessThan:
                t.emit(c)
                t.transition(.ScriptDataDoubleEscapedLessthanSign)
                break
            case Byte.greaterThan:
                t.emit(c)
                t.transition(.ScriptData)
                break
            case Byte.null:
                t.error(self)
                t.emit(TokeniserStateVars.replacementChar)
                t.transition(.ScriptDataDoubleEscaped)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.transition(.Data)
                break
            default:
                t.emit(c)
                t.transition(.ScriptDataDoubleEscaped)
            }
            break
        case .ScriptDataDoubleEscapedLessthanSign:
            if (r.matches(Byte.forwardSlash)) {
                t.emit(Byte.forwardSlash)
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
            let c = r.consume()
            switch (c) {
            case Byte.horizontalTab:
                t.transition(.SelfClosingStartTag)
                break
            case Byte.newLine:
                t.transition(.SelfClosingStartTag)
                break
            case Byte.carriageReturn:
                t.transition(.SelfClosingStartTag)
                break
            case Byte.formfeed:
                t.transition(.SelfClosingStartTag)
                break
            case Byte.space:
                break // ignore whitespace
            case Byte.forwardSlash:
                t.transition(.SelfClosingStartTag)
                break
            case Byte.greaterThan:
                try t.emitTagPending()
                t.transition(.Data)
                break
            case Byte.null:
                t.error(self)
                try t.tagPending.newAttribute()
                r.unconsume()
                t.transition(.AttributeName)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.transition(.Data)
                break
            case Byte.quote:
                t.error(self)
                try t.tagPending.newAttribute()
                t.tagPending.appendAttributeName(c)
                t.transition(.AttributeName)
                break
            case Byte.apostrophe:
                t.error(self)
                try t.tagPending.newAttribute()
                t.tagPending.appendAttributeName(c)
                t.transition(.AttributeName)
                break
            case Byte.lessThan:
                t.error(self)
                try t.tagPending.newAttribute()
                t.tagPending.appendAttributeName(c)
                t.transition(.AttributeName)
                break
            case Byte.equals:
                t.error(self)
                try t.tagPending.newAttribute()
                t.tagPending.appendAttributeName(c)
                t.transition(.AttributeName)
                break
            default: // A-Z, anything else
                try t.tagPending.newAttribute()
                r.unconsume()
                t.transition(.AttributeName)
            }
            break
        case .AttributeName:
            let name = r.consumeToAnySorted(TokeniserStateVars.attributeNameCharsSorted)
            t.tagPending.appendAttributeName(name)

            let c = r.consume()
            switch (c) {
            case Byte.horizontalTab:
                t.transition(.AfterAttributeName)
                break
            case Byte.newLine:
                t.transition(.AfterAttributeName)
                break
            case Byte.carriageReturn:
                t.transition(.AfterAttributeName)
                break
            case Byte.formfeed:
                t.transition(.AfterAttributeName)
                break
            case Byte.space:
                t.transition(.AfterAttributeName)
                break
            case Byte.forwardSlash:
                t.transition(.SelfClosingStartTag)
                break
            case Byte.equals:
                t.transition(.BeforeAttributeValue)
                break
            case Byte.greaterThan:
                try t.emitTagPending()
                t.transition(.Data)
                break
            case Byte.null:
                t.error(self)
                t.tagPending.appendAttributeName(TokeniserStateVars.replacementChar)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.transition(.Data)
                break
            case Byte.quote:
                t.error(self)
                t.tagPending.appendAttributeName(c)
            case Byte.apostrophe:
                t.error(self)
                t.tagPending.appendAttributeName(c)
            case Byte.lessThan:
                t.error(self)
                t.tagPending.appendAttributeName(c)
                // no default, as covered in consumeToAny
            default:
                break
            }
            break
        case .AfterAttributeName:
            let c = r.consume()
            switch (c) {
            case Byte.horizontalTab, Byte.newLine, Byte.carriageReturn, Byte.formfeed, Byte.space:
                // ignore
                break
            case Byte.forwardSlash:
                t.transition(.SelfClosingStartTag)
                break
            case Byte.equals:
                t.transition(.BeforeAttributeValue)
                break
            case Byte.greaterThan:
                try t.emitTagPending()
                t.transition(.Data)
                break
            case Byte.null:
                t.error(self)
                t.tagPending.appendAttributeName(TokeniserStateVars.replacementChar)
                t.transition(.AttributeName)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.transition(.Data)
                break
            case Byte.quote, Byte.apostrophe, Byte.lessThan:
                t.error(self)
                try t.tagPending.newAttribute()
                t.tagPending.appendAttributeName(c)
                t.transition(.AttributeName)
                break
            default: // A-Z, anything else
                try t.tagPending.newAttribute()
                r.unconsume()
                t.transition(.AttributeName)
            }
            break
        case .BeforeAttributeValue:
            let c = r.consume()
            switch (c) {
            case Byte.horizontalTab, Byte.newLine, Byte.carriageReturn, Byte.formfeed, Byte.space:
                // ignore
                break
            case Byte.quote:
                t.transition(.AttributeValue_doubleQuoted)
                break
            case Byte.ampersand:
                r.unconsume()
                t.transition(.AttributeValue_unquoted)
                break
            case Byte.apostrophe:
                t.transition(.AttributeValue_singleQuoted)
                break
            case Byte.null:
                t.error(self)
                t.tagPending.appendAttributeValue(TokeniserStateVars.replacementChar)
                t.transition(.AttributeValue_unquoted)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                try t.emitTagPending()
                t.transition(.Data)
                break
            case Byte.greaterThan:
                t.error(self)
                try t.emitTagPending()
                t.transition(.Data)
                break
            case Byte.lessThan, Byte.equals, Byte.backquote:
                t.error(self)
                t.tagPending.appendAttributeValue(c)
                t.transition(.AttributeValue_unquoted)
                break
            default:
                r.unconsume()
                t.transition(.AttributeValue_unquoted)
            }
            break
        case .AttributeValue_doubleQuoted:
            let value = r.consumeToAny(TokeniserStateVars.attributeDoubleValueCharsSorted)
            if (value.characters.count > 0) {
            t.tagPending.appendAttributeValue(value)
            } else {
            t.tagPending.setEmptyAttributeValue()
            }

            let c = r.consume()
            switch (c) {
            case Byte.quote:
                t.transition(.AfterAttributeValue_quoted)
                break
            case Byte.ampersand:

                if let ref = try t.consumeCharacterReference(Byte.quote, true) {
                t.tagPending.appendAttributeValue(ref)
                } else {
                t.tagPending.appendAttributeValue(Byte.ampersand)
                }
                break
            case Byte.null:
                t.error(self)
                t.tagPending.appendAttributeValue(TokeniserStateVars.replacementChar)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.transition(.Data)
                break
                // no default, handled in consume to any above
            default:
                break
            }
            break
        case .AttributeValue_singleQuoted:
            let value = r.consumeToAny(TokeniserStateVars.attributeSingleValueCharsSorted)
            if (value.characters.count > 0) {
            t.tagPending.appendAttributeValue(value)
            } else {
            t.tagPending.setEmptyAttributeValue()
            }

            let c = r.consume()
            switch (c) {
            case Byte.apostrophe:
                t.transition(.AfterAttributeValue_quoted)
                break
            case Byte.ampersand:

                if let ref = try t.consumeCharacterReference(Byte.apostrophe, true) {
                t.tagPending.appendAttributeValue(ref)
                } else {
                t.tagPending.appendAttributeValue(Byte.ampersand)
                }
                break
            case Byte.null:
                t.error(self)
                t.tagPending.appendAttributeValue(TokeniserStateVars.replacementChar)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.transition(.Data)
                break
                // no default, handled in consume to any above
            default:
                break
            }
            break
        case .AttributeValue_unquoted:
            let value = r.consumeToAnySorted(TokeniserStateVars.attributeValueUnquoted)
            if (value.characters.count > 0) {
            t.tagPending.appendAttributeValue(value)
            }

            let c = r.consume()
            switch (c) {
            case Byte.horizontalTab, Byte.newLine, Byte.carriageReturn, Byte.formfeed, Byte.space:
                t.transition(.BeforeAttributeName)
                break
            case Byte.ampersand:
                if let ref = try t.consumeCharacterReference(Byte.greaterThan, true) {
                t.tagPending.appendAttributeValue(ref)
                } else {
                t.tagPending.appendAttributeValue(Byte.ampersand)
                }
                break
            case Byte.greaterThan:
                try t.emitTagPending()
                t.transition(.Data)
                break
            case Byte.null:
                t.error(self)
                t.tagPending.appendAttributeValue(TokeniserStateVars.replacementChar)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.transition(.Data)
                break
            case Byte.quote, Byte.apostrophe, Byte.lessThan, Byte.equals, Byte.backquote:
                t.error(self)
                t.tagPending.appendAttributeValue(c)
                break
                // no default, handled in consume to any above
            default:
                break
            }
            break
        case .AfterAttributeValue_quoted:
            // CharacterReferenceInAttributeValue state handled inline
            let c = r.consume()
            switch (c) {
            case Byte.horizontalTab, Byte.newLine, Byte.carriageReturn, Byte.formfeed, Byte.space:
                t.transition(.BeforeAttributeName)
                break
            case Byte.forwardSlash:
                t.transition(.SelfClosingStartTag)
                break
            case Byte.greaterThan:
                try t.emitTagPending()
                t.transition(.Data)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.transition(.Data)
                break
            default:
                t.error(self)
                r.unconsume()
                t.transition(.BeforeAttributeName)
            }
            break
        case .SelfClosingStartTag:
            let c = r.consume()
            switch (c) {
            case Byte.greaterThan:
                t.tagPending._selfClosing = true
                try t.emitTagPending()
                t.transition(.Data)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                t.transition(.Data)
                break
            default:
                t.error(self)
                r.unconsume()
                t.transition(.BeforeAttributeName)
            }
            break
        case .BogusComment:
            // todo: handle bogus comment starting from eof. when does that trigger?
            // rewind to capture character that lead us here
            r.unconsume()
            let comment: Token.Comment = Token.Comment()
            comment.bogus = true
            comment.data.append(r.consumeTo(Byte.greaterThan))
            // todo: replace nullChar with replaceChar
            try t.emit(comment)
            t.advanceTransition(.Data)
            break
        case .MarkupDeclarationOpen:
            if (r.matchConsume("--".makeBytes())) {
                t.createCommentPending()
                t.transition(.CommentStart)
            } else if (r.matchConsumeIgnoreCase("DOCTYPE")) {
                t.transition(.Doctype)
            } else if (r.matchConsume("[CDATA[".makeBytes())) {
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
            let c = r.consume()
            switch (c) {
            case Byte.hyphen:
                t.transition(.CommentStartDash)
                break
            case Byte.null:
                t.error(self)
                t.commentPending.data.append(TokeniserStateVars.replacementChar)
                t.transition(.Comment)
                break
            case Byte.greaterThan:
                t.error(self)
                try t.emitCommentPending()
                t.transition(.Data)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                try t.emitCommentPending()
                t.transition(.Data)
                break
            default:
                t.commentPending.data.append(c)
                t.transition(.Comment)
            }
            break
        case .CommentStartDash:
            let c = r.consume()
            switch (c) {
            case Byte.hyphen:
                t.transition(.CommentStartDash)
                break
            case Byte.null:
                t.error(self)
                t.commentPending.data.append(TokeniserStateVars.replacementChar)
                t.transition(.Comment)
                break
            case Byte.greaterThan:
                t.error(self)
                try t.emitCommentPending()
                t.transition(.Data)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                try t.emitCommentPending()
                t.transition(.Data)
                break
            default:
                t.commentPending.data.append(c)
                t.transition(.Comment)
            }
            break
        case .Comment:
            let c = r.current()
            switch (c) {
            case Byte.hyphen:
                t.advanceTransition(.CommentEndDash)
                break
            case Byte.null:
                t.error(self)
                r.advance()
                t.commentPending.data.append(TokeniserStateVars.replacementChar)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                try t.emitCommentPending()
                t.transition(.Data)
                break
            default:
                t.commentPending.data.append(r.consumeToAny(Byte.hyphen, Byte.null))
            }
            break
        case .CommentEndDash:
            let c = r.consume()
            switch (c) {
            case Byte.hyphen:
                t.transition(.CommentEnd)
                break
            case Byte.null:
                t.error(self)
                t.commentPending.data.append(Byte.hyphen).append(TokeniserStateVars.replacementChar)
                t.transition(.Comment)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                try t.emitCommentPending()
                t.transition(.Data)
                break
            default:
                t.commentPending.data.append(Byte.hyphen).append(c)
                t.transition(.Comment)
            }
            break
        case .CommentEnd:
            let c = r.consume()
            switch (c) {
            case Byte.greaterThan:
                try t.emitCommentPending()
                t.transition(.Data)
                break
            case Byte.null:
                t.error(self)
                t.commentPending.data.append("--").append(TokeniserStateVars.replacementChar)
                t.transition(.Comment)
                break
            case Byte.exclamation:
                t.error(self)
                t.transition(.CommentEndBang)
                break
            case Byte.hyphen:
                t.error(self)
                t.commentPending.data.append(Byte.hyphen)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                try t.emitCommentPending()
                t.transition(.Data)
                break
            default:
                t.error(self)
                t.commentPending.data.append("--").append(c)
                t.transition(.Comment)
            }
            break
        case .CommentEndBang:
            let c = r.consume()
            switch (c) {
            case Byte.hyphen:
                t.commentPending.data.append("--!")
                t.transition(.CommentEndDash)
                break
            case Byte.greaterThan:
                try t.emitCommentPending()
                t.transition(.Data)
                break
            case Byte.null:
                t.error(self)
                t.commentPending.data.append("--!").append(TokeniserStateVars.replacementChar)
                t.transition(.Comment)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
                try t.emitCommentPending()
                t.transition(.Data)
                break
            default:
                t.commentPending.data.append("--!").append(c)
                t.transition(.Comment)
            }
            break
        case .Doctype:
            let c = r.consume()
            switch (c) {
            case Byte.horizontalTab, Byte.newLine, Byte.carriageReturn, Byte.formfeed, Byte.space:
                t.transition(.BeforeDoctypeName)
                break
            case TokeniserStateVars.eof:
                t.eofError(self)
            // note: fall through to > case
            case Byte.greaterThan: // catch invalid <!DOCTYPE>
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
            case Byte.horizontalTab, Byte.newLine, Byte.carriageReturn, Byte.formfeed, Byte.space:
                break // ignore whitespace
            case Byte.null:
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
            case Byte.greaterThan:
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            case Byte.horizontalTab, Byte.newLine, Byte.carriageReturn, Byte.formfeed, Byte.space:
                t.transition(.AfterDoctypeName)
                break
            case Byte.null:
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
            if (r.matchesAny(Byte.horizontalTab, Byte.newLine, Byte.carriageReturn, Byte.formfeed, Byte.space)) {
            r.advance() // ignore whitespace
            } else if (r.matches(Byte.greaterThan)) {
                try t.emitDoctypePending()
                t.advanceTransition(.Data)
            } else if (r.matchConsumeIgnoreCase(DocumentType.PUBLIC_KEY)) {
                t.doctypePending.pubSysKey = DocumentType.PUBLIC_KEY
                t.transition(.AfterDoctypePublicKeyword)
            } else if (r.matchConsumeIgnoreCase(DocumentType.SYSTEM_KEY)) {
                t.doctypePending.pubSysKey = DocumentType.SYSTEM_KEY;
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
            case Byte.horizontalTab, Byte.newLine, Byte.carriageReturn, Byte.formfeed, Byte.space:
                t.transition(.BeforeDoctypePublicIdentifier)
                break
            case Byte.quote:
                t.error(self)
                // set public id to empty string
                t.transition(.DoctypePublicIdentifier_doubleQuoted)
                break
            case Byte.apostrophe:
                t.error(self)
                // set public id to empty string
                t.transition(.DoctypePublicIdentifier_singleQuoted)
                break
            case Byte.greaterThan:
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
            case Byte.horizontalTab, Byte.newLine, Byte.carriageReturn, Byte.formfeed, Byte.space:
                break
            case Byte.quote:
                // set public id to empty string
                t.transition(.DoctypePublicIdentifier_doubleQuoted)
                break
            case Byte.apostrophe:
                // set public id to empty string
                t.transition(.DoctypePublicIdentifier_singleQuoted)
                break
            case Byte.greaterThan:
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
            case Byte.quote:
                t.transition(.AfterDoctypePublicIdentifier)
                break
            case Byte.null:
                t.error(self)
                t.doctypePending.publicIdentifier.append(TokeniserStateVars.replacementChar)
                break
            case Byte.greaterThan:
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
            case Byte.apostrophe:
                t.transition(.AfterDoctypePublicIdentifier)
                break
            case Byte.null:
                t.error(self)
                t.doctypePending.publicIdentifier.append(TokeniserStateVars.replacementChar)
                break
            case Byte.greaterThan:
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
            case Byte.horizontalTab, Byte.newLine, Byte.carriageReturn, Byte.formfeed, Byte.space:
                t.transition(.BetweenDoctypePublicAndSystemIdentifiers)
                break
            case Byte.greaterThan:
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            case Byte.quote:
                t.error(self)
                // system id empty
                t.transition(.DoctypeSystemIdentifier_doubleQuoted)
                break
            case Byte.apostrophe:
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
            case Byte.horizontalTab, Byte.newLine, Byte.carriageReturn, Byte.formfeed, Byte.space:
                break
            case Byte.greaterThan:
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            case Byte.quote:
                t.error(self)
                // system id empty
                t.transition(.DoctypeSystemIdentifier_doubleQuoted)
                break
            case Byte.apostrophe:
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
            case Byte.horizontalTab, Byte.newLine, Byte.carriageReturn, Byte.formfeed, Byte.space:
                t.transition(.BeforeDoctypeSystemIdentifier)
                break
            case Byte.greaterThan:
                t.error(self)
                t.doctypePending.forceQuirks = true
                try t.emitDoctypePending()
                t.transition(.Data)
                break
            case Byte.quote:
                t.error(self)
                // system id empty
                t.transition(.DoctypeSystemIdentifier_doubleQuoted)
                break
            case Byte.apostrophe:
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
            case Byte.horizontalTab, Byte.newLine, Byte.carriageReturn, Byte.formfeed, Byte.space:
                break
            case Byte.quote:
                // set system id to empty string
                t.transition(.DoctypeSystemIdentifier_doubleQuoted)
                break
            case Byte.apostrophe:
                // set public id to empty string
                t.transition(.DoctypeSystemIdentifier_singleQuoted)
                break
            case Byte.greaterThan:
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
            case Byte.quote:
                t.transition(.AfterDoctypeSystemIdentifier)
                break
            case Byte.null:
                t.error(self)
                t.doctypePending.systemIdentifier.append(TokeniserStateVars.replacementChar)
                break
            case Byte.greaterThan:
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
            case Byte.apostrophe:
                t.transition(.AfterDoctypeSystemIdentifier)
                break
            case Byte.null:
                t.error(self)
                t.doctypePending.systemIdentifier.append(TokeniserStateVars.replacementChar)
                break
            case Byte.greaterThan:
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
            case Byte.horizontalTab, Byte.newLine, Byte.carriageReturn, Byte.formfeed, Byte.space:
                break
            case Byte.greaterThan:
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
            case Byte.greaterThan:
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
            let data = r.consumeTo("]]>")
            t.emit(data)
            r.matchConsume("]]>".makeBytes())
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
            let name = r.consumeLetterSequence()
            t.tagPending.appendTagName(name)
            t.dataBuffer.append(name)
            return
        }

        var needsExitTransition = false
        if (try t.isAppropriateEndTagToken() && !r.isEmpty()) {
            let c = r.consume()
            switch (c) {
            case Byte.horizontalTab, Byte.newLine, Byte.carriageReturn, Byte.formfeed, Byte.space:
                t.transition(BeforeAttributeName)
                break
            case Byte.forwardSlash:
                t.transition(SelfClosingStartTag)
                break
            case Byte.greaterThan:
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
            t.emit("</" + t.dataBuffer.toString())
            t.transition(elseTransition)
        }
    }

    private static func readData(_ t: Tokeniser, _ r: CharacterReader, _ current: TokeniserState, _ advance: TokeniserState)throws {
        switch (r.current()) {
        case Byte.lessThan:
            t.advanceTransition(advance)
            break
        case Byte.null:
            t.error(current)
            r.advance()
            t.emit(TokeniserStateVars.replacementChar)
            break
        case TokeniserStateVars.eof:
            try t.emit(Token.EOF())
            break
        default:
            let data = r.consumeToAny(Byte.lessThan, Byte.null)
            t.emit(data)
            break
        }
    }

    private static func readCharRef(_ t: Tokeniser, _ advance: TokeniserState)throws {
        let c = try t.consumeCharacterReference(nil, false)
        if (c == nil) {
            t.emit(Byte.ampersand)
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
            t.emit("</")
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
        case Byte.horizontalTab, Byte.newLine, Byte.carriageReturn, Byte.formfeed, Byte.space, Byte.forwardSlash, Byte.greaterThan:
            if (t.dataBuffer.toString() == "script") {
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
