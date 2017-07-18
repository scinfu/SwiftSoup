extension Sequence {
    /**
        Convert the given sequence to its array representation
    */
    public var array: [Iterator.Element] {
        return Array(self)
    }
}
