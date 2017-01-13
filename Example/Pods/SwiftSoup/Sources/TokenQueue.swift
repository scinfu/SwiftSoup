//
//  TokenQueue.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 13/10/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import Foundation

open class TokenQueue {
    private var queue: String
    private var pos: Int = 0

    private static let ESC: Character = "\\" // escape char for chomp balanced.

    /**
     Create a new TokenQueue.
     @param data string of data to back queue.
     */
    public init (_ data: String) {
        queue = data
    }

    /**
     * Is the queue empty?
     * @return true if no data left in queue.
     */
    open func isEmpty() -> Bool {
        return remainingLength() == 0
    }

    private func remainingLength() -> Int {
        return queue.characters.count - pos
    }

    /**
     * Retrieves but does not remove the first character from the queue.
     * @return First character, or 0 if empty.
     */
    open func peek() -> Character {
        return isEmpty() ? Character(UnicodeScalar(0)) : queue[pos]
    }

    /**
     Add a character to the start of the queue (will be the next character retrieved).
     @param c character to add
     */
    open func addFirst(_ c: Character) {
        addFirst(String(c))
    }

    /**
     Add a string to the start of the queue.
     @param seq string to add.
     */
    open func addFirst(_ seq: String) {
        // not very performant, but an edge case
        queue = seq + queue.substring(pos)
        pos = 0
    }

    /**
     * Tests if the next characters on the queue match the sequence. Case insensitive.
     * @param seq String to check queue for.
     * @return true if the next characters match.
     */
    open func matches(_ seq: String) -> Bool {
        return queue.regionMatches(true, pos, seq, 0, seq.characters.count)
    }

    /**
     * Case sensitive match test.
     * @param seq string to case sensitively check for
     * @return true if matched, false if not
     */
    open func matchesCS(_ seq: String) -> Bool {
        return queue.startsWith(seq, pos)
    }

    /**
     Tests if the next characters match any of the sequences. Case insensitive.
     @param seq list of strings to case insensitively check for
     @return true of any matched, false if none did
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
     * Tests if the queue matches the sequence (as with match), and if they do, removes the matched string from the
     * queue.
     * @param seq String to search for, and if found, remove from queue.
     * @return true if found and removed, false if not found.
     */
    @discardableResult
    open func matchChomp(_ seq: String) -> Bool {
        if (matches(seq)) {
            pos += seq.characters.count
            return true
        } else {
            return false
        }
    }

    /**
     Tests if queue starts with a whitespace character.
     @return if starts with whitespace
     */
    open func matchesWhitespace() -> Bool {
        return !isEmpty() && StringUtil.isWhitespace(queue.charAt(pos))
    }

    /**
     Test if the queue matches a word character (letter or digit).
     @return if matches a word character
     */
    open func matchesWord() -> Bool {
        return !isEmpty() && (Character.isLetterOrDigit(queue.charAt(pos)))
    }

    /**
     * Drops the next character off the queue.
     */
    open func advance() {

        if (!isEmpty()) {pos+=1}
    }

    /**
     * Consume one character off queue.
     * @return first character on queue.
     */
    open func consume() -> Character {
        let i = pos
        pos+=1
        return queue.charAt(i)
    }

    /**
     * Consumes the supplied sequence of the queue. If the queue does not start with the supplied sequence, will
     * throw an illegal state exception -- but you should be running match() against that condition.
     <p>
     Case insensitive.
     * @param seq sequence to remove from head of queue.
     */
    open func consume(_ seq: String)throws {
        if (!matches(seq)) {
            //throw new IllegalStateException("Queue did not match expected sequence")
            throw Exception.Error(type: ExceptionType.IllegalArgumentException, Message: "Queue did not match expected sequence")
        }
        let len = seq.characters.count
        if (len > remainingLength()) {
            //throw new IllegalStateException("Queue not long enough to consume sequence")
            throw Exception.Error(type: ExceptionType.IllegalArgumentException, Message: "Queue not long enough to consume sequence")
        }

        pos += len
    }

    /**
     * Pulls a string off the queue, up to but exclusive of the match sequence, or to the queue running out.
     * @param seq String to end on (and not include in return, but leave on queue). <b>Case sensitive.</b>
     * @return The matched data consumed from queue.
     */
	@discardableResult
    open func consumeTo(_ seq: String) -> String {
        let offset = queue.indexOf(seq, pos)
        if (offset != -1) {
            let consumed = queue.substring(pos, offset-pos)
            pos += consumed.characters.count
            return consumed
        } else {
            //return remainder()
        }
        return ""
    }

    open func consumeToIgnoreCase(_ seq: String) -> String {
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
                    pos = queue.characters.count
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
     @param seq any number of terminators to consume to. <b>Case insensitive.</b>
     @return consumed string
     */
    // todo: method name. not good that consumeTo cares for case, and consume to any doesn't. And the only use for this
    // is is a case sensitive time...
    open func consumeToAny(_ seq: String...) -> String {
        return consumeToAny(seq)
    }
    open func consumeToAny(_ seq: [String]) -> String {
        let start = pos
        while (!isEmpty() && !matchesAny(seq)) {
            pos+=1
        }

        return queue.substring(start, pos-start)
    }
    /**
     * Pulls a string off the queue (like consumeTo), and then pulls off the matched string (but does not return it).
     * <p>
     * If the queue runs out of characters before finding the seq, will return as much as it can (and queue will go
     * isEmpty() == true).
     * @param seq String to match up to, and not include in return, and to pull off queue. <b>Case sensitive.</b>
     * @return Data matched from queue.
     */
    open func chompTo(_ seq: String) -> String {
        let data = consumeTo(seq)
        matchChomp(seq)
        return data
    }

    open func chompToIgnoreCase(_ seq: String) -> String {
        let data = consumeToIgnoreCase(seq) // case insensitive scan
        matchChomp(seq)
        return data
    }

    /**
     * Pulls a balanced string off the queue. E.g. if queue is "(one (two) three) four", (,) will return "one (two) three",
     * and leave " four" on the queue. Unbalanced openers and closers can quoted (with ' or ") or escaped (with \). Those escapes will be left
     * in the returned string, which is suitable for regexes (where we need to preserve the escape), but unsuitable for
     * contains text strings; use unescape for that.
     * @param open opener
     * @param close closer
     * @return data matched from the queue
     */
    open func chompBalanced(_ open: Character, _ close: Character) -> String {
        var start = -1
        var end = -1
        var depth = 0
        var last: Character = Character(UnicodeScalar(0))
        var inQuote = false

        repeat {
            if (isEmpty()) {break}
            let c = consume()
            if (last.unicodeScalar.value == 0 || last != TokenQueue.ESC) {
                if ((c=="'" || c=="\"") && c != open) {
                    inQuote = !inQuote
                }
                if (inQuote) {
                    continue
                }
                if (c==open) {
                    depth+=1
                    if (start == -1) {
                        start = pos
                    }
                } else if (c==close) {
                    depth-=1
                }
            }

            if (depth > 0 && last.unicodeScalar.value != 0) {
                end = pos // don't include the outer match pair in the return
            }
            last = c
        } while (depth > 0)
        return (end >= 0) ? queue.substring(start, end-start) : ""
    }

    /**
     * Unescaped a \ escaped string.
     * @param in backslash escaped string
     * @return unescaped string
     */
    open static func unescape(_ input: String) -> String {
        let out = StringBuilder()
        var last = Character(UnicodeScalar(0))
        for c in input.characters {
            if (c == ESC) {
                if (last.unicodeScalar.value != 0 && last == TokenQueue.ESC) {
                    out.append(c)
                }
            } else {
                out.append(c)
            }
            last = c
        }
        return out.toString()
    }

    /**
     * Pulls the next run of whitespace characters of the queue.
     * @return Whether consuming whitespace or not
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
     * Retrieves the next run of word type (letter or digit) off the queue.
     * @return String of word characters from queue, or empty string if none.
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
     * Consume an tag name off the queue (word or :, _, -)
     *
     * @return tag name
     */
    open func consumeTagName() -> String {
        let start = pos
        while (!isEmpty() && (matchesWord() || matchesAny(":", "_", "-"))) {
            pos+=1
        }

        return queue.substring(start, pos-start)
    }

    /**
     * Consume a CSS element selector (tag name, but | instead of : for namespaces (or *| for wildcard namespace), to not conflict with :pseudo selects).
     *
     * @return tag name
     */
    open func consumeElementSelector() -> String {
        let start = pos
        while (!isEmpty() && (matchesWord() || matchesAny("*|", "|", "_", "-"))) {
            pos+=1
        }

        return queue.substring(start, pos-start)
    }

    /**
     Consume a CSS identifier (ID or class) off the queue (letter, digit, -, _)
     http://www.w3.org/TR/CSS2/syndata.html#value-def-identifier
     @return identifier
     */
    open func consumeCssIdentifier() -> String {
        let start = pos
        while (!isEmpty() && (matchesWord() || matchesAny("-", "_"))) {
            pos+=1
        }

        return queue.substring(start, pos-start)
    }

    /**
     Consume an attribute key off the queue (letter, digit, -, _, :")
     @return attribute key
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
     @return remained of queue.
     */
    open func remainder() -> String {
        let remainder = queue.substring(pos, queue.characters.count-pos)
        pos = queue.characters.count
        return remainder
    }

    open func toString() -> String {
        return queue.substring(pos)
    }
}
