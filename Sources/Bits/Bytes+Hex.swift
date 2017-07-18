import Foundation

extension Sequence where Iterator.Element == Byte {
    public var hexEncoded: Bytes {
        let bytes = Array(self)
        return HexEncoder.shared.encode(bytes)
    }

    public var hexDecoded: Bytes {
        let bytes = Array(self)
        return HexEncoder.shared.decode(bytes)
    }
}
