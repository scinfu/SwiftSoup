//
//  DataNode.swift
//  SwifSoup
//
//  Created by Nabil Chatbi on 29/09/16.
//

import Foundation

/**
 A data node, for contents of style, script tags etc, where contents should not show in text().
 */
open class DataNode: Node {
    private static let DATA_KEY  = "data".utf8Array
    private var rawDataSlice: ByteSlice? = nil

    /**
     Create a new DataNode.
     - parameter data: data contents
     - parameter baseUri: base URI
     */
    public init(_ data: [UInt8], _ baseUri: [UInt8]) {
        super.init(baseUri)
        do {
            try ensureAttributesForWrite().put(DataNode.DATA_KEY, data)
        } catch {}

    }

    @usableFromInline
    internal init(slice: ByteSlice, baseUri: [UInt8]) {
        super.init(baseUri)
        rawDataSlice = slice
    }

    @usableFromInline
    internal convenience init(slice: ArraySlice<UInt8>, baseUri: [UInt8]) {
        self.init(slice: ByteSlice.fromArraySlice(slice), baseUri: baseUri)
    }

    @inline(__always)
    open override func nodeNameUTF8() -> [UInt8] {
        return nodeName().utf8Array
    }
    
    @inline(__always)
    open override func nodeName() -> String {
        return "#data"
    }

    /**
     Get the data contents of this node. Will be unescaped and with original new lines, space etc.
     - returns: data
     */
    @inline(__always)
    open func getWholeData() -> String {
        return String(decoding: getWholeDataUTF8(), as: UTF8.self)
    }
    
    @inline(__always)
    open func getWholeDataUTF8() -> [UInt8] {
        if let slice = rawDataSlice {
            let materialized = slice.toArray()
            rawDataSlice = nil
            do {
                try ensureAttributesForWrite().put(DataNode.DATA_KEY, materialized)
            } catch {}
            return materialized
        }
        guard let attributes = attributes else {
            return []
        }
        return attributes.get(key: DataNode.DATA_KEY)
    }

    @usableFromInline
    internal func wholeDataSlice() -> ByteSlice {
        if let slice = rawDataSlice {
            return slice
        }
        guard let attributes = attributes else {
            return ByteSlice.empty
        }
        return ByteSlice.fromArray(attributes.get(key: DataNode.DATA_KEY))
    }

    @usableFromInline
    internal func appendSlice(_ slice: ByteSlice) {
        var data = getWholeDataUTF8()
        data.append(contentsOf: slice)
        do {
            try ensureAttributesForWrite().put(DataNode.DATA_KEY, data)
        } catch {}
        markSourceDirty()
    }

    @usableFromInline
    internal func extendSliceFromSourceRange(_ source: SourceBuffer, newRange: SourceRange) -> Bool {
        guard rawDataSlice != nil, !sourceRangeDirty else {
            return false
        }
        guard let existingRange = sourceRange,
              existingRange.isValid,
              newRange.isValid,
              existingRange.end == newRange.start,
              newRange.end <= source.bytes.count
        else {
            return false
        }
        rawDataSlice = ByteSlice(storage: source.storage, start: existingRange.start, end: newRange.end)
        return true
    }


    @usableFromInline
    internal func appendBytes(_ bytes: [UInt8]) {
        appendSlice(ByteSlice.fromArray(bytes))
    }




    /**
     Set the data contents of this node.
     - parameter data: unencoded data
     - returns: this node, for chaining
     */
    @discardableResult
    @inline(__always)
    open func setWholeData(_ data: String) -> DataNode {
        rawDataSlice = nil
        do {
            try ensureAttributesForWrite().put(DataNode.DATA_KEY, data.utf8Array)
        } catch {}
        markSourceDirty()
        return self
    }


    @inline(__always)
    override func outerHtmlHead(_ accum: StringBuilder, _ depth: Int, _ out: OutputSettings)throws {
        accum.append(wholeDataSlice()) // data is not escaped in return from data nodes, so " in script, style is plain
    }

    @inline(__always)
    override func outerHtmlTail(_ accum: StringBuilder, _ depth: Int, _ out: OutputSettings) {}

    /**
     Create a new DataNode from HTML encoded data.
     - parameter encodedData: encoded data
     - parameter baseUri: bass URI
     - returns: new DataNode
     */
    @inline(__always)
    public static func createFromEncoded(_ encodedData: String, _ baseUri: String) throws -> DataNode {
        let data = try Entities.unescape(encodedData.utf8Array)
        return DataNode(data, baseUri.utf8Array)
    }

    @inline(__always)
	public override func copy(with zone: NSZone? = nil) -> Any {
		let clone = DataNode(getWholeDataUTF8(), baseUri!)
		return copy(clone: clone)
	}

	@inline(__always)
	public override func copy(parent: Node?) -> Node {
		let clone = DataNode(getWholeDataUTF8(), baseUri!)
		return copy(clone: clone, parent: parent)
	}

    @inline(__always)
    override func copyForDeepClone(parent: Node?) -> Node {
        let clone = DataNode(getWholeDataUTF8(), baseUri!)
        return copy(clone: clone, parent: parent, copyChildren: false, rebuildIndexes: false)
    }

    @inline(__always)
	public override func copy(clone: Node, parent: Node?) -> Node {
		return super.copy(clone: clone, parent: parent)
	}
}
