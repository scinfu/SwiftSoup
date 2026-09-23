//
//  TokenQueue.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 13/10/16.
//

import Foundation

open class TokenQueue {
    private var queue: String
    private var pos: Int = 0
    private static let empty: Character = Character(UnicodeScalar(0))
    private static let ESC: Character = "\\" // escape char for chomp balanced.

    /**
     Create a new TokenQueue.
     - parameter data: string of data to back queue.
     */
    public init (_ data: String) {
        queue = data
    }

    /**
     Is the queue empty?
     - returns: true if no data left in queue.
     */
    open func isEmpty() -> Bool {
        return remainingLength() == 0
    }

    private func remainingLength() -> Int {
        return queue.count - pos
    }

    /**
     Retrieves but does not remove the first character from the queue.
     - returns: First character, or 0 if empty.
     */
    open func peek() -> Character {
        return isEmpty() ? Character(UnicodeScalar(0)) : queue[pos]
    }

    /**
     Add a character to the start of the queue (will be the next character retrieved).
     - parameter c: character to add
     */
    open func addFirst(_ c: Character) {
        addFirst(String(c))
    }

    /**
     Add a string to the start of the queue.
     - parameter seq: string to add.
     */
    open func addFirst(_ seq: String) {
        // not very performant, but an edge case
        queue = seq + queue.substring(pos)
        pos = 0
    }

    /**
     Tests if the next characters on the queue match the sequence. Case insensitive.
     - parameter seq: String to check queue for.
     - returns: true if the next characters match.
     */
    open func matches(_ seq: String) -> Bool {
        return queue.regionMatches(
            ignoreCase: true,
            selfOffset: pos,
            other: seq,
            otherOffset: 0,
            targetLength: seq.count
        )
    }

    /**
     Case sensitive match test.
     - parameter seq: string to case sensitively check for
     - returns: true if matched, false if not
     */
    open func matchesCS(_ seq: String) -> Bool {
        return queue.startsWith(seq, pos)
    }

    /**
     Tests if the next characters match any of the sequences. Case insensitive.
     - parameter seq: list of strings to case insensitively check for
     - returns: true of any matched, false if none did
     */
    open func matchesAny(_ seq: [String]) -> Bool {
        for s in seq {
            if (matches(s)) {
                return true
            }
        }
        return false
    }

    open func matchesAny(_ seq: String...) -> Bool {
        return matchesAny(seq)
    }

    open func matchesAny(_ seq: Character...) -> Bool {
        if (isEmpty()) {
            return false
        }

        for c in seq {
            if (queue[pos] as Character == c) {
                return true
            }
        }
        return false
    }

    open func matchesStartTag() -> Bool {
        // micro opt for matching "<x"
        return (remainingLength() >= 2 && queue[pos] as Character == "<" && Character.isLetter(queue.charAt(pos+1)))
    }

    /**
     Tests if the queue matches the sequence (as with match), and if they do, removes the matched string from the
     queue.
     - parameter seq: String to search for, and if found, remove from queue.
     - returns: true if found and removed, false if not found.
     */
    @discardableResult
    open func matchChomp(_ seq: String) -> Bool {
        if (matches(seq)) {
            pos += seq.count
            return true
        } else {
            return false
        }
    }

    /**
     Tests if queue starts with a whitespace character.
     - returns: if starts with whitespace
     */
    open func matchesWhitespace() -> Bool {
        return !isEmpty() && StringUtil.isWhitespace(queue.charAt(pos))
    }

    /**
     Test if the queue matches a word character (letter or digit).
     - returns: if matches a word character
     */
    open func matchesWord() -> Bool {
        return !isEmpty() && (Character.isLetterOrDigit(queue.charAt(pos)))
    }

    /**
     Drops the next character off the queue.
     */
    open func advance() {

        if (!isEmpty()) {pos+=1}
    }

    /**
     Consume one character off queue.
     - returns: first character on queue.
     */
    open func consume() -> Character {
        let i = pos
        pos+=1
        return queue.charAt(i)
    }

    /**
     Consumes the supplied sequence of the queue. If the queue does not start with the supplied sequence, will
     throw an illegal state exception -- but you should be running match() against that condition.
     
     Case insensitive.
     
     - parameter seq: sequence to remove from head of queue.
     */
    open func consume(_ seq: String)throws {
        if (!matches(seq)) {
            //throw new IllegalStateException("Queue did not match expected sequence")
            throw Exception.Error(type: ExceptionType.IllegalArgumentException, Message: "Queue did not match expected sequence")
        }
        let len = seq.count
        if (len > remainingLength()) {
            //throw new IllegalStateException("Queue not long enough to consume sequence")
            throw Exception.Error(type: ExceptionType.IllegalArgumentException, Message: "Queue not long enough to consume sequence")
        }

        pos += len
    }

    /**
     Pulls a string off the queue, up to but exclusive of the match sequence, or to the queue running out.
     - parameter seq: String to end on (and not include in return, but leave on queue). **Case sensitive.**
     - returns: The matched data consumed from queue.
     */
	@discardableResult
    open func consumeToSlice(_ seq: String) -> String {
        let offset = queue.indexOf(seq, pos)
        if (offset != -1) {
            let consumed = queue.substring(pos, offset-pos)
            pos += consumed.count
            return consumed
        } else {
            //return remainder()
        }
        return ""
    }

    open func consumeToIgnoreCase(_ seq: String) -> String {
        guard !seq.isEmpty else { return "" }
        let start = pos
        let first = seq.substring(0, 1)
        let canScan = first.lowercased() == first.uppercased() // if first is not cased, use index of
        while (!isEmpty()) {
            if (matches(seq)) {
                break
            }
            if (canScan) {
                let skip = queue.indexOf(first, pos) - pos
                if (skip == 0) { // this char is the skip char, but not match, so force advance of pos
                    pos+=1
                } else if (skip < 0) { // no chance of finding, grab to end
                    pos = queue.count
                } else {
                    pos += skip
                }
            } else {
                pos+=1
            }
        }

        return queue.substring(start, pos-start)
    }

    /**
     Consumes to the first sequence provided, or to the end of the queue. Leaves the terminator on the queue.
     - parameter seq: any number of terminators to consume to. **Case insensitive.**
     - returns: consumed string
     */
    // todo: method name. not good that consumeToSlice cares for case, and consume to any doesn't. And the only use for this
    // is is a case sensitive time...
    open func consumeToAnySlice(_ seq: String...) -> String {
        return consumeToAnySlice(seq)
    }
    open func consumeToAnySlice(_ seq: [String]) -> String {
        let start = pos
        while (!isEmpty() && !matchesAny(seq)) {
            pos+=1
        }

        return queue.substring(start, pos-start)
    }

    // Backward-compatible wrappers.
    @discardableResult
    open func consumeTo(_ seq: String) -> String {
        return consumeToSlice(seq)
    }

    @discardableResult
    open func consumeToAny(_ seq: String...) -> String {
        return consumeToAnySlice(seq)
    }

    @discardableResult
    open func consumeToAny(_ seq: [String]) -> String {
        return consumeToAnySlice(seq)
    }
    
    /**
     Pulls a string off the queue (like consumeToSlice), and then pulls off the matched string (but does not return it).
     
     If the queue runs out of characters before finding the seq, will return as much as it can (and queue will go
     isEmpty() == true).
     - parameter seq: String to match up to, and not include in return, and to pull off queue. **Case sensitive.**
     - returns: Data matched from queue.
     */
    open func chompTo(_ seq: String) -> String {
        let data = consumeToSlice(seq)
        if matchesCS(seq) {
            matchChomp(seq)
            return data
        }
        // consumeToSlice preserves the queue on a miss; chompTo promises to
        // consume the remainder, and must not accept a differently cased match.
        return data + remainder()
    }

    open func chompToIgnoreCase(_ seq: String) -> String {
        let data = consumeToIgnoreCase(seq) // case insensitive scan
        matchChomp(seq)
        return data
    }

    /**
     Pulls a balanced string off the queue. E.g. if queue is "(one (two) three) four", (,) will return "one (two) three",
     and leave " four" on the queue. Unbalanced openers and closers can quoted (with ' or ") or escaped (with \\). Those escapes will be left
     in the returned string, which is suitable for regexes (where we need to preserve the escape), but unsuitable for
     contains text strings; use unescape for that.
     - parameter open: opener
     - parameter close: closer
     - returns: data matched from the queue
     */
    open func chompBalanced(_ open: Character, _ close: Character) -> String {
        return chompBalanced(open, close, preservingDelimiters: false)
    }

    private func chompBalanced(_ open: Character, _ close: Character, preservingDelimiters: Bool) -> String {
        let start = queue.index(queue.startIndex, offsetBy: pos)
        // CSS delimiters are code points. A combining mark can share their
        // Character, and a Unicode prepend character can absorb a following
        // closer. Preserve the public API's multi-scalar delimiters as well.
        if open.unicodeScalars.count == 1, close.unicodeScalars.count == 1,
           let openScalar = open.unicodeScalars.first, let closeScalar = close.unicodeScalars.first {
            return chompBalanced(in: queue.unicodeScalars, from: start, open: openScalar, close: closeScalar,
                                 preservingDelimiters: preservingDelimiters)
        }
        return chompBalanced(in: queue, from: start, open: open, close: close,
                             preservingDelimiters: preservingDelimiters)
    }

    private func chompBalanced<Characters: Collection>(in characters: Characters, from start: String.Index,
                                                      open: Characters.Element, close: Characters.Element,
                                                      preservingDelimiters: Bool) -> String
        where Characters.Index == String.Index,
              Characters.Element: Equatable & ExpressibleByUnicodeScalarLiteral {
        var cursor = start
        var payloadStart: String.Index?
        var payloadEnd = start
        var depth = 0
        var escaped = false
        var quote: Characters.Element?

        repeat {
            guard cursor < characters.endIndex else { break }
            let c = characters[cursor]
            characters.formIndex(after: &cursor)
            if escaped {
                escaped = false
            } else if c == "\\" {
                escaped = true
            } else if let quoteCharacter = quote {
                if c == quoteCharacter { quote = nil }
            } else if (c == "'" || c == "\"") && c != open {
                quote = c
            } else if c == open {
                depth += 1
                if payloadStart == nil { payloadStart = cursor }
            } else if c == close {
                depth -= 1
            }

            if depth > 0 && payloadStart != nil {
                payloadEnd = cursor // don't include the outer match pair
            }
        } while depth > 0
        // A compound selector must retain the actual source spelling, including
        // partial input. Rebuilding open + payload + close invents a delimiter at
        // EOF and can bypass the inner numeric parser or change literal content.
        let result = preservingDelimiters
            ? String(decoding: queue.utf8[start..<cursor], as: UTF8.self)
            : payloadStart.map { String(decoding: queue.utf8[$0..<payloadEnd], as: UTF8.self) } ?? ""
        advanceCssPosition(from: start, to: cursor)
        return result
    }

    /**
     Unescaped a \ escaped string.
     - parameter input: backslash escaped string
     - returns: unescaped string
     */
    public static func unescape(_ input: String) -> String {
        let out = StringBuilder()
        var escaped = false
        // Quote one scalar at a time, including within a Swift grapheme. A run
        // of backslashes is consumed in pairs; a trailing lone escape is dropped
        // as before. This is text unescaping, not CSS hexadecimal decoding.
        for scalar in input.unicodeScalars {
            if escaped {
                out.appendCodePoint(scalar)
                escaped = false
            } else if scalar == "\\" {
                escaped = true
            } else {
                out.appendCodePoint(scalar)
            }
        }
        return out.toString()
    }

    /**
     Pulls the next run of whitespace characters of the queue.
     - returns: Whether consuming whitespace or not
     */
    @discardableResult
    open func consumeWhitespace() -> Bool {
        var seen = false
        while (matchesWhitespace()) {
            pos+=1
            seen = true
        }
        return seen
    }

    /**
     Retrieves the next run of word type (letter or digit) off the queue.
     - returns: String of word characters from queue, or empty string if none.
     */
	@discardableResult
    open func consumeWord() -> String {
        let start = pos
        while (matchesWord()) {
            pos+=1
        }
        return queue.substring(start, pos-start)
    }

    /**
     Consume an tag name off the queue (word or `:`, `_`, `-`)
     
     - returns: tag name
     */
    open func consumeTagNameSlice() -> String {
        let start = pos
        while (!isEmpty() && (matchesWord() || matchesAny(":", "_", "-"))) {
            pos+=1
        }

        return queue.substring(start, pos-start)
    }

    /**
     Consume a CSS element selector (tag name, but `|` instead of `:` for namespaces (or `*|` for wildcard namespace), to not conflict with `:pseudo` selects).
     
     - returns: tag name
     */
    open func consumeElementSelector() -> String {
        let start = pos
        while (!isEmpty() && (matchesWord() || matchesAny("*|", "|", "_", "-"))) {
            pos+=1
        }

        return queue.substring(start, pos-start)
    }

    /**
     Consume a CSS identifier (ID or class), decoding simple and hexadecimal escapes.
     Hex escapes consume one to six digits and one optional CSS whitespace terminator.
     https://www.w3.org/TR/css-syntax-3/#consume-escaped-code-point
     - returns: identifier
     */
    open func consumeCssIdentifier() -> String {
        let start = queue.index(queue.startIndex, offsetBy: pos)
        var cursor = start
        let bytes = queue.utf8
        let accum = StringBuilder()
        while cursor < bytes.endIndex {
            let byte = bytes[cursor]
            if byte == 0x5C { // backslash
                let escape = cssEscape(at: cursor)
                if let scalar = escape.scalar {
                    accum.appendCodePoint(scalar)
                } else {
                    // Preserve the existing handling of non-hex escapes and a trailing backslash.
                    for byte in bytes[bytes.index(after: cursor)..<escape.end] {
                        accum.append(byte)
                    }
                }
                cursor = escape.end
            } else if (byte >= 0x30 && byte <= 0x39) ||
                        (byte >= 0x41 && byte <= 0x5A) ||
                        (byte >= 0x61 && byte <= 0x7A) ||
                        byte == 0x2D || byte == 0x5F || byte >= 0x80 {
                // CSS permits non-ASCII code points, including combining marks after a hex digit.
                accum.append(byte)
                bytes.formIndex(after: &cursor)
            } else {
                break
            }
        }
        advanceCssPosition(from: start, to: cursor)
        return accum.toString()
    }

    /// Trim selector padding, not escaped identifier content or non-ASCII code points.
    internal static func trimCssQuery(_ query: String) -> String {
        let bytes = query.utf8
        var start = bytes.startIndex
        var end = bytes.endIndex
        while start < end, StringUtil.isAsciiWhitespaceByte(bytes[start]) {
            bytes.formIndex(after: &start)
        }
        while start < end {
            let previous = bytes.index(before: end)
            guard StringUtil.isAsciiWhitespaceByte(bytes[previous]) else { break }
            end = previous
        }
        if end < bytes.endIndex {
            // An odd run of backslashes escapes the first trailing whitespace
            // code point. Further whitespace is padding. Preserve legacy CRLF
            // escapes as a pair, just as cssEscape(at:) does.
            var cursor = end
            var escaped = false
            while cursor > start {
                let previous = bytes.index(before: cursor)
                guard bytes[previous] == 0x5C else { break }
                escaped.toggle()
                cursor = previous
            }
            if escaped {
                let first = bytes[end]
                bytes.formIndex(after: &end)
                if first == 0x0D, end < bytes.endIndex, bytes[end] == 0x0A {
                    bytes.formIndex(after: &end)
                }
            }
        }
        if start == bytes.startIndex && end == bytes.endIndex { return query }
        return String(decoding: bytes[start..<end], as: UTF8.self)
    }

    /// Consume an ASCII ID/class marker even when a following combining mark
    /// shares its Swift Character. CSS syntax operates on code points.
    internal func matchChompCssIdentifierPrefix(_ prefix: UInt8) -> Bool {
        let start = queue.index(queue.startIndex, offsetBy: pos)
        let bytes = queue.utf8
        guard start < bytes.endIndex, bytes[start] == prefix else { return false }
        advanceCssPosition(from: start, to: bytes.index(after: start))
        return true
    }

    /// Consume a compound selector up to its next unescaped combinator.
    /// Scan raw bytes so Unicode graphemes cannot swallow ASCII syntax.
    internal func consumeCssSubQuery() -> String {
        var result = ""
        while !isEmpty() {
            let start = queue.index(queue.startIndex, offsetBy: pos)
            let bytes = queue.utf8
            let byte = bytes[start]
            if byte == 0x5C {
                result.append(consumeCssEscapeSequence())
            } else if byte == 0x28 || byte == 0x5B {
                let open: Character = byte == 0x28 ? "(" : "["
                let close: Character = byte == 0x28 ? ")" : "]"
                result.append(chompBalanced(open, close, preservingDelimiters: true))
            } else if TokenQueue.isCssSubQueryBoundary(byte) {
                break
            } else {
                var end = bytes.index(after: start)
                while end < bytes.endIndex, !TokenQueue.isCssSubQueryBoundary(bytes[end]) {
                    bytes.formIndex(after: &end)
                }
                result.append(String(decoding: bytes[start..<end], as: UTF8.self))
                advanceCssPosition(from: start, to: end)
            }
        }
        return result
    }

    private static func isCssSubQueryBoundary(_ byte: UInt8) -> Bool {
        if StringUtil.isAsciiWhitespaceByte(byte) { return true }
        switch byte {
        case 0x5C, 0x28, 0x5B, 0x2C, 0x3E, 0x2B, 0x7E: return true
        default: return false
        }
    }

    /// Preserve an entire escape while splitting a selector. Its optional whitespace is not a combinator.
    internal func consumeCssEscapeSequence() -> String {
        let start = queue.index(queue.startIndex, offsetBy: pos)
        guard start < queue.endIndex, queue.utf8[start] == 0x5C else { return "" }
        let end = cssEscape(at: start).end
        let escaped = String(decoding: queue.utf8[start..<end], as: UTF8.self)
        advanceCssPosition(from: start, to: end)
        return escaped
    }

    /// Consume a comma-separated CSS selector list without splitting escapes,
    /// quoted text, attribute selectors, or nested functional expressions.
    internal func consumeCssSelectorList() -> [String] {
        var branches: [String] = []
        var branch = ""
        var quote: UInt8?
        while !isEmpty() {
            let start = queue.index(queue.startIndex, offsetBy: pos)
            let bytes = queue.utf8
            let byte = bytes[start]
            if byte == 0x5C { // backslash
                branch += consumeCssEscapeSequence()
            } else if let openQuote = quote {
                let end = queue.unicodeScalars.index(after: start)
                branch += String(decoding: bytes[start..<end], as: UTF8.self)
                advanceCssPosition(from: start, to: end)
                if byte == openQuote { quote = nil }
            } else if byte == 0x22 || byte == 0x27 { // double or single quote
                quote = byte
                let end = queue.unicodeScalars.index(after: start)
                branch += String(decoding: bytes[start..<end], as: UTF8.self)
                advanceCssPosition(from: start, to: end)
            } else if byte == 0x28 || byte == 0x5B { // ( or [
                let open: Character = byte == 0x28 ? "(" : "["
                let close: Character = byte == 0x28 ? ")" : "]"
                branch += chompBalanced(open, close, preservingDelimiters: true)
            } else if byte == 0x2C { // comma
                branches.append(branch)
                branch = ""
                let end = bytes.index(after: start)
                advanceCssPosition(from: start, to: end)
            } else {
                // Advance ordinary runs together instead of repeatedly resolving
                // a Character offset for every scalar in a long selector.
                var end = bytes.index(after: start)
                while end < bytes.endIndex {
                    let next = bytes[end]
                    if next == 0x5C || next == 0x22 || next == 0x27 ||
                        next == 0x28 || next == 0x5B || next == 0x2C { break }
                    bytes.formIndex(after: &end)
                }
                branch += String(decoding: bytes[start..<end], as: UTF8.self)
                advanceCssPosition(from: start, to: end)
            }
        }
        branches.append(branch)
        return branches
    }

    /// A nil scalar means a non-hex escape: retain its literal contents after the backslash.
    private func cssEscape(at start: String.Index) -> (end: String.Index, scalar: UnicodeScalar?) {
        let bytes = queue.utf8
        var cursor = bytes.index(after: start)
        var value: UInt32 = 0
        var digits = 0
        while cursor < bytes.endIndex, digits < 6, let digit = TokenQueue.cssHexValue(bytes[cursor]) {
            value = value * 16 + digit
            digits += 1
            bytes.formIndex(after: &cursor)
        }
        if digits == 0 {
            if cursor < bytes.endIndex {
                let first = bytes[cursor]
                cursor = queue.unicodeScalars.index(after: cursor)
                // Retain the legacy non-hex CRLF escape behavior.
                if first == 0x0D, cursor < bytes.endIndex, bytes[cursor] == 0x0A {
                    bytes.formIndex(after: &cursor)
                }
            }
            return (cursor, nil)
        }
        if cursor < bytes.endIndex {
            let terminator = bytes[cursor]
            if StringUtil.isAsciiWhitespaceByte(terminator) {
                bytes.formIndex(after: &cursor)
                // CSS preprocessing treats CRLF as one newline, not two terminators.
                if terminator == 0x0D, cursor < bytes.endIndex, bytes[cursor] == 0x0A {
                    bytes.formIndex(after: &cursor)
                }
            }
        }
        let replacement: UnicodeScalar = "\u{FFFD}"
        return (cursor, value == 0 ? replacement : (UnicodeScalar(value) ?? replacement))
    }

    @inline(__always)
    private static func cssHexValue(_ byte: UInt8) -> UInt32? {
        switch byte {
        case 0x30...0x39: return UInt32(byte - 0x30)
        case 0x41...0x46: return UInt32(byte - 0x41 + 10)
        case 0x61...0x66: return UInt32(byte - 0x61 + 10)
        default: return nil
        }
    }

    private func advanceCssPosition(from start: String.Index, to end: String.Index) {
        if end.samePosition(in: queue) != nil {
            pos += queue.distance(from: start, to: end)
        } else {
            // An ASCII syntax character can share a grapheme with a following combining mark.
            // Retain every unconsumed code point when advancing through that grapheme.
            queue = String(decoding: queue.utf8[end...], as: UTF8.self)
            pos = 0
        }
    }

    /**
     Consume an attribute key off the queue (letter, digit, `-`, `_`, `:`)
     - returns: attribute key
     */
    open func consumeAttributeKey() -> String {
        let start = pos
        while (!isEmpty() && (matchesWord() || matchesAny("-", "_", ":"))) {
            pos+=1
        }

        return queue.substring(start, pos-start)
    }

    /**
     Consume and return whatever is left on the queue.
     - returns: remained of queue.
     */
    open func remainder() -> String {
        let remainder = queue.substring(pos, queue.count-pos)
        pos = queue.count
        return remainder
    }

    open func toString() -> String {
        return queue.substring(pos)
    }
}
