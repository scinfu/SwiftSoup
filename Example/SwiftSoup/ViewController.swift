//
//  ViewController.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 11/19/2016.
//  Copyright (c) 2016 Nabil Chatbi. All rights reserved.
//

import UIKit
import SwiftSoup

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
		//testPerformanceDiv()
		ddd()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func ddd()
    {
        do{
            let unsafe: String = "<p><a href='http://example.com/' onclick='stealCookies()'>Link</a></p>"
            let safe: String = try SwiftSoup.clean(unsafe, Whitelist.basic())!
            print(safe)
            // now: <p><a href="http://example.com/" rel="nofollow">Link</a></p>
        }catch Exception.Error(let type, let message){
            print(message)
        }catch{
            print("error")
        }
    }

	func parseDocument()throws->Document {
		let html = "<html><head><title>First parse</title></head>"
			+ "<body><p>Parsed HTML into a doc.</p></body></html>"
		let doc: Document = try SwiftSoup.parse(html)
		return doc
	}

	func testPerformanceDiv() {
		let h: String = "<!doctype html>\n" +
			"<html>\n" +
			" <head></head>\n" +
			" <body>\n" +
			"  <img async checked src=\"&amp;<>&quot;\">&lt;&gt;&amp;\"\n" +
			"  <img async checked src=\"&amp;<>&quot;\">&lt;&gt;&amp;\"\n" +
			"  <img async checked src=\"&amp;<>&quot;\">&lt;&gt;&amp;\"\n" +
			"  <img async checked src=\"&amp;<>&quot;\">&lt;&gt;&amp;\"\n" +
			"  <img async checked src=\"&amp;<>&quot;\">&lt;&gt;&amp;\"\n" +
			"  <img async checked src=\"&amp;<>&quot;\">&lt;&gt;&amp;\"\n" +
			"  <img async checked src=\"&amp;<>&quot;\">&lt;&gt;&amp;\"\n" +
			"  <img async checked src=\"&amp;<>&quot;\">&lt;&gt;&amp;\"\n" +
			"  <img async checked src=\"&amp;<>&quot;\">&lt;&gt;&amp;\"\n" +
			"<div id=div1><p>Hello</p><p>Another <b>element</b></p><div id=div2><img src=foo.png></div></div>" +
			"<div id=div1><p>Hello</p><p>Another <b>element</b></p><div id=div2><img src=foo.png></div></div>" +
			"<div id=div1><p>Hello</p><p>Another <b>element</b></p><div id=div2><img src=foo.png></div></div>" +
			"<div id=div1><p>Hello</p><p>Another <b>element</b></p><div id=div2><img src=foo.png></div></div>" +
			"<div id=div1><p>Hello</p><p>Another <b>element</b></p><div id=div2><img src=foo.png></div></div>" +
			"<div id=div1><p>Hello</p><p>Another <b>element</b></p><div id=div2><img src=foo.png></div></div>" +
			"<div id=div1><p>Hello</p><p>Another <b>element</b></p><div id=div2><img src=foo.png></div></div>" +
			"<div id=div1><p>Hello</p><p>Another <b>element</b></p><div id=div2><img src=foo.png></div></div>" +
			"<div id=div1><p>Hello</p><p>Another <b>element</b></p><div id=div2><img src=foo.png></div></div>" +
			"<div id=div1><p>Hello</p><p>Another <b>element</b></p><div id=div2><img src=foo.png></div></div>" +
			"<div id=div1><p>Hello</p><p>Another <b>element</b></p><div id=div2><img src=foo.png></div></div>" +
			"<div id=div1><p>Hello</p><p>Another <b>element</b></p><div id=div2><img src=foo.png></div></div>" +
			"<div id=div1><p>Hello</p><p>Another <b>element</b></p><div id=div2><img src=foo.png></div></div>" +
			"<div id=div1><p>Hello</p><p>Another <b>element</b></p><div id=div2><img src=foo.png></div></div>" +
			"<div id=div1><p>Hello</p><p>Another <b>element</b></p><div id=div2><img src=foo.png></div></div>" +
			"<div id=div1><p>Hello</p><p>Another <b>element</b></p><div id=div2><img src=foo.png></div></div>" +
			"<div id=div1><p>Hello</p><p>Another <b>element</b></p><div id=div2><img src=foo.png></div></div>" +
			"<div id=div1><p>Hello</p><p>Another <b>element</b></p><div id=div2><img src=foo.png></div></div>" +
			"<div id=div1><p>Hello</p><p>Another <b>element</b></p><div id=div2><img src=foo.png></div></div>" +
			"<div id=div1><p>Hello</p><p>Another <b>element</b></p><div id=div2><img src=foo.png></div></div>" +
			"<div id=div1><p>Hello</p><p>Another <b>element</b></p><div id=div2><img src=foo.png></div></div>" +
			"  <foo />bar\n" +
			" </body>\n" +
		"</html>"
		let doc: Document = try! SwiftSoup.parse(h)
		do {
			for _ in 0...100000 {
				_ = try doc.select("div")
			}
		} catch {
		}
	}

		func testSite() {
			let myURLString = "http://apple.com"
			guard let myURL = URL(string: myURLString) else {
				print("Error: \(myURLString) doesn't seem to be a valid URL")
				return
			}
			let html = try! String(contentsOf: myURL, encoding: .utf8)
			let doc: Document = try! SwiftSoup.parse(html)

			do {
				for _ in 0...100 {
					_ = try doc.text()
				}
			} catch {
				print("Error")
			}
		}

}
