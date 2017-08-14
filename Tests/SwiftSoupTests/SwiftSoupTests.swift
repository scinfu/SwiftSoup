//
//  SwiftSoupTests.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 12/12/16.
//  Copyright © 2016 Nabil Chatbi. All rights reserved.
//

import XCTest
@testable import SwiftSoup

class SwiftSoupTests: XCTestCase {
    var html : String!
    override func setUp() {
        super.setUp()
        let myURLString = "http://www.pointlesssites.com"
        guard let myURL = URL(string: myURLString) else {
            print("Error: \(myURLString) doesn't seem to be a valid URL")
            return
        }
        html = try! String(contentsOf: myURL, encoding: .utf8)
    }
    
    private func getCustomWhiteList() -> Whitelist {
        var whiteList: Whitelist?
        do {
            whiteList = try Whitelist.relaxed().preserveRelativeLinks(true)
                .addTags("style")
                .addTags("font")
                .addTags("center")
                .addTags("input")
                .addTags("hr")
                .addTags("title")
                .addTags("iframe")
                .addTags("map")
                .addTags("area")
                .addAttributes("font", "style", "color", "class", "face", "size")
                .addAttributes("a", "style", "class")
                .addAttributes("b", "style", "class")
                .addAttributes("blockquote", "style", "class")
                .addAttributes("br", "style", "class")
                .addAttributes("caption", "style", "class")
                .addAttributes("cite", "style", "class")
                .addAttributes("code", "style", "class")
                .addAttributes("col", "style", "class")
                .addAttributes("colgroup", "style", "class")
                .addAttributes("div", "style", "color", "class", "align")
                .addAttributes("dl", "style", "class")
                .addAttributes("dt", "style", "class")
                .addAttributes("em", "style", "class")
                .addAttributes("h1", "style", "class")
                .addAttributes("h2", "style", "class")
                .addAttributes("h3", "style", "class")
                .addAttributes("h4", "style", "class")
                .addAttributes("h5", "style", "class")
                .addAttributes("h6", "style", "class")
                .addAttributes("i", "style", "class")
                .addAttributes("img", "style", "class", "usemap", "border")
                .addAttributes("li", "style", "class")
                .addAttributes("ol", "style", "class")
                .addAttributes("p", "style", "class", "align")
                .addAttributes("pre", "style", "class")
                .addAttributes("q", "style", "class")
                .addAttributes("small", "style", "class")
                .addAttributes("span", "style", "class")
                .addAttributes("strike", "style", "class")
                .addAttributes("strong", "style", "class")
                .addAttributes("sub", "style", "class")
                .addAttributes("sup", "style", "class")
                .addAttributes("table", "style", "class", "bgcolor", "align", "cellpadding",
                               "cellspacing", "border", "height", "align", "role", "dir")
                .addAttributes("tbody", "style", "class")
                .addAttributes("td", "style", "class", "bgcolor", "align", "valign", "height", "tabindex")
                .addAttributes("tfoot", "style", "class")
                .addAttributes("th", "style", "class", "align")
                .addAttributes("thead", "style", "class")
                .addAttributes("tr", "style", "class", "valign", "align")
                .addAttributes("u", "style", "class")
                .addAttributes("ul", "style", "class")
                .addAttributes("center", "style", "class")
                .addAttributes("style", "type")
                .addAttributes("input", "type", "class", "disabled")
                .addAttributes("iframe", "src", "style", "class")
                .addAttributes("map", "name")
                .addAttributes("area", "shape", "coords", "id", "href", "alt")
                
                .addProtocols("img", "src", "cid", "data", "http", "https")
                .addProtocols("a", "href", "travelertodo")
                .addProtocols("a", "href", "ibmscp")
                .addProtocols("a", "href", "sametime")
                .addProtocols("a", "href", "stmeetings")
        } catch Exception.Error (let type, let message) {
        } catch {
        }
        return whiteList!
    }
    
    func testClean()
    {
        let customWhitelist = getCustomWhiteList()
        var cleanHTML: String
        do{
            let noPrettyPrint = OutputSettings().prettyPrint(pretty: false)
            let outputDocument = try SwiftSoup.parse(html.replaceAll(of: "\r\n", with: "\n"))
            let bodyElement = outputDocument.body()
            
            outputDocument.outputSettings(noPrettyPrint)
            cleanHTML = try SwiftSoup.clean(outputDocument.html(), customWhitelist)!
            
            
        }catch{
            print("")
        }
    }
    
    

	static var allTests = {
		return [
		]
	}()

}
