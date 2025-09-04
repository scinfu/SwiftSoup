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
        var node: Node? = root
        var depth: Int = 0

        while (node != nil) {
            try visitor.head(node!, depth)
            if node!.hasChildNodes() {
                node = node!.childNode(0)
                depth += 1
            } else {
                while !node!.hasNextSibling() && depth > 0 {
                    let parent = node!.getParentNode()
                    try visitor.tail(node!, depth)
                    node = parent
                    depth -= 1
                }
                let nextSib = node!.nextSibling()
                try visitor.tail(node!, depth)
                if node === root {
                    break
                }
                node = nextSib
            }
        }
    }

    @available(iOS 13.0.0, *)
    open func traverse(_ root: Node?) async throws {
        var node: Node? = root
        var depth: Int = 0

        while node != nil && !Task.isCancelled {
            try visitor.head(node!, depth)
            if (node!.childNodeSize() > 0) {
                node = node!.childNode(0)
                depth+=1
            } else {
                while (node!.nextSibling() == nil && depth > 0 && !Task.isCancelled) {
                    let parent = node!.getParentNode()
                    try visitor.tail(node!, depth)
                    node = parent
                    depth-=1
                }
                let nextSib = node!.nextSibling()
                try visitor.tail(node!, depth)
                if (node === root) {
                    break
                }
                node = nextSib
            }
        }
    }

}
