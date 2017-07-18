/**
    Append the right-hand byte to the end of the bytes array
*/
public func +=(lhs: inout Bytes, rhs: Byte) {
    lhs.append(rhs)
}

/**
    Append the contents of the byteslice to the end of the bytes array
*/
public func +=(lhs: inout Bytes, rhs: BytesSlice) {
    lhs += Array(rhs)
}
