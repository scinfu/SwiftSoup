//
//  XmlDeclaration.swift
//  SwifSoup
//
//  Created by Nabil Chatbi on 29/09/16.
//

import Foundation

/**
 An XML Declaration.
  */
public class XmlDeclaration: Node {
    private let _name: [UInt8]
    private let isProcessingInstruction: Bool // <! if true, <? if false, declaration (and last data char should be ?)

    /**
     Create a new XML declaration
     - parameter name: of declaration
     - parameter baseUri: base uri
     - parameter isProcessingInstruction: is processing instruction
     */
    public init(_ name: [UInt8], _ baseUri: [UInt8], _ isProcessingInstruction: Bool) {
        self._name = name
        self.isProcessingInstruction = isProcessingInstruction
        super.init(baseUri)
    }
    
    public convenience init(_ name: String, _ baseUri: String, _ isProcessingInstruction: Bool) {
        self.init(name.utf8Array, baseUri.utf8Array, isProcessingInstruction)
    }

    public override func nodeNameUTF8() -> [UInt8] {
        return nodeName().utf8Array
    }
    
    public override func nodeName() -> String {
        return "#declaration"
    }

    /**
     Get the name of this declaration.
     - returns: name of this declaration.
     */
    public func name() -> String {
        return String(decoding: _name, as: UTF8.self)
    }

    /**
     Get the unencoded XML declaration.
     - returns: XML declaration
     */
    public func getWholeDeclaration()throws->String {
        return try attributes!.html().trim() // attr html starts with a " "
    }

    override func outerHtmlHead(_ accum: StringBuilder, _ depth: Int, _ out: OutputSettings) {
        accum
            .append(UTF8Arrays.tagStart)
            .append(isProcessingInstruction ? "!" : "?")
            .append(_name)
        do {
            try attributes?.html(accum: accum, out: out)
        } catch {}
        accum
            .append(isProcessingInstruction ? "!" : "?")
            .append(UTF8Arrays.tagEnd)
    }

    override func outerHtmlTail(_ accum: StringBuilder, _ depth: Int, _ out: OutputSettings) {}

	public override func copy(with zone: NSZone? = nil) -> Any {
		let clone = XmlDeclaration(_name, baseUri!, isProcessingInstruction)
		return copy(clone: clone)
	}

	public override func copy(parent: Node?) -> Node {
		let clone = XmlDeclaration(_name, baseUri!, isProcessingInstruction)
		return copy(clone: clone, parent: parent)
	}

    override func copyForDeepClone(parent: Node?) -> Node {
        let clone = XmlDeclaration(_name, baseUri!, isProcessingInstruction)
        return copy(clone: clone, parent: parent, copyChildren: false)
    }
	public override func copy(clone: Node, parent: Node?) -> Node {
		return super.copy(clone: clone, parent: parent)
	}
}
