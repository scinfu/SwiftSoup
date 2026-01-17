//
//  BuildEntities.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 31/10/16.
//

import XCTest
import SwiftSoup

class BuildEntitiesTests: SwiftSoupTestCase {
    
    func testEscapeEntities() {
        XCTAssertEqual(Entities.escape("foo<\u{A0}>bar"), "foo&lt;&nbsp;&gt;bar")
        
        let xhtml = OutputSettings().charset(.utf8).escapeMode(Entities.EscapeMode.xhtml)
        XCTAssertEqual(Entities.escape("foo<\u{A0}>bar", xhtml), "foo&lt;&#xa0;&gt;bar")
    }
    
}
