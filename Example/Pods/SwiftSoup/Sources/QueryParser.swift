//
//  QueryParser.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 23/10/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import Foundation

/**
 * Parses a CSS selector into an Evaluator tree.
 */
public class QueryParser {
    private static let combinators: [String]  = [",", ">", "+", "~", " "]
    private static let AttributeEvals: [String]  = ["=", "!=", "^=", "$=", "*=", "~="]

    private var tq: TokenQueue
    private var query: String
    private var evals: Array<Evaluator>  = Array<Evaluator>()

    /**
     * Create a new QueryParser.
     * @param query CSS query
     */
    private init(_ query: String) {
        self.query = query
        self.tq = TokenQueue(query)
    }

    /**
     * Parse a CSS query into an Evaluator.
     * @param query CSS query
     * @return Evaluator
     */
    public static func parse(_ query: String)throws->Evaluator {
        let p = QueryParser(query)
        return try p.parse()
    }

    /**
     * Parse the query
     * @return Evaluator
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
        let sq: StringBuilder = StringBuilder()
        while (!tq.isEmpty()) {
            if (tq.matches("(")) {
                sq.append("(").append(tq.chompBalanced("(", ")")).append(")")
            } else if (tq.matches("[")) {
                sq.append("[").append(tq.chompBalanced("[", "]")).append("]")
            } else if (tq.matchesAny(QueryParser.combinators)) {
                break
            } else {
                sq.append(tq.consume())
            }
        }
        return sq.toString()
    }

    private func findElements()throws {
        if (tq.matchChomp("#")) {
            try byId()
        } else if (tq.matchChomp(".")) {
            try byClass()} else if (tq.matchesWord() || tq.matches("*|")) {try byTag()} else if (tq.matches("[")) {try byAttribute()} else if (tq.matchChomp("*")) { allElements()} else if (tq.matchChomp(":lt(")) {try indexLessThan()} else if (tq.matchChomp(":gt(")) {try indexGreaterThan()} else if (tq.matchChomp(":eq(")) {try indexEquals()} else if (tq.matches(":has(")) {try has()} else if (tq.matches(":contains(")) {try contains(false)} else if (tq.matches(":containsOwn(")) {try contains(true)} else if (tq.matches(":matches(")) {try matches(false)} else if (tq.matches(":matchesOwn(")) {try matches(true)} else if (tq.matches(":not(")) {try not()} else if (tq.matchChomp(":nth-child(")) {try cssNthChild(false, false)} else if (tq.matchChomp(":nth-last-child(")) {try cssNthChild(true, false)} else if (tq.matchChomp(":nth-of-type(")) {try cssNthChild(false, true)} else if (tq.matchChomp(":nth-last-of-type(")) {try cssNthChild(true, true)} else if (tq.matchChomp(":first-child")) {evals.append(Evaluator.IsFirstChild())} else if (tq.matchChomp(":last-child")) {evals.append(Evaluator.IsLastChild())} else if (tq.matchChomp(":first-of-type")) {evals.append(Evaluator.IsFirstOfType())} else if (tq.matchChomp(":last-of-type")) {evals.append(Evaluator.IsLastOfType())} else if (tq.matchChomp(":only-child")) {evals.append(Evaluator.IsOnlyChild())} else if (tq.matchChomp(":only-of-type")) {evals.append(Evaluator.IsOnlyOfType())} else if (tq.matchChomp(":empty")) {evals.append(Evaluator.IsEmpty())} else if (tq.matchChomp(":root")) {evals.append(Evaluator.IsRoot())} else // unhandled
        {
            throw Exception.Error(type: ExceptionType.SelectorParseException, Message:"Could not parse query \(query): unexpected token at \(tq.remainder())")
        }
    }

    private func byId()throws {
        let id: String = tq.consumeCssIdentifier()
        try Validate.notEmpty(string: id)
        evals.append(Evaluator.Id(id))
    }

    private func byClass()throws {
        let className: String = tq.consumeCssIdentifier()
        try Validate.notEmpty(string: className)
        evals.append(Evaluator.Class(className.trim()))
    }

    private func byTag()throws {
        var tagName = tq.consumeElementSelector()

        try Validate.notEmpty(string: tagName)

        // namespaces: wildcard match equals(tagName) or ending in ":"+tagName
        if (tagName.startsWith("*|")) {
            evals.append(
				CombiningEvaluator.Or(
					Evaluator.Tag(tagName.trim().lowercased()),
					Evaluator.TagEndsWith(tagName.replacingOccurrences(of: "*|", with: ":").trim().lowercased())))
        } else {
            // namespaces: if element name is "abc:def", selector must be "abc|def", so flip:
            if (tagName.contains("|")) {
                tagName = tagName.replacingOccurrences(of: "|", with: ":")
            }

            evals.append(Evaluator.Tag(tagName.trim()))
        }
    }

    private func byAttribute()throws {
        let cq: TokenQueue = TokenQueue(tq.chompBalanced("[", "]")) // content queue
        let key: String = cq.consumeToAny(QueryParser.AttributeEvals) // eq, not, start, end, contain, match, (no val)
        try Validate.notEmpty(string: key)
        cq.consumeWhitespace()

        if (cq.isEmpty()) {
            if (key.startsWith("^")) {
                evals.append(try Evaluator.AttributeStarting(key.substring(1)))
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
                throw Exception.Error(type: ExceptionType.SelectorParseException, Message:"Could not parse attribute query '\(query)': unexpected token at '\(cq.remainder())'")
            }
        }
    }

    private func allElements() {
        evals.append(Evaluator.AllElements())
    }

    // pseudo selectors :lt, :gt, :eq
    private func indexLessThan()throws {
        evals.append(Evaluator.IndexLessThan(try consumeIndex()))
    }

    private func indexGreaterThan()throws {
        evals.append(Evaluator.IndexGreaterThan(try consumeIndex()))
    }

    private func indexEquals()throws {
        evals.append(Evaluator.IndexEquals(try consumeIndex()))
    }

    //pseudo selectors :first-child, :last-child, :nth-child, ...
    private static let NTH_AB: Pattern = Pattern.compile("((\\+|-)?(\\d+)?)n(\\s*(\\+|-)?\\s*\\d+)?", Pattern.CASE_INSENSITIVE)
    private static let NTH_B: Pattern = Pattern.compile("(\\+|-)?(\\d+)")

    private func cssNthChild(_ backwards: Bool, _ ofType: Bool)throws {
        let argS: String = tq.chompTo(")").trim().lowercased()
        let mAB: Matcher = QueryParser.NTH_AB.matcher(in: argS)
        let mB: Matcher = QueryParser.NTH_B.matcher(in: argS)
        var a: Int
        var b: Int
        if ("odd"==argS) {
            a = 2
            b = 1
        } else if ("even"==argS) {
            a = 2
            b = 0
        } else if (mAB.matches.count > 0) {
			mAB.find()
            a = mAB.group(3) != nil ? Int(mAB.group(1)!.replaceFirst(of: "^\\+", with: ""))! : 1
            b = mAB.group(4) != nil ? Int(mAB.group(4)!.replaceFirst(of: "^\\+", with: ""))! : 0
        } else if (mB.matches.count > 0) {
            a = 0
			mB.find()
            b = Int(mB.group()!.replaceFirst(of: "^\\+", with: ""))!
        } else {
            throw Exception.Error(type: ExceptionType.SelectorParseException, Message:"Could not parse nth-index '\(argS)': unexpected format")
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

    private func consumeIndex()throws->Int {
        let indexS: String = tq.chompTo(")").trim()
        try Validate.isTrue(val: StringUtil.isNumeric(indexS), msg: "Index must be numeric")
        return Int(indexS)!
    }

    // pseudo selector :has(el)
    private func has()throws {
        try tq.consume(":has")
        let subQuery: String = tq.chompBalanced("(", ")")
        try Validate.notEmpty(string: subQuery, msg: ":has(el) subselect must not be empty")
        evals.append(StructuralEvaluator.Has(try QueryParser.parse(subQuery)))
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
    private func not()throws {
        try tq.consume(":not")
        let subQuery: String = tq.chompBalanced("(", ")")
        try Validate.notEmpty(string: subQuery, msg: ":not(selector) subselect must not be empty")

        evals.append(StructuralEvaluator.Not(try QueryParser.parse(subQuery)))
    }

}
