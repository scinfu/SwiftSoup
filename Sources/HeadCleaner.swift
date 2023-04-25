//
//  HeadCleaner.swift
//  SwiftSoup
//
//  Created by Valentin Perignon on 25/04/2023.
//

import Foundation

public enum HeadCleaner {
    /// Adds to the destination document a sanitized version from the dirt document's `<head>code</head>`.
    /// - Parameters:
    ///   - dirtyDocument: Source document containing the tag `<head>` to sanitize
    ///   - destinationDocument: Document with a cleaned body.
    public static func clean(dirtyDocument: Document, destinationDocument: Document) throws {
        guard let dirtHead = dirtyDocument.head(), let cleanedHead = destinationDocument.head() else { return }
        try copySafeNodes(source: dirtHead, destination: cleanedHead)
    }

    static private func copySafeNodes(source: Element, destination: Element) throws {
        let cleaningVisitor = CleaningVisitor(root: source, destination: destination)
        try NodeTraversor(cleaningVisitor).traverse(source)
    }
}

extension HeadCleaner {
    private final class CleaningVisitor: NodeVisitor {
        private static let allowedTags = ["style", "meta", "base"]

        private let root: Element
        private var destination: Element

        private var elementToSkip: Element?

        init(root: Element, destination: Element) {
            self.root = root
            self.destination = destination
        }

        public func head(_ node: SwiftSoup.Node, _ depth: Int) throws {
            guard elementToSkip == nil else { return }

            if let elementNode = node as? Element {
                if isSafeTag(node: elementNode) {
                    let sourceTag = elementNode.nodeName()

                    guard let destinationAttributes = elementNode.attributes?.clone() else { return }
                    let destinationChild = Element(Tag(sourceTag), elementNode.baseUri ?? "", destinationAttributes)
                    try destination.appendChild(destinationChild)
                    destination = destinationChild
                } else if node != root {
                    elementToSkip = elementNode
                }
            } else if let textNode = node as? TextNode {
                let destinationText = TextNode(textNode.getWholeText(), textNode.getBaseUri())
                try destination.appendChild(destinationText)
            } else if let dataNode = node as? DataNode, let parent = node.parent(), isSafeTag(node: parent) {
                let destinationData = DataNode(dataNode.getWholeData(), dataNode.getBaseUri())
                try destination.appendChild(destinationData)
            }
        }

        public func tail(_ node: SwiftSoup.Node, _ depth: Int) throws {
            if node == elementToSkip {
                elementToSkip = nil
            } else if let elementNode = node as? Element, isSafeTag(node: elementNode) {
                if let parent = destination.parent() {
                    destination = parent
                } else {
                    throw Exception.Error(type: .IllegalArgumentException, Message: "Illegal state")
                }
            }
        }

        private func isSafeTag(node: Node) -> Bool {
            guard !isMetaRefresh(node: node) else { return false }

            let tag = node.nodeName().lowercased()
            return Self.allowedTags.contains(tag)
        }

        private func isMetaRefresh(node: Node) -> Bool {
            let tag = node.nodeName().lowercased()
            guard tag == "meta" else { return false }

            let attributeValue = try? node.attributes?.getIgnoreCase(key: "http-equiv").trim().lowercased()
            return attributeValue == "refresh"
        }
    }
}
