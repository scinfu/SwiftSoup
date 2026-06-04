//
//  LRUCache.swift
//  LRUCache
//
//  Created by Nick Lockwood on 05/08/2021.
//  Copyright © 2021 Nick Lockwood. All rights reserved.
//
//  Distributed under the permissive MIT license
//  Get the latest version from here:
//
//  https://github.com/nicklockwood/LRUCache
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//
//  Vendored into SwiftSoup to eliminate external dependencies.
//  Trimmed to the subset of API used by SwiftSoup's QueryParserCache.
//

import Foundation

internal final class LRUCache<Key: Hashable & Sendable, Value>: @unchecked Sendable {
    private var values: [Key: Container] = [:]
    private var _countLimit: Int
    private unowned(unsafe) var head: Container?
    private unowned(unsafe) var tail: Container?
    private let lock: NSLock = .init()

    /// Initialize the cache with the specified `countLimit`.
    init(countLimit: Int = .max) {
        self._countLimit = countLimit
    }

    /// The maximum number of values permitted.
    var countLimit: Int {
        get { atomic { _countLimit } }
        set {
            atomic {
                _countLimit = newValue
                clean()
            }
        }
    }

    /// Insert or update a value and mark it as most recently used.
    func setValue(_ value: Value?, forKey key: Key) {
        guard let value else {
            removeValue(forKey: key)
            return
        }
        atomic {
            if let container = values[key] {
                container.value = value
                remove(container)
                append(container)
            } else {
                let container = Container(value: value, key: key)
                values[key] = container
                append(container)
            }
            clean()
        }
    }

    /// Fetch a value from the cache and mark it as most recently used.
    func value(forKey key: Key) -> Value? {
        atomic {
            if let container = values[key] {
                remove(container)
                append(container)
                return container.value
            }
            return nil
        }
    }

    /// Remove a value from the cache.
    @discardableResult func removeValue(forKey key: Key) -> Value? {
        atomic {
            guard let container = values.removeValue(forKey: key) else {
                return nil
            }
            remove(container)
            return container.value
        }
    }

    /// Remove all values from the cache.
    func removeAll() {
        atomic {
            values.removeAll()
            head = nil
            tail = nil
        }
    }
}

// MARK: - Private

private extension LRUCache {
    final class Container {
        var value: Value
        let key: Key
        unowned(unsafe) var prev: Container?
        unowned(unsafe) var next: Container?

        init(value: Value, key: Key) {
            self.value = value
            self.key = key
        }
    }

    func atomic<T>(_ action: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return action()
    }

    func remove(_ container: Container) {
        if head === container {
            head = container.next
        }
        if tail === container {
            tail = container.prev
        }
        container.next?.prev = container.prev
        container.prev?.next = container.next
        container.next = nil
    }

    func append(_ container: Container) {
        if head == nil {
            head = container
        }
        container.prev = tail
        tail?.next = container
        tail = container
    }

    func clean() {
        while values.count > _countLimit, let container = head {
            remove(container)
            values.removeValue(forKey: container.key)
        }
    }
}
