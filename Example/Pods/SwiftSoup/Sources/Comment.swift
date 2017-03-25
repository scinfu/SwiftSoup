//
//  Comment.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 22/10/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import Foundation

/**
 A comment node.
 */
public class Comment: Node {
    private static let COMMENT_KEY: String = "comment"

    /**
     Create a new comment node.
     @param data The contents of the comment
     @param baseUri base URI
     */
    public init(_ data: String, _ baseUri: String) {
        super.init(baseUri)
        do {
            try attributes?.put(Comment.COMMENT_KEY, data)
        } catch {}
    }

    public override func nodeName() -> String {
        return "#comment"
    }

    /**
     Get the contents of the comment.
     @return comment content
     */
    public func getData() -> String {
		return attributes!.get(key: Comment.COMMENT_KEY)
    }

    override func outerHtmlHead(_ accum: StringBuilder, _ depth: Int, _ out: OutputSettings) {
        if (out.prettyPrint()) {
            indent(accum, depth, out)
        }
        accum
            .append("<!--")
            .append(getData())
            .append("-->")
    }

    override func outerHtmlTail(_ accum: StringBuilder, _ depth: Int, _ out: OutputSettings) {}

	public override func copy(with zone: NSZone? = nil) -> Any {
		let clone = Comment(attributes!.get(key: Comment.COMMENT_KEY), baseUri!)
		return copy(clone: clone)
	}

	public override func copy(parent: Node?) -> Node {
		let clone = Comment(attributes!.get(key: Comment.COMMENT_KEY), baseUri!)
		return copy(clone: clone, parent: parent)
	}

	public override func copy(clone: Node, parent: Node?) -> Node {
		return super.copy(clone: clone, parent: parent)
	}
}
