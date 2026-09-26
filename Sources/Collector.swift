//
//  Collector.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 22/10/16.
//

import Foundation

/**
 * Collects a list of elements that match the supplied criteria.
 *
 */
open class Collector {

    private init() {
    }


    /**
     Build a list of elements, by visiting root and every descendant of root, and testing it against the evaluator.
     - parameter eval: Evaluator to test elements against
     - parameter root: root of tree to descend
     - returns: list of matches; empty if none
     */
    public static func collect (_ eval: Evaluator, _ root: Element) throws -> Elements {
        if eval is Evaluator.AllElements {
            let elements = Elements()
            var stack: ContiguousArray<Element> = []
            stack.reserveCapacity(root.childNodes.count + 1)
            stack.append(root)
            while let el = stack.popLast() {
                elements.add(el)
                let children = el.childNodes
                var i = children.count
                while i > 0 {
                    i &-= 1
                    if let childEl = children[i] as? Element {
                        stack.append(childEl)
                    }
                }
            }
            return elements
        }
        if let hasEval = eval as? StructuralEvaluator.Has,
           type(of: hasEval) == StructuralEvaluator.Has.self,
           !hasEval.searchesFollowingSiblings,
           isRootIndependent(hasEval.evaluator) {
            return try collectHas(hasEval, root: root)
        }
        let elements: Elements = Elements()
        if let andEval = eval as? CombiningEvaluator.And,
           let seeded = try seedCandidates(for: andEval, root: root) {
            let (seedElements, satisfiedIndex) = seeded
            let evaluators = andEval.evaluators
            if seedElements.isEmpty || (evaluators.count == 1 && satisfiedIndex == 0) {
                return seedElements
            }
            elements.reserveCapacity(seedElements.size())
            for el in seedElements.array() {
                var matchesAll = true
                for (idx, evaluator) in evaluators.enumerated() {
                    if idx == satisfiedIndex { continue }
                    // Preserve And.matches catch-and-continue behavior.
                    if (try? evaluator.matches(root, el)) == false {
                        matchesAll = false
                        break
                    }
                }
                if matchesAll {
                    elements.add(el)
                }
            }
            return elements
        }
        if let fast = try simpleEvaluatorFastPath(eval, root: root) {
            return fast
        }
        // Manual DFS to reduce NodeTraversor/visitor overhead in hot selector paths.
        var stack: ContiguousArray<Element> = []
        stack.reserveCapacity(root.childNodes.count + 1)
        stack.append(root)
        while let el = stack.popLast() {
            let matched = try eval.matches(root, el)
            if matched {
                elements.add(el)
            }
            let children = el.childNodes
            var i = children.count
            while i > 0 {
                i &-= 1
                if let childEl = children[i] as? Element {
                    stack.append(childEl)
                }
            }
        }
        return elements
    }

    // Collect-once/mark-ancestors is valid only when the inner predicate does
    // not depend on the candidate :has root. Relative or structural selectors
    // must use Has.matches for each candidate instead.
    private static func isRootIndependent(_ eval: Evaluator) -> Bool {
        let type = type(of: eval)
        if type == Evaluator.Tag.self || type == Evaluator.Id.self ||
            type == Evaluator.Class.self || type == Evaluator.Attribute.self {
            return true
        }
        if let combined = eval as? CombiningEvaluator,
           combined is CombiningEvaluator.And || combined is CombiningEvaluator.Or {
            return combined.evaluators.allSatisfy(isRootIndependent)
        }
        return false
    }

    private static func collectHas(_ hasEval: StructuralEvaluator.Has, root: Element) throws -> Elements {
        let matches = try collect(hasEval.evaluator, root)
        if matches.isEmpty {
            return Elements()
        }
        var hasDescendant = Set<ObjectIdentifier>()
        hasDescendant.reserveCapacity(matches.size() * 2)
        for el in matches.array() where el !== root {
            var parent = el.parent()
            while let current = parent {
                // An earlier match already marked every ancestor above this one.
                // Stop here so overlapping matches visit each ancestor only once.
                guard hasDescendant.insert(ObjectIdentifier(current)).inserted else { break }
                if current === root { break }
                parent = current.parent()
            }
        }
        if hasDescendant.isEmpty {
            return Elements()
        }
        let elements = Elements()
        elements.reserveCapacity(hasDescendant.count)
        var stack: ContiguousArray<Element> = []
        stack.reserveCapacity(root.childNodes.count + 1)
        stack.append(root)
        while let el = stack.popLast() {
            if hasDescendant.contains(ObjectIdentifier(el)) {
                elements.add(el)
            }
            let children = el.childNodes
            var i = children.count
            while i > 0 {
                i &-= 1
                if let childEl = children[i] as? Element {
                    stack.append(childEl)
                }
            }
        }
        return elements
    }

    private static func simpleEvaluatorFastPath(_ eval: Evaluator, root: Element) throws -> Elements? {
        if let idEval = eval as? Evaluator.Id {
            return root.getElementsById(idEval.idBytes)
        }
        if let tagEval = eval as? Evaluator.Tag, type(of: tagEval) == Evaluator.Tag.self {
            return try root.getElementsByTagNormalized(tagEval.tagNameNormal)
        }
        if let classEval = eval as? Evaluator.Class {
            let classBytes = classEval.classNameBytes
            let normalizedClass: [UInt8]
            if !Attributes.containsAsciiUppercase(classBytes) {
                normalizedClass = classBytes
            } else {
                normalizedClass = classBytes.lowercased()
            }
            return root.getElementsByClassNormalizedBytes(normalizedClass)
        }
        if let attrEval = eval as? Evaluator.Attribute {
            return root.getElementsByAttributeNormalized(attrEval.keyBytes)
        }
        if let attrValueEval = eval as? Evaluator.AttributeWithValue {
            if attrValueEval.keyBytes.starts(with: UTF8Arrays.absPrefix) {
                return nil
            }
            return try root.getElementsByAttributeValueNormalized(
                attrValueEval.keyBytes,
                attrValueEval.valueBytes,
                attrValueEval.key,
                attrValueEval.value
            )
        }
        if type(of: eval) == StructuralEvaluator.Root.self {
            return Elements([root])
        }
        return nil
    }

    private static func seedCandidates(for eval: CombiningEvaluator.And, root: Element) throws -> (Elements, Int?)? {
        guard eval.supportsIndexedCandidateFiltering else { return nil }
        let evaluators = eval.evaluators

        // An index may discharge only a predicate it fully proves. Attribute
        // presence is merely a superset for value/regex predicates: nil means
        // every predicate must still be evaluated on the seeded candidates.

        for (idx, evaluator) in evaluators.enumerated() {
            if let idEval = evaluator as? Evaluator.Id {
                return (root.getElementsById(idEval.idBytes), idx)
            }
        }

        for (idx, evaluator) in evaluators.enumerated() {
            if let attrValueEval = evaluator as? Evaluator.AttributeWithValue {
                if attrValueEval.keyBytes.starts(with: UTF8Arrays.absPrefix) {
                    return nil
                }
                return (try root.getElementsByAttributeValueNormalized(
                            attrValueEval.keyBytes,
                            attrValueEval.valueBytes,
                            attrValueEval.key,
                            attrValueEval.value
                        ),
                        idx)
            }
        }

        for (idx, evaluator) in evaluators.enumerated() {
            if let classEval = evaluator as? Evaluator.Class {
                let classBytes = classEval.classNameBytes
                let normalizedClass: [UInt8]
                if !Attributes.containsAsciiUppercase(classBytes) {
                    normalizedClass = classBytes
                } else {
                    normalizedClass = classBytes.lowercased()
                }
                return (root.getElementsByClassNormalizedBytes(normalizedClass),
                        idx)
            }
        }

        for (idx, evaluator) in evaluators.enumerated() {
            if let tagEval = evaluator as? Evaluator.Tag, type(of: tagEval) == Evaluator.Tag.self {
                return (try root.getElementsByTagNormalized(tagEval.tagNameNormal),
                        idx)
            }
        }

        for (idx, evaluator) in evaluators.enumerated() {
            if let attrEval = evaluator as? Evaluator.Attribute {
                return (root.getElementsByAttributeNormalized(attrEval.keyBytes),
                        idx)
            }
        }

        for evaluator in evaluators {
            if let attrMatchingEval = evaluator as? Evaluator.AttributeWithValueMatching {
                let keyBytes = attrMatchingEval.key.utf8Array
                return (root.getElementsByAttributeNormalized(keyBytes), nil)
            }
        }

        for evaluator in evaluators {
            if evaluator is Evaluator.AttributeWithValueNot {
                continue
            }
            if (evaluator is Evaluator.AttributeWithValueStarting ||
                evaluator is Evaluator.AttributeWithValueEnding ||
                evaluator is Evaluator.AttributeWithValueContaining),
               let attrKeyPairEval = evaluator as? Evaluator.AttributeKeyPair {
                return (root.getElementsByAttributeNormalized(attrKeyPairEval.keyBytes), nil)
            }
        }

        return nil
    }

}

private final class Accumulator: NodeVisitor {
    private let root: Element
    private let elements: Elements
    private let eval: Evaluator

    init(_ root: Element, _ elements: Elements, _ eval: Evaluator) {
        self.root = root
        self.elements = elements
        self.eval = eval
    }

    @inlinable
    public func head(_ node: Node, _ depth: Int) {
        guard let el = node as? Element else {
            return
        }
        do {
            if try eval.matches(root, el) {
                elements.add(el)
            }
        } catch {}
    }

    public func tail(_ node: Node, _ depth: Int) {
        // void
    }
}
