//
//  QueryParserCacheTest.swift
//  SwiftSoupTests
//
//  Created by Marc Haisenko on 2025-08-24.
//  Copyright © 2025 Nabil Chatbi. All rights reserved.
//

import XCTest
import SwiftSoup

class QueryParserCacheTest: SwiftSoupTestCase {
    
    override func setUp() {
        // Reset the limit since some tests may change it.
        QueryParser.cache = QueryParser.DefaultCache()
        
    }
    
    func testBasic() throws {
        QueryParser.cache = QueryParser.DefaultCache(limit: .count(2))
        
        let eval1 = try QueryParser.parse("div")
        let eval2 = try QueryParser.parse("div")
        XCTAssert(eval1 === eval2, "Must get a cached instance")
        
        // Parse some more, pushes the `div` query out of the cache.
        _ = try QueryParser.parse("p")
        _ = try QueryParser.parse("a")
        
        let eval3 = try QueryParser.parse("div")
        XCTAssert(eval3 !== eval1, "Must get a new instance")
    }
    
}
