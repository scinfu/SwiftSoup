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
        let elements: Elements = Elements()
        if ProcessInfo.processInfo.environment["SWIFTSOUP_DISABLE_COLLECTOR_FASTPATH"] == "1" {
            try NodeTraversor(Accumulator(root, elements, eval)).traverse(root)
            return elements
        }
        // Manual DFS to reduce NodeTraversor/visitor overhead in hot selector paths.
        var stack: [Node] = []
        stack.reserveCapacity(root.childNodes.count + 1)
        stack.append(root)
        while let node = stack.popLast() {
            if let el = node as? Element {
                if try eval.matches(root, el) {
                    elements.add(el)
                }
            }
            let children = node.childNodes
            if !children.isEmpty {
                for child in children.reversed() {
                    stack.append(child)
                }
            }
        }
        return elements
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
