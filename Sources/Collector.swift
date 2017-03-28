//
//  Collector.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 22/10/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
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
     @param eval Evaluator to test elements against
     @param root root of tree to descend
     @return list of matches; empty if none
     */
    open static func collect (_ eval: Evaluator, _ root: Element)throws->Elements {
        let elements: Elements = Elements()
        try NodeTraversor(Accumulator(root, elements, eval)).traverse(root)
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

    open func head(_ node: Node, _ depth: Int) {
        if let el = node as? Element {
            do {
                if (try eval.matches(root, el)) {
                    elements.add(el)
                }
            } catch {}

        }
    }

    open func tail(_ node: Node, _ depth: Int) {
        // void
    }
}
