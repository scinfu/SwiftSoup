//
//  QueryParser.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 23/10/16.
//

import Foundation


/**
 * Parses a CSS selector into an Evaluator tree.
 */
public class QueryParser {
    private static let combinators: [String]  = [",", ">", "+", "~", " "]
    private static let AttributeEvals: [String]  = ["=", "!=", "^=", "$=", "*=", "~="]

    /// Mutex lock for the cache instance.
    private static let cacheMutex = Mutex()

    /// Cache instance. Must always access this with the ``QueryParser/cacheMutex``.
    nonisolated(unsafe)
    private static var cacheInstance: (any QueryParserCache)? = DefaultCache()
    
    private var tq: TokenQueue
    private var query: String
    private var evals: Array<Evaluator>  = Array<Evaluator>()
    
    
    // MARK: Initializer
    
    /**
     Create a new QueryParser.
     - parameter query: CSS query
     */
    private init(_ query: String) {
        self.query = query
        self.tq = TokenQueue(query)
    }
    
    
    // MARK: Public methods

    /**
     Parse a CSS query into an Evaluator.
     - parameter query: CSS query
     - returns: ``Evaluator``
     - seealso: ``cache``
     */
    public static func parse(_ query: String)throws->Evaluator {
        let query = TokenQueue.trimCssQuery(query)
        let cache = Self.cache
        if let cached = cache?.get(query) {
            return cached
        }
        
        let p = QueryParser(query)
        let eval = try p.parse()
        cache?.set(query, eval)
        return eval
    }

    /**
     Parse the query
     - returns: ``Evaluator``
     */
    public func parse()throws->Evaluator {
        tq.consumeWhitespace()

        if (tq.matchesAny(QueryParser.combinators)) { // if starts with a combinator, use root as elements
            evals.append( StructuralEvaluator.Root())
            try combinator(tq.consume())
        } else {
            try findElements()
        }

        while (!tq.isEmpty()) {
            // hierarchy and extras
            let seenWhite: Bool = tq.consumeWhitespace()

            if (tq.matchesAny(QueryParser.combinators)) {
                try combinator(tq.consume())
            } else if (seenWhite) {
                try combinator(" " as Character)
            } else { // E.class, E#id, E[attr] etc. AND
                try findElements() // take next el, #. etc off queue
            }
        }

        if (evals.count == 1) {
            return evals[0]
        }
        return CombiningEvaluator.And(evals)
    }
    
    
    /// Cache to use for the query parser.
    ///
    /// Defaults to ``DefaultCache``. You can set this to `nil` to disable caching, provide a
    /// ``DefaultCache`` instance with a different limit, or provide your own cache.
    public static var cache: (any QueryParserCache)? {
        get {
            Self.cacheMutex.lock()
            defer { Self.cacheMutex.unlock() }
            return Self.cacheInstance
        }
        set {
            Self.cacheMutex.lock()
            defer { Self.cacheMutex.unlock() }
            Self.cacheInstance = newValue
        }
    }
    
    
    // MARK: Private methods

    private func combinator(_ combinator: Character)throws {
        tq.consumeWhitespace()
        let subQuery: String = consumeSubQuery() // support multi > childs

        var rootEval: Evaluator? // the new topmost evaluator
        var currentEval: Evaluator? // the evaluator the new eval will be combined to. could be root, or rightmost or.
        let newEval: Evaluator = try QueryParser.parse(subQuery) // the evaluator to add into target evaluator
        var replaceRightMost: Bool = false

        if (evals.count == 1) {
            currentEval = evals[0]
            rootEval = currentEval
            // make sure OR (,) has precedence:
            if (((rootEval as? CombiningEvaluator.Or) != nil) && combinator != ",") {
                currentEval = (currentEval as! CombiningEvaluator.Or).rightMostEvaluator()
                replaceRightMost = true
            }
        } else {
            currentEval = CombiningEvaluator.And(evals)
            rootEval = currentEval
        }
        evals.removeAll()

        // for most combinators: change the current eval into an AND of the current eval and the new eval
        if (combinator == ">") {currentEval = CombiningEvaluator.And(newEval, StructuralEvaluator.ImmediateParent(currentEval!))} else if (combinator == " ") {currentEval = CombiningEvaluator.And(newEval, StructuralEvaluator.Parent(currentEval!))} else if (combinator == "+") {currentEval = CombiningEvaluator.And(newEval, StructuralEvaluator.ImmediatePreviousSibling(currentEval!))} else if (combinator == "~") {currentEval = CombiningEvaluator.And(newEval, StructuralEvaluator.PreviousSibling(currentEval!))} else if (combinator == ",") { // group or.
            let or: CombiningEvaluator.Or
            if ((currentEval as? CombiningEvaluator.Or) != nil) {
                or = currentEval as! CombiningEvaluator.Or
                or.add(newEval)
            } else {
                or = CombiningEvaluator.Or()
                or.add(currentEval!)
                or.add(newEval)
            }
            currentEval = or
        } else {
            throw Exception.Error(type: ExceptionType.SelectorParseException, Message: "Unknown combinator: \(String(combinator))")
        }

        if (replaceRightMost) {
            (rootEval as! CombiningEvaluator.Or).replaceRightMostEvaluator(currentEval!)
        } else {
            rootEval = currentEval
        }
        evals.append(rootEval!)
    }

    private func consumeSubQuery() -> String {
        return tq.consumeCssSubQuery()
    }

    private func findElements() throws {
        if (tq.matchChompCssIdentifierPrefix(0x23)) {
            try byId()
        } else if (tq.matchChompCssIdentifierPrefix(0x2E)) {
            try byClass()} else if (tq.matchesWord() || tq.matches("*|")) {try byTag()} else if (tq.matches("[")) {try byAttribute()} else if (tq.matchChomp("*")) { allElements()} else if (tq.matchChomp(":lt(")) {try indexLessThan()} else if (tq.matchChomp(":gt(")) {try indexGreaterThan()} else if (tq.matchChomp(":eq(")) {try indexEquals()} else if (tq.matches(":has(")) {try has()} else if (tq.matches(":containsData(")) {try containsData()} else if (tq.matches(":contains(")) {try contains(false)} else if (tq.matches(":containsOwn(")) {try contains(true)} else if (tq.matches(":matches(")) {try matches(false)} else if (tq.matches(":matchesOwn(")) {try matches(true)} else if (tq.matches(":not(")) {try not()} else if (tq.matchChomp(":nth-child(")) {try cssNthChild(false, false)} else if (tq.matchChomp(":nth-last-child(")) {try cssNthChild(true, false)} else if (tq.matchChomp(":nth-of-type(")) {try cssNthChild(false, true)} else if (tq.matchChomp(":nth-last-of-type(")) {try cssNthChild(true, true)} else if (tq.matchChomp(":first-child")) {evals.append(Evaluator.IsFirstChild())} else if (tq.matchChomp(":last-child")) {evals.append(Evaluator.IsLastChild())} else if (tq.matchChomp(":first-of-type")) {evals.append(Evaluator.IsFirstOfType())} else if (tq.matchChomp(":last-of-type")) {evals.append(Evaluator.IsLastOfType())} else if (tq.matchChomp(":only-child")) {evals.append(Evaluator.IsOnlyChild())} else if (tq.matchChomp(":only-of-type")) {evals.append(Evaluator.IsOnlyOfType())} else if (tq.matchChomp(":empty")) {evals.append(Evaluator.IsEmpty())} else if (tq.matchChomp(":root")) {evals.append(Evaluator.IsRoot())} else // unhandled
        {
            throw Exception.Error(type: ExceptionType.SelectorParseException, Message: "Could not parse query \(query): unexpected token at \(tq.remainder())")
        }
    }

    private func byId() throws {
        let id: String = tq.consumeCssIdentifier()
        try Validate.notEmpty(string: id)
        evals.append(Evaluator.Id(id))
    }

    private func byClass() throws {
        let className: String = tq.consumeCssIdentifier()
        try Validate.notEmpty(string: className)
        // Whitespace decoded from an escape is identifier content, not query padding.
        evals.append(Evaluator.Class(className))
    }

    private func byTag() throws {
        var tagName = tq.consumeElementSelector()

        try Validate.notEmpty(string: tagName)

        // namespaces: wildcard match equals(tagName) or ending in ":"+tagName
        if (tagName.startsWith("*|")) {
            let localName = String(tagName.dropFirst(2))
            try Validate.notEmpty(string: localName)
            // Keep these alternatives grouped: a top-level Or represents a
            // comma-separated list when a later combinator is attached.
            evals.append(
				CombiningEvaluator.And(CombiningEvaluator.Or(
					Evaluator.Tag(localName),
					Evaluator.TagEndsWith(":" + localName))))
        } else {
            // namespaces: if element name is "abc:def", selector must be "abc|def", so flip:
            if (tagName.contains("|")) {
                tagName = tagName.replacingOccurrences(of: "|", with: ":")
            }

            evals.append(Evaluator.Tag(tagName.trim()))
        }
    }

    private func byAttribute() throws {
        let cq: TokenQueue = TokenQueue(tq.chompBalanced("[", "]")) // content queue
        let key: String = cq.consumeToAnySlice(QueryParser.AttributeEvals) // eq, not, start, end, contain, match, (no val)
        try Validate.notEmpty(string: key)
        cq.consumeWhitespace()

        if (cq.isEmpty()) {
            if (key.startsWith("^")) {
                evals.append(try Evaluator.AttributeStarting(key.substring(1).utf8Array))
            } else {
                evals.append(Evaluator.Attribute(key))
            }
        } else {
            if (cq.matchChomp("=")) {
                evals.append(try Evaluator.AttributeWithValue(key, cq.remainder()))
            } else if (cq.matchChomp("!=")) {
                evals.append(try Evaluator.AttributeWithValueNot(key, cq.remainder()))
            } else if (cq.matchChomp("^=")) {
                evals.append(try Evaluator.AttributeWithValueStarting(key, cq.remainder()))
            } else if (cq.matchChomp("$=")) {
                evals.append(try Evaluator.AttributeWithValueEnding(key, cq.remainder()))
            } else if (cq.matchChomp("*=")) {
                evals.append(try Evaluator.AttributeWithValueContaining(key, cq.remainder()))
            } else if (cq.matchChomp("~=")) {
                evals.append( Evaluator.AttributeWithValueMatching(key, Pattern.compile(cq.remainder())))
            } else {
                throw Exception.Error(type: ExceptionType.SelectorParseException, Message: "Could not parse attribute query '\(query)': unexpected token at '\(cq.remainder())'")
            }
        }
    }

    private func allElements() {
        evals.append(Evaluator.AllElements())
    }

    // pseudo selectors :lt, :gt, :eq
    private func indexLessThan() throws {
        evals.append(Evaluator.IndexLessThan(try consumeIndex()))
    }

    private func indexGreaterThan() throws {
        evals.append(Evaluator.IndexGreaterThan(try consumeIndex()))
    }

    private func indexEquals() throws {
        evals.append(Evaluator.IndexEquals(try consumeIndex()))
    }

    // Parse the entire supported An+B spelling. CSS permits whitespace around
    // the B separator, not inside the A coefficient or an integer's sign.
    private static let NTH_AB = Pattern.compile(#"\A([+-]?[0-9]*)n(?:[\t\n\f\r ]*([+-])[\t\n\f\r ]*([0-9]+))?\z"#)
    private static let NTH_B = Pattern.compile(#"\A[+-]?[0-9]+\z"#)

    private func cssNthChild(_ backwards: Bool, _ ofType: Bool) throws {
        let argS = try consumeNumericArgument().lowercased()
        let a: Int
        let b: Int
        if argS == "odd" {
            a = 2
            b = 1
        } else if argS == "even" {
            a = 2
            b = 0
        } else {
            let mAB = QueryParser.NTH_AB.matcher(in: argS)
            if mAB.find(), let coefficient = mAB.group(1) {
                switch coefficient {
                case "", "+": a = 1
                case "-": a = -1
                default: a = try QueryParser.nthInteger(coefficient)
                }
                if let sign = mAB.group(2), let digits = mAB.group(3) {
                    // Convert the signed spelling together so Int.min is valid.
                    b = try QueryParser.nthInteger(sign + digits)
                } else {
                    b = 0
                }
            } else if QueryParser.NTH_B.matcher(in: argS).find() {
                a = 0
                b = try QueryParser.nthInteger(argS)
            } else {
                throw Exception.Error(type: .SelectorParseException,
                                      Message: "Could not parse nth-index '\(argS)': unexpected format")
            }
        }
        if (ofType) {
            if (backwards) {
                evals.append(Evaluator.IsNthLastOfType(a, b))
            } else {
                evals.append(Evaluator.IsNthOfType(a, b))
            }
        } else {
            if (backwards) {
                evals.append(Evaluator.IsNthLastChild(a, b))
            } else {
                evals.append(Evaluator.IsNthChild(a, b))
            }
        }
    }

    private static func nthInteger(_ spelling: String) throws -> Int {
        guard let value = Int(spelling) else {
            throw Exception.Error(type: .SelectorParseException,
                                  Message: "Nth-index integer is outside the supported Int range")
        }
        return value
    }

    private func consumeNumericArgument() throws -> String {
        // Do not call the general substring search at end-of-input: it assumes
        // there is at least one remaining character for its search range.
        guard !tq.isEmpty() else {
            throw Exception.Error(type: .SelectorParseException, Message: "Unclosed numeric selector")
        }
        let argument = TokenQueue.trimCssQuery(tq.consumeTo(")"))
        guard tq.matchChomp(")") else {
            throw Exception.Error(type: .SelectorParseException, Message: "Unclosed numeric selector")
        }
        return argument
    }

    private func consumeIndex() throws -> Int {
        let indexS = try consumeNumericArgument()
        guard !indexS.isEmpty,
              indexS.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }),
              let index = Int(indexS) else {
            throw Exception.Error(type: .SelectorParseException,
                                  Message: "Index must be an unsigned decimal within the supported Int range")
        }
        return index
    }

    // pseudo selector :has(el)
    private func has() throws {
        try tq.consume(":has")
        let subQuery: String = tq.chompBalanced("(", ")")
        try Validate.notEmpty(string: subQuery, msg: ":has(el) subselect must not be empty")
        let branches = try TokenQueue(subQuery).consumeCssSelectorList().map { branch -> Evaluator in
            let query = TokenQueue.trimCssQuery(branch)
            try Validate.notEmpty(string: query, msg: ":has selector-list branch must not be empty")
            let leadingByte = query.utf8.first
            let followsSiblings = leadingByte == 0x2B || leadingByte == 0x7E // + or ~
            return StructuralEvaluator.Has(try QueryParser.parse(query), followingSiblings: followsSiblings)
        }
        evals.append(branches.count == 1 ? branches[0] : CombiningEvaluator.Or(branches))
    }

    // pseudo selector :contains(text), containsOwn(text)
    private func contains(_ own: Bool)throws {
        try tq.consume(own ? ":containsOwn" : ":contains")
        let searchText: String = TokenQueue.unescape(tq.chompBalanced("(", ")"))
        try Validate.notEmpty(string: searchText, msg: ":contains(text) query must not be empty")
        if (own) {
            evals.append(Evaluator.ContainsOwnText(searchText))
        } else {
            evals.append(Evaluator.ContainsText(searchText))
        }
    }

    // pseudo selector :containsData(data)
    private func containsData() throws {
        try tq.consume(":containsData")
        let searchText: String = TokenQueue.unescape(tq.chompBalanced("(", ")"))
        try Validate.notEmpty(string: searchText, msg: ":containsData(text) query must not be empty")
        evals.append(Evaluator.ContainsData(searchText))
    }

    // :matches(regex), matchesOwn(regex)
    private func matches(_ own: Bool)throws {
        try tq.consume(own ? ":matchesOwn" : ":matches")
        let regex: String = tq.chompBalanced("(", ")") // don't unescape, as regex bits will be escaped
        try Validate.notEmpty(string: regex, msg: ":matches(regex) query must not be empty")

        if (own) {
            evals.append(Evaluator.MatchesOwn(Pattern.compile(regex)))
        } else {
            evals.append(Evaluator.Matches(Pattern.compile(regex)))
        }
    }

    // :not(selector)
    private func not() throws {
        try tq.consume(":not")
        let subQuery: String = tq.chompBalanced("(", ")")
        try Validate.notEmpty(string: subQuery, msg: ":not(selector) subselect must not be empty")

        evals.append(StructuralEvaluator.Not(try QueryParser.parse(subQuery)))
    }

}
