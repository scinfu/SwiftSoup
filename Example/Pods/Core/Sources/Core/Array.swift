extension Array {
    /**
        Turn into an array of various chunk sizes
     
        Last component may not be equal size as others.
     
        [1,2,3,4,5].chunked(size: 2)
        ==
        [[1,2],[3,4],[5]]
    */
    public func chunked(size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map { startIndex in
            let next = startIndex.advanced(by: size)
            let end = next <= endIndex ? next : endIndex
            return Array(self[startIndex ..< end])
        }
    }
}

extension Array where Element: Hashable {
    /**
         Trims the head and tail of the array to remove contained elements.
     
         [0,1,2,1,0,1,0,0,0,0].trimmed([0])
         // == [1,2,1,0,1]
     
         This function is intended to be as performant as possible, which is part of the reason
         why some of the underlying logic may seem a bit more tedious than is necessary
    */
    public func trimmed(_ elements: [Element]) -> SubSequence {
        guard !isEmpty else { return [] }

        let lastIdx = self.count - 1
        var leadingIterator = self.indices.makeIterator()
        var trailingIterator = leadingIterator

        var leading = 0
        var trailing = lastIdx
        while let next = leadingIterator.next(), elements.contains(self[next]) {
            leading += 1
        }
        while let next = trailingIterator.next(), elements.contains(self[lastIdx - next]) {
            trailing -= 1
        }

        guard trailing >= leading else { return [] }
        return self[leading...trailing]
    }
}
