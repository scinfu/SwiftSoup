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
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func parse(_ sender: Any) {
        let myURLString = "https://samdutton.wordpress.com/2015/04/02/high-performance-html/"
        guard let myURL = URL(string: myURLString) else {
            print("Error: \(myURLString) doesn't seem to be a valid URL")
            return
        }
        
        
        
        do {
            let html = try String(contentsOf: myURL, encoding: .utf8)
            
            for _ in 0...10 {
                let doc: Document = try! SwiftSoup.parse(html)
                let contentTag = try doc.select("div").first()
                _ = try (contentTag?.html())!
            }
        } catch {
            print("Error")
        }
    }    
}
