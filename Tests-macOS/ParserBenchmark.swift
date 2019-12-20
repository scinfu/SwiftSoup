//
//  ParserBenchmark.swift
//  SwiftSoupTests
//
//  Created by garth on 2/26/19.
//  Copyright © 2019 Nabil Chatbi. All rights reserved.
//

import XCTest
import SwiftSoup

class ParserBenchmark: XCTestCase {
    
    enum Const {
        static var corpusHTMLData: [String] = []
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

}
