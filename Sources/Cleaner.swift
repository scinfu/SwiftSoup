//
//  Cleaner.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 15/10/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import Foundation

open class Cleaner {
    fileprivate let whitelist: Whitelist

    /**
     Create a new cleaner, that sanitizes documents using the supplied whitelist.
     @param whitelist white-list to clean with
     */
    public init(_ whitelist: Whitelist) {
        self.whitelist = whitelist
    }

	/**
	Creates a new, clean document, from the original dirty document, containing only elements allowed by the whitelist.
	The original document is not modified. Only elements from the dirt document's <code>body</code> are used.
	@param dirtyDocument Untrusted base document to clean.
	@return cleaned document.
	*/
	public func clean(_ dirtyDocument: Document)throws->Document {
		//Validate.notNull(dirtyDocument)
		let clean: Document = Document.createShell(dirtyDocument.getBaseUri())
		if (dirtyDocument.body() != nil && clean.body() != nil) // frameset documents won't have a body. the clean doc will have empty body.
		{
			try copySafeNodes(dirtyDocument.body()!, clean.body()!)
		}
		return clean
	}

	/**
	Determines if the input document is valid, against the whitelist. It is considered valid if all the tags and attributes
	in the input HTML are allowed by the whitelist.
	<p>
	This method can be used as a validator for user input forms. An invalid document will still be cleaned successfully
	using the {@link #clean(Document)} document. If using as a validator, it is recommended to still clean the document
	to ensure enforced attributes are set correctly, and that the output is tidied.
	</p>
	@param dirtyDocument document to test
	@return true if no tags or attributes need to be removed; false if they do
	*/
	public func isValid(_ dirtyDocument: Document)throws->Bool {
	//Validate.notNull(dirtyDocument)
		let clean: Document = Document.createShell(dirtyDocument.getBaseUri())
		let numDiscarded: Int = try copySafeNodes(dirtyDocument.body()!, clean.body()!)
		return numDiscarded == 0
	}

    @discardableResult
	fileprivate func copySafeNodes(_ source: Element, _ dest: Element)throws->Int {
		let cleaningVisitor: Cleaner.CleaningVisitor = Cleaner.CleaningVisitor(source, dest, self)
		let traversor: NodeTraversor = NodeTraversor(cleaningVisitor)
		try traversor.traverse(source)
		return cleaningVisitor.numDiscarded
	}

	fileprivate func createSafeElement(_ sourceEl: Element)throws->ElementMeta {
		let sourceTag: String = sourceEl.tagName()
		let destAttrs: Attributes = Attributes()
		let dest: Element = try Element(Tag.valueOf(sourceTag), sourceEl.getBaseUri(), destAttrs)
		var numDiscarded: Int = 0

		if let sourceAttrs = sourceEl.getAttributes() {
			for sourceAttr: Attribute in sourceAttrs {
				if (try whitelist.isSafeAttribute(sourceTag, sourceEl, sourceAttr)) {
					destAttrs.put(attribute: sourceAttr)
				} else {
					numDiscarded+=1
				}
			}
		}
		let enforcedAttrs: Attributes = try whitelist.getEnforcedAttributes(sourceTag)
		destAttrs.addAll(incoming: enforcedAttrs)

		return ElementMeta(dest, numDiscarded)
	}

}

extension Cleaner {
	fileprivate final class CleaningVisitor: NodeVisitor {
		var numDiscarded: Int = 0
		let root: Element
		var destination: Element?  // current element to append nodes to

		private var cleaner: Cleaner

		public init(_ root: Element, _ destination: Element, _ cleaner: Cleaner) {
			self.root = root
			self.destination = destination
            self.cleaner = cleaner
		}

		public func head(_ source: Node, _ depth: Int)throws {
			if let sourceEl = (source as? Element) {
				if (cleaner.whitelist.isSafeTag(sourceEl.tagName())) { // safe, clone and copy safe attrs
					let meta: Cleaner.ElementMeta = try cleaner.createSafeElement(sourceEl)
					let destChild: Element = meta.el
					try destination?.appendChild(destChild)

					numDiscarded += meta.numAttribsDiscarded
					destination = destChild
				} else if (source != root) { // not a safe tag, so don't add. don't count root against discarded.
					numDiscarded+=1
				}
			} else if let sourceText = (source as? TextNode) {
				let destText: TextNode = TextNode(sourceText.getWholeText(), source.getBaseUri())
				try destination?.appendChild(destText)
			} else if let sourceData = (source as? DataNode) {
				if  sourceData.parent() != nil && cleaner.whitelist.isSafeTag(sourceData.parent()!.nodeName()) {
					//let sourceData: DataNode = (DataNode) source
					let destData: DataNode =  DataNode(sourceData.getWholeData(), source.getBaseUri())
					try destination?.appendChild(destData)
                }else{
                    numDiscarded+=1
                }
			} else { // else, we don't care about comments, xml proc instructions, etc
				numDiscarded+=1
			}
		}

		public func tail(_ source: Node, _ depth: Int)throws {
			if let x = (source as? Element) {
				if cleaner.whitelist.isSafeTag(x.nodeName()) {
					// would have descended, so pop destination stack
					destination = destination?.parent()
				}
			}
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
