//
//  Cleaner.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 15/10/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import Foundation

open class Cleaner {
    fileprivate let headWhitelist: Whitelist?
    fileprivate let bodyWhitelist: Whitelist

    /// Create a new cleaner, that sanitizes documents' `<head>` and  `<body>` using the supplied whitelist.
    /// - Parameters:
    ///   - headWhitelist: Whitelist to clean the head with
    ///   - bodyWhitelist: Whitelist to clean the body with
    public init(headWhitelist: Whitelist?, bodyWhitelist: Whitelist) {
        self.headWhitelist = headWhitelist
        self.bodyWhitelist = bodyWhitelist
    }

    /// Create a new cleaner, that sanitizes documents' `<body>` using the supplied whitelist.
    /// - Parameter whitelist: Whitelist to clean the body with
    convenience init(_ whitelist: Whitelist) {
        self.init(headWhitelist: nil, bodyWhitelist: whitelist)
    }

    /// Creates a new, clean document, from the original dirty document, containing only elements allowed by the whitelist.
    /// The original document is not modified. Only elements from the dirt document's `<body>` are used.
    /// - Parameter dirtyDocument: Untrusted base document to clean.
    /// - Returns: A cleaned document.
	public func clean(_ dirtyDocument: Document) throws -> Document {
		let clean = Document.createShell(dirtyDocument.getBaseUri())
        if let headWhitelist, let dirtHead = dirtyDocument.head(), let cleanHead = clean.head() { // frameset documents won't have a head. the clean doc will have empty head.
            try copySafeNodes(dirtHead, cleanHead, whitelist: headWhitelist)
        }
        if let dirtBody = dirtyDocument.body(), let cleanBody = clean.body() { // frameset documents won't have a body. the clean doc will have empty body.
            try copySafeNodes(dirtBody, cleanBody, whitelist: bodyWhitelist)
        }
		return clean
	}

    /// Determines if the input document is valid, against the whitelist. It is considered valid if all the tags and attributes
    /// in the input HTML are allowed by the whitelist.
    ///
    /// This method can be used as a validator for user input forms. An invalid document will still be cleaned successfully
    /// using the ``clean(_:)`` document. If using as a validator, it is recommended to still clean the document
    /// to ensure enforced attributes are set correctly, and that the output is tidied.
    /// - Parameter dirtyDocument: document to test
    /// - Returns: true if no tags or attributes need to be removed; false if they do
	public func isValid(_ dirtyDocument: Document) throws -> Bool {
        let clean = Document.createShell(dirtyDocument.getBaseUri())
        let numDiscarded = try copySafeNodes(dirtyDocument.body()!, clean.body()!, whitelist: bodyWhitelist)
        return numDiscarded == 0
	}

    @discardableResult
    fileprivate func copySafeNodes(_ source: Element, _ dest: Element, whitelist: Whitelist) throws -> Int {
		let cleaningVisitor = Cleaner.CleaningVisitor(source, dest, whitelist)
		try NodeTraversor(cleaningVisitor).traverse(source)
		return cleaningVisitor.numDiscarded
	}
}

extension Cleaner {
	fileprivate final class CleaningVisitor: NodeVisitor {
		private(set) var numDiscarded = 0

		private let root: Element
		private var destination: Element? // current element to append nodes to

        private let whitelist: Whitelist

		public init(_ root: Element, _ destination: Element, _ whitelist: Whitelist) {
			self.root = root
			self.destination = destination
            self.whitelist = whitelist
		}

		public func head(_ source: Node, _ depth: Int) throws {
			if let sourceEl = source as? Element {
				if whitelist.isSafeTag(sourceEl.tagName()) { // safe, clone and copy safe attrs
					let meta = try createSafeElement(sourceEl)
					let destChild = meta.el
					try destination?.appendChild(destChild)

					numDiscarded += meta.numAttribsDiscarded
					destination = destChild
				} else if source != root { // not a safe tag, so don't add. don't count root against discarded.
					numDiscarded += 1
				}
			} else if let sourceText = source as? TextNode {
				let destText = TextNode(sourceText.getWholeText(), source.getBaseUri())
				try destination?.appendChild(destText)
			} else if let sourceData = source as? DataNode {
				if sourceData.parent() != nil && whitelist.isSafeTag(sourceData.parent()!.nodeName()) {
					let destData =  DataNode(sourceData.getWholeData(), source.getBaseUri())
					try destination?.appendChild(destData)
                } else {
                    numDiscarded += 1
                }
			} else { // else, we don't care about comments, xml proc instructions, etc
				numDiscarded += 1
			}
		}

		public func tail(_ source: Node, _ depth: Int) throws {
			if let x = source as? Element {
				if whitelist.isSafeTag(x.nodeName()) {
					// would have descended, so pop destination stack
					destination = destination?.parent()
				}
			}
		}

        private func createSafeElement(_ sourceEl: Element) throws -> ElementMeta {
            let sourceTag = sourceEl.tagName()
            let destAttrs = Attributes()
            var numDiscarded = 0

            if let sourceAttrs = sourceEl.getAttributes() {
                for sourceAttr in sourceAttrs {
                    if try whitelist.isSafeAttribute(sourceTag, sourceEl, sourceAttr) {
                        destAttrs.put(attribute: sourceAttr)
                    } else {
                        numDiscarded += 1
                    }
                }
            }
            let enforcedAttrs = try whitelist.getEnforcedAttributes(sourceTag)
            destAttrs.addAll(incoming: enforcedAttrs)

            let dest = try Element(Tag.valueOf(sourceTag), sourceEl.getBaseUri(), destAttrs)
            return ElementMeta(dest, numDiscarded)
        }
	}
}

extension Cleaner {
	fileprivate struct ElementMeta {
		let el: Element
		let numAttribsDiscarded: Int

		init(_ el: Element, _ numAttribsDiscarded: Int) {
			self.el = el
			self.numAttribsDiscarded = numAttribsDiscarded
		}
	}
}
