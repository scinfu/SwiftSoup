// libxml2-backed serialization helpers (opt-in via env var).
#if canImport(CLibxml2) || canImport(libxml2)
import Foundation
#if canImport(CLibxml2)
@preconcurrency import CLibxml2
#elseif canImport(libxml2)
@preconcurrency import libxml2
#endif

enum Libxml2Serialization {
    static let enabled: Bool = {
        let value = ProcessInfo.processInfo.environment["SWIFTSOUP_LIBXML2_SERIALIZE"]?.lowercased()
        return value == "1" || value == "true" || value == "yes"
    }()

    static func htmlDump(doc: xmlDocPtr) -> [UInt8]? {
        var mem: UnsafeMutablePointer<xmlChar>? = nil
        var size: Int32 = 0
        htmlDocDumpMemory(doc, &mem, &size)
        guard size >= 0 else { return nil }
        guard let mem else { return [] }
        let count = Int(size)
        let bytes = count > 0 ? Array(UnsafeBufferPointer(start: mem, count: count)) : []
        xmlFree(mem)
        return bytes
    }

    static func htmlDumpFormat(doc: xmlDocPtr, prettyPrint: Bool) -> [UInt8]? {
        var mem: UnsafeMutablePointer<xmlChar>? = nil
        var size: Int32 = 0
        htmlDocDumpMemoryFormat(doc, &mem, &size, prettyPrint ? 1 : 0)
        guard size >= 0 else { return nil }
        guard let mem else { return [] }
        let count = Int(size)
        let bytes = count > 0 ? Array(UnsafeBufferPointer(start: mem, count: count)) : []
        xmlFree(mem)
        return bytes
    }

    static func htmlDump(node: xmlNodePtr, doc: xmlDocPtr) -> [UInt8]? {
        guard let buffer = xmlBufferCreate() else { return nil }
        defer { xmlBufferFree(buffer) }
        let written = htmlNodeDump(buffer, doc, node)
        guard written >= 0 else { return nil }
        guard let content = buffer.pointee.content else { return nil }
        let size = Int(buffer.pointee.use)
        guard size > 0 else { return [] }
        return Array(UnsafeBufferPointer(start: content, count: size))
    }

    static func htmlDumpFormat(node: xmlNodePtr, doc: xmlDocPtr, prettyPrint: Bool) -> [UInt8]? {
        guard let buffer = xmlBufferCreate() else { return nil }
        guard let out = xmlOutputBufferCreateBuffer(buffer, nil) else {
            xmlBufferFree(buffer)
            return nil
        }
        let format: Int32 = prettyPrint ? 1 : 0
        "UTF-8".withCString { encodingPtr in
            htmlNodeDumpFormatOutput(out, doc, node, encodingPtr, format)
        }
        xmlOutputBufferFlush(out)
        let size = Int(xmlOutputBufferGetSize(out))
        let content = xmlOutputBufferGetContent(out)
        let bytes: [UInt8]
        if let content, size > 0 {
            bytes = Array(UnsafeBufferPointer(start: content, count: size))
        } else {
            bytes = []
        }
        xmlOutputBufferClose(out)
        xmlBufferFree(buffer)
        return bytes
    }

    static func htmlDumpChildren(node: xmlNodePtr, doc: xmlDocPtr) -> [UInt8]? {
        guard let buffer = xmlBufferCreate() else { return nil }
        defer { xmlBufferFree(buffer) }
        var child = node.pointee.children
        while let current = child {
            _ = htmlNodeDump(buffer, doc, current)
            child = current.pointee.next
        }
        guard let content = buffer.pointee.content else { return nil }
        let size = Int(buffer.pointee.use)
        guard size > 0 else { return [] }
        return Array(UnsafeBufferPointer(start: content, count: size))
    }

    static func htmlDumpChildrenFormat(node: xmlNodePtr, doc: xmlDocPtr, prettyPrint: Bool) -> [UInt8]? {
        guard let buffer = xmlBufferCreate() else { return nil }
        guard let out = xmlOutputBufferCreateBuffer(buffer, nil) else {
            xmlBufferFree(buffer)
            return nil
        }
        var child = node.pointee.children
        let format: Int32 = prettyPrint ? 1 : 0
        "UTF-8".withCString { encodingPtr in
            while let current = child {
                htmlNodeDumpFormatOutput(out, doc, current, encodingPtr, format)
                child = current.pointee.next
            }
        }
        xmlOutputBufferFlush(out)
        let size = Int(xmlOutputBufferGetSize(out))
        let content = xmlOutputBufferGetContent(out)
        let bytes: [UInt8]
        if let content, size > 0 {
            bytes = Array(UnsafeBufferPointer(start: content, count: size))
        } else {
            bytes = []
        }
        xmlOutputBufferClose(out)
        xmlBufferFree(buffer)
        return bytes
    }
}
#endif
