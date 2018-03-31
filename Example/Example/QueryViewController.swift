//
//  QueryViewController.swift
//  Example
//
//  Created by Nabil on 02/03/18.
//  Copyright © 2018 Nabil. All rights reserved.
//

import UIKit

class QueryViewControllerCell: UITableViewCell {
    @IBOutlet weak var selector: UILabel!
    @IBOutlet weak var example: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!

}

class QueryViewController: UIViewController {

    typealias Item = (selector: String, example: String, description: String)

    //example items
    let items: [
        Item] = [ Item(selector: "*", example: "*", description: "any element"),
                  Item(selector: "#id", example: "#pageFooter", description: "elements with attribute ID of \"pageFooter\""),
                  Item(selector: ".class", example: ".login_form_label_field", description: "Selects all elements with class=\"login_form_label_field\""),
                  Item(selector: "element", example: "p", description: "Selects all <p> elements"),
                  Item(selector: "element", example: "div", description: "Selects all <div> elements"),
                  Item(selector: "element,element", example: "div, p", description: "Selects all <div> elements and all <p> elements"),
                  Item(selector: "element element", example: "div p", description: "Selects all <p> elements inside <div> elements"),
                  Item(selector: "element>element", example: "div > p", description: "Selects all <p> elements where the parent is a <div> element"),
                  Item(selector: "[attribute]", example: "[title]", description: "Selects all elements with a \"title\" attribute"),
                  Item(selector: "[^attrPrefix]", example: "[^cell]", description: "elements with an attribute name starting with \"cell\". Use to find elements with HTML5 datasets"),
                  Item(selector: "[attribute=value]", example: "[id=pageTitle]", description: "Selects all elements with id=\"pageTitle\""),
                  Item(selector: "[attribute^=value]", example: "a[href^=https]", description: "Selects every <a> element whose href attribute value begins with \"https\""),
                  Item(selector: "[attribute$=value]", example: "a[href$=.com/]", description: "Selects every <a> element whose href attribute value ends with \".com/\""),
                  Item(selector: "[attribute*=value]", example: "a[href*=login]", description: "Selects every <a> element whose href attribute value contains the substring \"login\""),
                  Item(selector: "[attr~=regex]", example: "img[src~=[gif]]", description: "elements with an attribute named \"img\", and value matching the regular expression")
                  ]

    var completionHandler: (Item) -> Void = { arg in }
    @IBOutlet weak var tableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = ""

        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.estimatedRowHeight = UITableViewAutomaticDimension
    }

}

extension QueryViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "QueryViewControllerCell", for: indexPath) as! QueryViewControllerCell

        cell.selector.text = items[indexPath.row].selector
        cell.example.text = items[indexPath.row].example
        cell.descriptionLabel.text = items[indexPath.row].description

        let color1 = UIColor.init(red: 245.0/255, green: 245.0/255, blue: 245.0/255, alpha: 1)
        let color2 = UIColor.init(red: 240.0/255, green: 240.0/255, blue: 240.0/255, alpha: 1)
        cell.backgroundColor = (indexPath.row % 2) == 0 ? color1 : color2

        return  cell
    }
}

extension QueryViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // user select an item
        completionHandler(items[indexPath.row])
    }
}
