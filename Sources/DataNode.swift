//
//  DataNode.swift
//  SwifSoup
//
//  Created by Nabil Chatbi on 29/09/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import Foundation

/**
 A data node, for contents of style, script tags etc, where contents should not show in text().
 */
open class DataNode: Node {
    private static let DATA_KEY: String  = "data"

    /**
     Create a new DataNode.
     @param data data contents
     @param baseUri base URI
     */
    public init(_ data: String, _ baseUri: String) {
        super.init(baseUri)
        do {
            try attributes?.put(DataNode.DATA_KEY, data)
        } catch {}

    }

    open override func nodeName() -> String {
        return "#data"
    }

    /**
     Get the data contents of this node. Will be unescaped and with original new lines, space etc.
     @return data
     */
    open func getWholeData() -> String {
		return attributes!.get(key: DataNode.DATA_KEY)
    }

    /**
     * Set the data contents of this node.
     * @param data unencoded data
     * @return this node, for chaining
     */
    @discardableResult
    open func setWholeData(_ data: String) -> DataNode {
        do {
            try attributes?.put(DataNode.DATA_KEY, data)
        } catch {}
        return self
    }

    override func outerHtmlHead(_ accum: StringBuilder, _ depth: Int, _ out: OutputSettings)throws {
        accum.append(getWholeData()) // data is not escaped in return from data nodes, so " in script, style is plain
    }

    override func outerHtmlTail(_ accum: StringBuilder, _ depth: Int, _ out: OutputSettings) {}

    /**
     Create a new DataNode from HTML encoded data.
     @param encodedData encoded data
     @param baseUri bass URI
     @return new DataNode
     */
    public static func createFromEncoded(_ encodedData: String, _ baseUri: String)throws->DataNode {
        let data = try Entities.unescape(encodedData)
        return DataNode(data, baseUri)
    }

	public override func copy(with zone: NSZone? = nil) -> Any {
		let clone = DataNode(attributes!.get(key: DataNode.DATA_KEY), baseUri!)
		return copy(clone: clone)
	}

	public override func copy(parent: Node?) -> Node {
		let clone = DataNode(attributes!.get(key: DataNode.DATA_KEY), baseUri!)
		return copy(clone: clone, parent: parent)
	}

	public override func copy(clone: Node, parent: Node?) -> Node {
		return super.copy(clone: clone, parent: parent)
	}
}
