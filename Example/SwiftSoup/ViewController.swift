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
		do{
			let txt = try getText()
			print(txt);
		}catch{
			
		}
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
	
	
	func getText()throws->String {
		let html = "<html><head><title>First parse</title></head>"
			+ "<body><p>Parsed HTML into a doc.</p></body></html>"
		let doc: Document = try SwiftSoup.parse(html)
		return try doc.text()
	}

}

