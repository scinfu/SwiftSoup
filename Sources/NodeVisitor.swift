//
//  NodeVisitor.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 16/10/16.
//

import Foundation

/**
 Node visitor interface. Provide an implementing class to ``NodeTraversor`` to iterate through nodes.
 
 This interface provides two methods, ``head(_:_:)`` and ``tail(_:_:)``. The head method is called when the node is first
 seen, and the tail method when all of the node's children have been visited. As an example, head can be used to
 create a start tag for a node, and tail to create the end tag.
 */
public protocol NodeVisitor {
    /**
     Callback for when a node is first visited. `head` cannot safely call ``Node/remove()``.
     
     - parameter node: the node being visited.
     - parameter depth: the depth of the node, relative to the root node. E.g., the root node has depth 0, and a child node
     of that will have depth 1.
     */
    func head(_ node: Node, _ depth: Int) throws

    /**
     Callback for when a node is last visited, after all of its descendants have been visited. `tail` can safely call ``Node/remove()``.
     
     - parameter node: the node being visited.
     - parameter depth: the depth of the node, relative to the root node. E.g., the root node has depth 0, and a child node
     of that will have depth 1.
     */
    func tail(_ node: Node, _ depth: Int) throws
}
