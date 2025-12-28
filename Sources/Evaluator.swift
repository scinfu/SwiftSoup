//
//  Evaluator.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 22/10/16.
//

import Foundation

/// Evaluates that an element matches the selector.
open class Evaluator: @unchecked Sendable {
    public init () {}

    /**
     Test if the element meets the evaluator's requirements.
     
     - parameter root:    Root of the matching subtree
     - parameter element: tested element
     - returns: Returns `true` if the requirements are met or `false` otherwise.
     */
    open func matches(_ root: Element, _ element: Element)throws->Bool {
        preconditionFailure("self method must be overridden")
    }

    open func toString() -> String {
        preconditionFailure("self method must be overridden")
    }

    /**
     * Evaluator for tag name
     */
    public class Tag: Evaluator, @unchecked Sendable {
        private let tagName: [UInt8]
        public let tagNameNormal: [UInt8]
        private let tagId: Token.Tag.TagId

        public init(_ tagName: String) {
            let utf8TagName = tagName.utf8Array
            self.tagName = utf8TagName
            self.tagNameNormal = utf8TagName.lowercased()
            self.tagId = Token.Tag.tagIdForBytes(self.tagNameNormal) ?? .none
        }
        
        public init(_ tagName: [UInt8]) {
            self.tagName = tagName
            self.tagNameNormal = tagName.lowercased()
            self.tagId = Token.Tag.tagIdForBytes(self.tagNameNormal) ?? .none
        }

        open override func matches(_ root: Element, _ element: Element) throws -> Bool {
            if tagId != .none {
                let elTagId = element._tag.tagId
                if elTagId != .none {
                    return elTagId == tagId
                }
            }
            return element.tagNameNormalUTF8() == tagNameNormal
        }

        open override func toString() -> String {
            return String(decoding: tagName, as: UTF8.self)
        }
    }

    /**
     * Evaluator for tag name that ends with the given suffix.
     */
    public final class TagEndsWith: Evaluator, @unchecked Sendable {
        private let tagName: String

        public init(_ tagName: String) {
            self.tagName = tagName
        }

        public override func matches(_ root: Element, _ element: Element)throws->Bool {
            return (element.tagName().hasSuffix(tagName))
        }

        public override func toString() -> String {
            return String(tagName)
        }
    }

    /**
     * Evaluator for element id
     */
    public final class Id: Evaluator, @unchecked Sendable {
        @usableFromInline
        let id: String
        @usableFromInline
        let idBytes: [UInt8]

        public init(_ id: String) {
            self.id = id
            self.idBytes = id.utf8Array
        }

        public override func matches(_ root: Element, _ element: Element)throws->Bool {
            return idBytes == element.idUTF8()
        }

        public override func toString() -> String {
            return "#\(id)"
        }

    }

    /**
     * Evaluator for element class
     */
    public final class Class: Evaluator, @unchecked Sendable {
        @usableFromInline
        let className: String
        @usableFromInline
        let classNameBytes: [UInt8]

        public init(_ className: String) {
            self.className = className
            self.classNameBytes = className.utf8Array
        }

        public override func matches(_ root: Element, _ element: Element) -> Bool {
            return element.hasClass(classNameBytes)
        }

        public override func toString() -> String {
            return ".\(className)"
        }

    }

    /**
     * Evaluator for attribute name matching
     */
    public final class Attribute: Evaluator, @unchecked Sendable {
        @usableFromInline
        let key: String
        @usableFromInline
        let keyBytes: [UInt8]

        public init(_ key: String) {
            self.key = key
            self.keyBytes = key.trim().lowercased().utf8Array
        }

        public override func matches(_ root: Element, _ element: Element)throws->Bool {
            return element.hasAttr(keyBytes)
        }

        public override func toString() -> String {
            return "[\(key)]"
        }

    }

    /**
     * Evaluator for attribute name prefix matching
     */
    public final class AttributeStarting: Evaluator, @unchecked Sendable {
        private let keyPrefix: [UInt8]

        public init(_ keyPrefix: [UInt8]) throws {
            try Validate.notEmpty(string: keyPrefix)
            self.keyPrefix = keyPrefix.lowercased()
        }

        public override func matches(_ root: Element, _ element: Element) throws -> Bool {
            if let values = element.getAttributes() {
                for attribute in values where attribute.getKeyUTF8().lowercased().hasPrefix(keyPrefix) {
                    return true
                }
            }
            return false
        }

        public override func toString() -> String {
            return "[^\(String(decoding: keyPrefix, as: UTF8.self))]"
        }

    }

    /**
     * Evaluator for attribute name/value matching
     */
    public final class AttributeWithValue: AttributeKeyPair, @unchecked Sendable {
        public override init(_ key: String, _ value: String)throws {
            try super.init(key, value)
        }

        public override func matches(_ root: Element, _ element: Element)throws->Bool {
            if element.hasAttr(keyBytes) {
                let bytes = try element.attr(keyBytes)
                return valueBytes.equalsIgnoreCase(string: bytes.trim())
            }
            return false
        }

        public override func toString() -> String {
            return "[\(key)=\(value)]"
        }

    }

    /**
     * Evaluator for attribute name != value matching
     */
    public final class AttributeWithValueNot: AttributeKeyPair, @unchecked Sendable {
        public override init(_ key: String, _ value: String)throws {
            try super.init(key, value)
        }

        public override func matches(_ root: Element, _ element: Element)throws->Bool {
            let bytes = try element.attr(keyBytes)
            return !valueBytes.equalsIgnoreCase(string: bytes)
        }

        public override func toString() -> String {
            return "[\(key)!=\(value)]"
        }

    }

    /**
     * Evaluator for attribute name/value matching (value prefix)
     */
    public final class AttributeWithValueStarting: AttributeKeyPair, @unchecked Sendable {
        private static let useAsciiFastPath: Bool = {
            ProcessInfo.processInfo.environment["SWIFTSOUP_DISABLE_ATTRVALUE_ASCII_FASTPATH"] != "1"
        }()

        public override init(_ key: String, _ value: String)throws {
            try super.init(key, value)
        }

        public override func matches(_ root: Element, _ element: Element)throws->Bool {
            if element.hasAttr(keyBytes) {
                let bytes = try element.attr(keyBytes)
                if Self.useAsciiFastPath,
                   StringUtil.isAscii(bytes),
                   StringUtil.isAscii(valueBytes) {
                    return StringUtil.hasPrefixIgnoreCaseAscii(bytes, valueBytes)
                }
                return String(decoding: bytes, as: UTF8.self).lowercased().hasPrefix(value)
            }
            return false
        }

        public override func toString() -> String {
            return "[\(key)^=\(value)]"
        }

    }

    /**
     * Evaluator for attribute name/value matching (value ending)
     */
    public final class AttributeWithValueEnding: AttributeKeyPair, @unchecked Sendable {
        private static let useAsciiFastPath: Bool = {
            ProcessInfo.processInfo.environment["SWIFTSOUP_DISABLE_ATTRVALUE_ASCII_FASTPATH"] != "1"
        }()

        public override init(_ key: String, _ value: String)throws {
            try super.init(key, value)
        }

        public override func matches(_ root: Element, _ element: Element)throws->Bool {
            if element.hasAttr(keyBytes) {
                let bytes = try element.attr(keyBytes)
                if Self.useAsciiFastPath,
                   StringUtil.isAscii(bytes),
                   StringUtil.isAscii(valueBytes) {
                    return StringUtil.hasSuffixIgnoreCaseAscii(bytes, valueBytes)
                }
                return String(decoding: bytes, as: UTF8.self).lowercased().hasSuffix(value)
            }
            return false
        }

        public override func toString() -> String {
            return "[\(key)$=\(value)]"
        }

    }

    /**
     * Evaluator for attribute name/value matching (value containing)
     */
    public final class AttributeWithValueContaining: AttributeKeyPair, @unchecked Sendable {
        private static let useAsciiFastPath: Bool = {
            ProcessInfo.processInfo.environment["SWIFTSOUP_DISABLE_ATTRVALUE_ASCII_FASTPATH"] != "1"
        }()

        public override init(_ key: String, _ value: String)throws {
            try super.init(key, value)
        }

        public override func matches(_ root: Element, _ element: Element)throws->Bool {
            if element.hasAttr(keyBytes) {
                let bytes = try element.attr(keyBytes)
                if Self.useAsciiFastPath,
                   StringUtil.isAscii(bytes),
                   StringUtil.isAscii(valueBytes) {
                    return StringUtil.containsIgnoreCaseAscii(bytes, valueBytes)
                }
                return String(decoding: bytes, as: UTF8.self).lowercased().contains(value)
            }
            return false
        }

        public override func toString() -> String {
            return "[\(key)*=\(value)]"
        }

    }

    /**
     * Evaluator for attribute name/value matching (value regex matching)
     */
    public final class AttributeWithValueMatching: Evaluator, @unchecked Sendable {
        let key: String
        let pattern: Pattern

        public init(_ key: String, _ pattern: Pattern) {
            self.key = key.trim().lowercased()
            self.pattern = pattern
            super.init()
        }

        public override func matches(_ root: Element, _ element: Element)throws->Bool {
            if element.hasAttr(key) {
                let string = try element.attr(key)
                return pattern.matcher(in: string).find()
            }
            return false
        }

        public override func toString() -> String {
            return "[\(key)~=\(pattern.toString())]"
        }

    }

    /**
     * Abstract evaluator for attribute name/value matching
     */
    public class AttributeKeyPair: Evaluator, @unchecked Sendable {
        let key: String
        let value: String
        let keyBytes: [UInt8]
        let valueBytes: [UInt8]

        public init(_ key: String, _ value2: String)throws {
            var value2 = value2
            try Validate.notEmpty(string: key)
            try Validate.notEmpty(string: value2)

            self.key = key.trim().lowercased()
            if value2.startsWith("\"") && value2.hasSuffix("\"") || value2.startsWith("'") && value2.hasSuffix("'") {
                value2 = value2.substring(1, value2.count-2)
            }
            self.value = value2.trim().lowercased()
            self.keyBytes = self.key.utf8Array
            self.valueBytes = self.value.utf8Array
        }

        open override func matches(_ root: Element, _ element: Element)throws->Bool {
            preconditionFailure("self method must be overridden")
        }
    }

    /**
     * Evaluator for any / all element matching
     */
    public final class AllElements: Evaluator, @unchecked Sendable {

        public override func matches(_ root: Element, _ element: Element)throws->Bool {
            return true
        }

        public override func toString() -> String {
            return "*"
        }
    }

    /**
     * Evaluator for matching by sibling index number (`e < idx`).
     */
    public final class IndexLessThan: IndexEvaluator, @unchecked Sendable {
        public override init(_ index: Int) {
            super.init(index)
        }

        public override func matches(_ root: Element, _ element: Element)throws->Bool {
            return try element.elementSiblingIndex() < index
        }

        public override func toString() -> String {
            return ":lt(\(index))"
        }

    }

    /**
     * Evaluator for matching by sibling index number (`e > idx`).
     */
    public final class IndexGreaterThan: IndexEvaluator, @unchecked Sendable {
        public override init(_ index: Int) {
            super.init(index)
        }

        public override func matches(_ root: Element, _ element: Element)throws->Bool {
            return try element.elementSiblingIndex() > index
        }

        public override func toString() -> String {
            return ":gt(\(index))"
        }

    }

    /**
     * Evaluator for matching by sibling index number (`e == idx`)
     */
    public final class IndexEquals: IndexEvaluator, @unchecked Sendable {
        public override init(_ index: Int) {
            super.init(index)
        }

        public override func matches(_ root: Element, _ element: Element)throws->Bool {
            return try element.elementSiblingIndex() == index
        }

        public override func toString() -> String {
            return ":eq(\(index))"
        }

    }

    /**
     * Evaluator for matching the last sibling (CSS `:last-child`)
     */
    public final class IsLastChild: Evaluator, @unchecked Sendable {
        public override func matches(_ root: Element, _ element: Element)throws->Bool {
            if let parent = element.parent(), !(parent is Document), element !== root {
                return (try element.nextElementSibling()) == nil
            }
            return false
        }

        public override func toString() -> String {
            return ":last-child"
        }
    }

    public final class IsFirstOfType: IsNthOfType, @unchecked Sendable {
        public init() {
            super.init(0, 1)
        }
        public override func toString() -> String {
            return ":first-of-type"
        }
    }

    public final class IsLastOfType: IsNthLastOfType, @unchecked Sendable {
        public init() {
            super.init(0, 1)
        }
        public override func toString() -> String {
            return ":last-of-type"
        }
    }

    public class CssNthEvaluator: Evaluator, @unchecked Sendable {
        public let a: Int
        public let b: Int

        public init(_ a: Int, _ b: Int) {
            self.a = a
            self.b = b
        }
        public init(_ b: Int) {
            self.a = 0
            self.b = b
        }

        open override func matches(_ root: Element, _ element: Element)throws->Bool {
            let p: Element? = element.parent()
            if (p == nil || (((p as? Document) != nil))) {return false}

            let pos: Int = try calculatePosition(root, element)
            if (a == 0) {return pos == b}

            return (pos-b)*a >= 0 && (pos-b)%a==0
        }

        open override func toString() -> String {
            if (a == 0) {
                return ":\(getPseudoClass())(\(b))"
            }
            if (b == 0) {
                return ":\(getPseudoClass())(\(a))"
            }
            return ":\(getPseudoClass())(\(a)\(b))"
        }

        open func getPseudoClass() -> String {
            preconditionFailure("self method must be overridden")
        }
        open func calculatePosition(_ root: Element, _ element: Element)throws->Int {
            preconditionFailure("self method must be overridden")
        }
    }

    /**
     CSS-compatible Evaluator for `:eq` (CSS `:nth-child`)
     
     - seealso: ``IndexEquals``
     */
    public final class IsNthChild: CssNthEvaluator, @unchecked Sendable {

        public override init(_ a: Int, _ b: Int) {
            super.init(a, b)
        }

        public override func calculatePosition(_ root: Element, _ element: Element)throws->Int {
            return try element.elementSiblingIndex()+1
        }

        public override func getPseudoClass() -> String {
            return "nth-child"
        }
    }

    /**
     CSS pseudo class `:nth-last-child`
     
     - seealso: ``IndexEquals``
     */
    public final class IsNthLastChild: CssNthEvaluator, @unchecked Sendable {
        public override init(_ a: Int, _ b: Int) {
            super.init(a, b)
        }

        public override func calculatePosition(_ root: Element, _ element: Element)throws->Int {
            var i = 0

            if let l = element.parent() {
                i = l.children().array().count
            }
            return i - (try element.elementSiblingIndex())
        }

        public override func getPseudoClass() -> String {
            return "nth-last-child"
        }
    }

    /**
     CSS pseudo class `:nth-of-type`
     */
    public class IsNthOfType: CssNthEvaluator, @unchecked Sendable {
        public override init(_ a: Int, _ b: Int) {
            super.init(a, b)
        }

        open override func calculatePosition(_ root: Element, _ element: Element) -> Int {
            var pos = 0
            let family: Elements? = element.parent()?.children()
            if let array = family?.array() {
                for el in array {
                    if (el.tag() == element.tag()) {pos+=1}
                    if (el === element) {break}
                }
            }

            return pos
        }

        open override func getPseudoClass() -> String {
            return "nth-of-type"
        }
    }

    public class IsNthLastOfType: CssNthEvaluator, @unchecked Sendable {

        public override init(_ a: Int, _ b: Int) {
            super.init(a, b)
        }

        open override func calculatePosition(_ root: Element, _ element: Element)throws->Int {
            var pos = 0
            if let family = element.parent()?.children() {
                let x = try element.elementSiblingIndex()
                for i in x..<family.array().count {
                    if (family.get(i).tag() == element.tag()) {
                        pos+=1
                    }
                }
            }

            return pos
        }

        open override func getPseudoClass() -> String {
            return "nth-last-of-type"
        }
    }

    /**
     * Evaluator for matching the first sibling (CSS `:first-child`)
     */
    public final class IsFirstChild: Evaluator, @unchecked Sendable {
        public override func matches(_ root: Element, _ element: Element)throws->Bool {
            let p = element.parent()
            if element !== root, p != nil, !(p is Document) {
                return (try element.elementSiblingIndex()) == 0
            }
            return false
        }

        public override func toString() -> String {
            return ":first-child"
        }
    }

    /**
     CSS3 pseudo-class `:root`
     
     - seealso: [`:root` selector](https://www.w3.org/TR/selectors/#root-pseudo)
     */
    public final class IsRoot: Evaluator, @unchecked Sendable {
        public override func matches(_ root: Element, _ element: Element)throws->Bool {
            let r: Element = ((root as? Document) != nil) ? root.child(0) : root
            return element === r
        }
        public override func toString() -> String {
            return ":root"
        }
    }

    public final class IsOnlyChild: Evaluator, @unchecked Sendable {
        public override func matches(_ root: Element, _ element: Element)throws->Bool {
            let p = element.parent()
            return p != nil && !((p as? Document) != nil) && element.siblingElements().isEmpty()
        }
        public override func toString() -> String {
            return ":only-child"
        }
    }

    public final class IsOnlyOfType: Evaluator, @unchecked Sendable {
        public override func matches(_ root: Element, _ element: Element)throws->Bool {
            let p = element.parent()
            if (p == nil || (p as? Document) != nil) {return false}

            var pos = 0
            if let family = p?.children().array() {
                for  el in family {
                    if (el.tag() == element.tag()) {pos+=1}
                }
            }
            return pos == 1
        }

        public override func toString() -> String {
            return ":only-of-type"
        }
    }

    public final class IsEmpty: Evaluator, @unchecked Sendable {
        public override func matches(_ root: Element, _ element: Element)throws->Bool {
            let family: Array<Node> = element.getChildNodes()
            for n in family {
                if (!((n as? Comment) != nil || (n as? XmlDeclaration) != nil || (n as? DocumentType) != nil)) {return false}
            }
            return true
        }

        public override func toString() -> String {
            return ":empty"
        }
    }

    /**
     * Abstract evaluator for sibling index matching
     */
    public class IndexEvaluator: Evaluator, @unchecked Sendable {
        let index: Int

        public init(_ index: Int) {
            self.index = index
        }
    }

    /**
     * Evaluator for matching Element (and its descendants) text
     */
    public final class ContainsText: Evaluator, @unchecked Sendable {
        private let searchText: String

        public init(_ searchText: String) {
            self.searchText = searchText.lowercased()
        }

        public override func matches(_ root: Element, _ element: Element)throws->Bool {
            return (try element.text().lowercased().contains(searchText))
        }

        public override func toString() -> String {
            return ":contains(\(searchText)"
        }
    }

    /**
     * Evaluator for matching Element's own text
     */
    public final class ContainsOwnText: Evaluator, @unchecked Sendable {
        private let searchText: String

        public init(_ searchText: String) {
            self.searchText = searchText.lowercased()
        }

        public override func matches(_ root: Element, _ element: Element)throws->Bool {
            return (element.ownText().lowercased().contains(searchText))
        }

        public override func toString() -> String {
            return ":containsOwn(\(searchText)"
        }
    }

    /**
     * Evaluator for matching Element (and its descendants) text with regex
     */
    public final class Matches: Evaluator, @unchecked Sendable {
        private let pattern: Pattern

        public init(_ pattern: Pattern) {
            self.pattern = pattern
        }

        public override func matches(_ root: Element, _ element: Element)throws->Bool {
            let m = try pattern.matcher(in: element.text())
            return m.find()
        }

        public override func toString() -> String {
            return ":matches(\(pattern)"
        }
    }

    /**
     * Evaluator for matching Element's own text with regex
     */
    public final class MatchesOwn: Evaluator, @unchecked Sendable {
        private let pattern: Pattern

        public init(_ pattern: Pattern) {
            self.pattern = pattern
        }

        public override func matches(_ root: Element, _ element: Element)throws->Bool {
            let m = pattern.matcher(in: element.ownText())
            return m.find()
        }

        public override func toString() -> String {
            return ":matchesOwn(\(pattern.toString())"
        }
    }
}
