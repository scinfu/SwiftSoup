extension Byte {
    /**
        Returns whether or not the given byte can be considered UTF8 whitespace
    */
    public var isWhitespace: Bool {
        return self == .space || self == .newLine || self == .carriageReturn || self == .horizontalTab
    }

    /**
        Returns whether or not the given byte is an arabic letter
    */
    public var isLetter: Bool {
        return (.a ... .z).contains(self) || (.A ... .Z).contains(self)
    }

    /**
        Returns whether or not a given byte represents a UTF8 digit 0 through 9
    */
    public var isDigit: Bool {
        return (.zero ... .nine).contains(self)
    }

    /**
        Returns whether or not a given byte represents a UTF8 digit 0 through 9, or an arabic letter
    */
    public var isAlphanumeric: Bool {
        return isLetter || isDigit
    }

    /**
        Returns whether a given byte can be interpreted as a hex value in UTF8, ie: 0-9, a-f, A-F.
    */
    public var isHexDigit: Bool {
        return (.zero ... .nine).contains(self) || (.A ... .F).contains(self) || (.a ... .f).contains(self)
    }
}
