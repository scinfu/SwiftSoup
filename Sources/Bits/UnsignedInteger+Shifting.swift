extension UnsignedInteger {
    /**
     Returns whether or not a given bitMask is part of the caller
     */
    public func containsMask(_ mask: Self) -> Bool {
        return (self & mask) == mask
    }
}

extension UnsignedInteger {
    /**
     A right bit shifter that is supported without the need for a concrete type.
     */
    mutating func shiftRight(_ places: Int) {
        (1...places).forEach { _ in
            self /= 2
        }
    }

    /**
     A bit shifter that is supported without the need for a concrete type.
     */
    mutating func shiftLeft(_ places: Int) {
        (1...places).forEach { _ in
            self *= 2
        }
    }
}
