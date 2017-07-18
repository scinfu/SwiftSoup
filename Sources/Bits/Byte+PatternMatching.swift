// MARK: Byte

public func ~=(pattern: Byte, value: Byte) -> Bool {
    return pattern == value
}

public func ~=(pattern: Byte, value: BytesSlice) -> Bool {
    return value.contains(pattern)
}

public func ~=(pattern: Byte, value: Bytes) -> Bool {
    return value.contains(pattern)
}

// MARK: Bytes

public func ~=(pattern: Bytes, value: Byte) -> Bool {
    return pattern.contains(value)
}

public func ~=(pattern: Bytes, value: Bytes) -> Bool {
    return pattern == value
}

public func ~=(pattern: Bytes, value: BytesSlice) -> Bool {
    return pattern == Bytes(value)
}

// MARK: BytesSlice


public func ~=(pattern: BytesSlice, value: Byte) -> Bool {
    return pattern.contains(value)
}

public func ~=(pattern: BytesSlice, value: BytesSlice) -> Bool {
    return pattern == value
}

public func ~=(pattern: BytesSlice, value: Bytes) -> Bool {
    return Bytes(pattern) == value
}
