//
//  CleanerTest.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 13/01/17.
//  Copyright © 2017 Nabil Chatbi. All rights reserved.
//

import XCTest
@testable import SwiftSoup

class CleanerTest: XCTestCase {
    
    func testSimpleBehaviourTest()throws {
    let h = "<div><p class=foo><a href='http://evil.com'>Hello <b id=bar>there</b>!</a></div>";
    let cleanHtml = try SwiftSoup.clean(h, Whitelist.simpleText());
    XCTAssertEqual("Hello <b>there</b>!", TextUtil.stripNewlines(cleanHtml!));
        
    }
    
}
