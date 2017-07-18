extension Collection {
    /**
        Safely access the contents of a collection. Nil if outside of bounds.
    */
    public subscript(safe idx: Index) -> Iterator.Element? {
        guard startIndex <= idx else { return nil }
        // NOT >=, endIndex is "past the end"
        guard endIndex > idx else { return nil }
        return self[idx]
    }
}
