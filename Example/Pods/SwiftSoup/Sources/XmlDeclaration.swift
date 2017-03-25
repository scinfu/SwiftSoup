//
//  XmlDeclaration.swift
//  SwifSoup
//
//  Created by Nabil Chatbi on 29/09/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import Foundation

/**
 An XML Declaration.
 
 @author Jonathan Hedley, jonathan@hedley.net */
public class XmlDeclaration: Node {
    private let _name: String
    private let isProcessingInstruction: Bool // <! if true, <? if false, declaration (and last data char should be ?)

    /**
     Create a new XML declaration
     @param name of declaration
     @param baseUri base uri
     @param isProcessingInstruction is processing instruction
     */
    public init(_ name: String, _ baseUri: String, _ isProcessingInstruction: Bool) {
        self._name = name
        self.isProcessingInstruction = isProcessingInstruction
        super.init(baseUri)
    }

    public override func nodeName() -> String {
        return "#declaration"
    }

    /**
     * Get the name of this declaration.
     * @return name of this declaration.
     */
    public func name() -> String {
        return _name
    }

    /**
     Get the unencoded XML declaration.
     @return XML declaration
     */
    public func getWholeDeclaration()throws->String {
        return try attributes!.html().trim() // attr html starts with a " "
    }

    override func outerHtmlHead(_ accum: StringBuilder, _ depth: Int, _ out: OutputSettings) {
        accum
            .append("<")
            .append(isProcessingInstruction ? "!" : "?")
            .append(_name)
        do {
            try attributes?.html(accum: accum, out: out)
        } catch {}
        accum
            .append(isProcessingInstruction ? "!" : "?")
            .append(">")
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
	public override func copy(clone: Node, parent: Node?) -> Node {
		return super.copy(clone: clone, parent: parent)
	}
}
