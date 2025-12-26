//
//  DocumentType.swift
//  SwifSoup
//
//  Created by Nabil Chatbi on 29/09/16.
//

import Foundation

/**
 * A `<!DOCTYPE>` node.
 */
public class DocumentType: Node {
    static let PUBLIC_KEY = "PUBLIC".utf8Array
    static let SYSTEM_KEY = "SYSTEM".utf8Array
    private static let NAME = "name".utf8Array
    private static let PUB_SYS_KEY = "pubSysKey".utf8Array // PUBLIC or SYSTEM
    private static let PUBLIC_ID = "publicId".utf8Array
    private static let SYSTEM_ID = "systemId".utf8Array
    // todo: quirk mode from publicId and systemId

    /**
     Create a new doctype element.
     - parameter name: the doctype's name
     - parameter publicId: the doctype's public ID
     - parameter systemId: the doctype's system ID
     - parameter baseUri: the doctype's base URI
     */
    public convenience init(_ name: String, _ publicId: String, _ systemId: String, _ baseUri: String) {
        self.init(name.utf8Array, publicId.utf8Array, systemId.utf8Array, baseUri.utf8Array)
    }
    
    public init(_ name: [UInt8], _ publicId: [UInt8], _ systemId: [UInt8], _ baseUri: [UInt8]) {
        super.init(baseUri)
        do {
            try attr(DocumentType.NAME, name)
            try attr(DocumentType.PUBLIC_ID, publicId)
            if (has(DocumentType.PUBLIC_ID)) {
                try attr(DocumentType.PUB_SYS_KEY, DocumentType.PUBLIC_KEY)
            }
            try attr(DocumentType.SYSTEM_ID, systemId)
        } catch {}
    }

    /**
     Create a new doctype element.
     - parameter name: the doctype's name
     - parameter pubSysKey: (unknown)
     - parameter publicId: the doctype's public ID
     - parameter systemId: the doctype's system ID
     - parameter baseUri: the doctype's base URI
     */
    public init(_ name: [UInt8], _ pubSysKey: [UInt8]?, _ publicId: [UInt8], _ systemId: [UInt8], _ baseUri: [UInt8]) {
        super.init(baseUri)
        do {
            try attr(DocumentType.NAME, name)
            if(pubSysKey != nil) {
                try attr(DocumentType.PUB_SYS_KEY, pubSysKey!)
            }
            try attr(DocumentType.PUBLIC_ID, publicId)
            try attr(DocumentType.SYSTEM_ID, systemId)
        } catch {}
    }

    public override func nodeNameUTF8() -> [UInt8] {
        return nodeName().utf8Array
    }
    
    public override func nodeName() -> String {
        return "#doctype"
    }


    override func outerHtmlHead(_ accum: StringBuilder, _ depth: Int, _ out: OutputSettings) {
        if (out.syntax() == OutputSettings.Syntax.html && !has(DocumentType.PUBLIC_ID) && !has(DocumentType.SYSTEM_ID)) {
            // looks like a html5 doctype, go lowercase for aesthetics
            accum.append("<!doctype")
        } else {
            accum.append("<!DOCTYPE")
        }
        if (has(DocumentType.NAME)) {
            do {
                accum.append(" ").append(try attr(DocumentType.NAME))
            } catch {}

        }

        if (has(DocumentType.PUB_SYS_KEY)) {
            do {
                try accum.append(" ").append(attr(DocumentType.PUB_SYS_KEY))
            } catch {}
        }

        if (has(DocumentType.PUBLIC_ID)) {
            do {
                try accum.append(" \"").append(attr(DocumentType.PUBLIC_ID)).append("\"")
            } catch {}

        }
        if (has(DocumentType.SYSTEM_ID)) {
            do {
                accum.append(" \"").append(try attr(DocumentType.SYSTEM_ID)).append("\"")
            } catch {}

        }
        accum.append(">")
    }

    override func outerHtmlTail(_ accum: StringBuilder, _ depth: Int, _ out: OutputSettings) {
    }

    private func has(_ attribute: [UInt8]) -> Bool {
        do {
            return !StringUtil.isBlank(try String(decoding: attr(attribute), as: UTF8.self))
        } catch {return false}
    }

	public override func copy(with zone: NSZone? = nil) -> Any {
		let clone = DocumentType(attributes!.get(key: DocumentType.NAME),
		                         attributes!.get(key: DocumentType.PUBLIC_ID),
		                         attributes!.get(key: DocumentType.SYSTEM_ID),
		                         baseUri!)
		return copy(clone: clone)
	}

	public override func copy(parent: Node?) -> Node {
		let clone = DocumentType(attributes!.get(key: DocumentType.NAME),
		                         attributes!.get(key: DocumentType.PUBLIC_ID),
		                         attributes!.get(key: DocumentType.SYSTEM_ID),
		                         baseUri!)
		return copy(clone: clone, parent: parent)
	}

    override func copyForDeepClone(parent: Node?) -> Node {
        let clone = DocumentType(attributes!.get(key: DocumentType.NAME),
                                 attributes!.get(key: DocumentType.PUBLIC_ID),
                                 attributes!.get(key: DocumentType.SYSTEM_ID),
                                 baseUri!)
        return copy(clone: clone, parent: parent, copyChildren: false, rebuildIndexes: false)
    }

	public override func copy(clone: Node, parent: Node?) -> Node {
		return super.copy(clone: clone, parent: parent)
	}

}
