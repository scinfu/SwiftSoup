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
        #if PROFILE
        let _p = Profiler.start("Collector.collect")
        defer { Profiler.end("Collector.collect", _p) }
        #endif
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
        if let hasEval = eval as? StructuralEvaluator.Has {
            return try collectHas(hasEval, root: root)
        }
        let elements: Elements = Elements()
        if let andEval = eval as? CombiningEvaluator.And,
           let seeded = try seedCandidates(for: andEval, root: root) {
            let (seedElements, skipIndex) = seeded
            if seedElements.isEmpty {
                return seedElements
            }
            elements.reserveCapacity(seedElements.size())
            if let skipIndex {
                let evaluators = andEval.evaluators
                for el in seedElements.array() {
                    var matchesAll = true
                    for (idx, evaluator) in evaluators.enumerated() {
                        if idx == skipIndex { continue }
                        #if PROFILE
                        let _pMatch = Profiler.start("Collector.matches.seeded")
                        #endif
                        let matched = try evaluator.matches(root, el)
                        #if PROFILE
                        Profiler.end("Collector.matches.seeded", _pMatch)
                        #endif
                        if !matched {
                            matchesAll = false
                            break
                        }
                    }
                    if matchesAll {
                        elements.add(el)
                    }
                }
            } else {
                return seedElements
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
            #if PROFILE
            let _pMatch = Profiler.start("Collector.matches")
            #endif
            let matched = try eval.matches(root, el)
            #if PROFILE
            Profiler.end("Collector.matches", _pMatch)
            #endif
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

    private static func collectHas(_ hasEval: StructuralEvaluator.Has, root: Element) throws -> Elements {
        let matches = try collect(hasEval.evaluator, root)
        if matches.isEmpty {
            return Elements()
        }
        var hasDescendant = Set<ObjectIdentifier>()
        hasDescendant.reserveCapacity(matches.size() * 2)
        for el in matches.array() {
            var parent = el.parent()
            while let current = parent {
                hasDescendant.insert(ObjectIdentifier(current))
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
        if let tagEval = eval as? Evaluator.Tag {
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
        if eval is StructuralEvaluator.Root {
            return Elements([root])
        }
        return nil
    }

    private static func seedCandidates(for eval: CombiningEvaluator.And, root: Element) throws -> (Elements, Int?)? {
        let evaluators = eval.evaluators

        @inline(__always)
        func shouldSkipIndex(_ index: Int) -> Int? {
            return evaluators.count > 1 ? index : nil
        }

        for (idx, evaluator) in evaluators.enumerated() {
            if let idEval = evaluator as? Evaluator.Id {
                return (root.getElementsById(idEval.idBytes), shouldSkipIndex(idx))
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
                        shouldSkipIndex(idx))
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
                        shouldSkipIndex(idx))
            }
        }

        for (idx, evaluator) in evaluators.enumerated() {
            if let tagEval = evaluator as? Evaluator.Tag {
                return (try root.getElementsByTagNormalized(tagEval.tagNameNormal),
                        shouldSkipIndex(idx))
            }
        }

        for (idx, evaluator) in evaluators.enumerated() {
            if let attrEval = evaluator as? Evaluator.Attribute {
                return (root.getElementsByAttributeNormalized(attrEval.keyBytes),
                        shouldSkipIndex(idx))
            }
        }

        for (idx, evaluator) in evaluators.enumerated() {
            if let attrMatchingEval = evaluator as? Evaluator.AttributeWithValueMatching {
                return (root.getElementsByAttributeNormalized(attrMatchingEval.key.utf8Array),
                        shouldSkipIndex(idx))
            }
        }

        for (idx, evaluator) in evaluators.enumerated() {
            if evaluator is Evaluator.AttributeWithValueNot {
                continue
            }
            if let attrKeyPairEval = evaluator as? Evaluator.AttributeKeyPair {
                return (root.getElementsByAttributeNormalized(attrKeyPairEval.keyBytes),
                        shouldSkipIndex(idx))
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
