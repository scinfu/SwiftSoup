//
//  ParserBenchmark.swift
//  SwiftSoupTests
//
//  Created by garth on 2/26/19.
//

import XCTest
import SwiftSoup

class ParserBenchmark: XCTestCase {
    
    enum Const {
        nonisolated(unsafe) static var corpusHTMLData: [String] = []
        static let repetitions = 5
    }

    override func setUp() {
        let bundle = Bundle(for: type(of: self))
        let urls = bundle.urls(forResourcesWithExtension: ".html", subdirectory: nil)
        Const.corpusHTMLData = urls!.compactMap { try? Data(contentsOf: $0) }.map { String(decoding: $0, as: UTF8.self) }
    }

    func testParserPerformance() throws {
        var count = 0
        measure {
            for htmlDoc in Const.corpusHTMLData {
                for _ in 1...Const.repetitions {
                    do {
                        let _ = try SwiftSoup.parse(htmlDoc)
                        count += 1
                    } catch {
                        XCTFail("Exception while parsing HTML")
                    }
                }
            }
            print("Did \(count) iterations")
        }
    }
    
    // Provides a baseline to see how much the cache speeds up parsing.
    func testQueryParserPerformanceUncached() throws {
        let basic = ".foo > ol, ol > li + li.bar"
        let count = 10_000
        let queries: [String] = Array(0 ..< count).map { basic + String($0) }
        
        // Temporarily disable the cache.
        QueryParser.cache = nil
        defer {
            QueryParser.cache = QueryParser.DefaultCache()
        }
        
        measure {
            for query in queries {
                _ = try! QueryParser.parse(query)
            }
        }
    }

    func testQueryParserPerformanceCached() throws {
        let basic = ".foo > ol, ol > li + li.bar"
        let count = 10_000
        let queries: [String] = Array(0 ..< count).map { basic + String($0) }

        // Raise limit, pre-fill cache.
        QueryParser.cache = QueryParser.DefaultCache(limit: .unlimited)
        defer {
            QueryParser.cache = QueryParser.DefaultCache()
        }
        
        for query in queries {
            _ = try! QueryParser.parse(query)
        }
        
        // Measure cached access.
        measure {
            for _ in 0 ..< count {
                _ = try! QueryParser.parse(queries[0])
            }
        }
    }
}

/// A NSCache-based cache implementation. Provided for testing.
final class QueryParserNSCache: QueryParserCache {
    /// Actual cache implementation.
    nonisolated(unsafe) private let cache: NSCache<NSString, Evaluator> = NSCache()
    // The value is arbitrarily chosen. Maybe use a low limit on watchOS?
    private static let defaultCountLimit = 300
    
    /// Initialize using a framework-provided default.
    public convenience init () {
        self.init(limit: .count(QueryParserNSCache.defaultCountLimit))
    }
    
    /// Initialize using an explicit limit.
    public init (limit: QueryParser.CacheLimit) {
        switch limit {
        case .count(let count):
            assert(count > 0, "Cache count must be greater than 0")
            if count > 0 {
                cache.countLimit = count
            } else {
                cache.countLimit = QueryParserNSCache.defaultCountLimit
            }
        case .unlimited:
            cache.countLimit = 0
        }
    }
    
    public func get(_ query: String) -> Evaluator? {
        return cache.object(forKey: query as NSString)
    }
    
    public func set(_ query: String, _ evaluator: Evaluator) {
        cache.setObject(evaluator, forKey: query as NSString)
    }
}
