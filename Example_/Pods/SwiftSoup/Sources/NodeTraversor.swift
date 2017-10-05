//
//  NodeTraversor.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 17/10/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import Foundation

class NodeTraversor {
    private let visitor: NodeVisitor

    /**
     * Create a new traversor.
     * @param visitor a class implementing the {@link NodeVisitor} interface, to be called when visiting each node.
     */
    public init(_ visitor: NodeVisitor) {
        self.visitor = visitor
    }

    /**
     * Start a depth-first traverse of the root and all of its descendants.
     * @param root the root node point to traverse.
     */
    open func traverse(_ root: Node?)throws {
        var node: Node? = root
        var depth: Int = 0

        while (node != nil) {
			try visitor.head(node!, depth)
			if (node!.childNodeSize() > 0) {
				node = node!.childNode(0)
				depth+=1
			} else {
				while (node!.nextSibling() == nil && depth > 0) {
					try visitor.tail(node!, depth)
					node = node!.getParentNode()
					depth-=1
				}
				try visitor.tail(node!, depth)
				if (node === root) {
					break
				}
				node = node!.nextSibling()
			}
        }
    }

}
