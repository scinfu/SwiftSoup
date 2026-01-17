//
//  NodeTraversor.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 17/10/16.
//

import Foundation

open class NodeTraversor {
    private let visitor: NodeVisitor

    /**
     Create a new traversor.
     - parameter visitor: a class implementing the ``NodeVisitor`` interface, to be called when visiting each node.
     */
    public init(_ visitor: NodeVisitor) {
        self.visitor = visitor
    }

    /**
     Start a depth-first traverse of the root and all of its descendants.
     - parameter root: the root node point to traverse.
     */
    open func traverse(_ root: Node?) throws {
        root?.ensureLibxml2TreeIfNeeded()
        var node: Node? = root
        var depth: Int = 0

        while let current = node {
            try visitor.head(current, depth)
            if current.hasChildNodes() {
                node = current.childNode(0)
                depth += 1
                continue
            }
            var cursor = current
            while depth > 0 && !cursor.hasNextSibling() {
                let parent = cursor.getParentNode()
                try visitor.tail(cursor, depth)
                guard let parent else {
                    node = nil
                    break
                }
                cursor = parent
                depth -= 1
            }
            guard node != nil else { break }
            let nextSib = cursor.nextSibling()
            try visitor.tail(cursor, depth)
            if cursor === root {
                break
            }
            node = nextSib
        }
    }
}
