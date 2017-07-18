extension SignedInteger {
    /**
        Convert a Signed integer into a hex string representation
     
        255
        =>
        FF
     
        NOTE: Will always return UPPERCASED VALUES
    */
    public var hex: String {
        return String(self, radix: 16).uppercased()
    }
}

extension UnsignedInteger {
    /**
         Convert a Signed integer into a hex string representation

         255
         =>
         FF

         NOTE: Will always return UPPERCASED VALUES
    */
    public var hex: String {
        return String(self, radix: 16).uppercased()
    }
}
