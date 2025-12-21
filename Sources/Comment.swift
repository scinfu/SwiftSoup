//
//  Comment.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 22/10/16.
//

import Foundation

/**
 A comment node.
 */
public class Comment: Node {
    private static let COMMENT_KEY: [UInt8] = UTF8Arrays.comment

    /**
     Create a new comment node.
     - parameter data: The contents of the comment
     - parameter baseUri: base URI
     */
    public init(_ data: [UInt8], _ baseUri: [UInt8]) {
        super.init(baseUri)
        do {
            try attributes?.put(Comment.COMMENT_KEY, data)
        } catch {}
    }

    @inline(__always)
    public override func nodeNameUTF8() -> [UInt8] {
        return nodeName().utf8Array
    }
    
    @inline(__always)
    public override func nodeName() -> String {
        return "#comment"
    }

    /**
     Get the contents of the comment.
     - returns: comment content
     */
    @inline(__always)
    public func getData() -> String {
        return String(decoding: getDataUTF8(), as: UTF8.self)
    }
    
    @inline(__always)
    public func getDataUTF8() -> [UInt8] {
		return attributes!.get(key: Comment.COMMENT_KEY)
    }

    @inline(__always)
    override func outerHtmlHead(_ accum: StringBuilder, _ depth: Int, _ out: OutputSettings) {
        if (out.prettyPrint()) {
            indent(accum, depth, out)
        }
        accum
            .append("<!--")
            .append(getData())
            .append("-->")
    }

    @inline(__always)
    override func outerHtmlTail(_ accum: StringBuilder, _ depth: Int, _ out: OutputSettings) {}

    @inline(__always)
	public override func copy(with zone: NSZone? = nil) -> Any {
		let clone = Comment(attributes!.get(key: Comment.COMMENT_KEY), baseUri!)
		return copy(clone: clone)
	}

	@inline(__always)
	public override func copy(parent: Node?) -> Node {
		let clone = Comment(attributes!.get(key: Comment.COMMENT_KEY), baseUri!)
		return copy(clone: clone, parent: parent)
	}

    @inline(__always)
    override func copyForDeepClone(parent: Node?) -> Node {
        let clone = Comment(attributes!.get(key: Comment.COMMENT_KEY), baseUri!)
        return copy(clone: clone, parent: parent, copyChildren: false)
    }

    @inline(__always)
	public override func copy(clone: Node, parent: Node?) -> Node {
		return super.copy(clone: clone, parent: parent)
	}
}
