import Foundation

// Fast-path token emission: avoids materializing Token objects when callers just need slices.
internal protocol TokeniserEventReceiver: AnyObject {
    func startTag(name: ArraySlice<UInt8>, normalName: ArraySlice<UInt8>?, tagId: Token.Tag.TagId, attributes: Attributes?, selfClosing: Bool)
    func endTag(name: ArraySlice<UInt8>, normalName: ArraySlice<UInt8>?, tagId: Token.Tag.TagId)
    func text(_ data: ArraySlice<UInt8>)
    func comment(_ data: ArraySlice<UInt8>)
    func doctype(name: ArraySlice<UInt8>?, publicId: ArraySlice<UInt8>?, systemId: ArraySlice<UInt8>?, forceQuirks: Bool)
    func eof()
}
