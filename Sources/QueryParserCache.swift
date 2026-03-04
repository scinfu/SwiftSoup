//
//  QueryParserCache.swift
//  SwiftSoup
//
//  Created by Marc Haisenko on 2025-08-26.
//  Copyright © 2025 Nabil Chatbi. All rights reserved.
//

import Foundation


/// Protocol for ``QueryParser`` caches.
public protocol QueryParserCache: AnyObject, Sendable {

    /// Get a cached evaluator for a given query.
    func get(_ query: String) -> Evaluator?

    /// Store an evaluator for the given query.
    ///
    /// Note that complex queries can produce multiple entries in the cache, because the parser can
    /// split queries into sub-queries which in turn get parsed as well. This is a dersirable trait
    /// because it speeds up parsing related queries.
    func set(_ query: String, _ evaluator: Evaluator)

}


public extension QueryParser {

    /// A limit value for a query parser cache.
    enum CacheLimit: Sendable {
        /// Limit the maximum number of parsed queries in the cache.
        ///
        /// Note that complex queries can produce multiple entries in the cache, because the parser
        /// can split queries into sub-queries which in turn get parsed as well. This is a
        /// dersirable trait because it speeds up parsing related queries.
        ///
        /// - note: The number must be greater than 0. For values smaller than or equal to 0, an
        ///   implementation may disable the cache or use a default value instead.
        case count(Int)

        /// Allows the cache to grow without bounds. Implementations should still provide some limit
        /// and/or respond to memory pressure on supported platforms.
        case unlimited
    }


    /// Default ``QueryParser`` caching implementation.
    final class DefaultCache: QueryParserCache {
        // The value is arbitrarily chosen. Maybe use a low limit on watchOS?
        private static let defaultCountLimit = 300

        /// Initialize using a framework-provided default.
        public convenience init () {
            self.init(limit: .count(Self.defaultCountLimit))
        }

        /// Actual cache implementation.
        private let cache: LRUCache<String, Evaluator>
        private let cacheLock = Mutex()

        /// Initialize using an explicit limit.
        public init (limit: CacheLimit) {
            switch limit {
            case .count(let count):
                assert(count > 0, "Cache count must be greater than 0")
                if count > 0 {
                    cache = LRUCache(countLimit: count)
                } else {
                    cache = LRUCache(countLimit: Self.defaultCountLimit)
                }
            case .unlimited:
                cache = LRUCache(countLimit: .max)
            }
        }

        public func get(_ query: String) -> Evaluator? {
            cacheLock.lock()
            defer { cacheLock.unlock() }
            return cache.value(forKey: query)
        }

        public func set(_ query: String, _ evaluator: Evaluator) {
            cacheLock.lock()
            defer { cacheLock.unlock() }
            cache.setValue(evaluator, forKey: query)
        }
    }

}
