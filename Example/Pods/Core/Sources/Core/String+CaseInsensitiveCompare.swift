extension String {
    /**
         Case insensitive comparison on argument
    */
    public func equals(caseInsensitive: String) -> Bool {
        return lowercased() == caseInsensitive.lowercased()
    }
}
