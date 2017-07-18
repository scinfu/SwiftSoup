/**
    A single byte represented as a UInt8
*/
public typealias Byte = UInt8

/**
    A byte array or collection of raw data
*/
public typealias Bytes = [Byte]

/**
    A sliced collection of raw data
*/
public typealias BytesSlice = ArraySlice<Byte>

// MARK: Sizes

private let _bytes = 1
private let _kilobytes = _bytes * 1000
private let _megabytes = _kilobytes * 1000
private let _gigabytes = _megabytes * 1000

extension Int {
    public var bytes: Int { return self }
    public var kilobytes: Int { return self * _kilobytes }
    public var megabytes: Int { return self * _megabytes }
    public var gigabytes: Int { return self * _gigabytes }
}

