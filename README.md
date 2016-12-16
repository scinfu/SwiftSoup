# SwiftSoup
[![Build Status](https://travis-ci.org/scinfu/SwiftSoup.svg?branch=master)](https://travis-ci.org/scinfu/SwiftSoup)
[![Version](https://img.shields.io/cocoapods/v/SwiftSoup.svg?style=flat)](http://cocoapods.org/pods/SwiftSoup)
[![License](https://img.shields.io/cocoapods/l/SwiftSoup.svg?style=flat)](http://cocoapods.org/pods/SwiftSoup)
[![Platform](https://img.shields.io/cocoapods/p/SwiftSoup.svg?style=flat)](http://cocoapods.org/pods/SwiftSoup)

`SwiftSoup` is a Swift library for working with real-world HTML. It provides a very convenient API for extracting and manipulating data, using the best of DOM, CSS, and jquery-like methods.
`SwiftSoup` implements the WHATWG HTML5 specification, and parses HTML to the same DOM as modern browsers do.
* scrape and parse HTML from a URL, file, or string
* find and extract data, using DOM traversal or CSS selectors
* manipulate the HTML elements, attributes, and text
* clean user-submitted content against a safe white-list, to prevent XSS attacks
* output tidy HTML
`SwiftSoup` is designed to deal with all varieties of HTML found in the wild; from pristine and validating, to invalid tag-soup; `SwiftSoup` will create a sensible parse tree.


## <a name="installation-pane"></a> Installation

SwiftSoup is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "SwiftSoup"
```
## [Read Wiki for more examples](https://github.com/scinfu/SwiftSoup/wiki)



## Example

To parse a HTML document:

```swift
let html = "<html><head><title>First parse</title></head>"
			+ "<body><p>Parsed HTML into a doc.</p></body></html>"
		let doc: Document = try SwiftSoup.parse(html)
		return try doc.text()
```

*   unclosed tags (e.g. `<p>Lorem <p>Ipsum` parses to `<p>Lorem</p> <p>Ipsum</p>`)
*   implicit tags (e.g. a naked `<td>Table data</td>` is wrapped into a `<table><tr><td>...`)
*  reliably creating the document structure (`html` containing a `head` and `body`, and only appropriate elements within the head)


###The object model of a document
* Documents consist of Elements and TextNodes
* The inheritance chain is: `Document` extends `Element` extends `Node.TextNode` extends `Node`.
* An Element contains a list of children Nodes, and has one parent Element. They also have provide a filtered list of child Elements only.




## Author

Nabil Chatbi, scinfu@gmail.com

## Note
SwiftSoup was ported to Swift from Java [Jsoup](https://jsoup.org/) library.

## License

SwiftSoup is available under the MIT license. See the LICENSE file for more info.
