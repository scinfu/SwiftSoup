public typealias Size = Int

public protocol Cacheable {
    func cacheSize() ->  Size
}

public final class SystemCache<Wrapped: Cacheable> {
    public let maxSize: Size

    private var ordered: OrderedDictionary<String, Wrapped> = .init()

    public init(maxSize: Size) {
        self.maxSize = maxSize
    }

    public subscript(key: String) -> Wrapped? {
        get {
            return ordered[key]
        }
        set {
            ordered[key] = newValue
            vent()
        }
    }

    private func vent() {
        var dropTotal = totalSize() - maxSize
        while dropTotal > 0 {
            let next = dropOldest()
            guard let size = next?.cacheSize() else { break }
            dropTotal -= size
        }
    }

    private func totalSize() -> Size {
        return ordered.unorderedItems.map { $0.cacheSize() } .reduce(0, +)
    }

    private func dropOldest() -> Wrapped? {
        guard let oldest = ordered.oldest else { return nil }
        ordered[oldest.key] = nil
        return oldest.value
    }
}

fileprivate struct OrderedDictionary<Key: Hashable, Value> {
    fileprivate var oldest: (key: Key, value: Value)? {
        guard let key = list.first, let value = backing[key] else { return nil }
        return (key, value)
    }

    fileprivate var newest: (key: Key, value: Value)? {
        guard let key = list.last, let value = backing[key] else { return nil }
        return (key, value)
    }

    fileprivate var items: [Value] {
        return list.flatMap { backing[$0] }
    }

    // theoretically slightly faster
    fileprivate var unorderedItems: LazyMapCollection<Dictionary<Key, Value>, Value> {
        return backing.values
    }

    private var list: [Key] = []
    private var backing: [Key: Value] = [:]

    fileprivate subscript(key: Key) -> Value? {
        mutating get {
            if let existing = backing[key] {
                return existing
            } else {
                remove(key)
                return nil
            }
        }
        set {
            if let newValue = newValue {
                // overwrite anything that might exist
                remove(key)
                backing[key] = newValue
                list.append(key)

            } else {
                backing[key] = nil
                remove(key)
            }
        }
    }

    fileprivate subscript(idx: Int) -> (key: Key, value: Value)? {
        guard idx < list.count, idx >= 0 else { return nil }
        let key = list[idx]
        guard let value = backing[key] else { return nil }
        return (key, value)
    }

    fileprivate mutating func remove(_ key: Key) {
        if let idx = list.index(of: key) {
            list.remove(at: idx)
        }
    }
}
