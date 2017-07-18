import Foundation

extension Data: BytesConvertible {
    public func makeBytes() -> Bytes {
        var array = Bytes(repeating: 0, count: count)
        let buffer = UnsafeMutableBufferPointer(start: &array, count: count)
        _ = copyBytes(to: buffer)
        return array
    }
}
