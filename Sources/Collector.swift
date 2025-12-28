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
            var stack: [Element] = []
            stack.reserveCapacity(root.childNodes.count + 1)
            stack.append(root)
            while let el = stack.popLast() {
                elements.add(el)
                let children = el.childNodes
                if !children.isEmpty {
                    for child in children.reversed() {
                        if let childEl = child as? Element {
                            stack.append(childEl)
                        }
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
            if seeded.isEmpty {
                return seeded
            }
            for el in seeded.array() {
                if try eval.matches(root, el) {
                    elements.add(el)
                }
            }
            return elements
        }
        if let fast = try simpleEvaluatorFastPath(eval, root: root) {
            return fast
        }
        // Manual DFS to reduce NodeTraversor/visitor overhead in hot selector paths.
        var stack: [Element] = []
        stack.reserveCapacity(root.childNodes.count + 1)
        stack.append(root)
        while let el = stack.popLast() {
            if try eval.matches(root, el) {
                elements.add(el)
            }
            let children = el.childNodes
            if !children.isEmpty {
                for child in children.reversed() {
                    if let childEl = child as? Element {
                        stack.append(childEl)
                    }
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
        var stack: [Element] = []
        stack.reserveCapacity(root.childNodes.count + 1)
        stack.append(root)
        while let el = stack.popLast() {
            if hasDescendant.contains(ObjectIdentifier(el)) {
                elements.add(el)
            }
            let children = el.childNodes
            if !children.isEmpty {
                for child in children.reversed() {
                    if let childEl = child as? Element {
                        stack.append(childEl)
                    }
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
            let normalizedKey = attrValueEval.keyBytes.lowercased().trim()
            let absPrefix = "abs:".utf8Array
            if !normalizedKey.starts(with: absPrefix),
               (Element.isHotAttributeKey(normalizedKey) ||
                (Element.dynamicAttributeValueIndexMaxKeys > 0)) {
                return try root.getElementsByAttributeValue(attrValueEval.key, attrValueEval.value)
            }
        }
        if eval is StructuralEvaluator.Root {
            return Elements([root])
        }
        return nil
    }

    private static func seedCandidates(for eval: CombiningEvaluator.And, root: Element) throws -> Elements? {
        var idEval: Evaluator.Id?
        var attrValueEval: Evaluator.AttributeWithValue?
        var classEval: Evaluator.Class?
        var tagEval: Evaluator.Tag?
        var attrEval: Evaluator.Attribute?
        var attrKeyPairEval: Evaluator.AttributeKeyPair?
        var attrMatchingEval: Evaluator.AttributeWithValueMatching?

        for evaluator in eval.evaluators {
            if let idCandidate = evaluator as? Evaluator.Id {
                idEval = idCandidate
                break
            }
        }
        if let idEval {
            return root.getElementsById(idEval.idBytes)
        }

        for evaluator in eval.evaluators {
            if let attrValueCandidate = evaluator as? Evaluator.AttributeWithValue {
                attrValueEval = attrValueCandidate
                break
            }
        }
        if let attrValueEval,
           !(attrValueEval.keyBytes.lowercased().starts(with: "abs:".utf8Array)),
           (Element.isHotAttributeKey(attrValueEval.keyBytes) ||
            (Element.dynamicAttributeValueIndexMaxKeys > 0)) {
            return try root.getElementsByAttributeValue(attrValueEval.key, attrValueEval.value)
        }

        for evaluator in eval.evaluators {
            if let classCandidate = evaluator as? Evaluator.Class {
                classEval = classCandidate
                break
            }
        }
        if let classEval {
            let classBytes = classEval.classNameBytes
            let normalizedClass: [UInt8]
            if !Attributes.containsAsciiUppercase(classBytes) {
                normalizedClass = classBytes
            } else {
                normalizedClass = classBytes.lowercased()
            }
            return root.getElementsByClassNormalizedBytes(normalizedClass)
        }

        for evaluator in eval.evaluators {
            if let tagCandidate = evaluator as? Evaluator.Tag {
                tagEval = tagCandidate
                break
            }
        }
        if let tagEval {
            return try root.getElementsByTagNormalized(tagEval.tagNameNormal)
        }

        for evaluator in eval.evaluators {
            if let attrCandidate = evaluator as? Evaluator.Attribute {
                attrEval = attrCandidate
                break
            }
        }
        if let attrEval {
            return root.getElementsByAttributeNormalized(attrEval.keyBytes)
        }

        for evaluator in eval.evaluators {
            if let attrMatchingCandidate = evaluator as? Evaluator.AttributeWithValueMatching {
                attrMatchingEval = attrMatchingCandidate
                break
            }
        }
        if let attrMatchingEval {
            return root.getElementsByAttributeNormalized(attrMatchingEval.key.utf8Array)
        }

        for evaluator in eval.evaluators {
            if evaluator is Evaluator.AttributeWithValueNot {
                continue
            }
            if let keyPairCandidate = evaluator as? Evaluator.AttributeKeyPair {
                attrKeyPairEval = keyPairCandidate
                break
            }
        }
        if let attrKeyPairEval {
            return root.getElementsByAttributeNormalized(attrKeyPairEval.keyBytes)
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
