//
//  ViewController.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 11/19/2016.
//  Copyright (c) 2016 Nabil Chatbi. All rights reserved.
//

import UIKit
import SwiftSoup

class ViewController: UIViewController
{
    var html : String!
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        let myURLString = "https://facebook.com"
        guard let myURL = URL(string: myURLString) else {
            print("Error: \(myURLString) doesn't seem to be a valid URL")
            return
        }
        html = try! String(contentsOf: myURL, encoding: .utf8)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    @IBAction func doaction(_ sender: Any) {
        for _ in 0...1000 {
            _ = try! SwiftSoup.parse(html)
        }
    }
}

