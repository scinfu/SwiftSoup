# SwiftSoup
![Platform OS X | iOS | tvOS | watchOS | Linux](https://img.shields.io/badge/platform-Linux%20%7C%20OS%20X%20%7C%20iOS%20%7C%20tvOS%20%7C%20watchOS-orange.svg)
![🐧 linux: ready](https://img.shields.io/badge/%F0%9F%90%A7%20linux-ready-red.svg)
![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)
[![Build Status](https://travis-ci.org/scinfu/SwiftSoup.svg?branch=master)](https://travis-ci.org/scinfu/SwiftSoup)
[![Version](https://img.shields.io/cocoapods/v/SwiftSoup.svg?style=flat)](http://cocoapods.org/pods/SwiftSoup)
[![License](https://img.shields.io/cocoapods/l/SwiftSoup.svg?style=flat)](http://cocoapods.org/pods/SwiftSoup)
[![GitHub release](https://img.shields.io/github/release/scinfu/SwiftSoup.svg)](https://github.com/scinfu/SwiftSoup/releases)
[![Twitter](https://img.shields.io/badge/twitter-@scinfu-blue.svg?style=flat)](http://twitter.com/scinfu)
[![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg)](https://www.paypal.me/scinfu)

`SwiftSoup` is a Swift library for working with real-world HTML. It provides a very convenient API for extracting and manipulating data, using the best of DOM, CSS, and jquery-like methods.
`SwiftSoup` implements the WHATWG HTML5 specification, and parses HTML to the same DOM as modern browsers do.
* scrape and parse HTML from a URL, file, or string
* find and extract data, using DOM traversal or CSS selectors
* manipulate the HTML elements, attributes, and text
* clean user-submitted content against a safe white-list, to prevent XSS attacks
* output tidy HTML
`SwiftSoup` is designed to deal with all varieties of HTML found in the wild; from pristine and validating, to invalid tag-soup; `SwiftSoup` will create a sensible parse tree.


## Installation

SwiftSoup is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "SwiftSoup"
```
## [Read Wiki for more examples](https://github.com/scinfu/SwiftSoup/wiki)



## Examples

###To parse a HTML document:

```swift
do{
	let html = "<html><head><title>First parse</title></head>"
				+ "<body><p>Parsed HTML into a doc.</p></body></html>"
	let doc: Document = try SwiftSoup.parse(html)
	return try doc.text()
}catch Exception.Error(let type, let message)
{
	print("")
}catch{
	print("")
}
```

##Set the HTML of an element
You need to modify the HTML of an element.
Use the HTML setter methods in Element:

```swift
do{
	let doc: Document = try SwiftSoup.parse("<div>One</div><span>One</span>")
	let div: Element = try doc.select("div").first()! // <div></div>
	try div.html("<p>lorem ipsum</p>") // <div><p>lorem ipsum</p></div>
	try div.prepend("<p>First</p>")
	try div.append("<p>Last</p>")
	print(div)
	// now div is: <div><p>First</p><p>lorem ipsum</p><p>Last</p></div>
	
	let span: Element = try doc.select("span").first()! // <span>One</span>
	try span.wrap("<li><a href='http://example.com/'></a></li>")
	print(doc)
	// now: <li><a href="http://example.com/"><span>One</span></a></li>
}catch Exception.Error(let type, let message)
{
	print("")
}catch{
	print("")
}
```

###Extract attributes, text, and HTML from elements
After parsing a document, and finding some elements, you'll want to get at the data inside those elements.
- To get the value of an attribute, use `Node.attr(_ String key)` method
- For the text on an element (and its combined children), use `Element.text()`
- For HTML, use `Element.html()`, or `Node.outerHtml()¡ as appropriate

```swift
do{
	let html: String = "<p>An <a href='http://example.com/'><b>example</b></a> link.</p>";
	let doc: Document = try! SwiftSoup.parse(html)
	let link: Element = try! doc.select("a").first()!
	
	let text: String = try! doc.body()!.text(); // "An example link"
	let linkHref: String = try! link.attr("href"); // "http://example.com/"
	let linkText: String = try! link.text(); // "example""
	
	let linkOuterH: String = try! link.outerHtml();
	// "<a href="http://example.com"><b>example</b></a>"
	let linkInnerH: String = try! link.html(); // "<b>example</b>"
}catch Exception.Error(let type, let message){
	print(message)
}catch{
	print("error")
}
```
###Parsing a body fragment
You have a fragment of body HTML (e.g. div containing a couple of p tags; as opposed to a full HTML document) that you want to parse. Perhaps it was provided by a user submitting a comment, or editing the body of a page in a CMS.

Use the `SwiftSoup.parseBodyFragment(_ html : String)` method.

```swift
do{
   let html: String = "<div><p>Lorem ipsum.</p>"
   let doc: Document = try SwiftSoup.parseBodyFragment(html)
   let body: Element? = doc.body()
}catch Exception.Error(let type, let message){
	print(message)
}catch{
	print("error")
}
```

###Use selector syntax to find elements
You want to find or manipulate elements using a CSS or jquery-like selector syntax.
Use the `Element.select(_ selector: String)` and `Elements.select(_ selector: String)` methods:
```swift
do{
	let doc: Document = try SwiftSoup.parse("...")
	let links: Elements = try doc.select("a[href]") // a with href
	let pngs: Elements = try doc.select("img[src$=.png]")
	// img with src ending .png
	let masthead: Element? = try doc.select("div.masthead").first()
	// div with class=masthead
	let resultLinks: Elements? = try doc.select("h3.r > a") // direct a after h3
}catch Exception.Error(let type, let message){
	print(message)
}catch{
	print("error")
}
```


###Set attribute values
You have a parsed document that you would like to update attribute values on, before saving it out to disk, or sending it on as a HTTP response.

```swift
do{
   try doc.select("div.comments a").attr("rel", "nofollow")
}catch Exception.Error(let type, let message){
    print(message)
}catch{
    print("error")
}
```
Like the other methods in `Element, the attr methods return the current `Element` (or `Elements` when working on a collection from a select). This allows convenient method chaining:

```swift
do{
   try doc.select("div.masthead").attr("title", "swiftsoup").addClass("round-box");
}catch Exception.Error(let type, let message){
	print(message)
}catch{
	print("error")
}
```
###Setting the text content of elements
You need to modify the text content of a HTML document.

```swift
do{
   let doc: Document = try! SwiftSoup.parse("")
	let div: Element = try! doc.select("div").first()! // <div></div>
	try div.text("five > four") // <div>five &gt; four</div>
	try div.prepend("First ")
	try div.append(" Last")
	// now: <div>First five &gt; four Last</div>
}catch Exception.Error(let type, let message){
	print(message)
}catch{
	print("error")
}
```


###Sanitize untrusted HTML (to prevent XSS)
You want to allow untrusted users to supply HTML for output on your website (e.g. as comment submission). You need to clean this HTML to avoid cross-site scripting (XSS) attacks.
Use the SwiftSoup HTML Cleaner with a configuration specified by a `Whitelist`.

```swift
do{
	let unsafe: String = "<p><a href='http://example.com/' onclick='stealCookies()'>Link</a></p>"
	let safe: String = try SwiftSoup.clean(unsafe, Whitelist.basic())!
	// now: <p><a href="http://example.com/" rel="nofollow">Link</a></p>
}catch Exception.Error(let type, let message){
	print(message)
}catch{
	print("error")
}
```

###Use DOM methods to navigate a document
You have a HTML document that you want to extract data from. You know generally the structure of the HTML document.
Use the DOM-like methods available after parsing HTML into a `Document¡.

```swift
do{
	let html: String = "<a id=1 href='?foo=bar&mid&lt=true'>One</a> <a id=2 href='?foo=bar&lt;qux&lg=1'>Two</a>"
	let els: Elements = try SwiftSoup.parse(html).select("a")
	for link: Element in els.array(){
    	let linkHref: String = try link.attr("href")
    	let linkText: String = try link.text()
	}
}catch Exception.Error(let type, let message){
	print(message)
}catch{
	print("error")
}
```

####Description
Elements provide a range of DOM-like methods to find elements, and extract and manipulate their data. The DOM getters are contextual: called on a parent Document they find matching elements under the document; called on a child element they find elements under that child. In this way you can winnow in on the data you want.
####Finding elements
* `getElementById(_ id: String)`
* `getElementsByTag(_ tag:String)`
* `getElementsByClass(_ className: String)`
* `getElementsByAttribute(_ key: String)` (and related methods)
* Element siblings: `siblingElements()`, `firstElementSibling()`, `lastElementSibling()`, `nextElementSibling()`, `previousElementSibling()`
* Graph: `parent()`, `children()`, `child(_ index: Int)`

####Element data
* `attr(_ key: Strin)` to get and `attr(_ key: String, _ value: String)` to set attributes
* `attributes()` to get all attributes
* `id()`, `className()` and `classNames()`
* `text()` to get and `text(_ value: String)` to set the text content
* `html()` to get and `html(_ value: String)` to set the inner HTML content
* `outerHtml()` to get the outer HTML value
* `data()` to get data content (e.g. of script and style tags)
* `tag()` and `tagName()`

####Manipulating HTML and text
* `append(_ html: String)`, `prepend(html: String)`
* `appendText(text: String)`, `prependText(text: String)`
* `appendElement(tagName: String)`, `prependElement(tagName: String)`
* `html(_ value: String)`




## Author

Nabil Chatbi, scinfu@gmail.com

## Note
SwiftSoup was ported to Swift from Java [Jsoup](https://jsoup.org/) library.

## License

SwiftSoup is available under the MIT license. See the LICENSE file for more info.
