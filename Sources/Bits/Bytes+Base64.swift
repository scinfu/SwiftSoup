extension Sequence where Iterator.Element == Byte {
    public var base64Encoded: Bytes {
        let bytes = Array(self)
        return Base64Encoder.shared.encode(bytes)
    }

    public var base64Decoded: Bytes {
        let bytes = Array(self)
        return Base64Encoder.shared.decode(bytes)
    }
}

extension Sequence where Iterator.Element == Byte {
    public var base64URLEncoded: Bytes {
        let bytes = Array(self)
        return Base64Encoder.url.encode(bytes)
    }

    public var base64URLDecoded: Bytes {
        let bytes = Array(self)
        return Base64Encoder.url.decode(bytes)
    }
}
