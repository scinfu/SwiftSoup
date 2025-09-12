//
//  QueryParserCache.swift
//  SwiftSoup
//
//  Created by Marc Haisenko on 2025-08-26.
//  Copyright © 2025 Nabil Chatbi. All rights reserved.
//

import Foundation
#if canImport(LRUCache)
import LRUCache
#endif
#if canImport(Atomics)
import Atomics
#endif


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
    ///
    /// On (Apple) platforms that support it, this cache responds to memory pressure.
    final class DefaultCache: QueryParserCache {
        // The value is arbitrarily chosen. Maybe use a low limit on watchOS?
        private static let defaultCountLimit = 300
        
        /// Initialize using a framework-provided default.
        public convenience init () {
            self.init(limit: .count(Self.defaultCountLimit))
        }
        
#if canImport(LRUCache)
        /// Actual cache implementation.
        private let cache: LRUCache<String, Evaluator>
        
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
            return cache.value(forKey: query)
        }
        
        public func set(_ query: String, _ evaluator: Evaluator) {
            cache.setValue(evaluator, forKey: query)
        }
#else
        /// Actual cache implementation.
        nonisolated(unsafe)
        private let cache: NSCache<NSString, Evaluator>
        // Note: Even though NSCache is not Sendable, Apple has documented it
        // as being thread-safe:
        //     You can add, remove, and query items in the cache from different threads
        //     without having to lock the cache yourself.
        
        /// Initialize using an explicit limit.
        public init (limit: CacheLimit) {
            cache = NSCache()
            
            switch limit {
            case .count(let count):
                assert(count > 0, "Cache count must be greater than 0")
                if count > 0 {
                    cache.countLimit = count
                } else {
                    cache.countLimit = Self.defaultCountLimit
                }
            case .unlimited:
                // For NSCache, 0 means "no limit".
                cache.countLimit = 0
            }
        }
        
        public func get(_ query: String) -> Evaluator? {
            return cache.object(forKey: query as NSString)
        }
        
        public func set(_ query: String, _ evaluator: Evaluator) {
            cache.setObject(evaluator, forKey: query as NSString)
        }
#endif
    }
    
}


#if canImport(Atomics)
internal extension QueryParser {
    
    /// Helper class to manage references to arbitrary cache instances using atomic references.
    final class AtomicCacheWrapper: AtomicReference, Sendable {
        let wrapped: any QueryParserCache
        
        init(cache: any QueryParserCache) {
            self.wrapped = cache
        }
    }
    
}
#endif
