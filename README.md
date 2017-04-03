# SwiftSoup
![Platform OS X | iOS | tvOS | watchOS | Linux](https://img.shields.io/badge/platform-Linux%20%7C%20OS%20X%20%7C%20iOS%20%7C%20tvOS%20%7C%20watchOS-orange.svg)
[![SPM compatible](https://img.shields.io/badge/SPM-compatible-4BC51D.svg?style=flat)](https://github.com/apple/swift-package-manager)
![🐧 linux: ready](https://img.shields.io/badge/%F0%9F%90%A7%20linux-ready-red.svg)
![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)
[![Build Status](https://travis-ci.org/scinfu/SwiftSoup.svg?branch=master)](https://travis-ci.org/scinfu/SwiftSoup)
[![Version](https://img.shields.io/cocoapods/v/SwiftSoup.svg?style=flat)](http://cocoapods.org/pods/SwiftSoup)
[![License](https://img.shields.io/cocoapods/l/SwiftSoup.svg?style=flat)](http://cocoapods.org/pods/SwiftSoup)
[![Twitter](https://img.shields.io/badge/twitter-@scinfu-blue.svg?style=flat)](http://twitter.com/scinfu)

`SwiftSoup` is a pure Swift library for working with real-world HTML. It provides a very convenient API for extracting and manipulating data, using the best of DOM, CSS, and jquery-like methods.
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

# To parse an HTML document:

```swift
do{
   let html = "<html><head><title>First parse</title></head>"
			+ "<body><p>Parsed HTML into a doc.</p></body></html>"
   let doc: Document = try SwiftSoup.parse(html)
   return try doc.text()
}catch Exception.Error(let type, let message){
	print(message)
}catch{
	print("error")
}
```

*   unclosed tags (e.g. `<p>Lorem <p>Ipsum` parses to `<p>Lorem</p> <p>Ipsum</p>`)
*   implicit tags (e.g. a naked `<td>Table data</td>` is wrapped into a `<table><tr><td>...`)
*  reliably creating the document structure (`html` containing a `head` and `body`, and only appropriate elements within the head)


### The object model of a document
* Documents consist of Elements and TextNodes
* The inheritance chain is: `Document` extends `Element` extends `Node.TextNode` extends `Node`.
* An Element contains a list of children Nodes, and has one parent Element. They also have provide a filtered list of child Elements only.



# Extract attributes, text, and HTML from elements
### Problem
After parsing a document, and finding some elements, you'll want to get at the data inside those elements.
### Solution
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

### Description
The methods above are the core of the element data access methods. There are additional others:
- `Element.id()`
- `Element.tagName()`
- `Element.className()` and `Element.hasClass(_ String className)`

All of these accessor methods have corresponding setter methods to change the data.





# Parse a document from a String
### Problem
You have HTML in a Swift String, and you want to parse that HTML to get at its contents, or to make sure it's well formed, or to modify it. The String may have come from user input, a file, or from the web.
### Solution
Use the static `SwiftSoup.parse(_ html : String)` method, or `SwiftSoup.parse(_ html : String, : baseUri: String)`.

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
### Description
The `parse(_ html : String, : baseUri: String)` method parses the input HTML into a new `Document`. The base URI argument is used to resolve relative URLs into absolute URLs, and should be set to the URL where the document was fetched from. If that's not applicable, or if you know the HTML has a base element, you can use the `parse(_ html : String)` method.

As long as you pass in a non-null string, you're guaranteed to have a successful, sensible parse, with a Document containing (at least) a `head` and a `body` element.

Once you have a `Document`, you can get get at the data using the appropriate methods in `Document` and its supers `Element` and `Node`.



# Parsing a body fragment
### Problem
You have a fragment of body HTML (e.g. `div` containing a couple of p tags; as opposed to a full HTML document) that you want to parse. Perhaps it was provided by a user submitting a comment, or editing the body of a page in a CMS.
### Solution
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

### Description
The `parseBodyFragment` method creates an empty shell document, and inserts the parsed HTML into the `body` element. If you used the normal `SwiftSoup(_ html: String)` method, you would generally get the same result, but explicitly treating the input as a body fragment ensures that any bozo HTML provided by the user is parsed into the `body` element.

The `Document.body()` method retrieves the element children of the document's `body` element; it is equivalent to `doc.getElementsByTag("body")`.

### Stay safe
If you are going to accept HTML input from a user, you need to be careful to avoid cross-site scripting attacks. See the documentation for the `Whitelist` based cleaner, and clean the input with `clean(String bodyHtml, Whitelist whitelist)`.





# Sanitize untrusted HTML (to prevent XSS)
### Problem
You want to allow untrusted users to supply HTML for output on your website (e.g. as comment submission). You need to clean this HTML to avoid [cross-site scripting](https://en.wikipedia.org/wiki/Cross-site_scripting) (XSS) attacks.
### Solution
Use the SwiftSoup HTML `Cleaner` with a configuration specified by a `Whitelist`.

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

### Discussion
A cross-site scripting attack against your site can really ruin your day, not to mention your users'. Many sites avoid XSS attacks by not allowing HTML in user submitted content: they enforce plain text only, or use an alternative markup syntax like wiki-text or Markdown. These are seldom optimal solutions for the user, as they lower expressiveness, and force the user to learn a new syntax.

A better solution may be to use a rich text WYSIWYG editor (like [CKEditor](http://ckeditor.com) or [TinyMCE](https://www.tinymce.com)). These output HTML, and allow the user to work visually. However, their validation is done on the client side: you need to apply a server-side validation to clean up the input and ensure the HTML is safe to place on your site. Otherwise, an attacker can avoid the client-side Javascript validation and inject unsafe HMTL directly into your site

The swiftsoup whitelist sanitizer works by parsing the input HTML (in a safe, sand-boxed environment), and then iterating through the parse tree and only allowing known-safe tags and attributes (and values) through into the cleaned output.

It does not use regular expressions, which are inappropriate for this task.

swiftsoup provides a range of `Whitelist` configurations to suit most requirements; they can be modified if necessary, but take care.

The cleaner is useful not only for avoiding XSS, but also in limiting the range of elements the user can provide: you may be OK with textual `a`, `strong` elements, but not structural `div` or `table` elements.

### See also
- See the [XSS cheat sheet](http://ha.ckers.org/xss.html) and filter evasion guide, as an example of how regular-expression filters don't work, and why a safe whitelist parser-based sanitizer is the correct approach.
- See the `Cleaner` reference if you want to get a `Document` instead of a String return
- See the `Whitelist reference for the different canned options, and to create a custom whitelist
- The [nofollow](https://en.wikipedia.org/wiki/Nofollow) link attribute




# Set attribute values
### Problem
You have a parsed document that you would like to update attribute values on, before saving it out to disk, or sending it on as a HTTP response.

### Solution
Use the attribute setter methods `Element.attr(_ key: String, _ value: String)`, and `Elements.attr(_ String: key, _ value: String)`.

If you need to modify the class attribute of an element, use the `Element.addClass(_ className: String)` and `Element.removeClass(_ className: String)` methods.

The `Elements collection has bulk attribue and class methods. For example, to add a `rel="nofollow" attribute to every `a` element inside a div:

```swift
do{
   try doc.select("div.comments a").attr("rel", "nofollow")
}catch Exception.Error(let type, let message){
	print(message)
}catch{
	print("error")
}
```
### Description
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


# Set the HTML of an element
### Problem
You need to modify the HTML of an element.
### Solution
Use the HTML setter methods in `Element`:
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
	print(message)
}catch{
	print("error")
}
```
### Discussion
- `Element.html(_ html: String)` clears any existing inner HTML in an element, and replaces it with parsed HTML.
- `Element.prepend(_ first: String)` and `Element.append(_ last: String)` add HTML to the start or end of an element's inner HTML, respectively
- `Element.wrap(_ around: String)` wraps HTML around the outer HTML of an element.

### See also
You can also use the `Element.prependElement(_ tag: String)` and `Element.appendElement(_ tag: String)` methods to create new elements and insert them into the document flow as a child element.





# Setting the text content of elements
### Problem
You need to modify the text content of a HTML document.
# Solution
Use the text setter methods of `Element`:

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

### Discussion
The text setter methods mirror the [[HTML setter|Set the HTML of an element]] methods:
- `Element.text(_ text: String)` clears any existing inner HTML in an element, and replaces it with the supplied text.
- `Element.prepend(_ first: String)` and `Element.append(_ last: String)` add text nodes to the start or end of an element's inner HTML, respectively
The text should be supplied unencoded: characters like `<`, `>` etc will be treated as literals, not HTML.





# Use DOM methods to navigate a document
### Problem
You have a HTML document that you want to extract data from. You know generally the structure of the HTML document.

### Solution
Use the DOM-like methods available after parsing HTML into a `Document`.

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
### Description
Elements provide a range of DOM-like methods to find elements, and extract and manipulate their data. The DOM getters are contextual: called on a parent Document they find matching elements under the document; called on a child element they find elements under that child. In this way you can winnow in on the data you want.
### Finding elements
* `getElementById(_ id: String)`
* `getElementsByTag(_ tag:String)`
* `getElementsByClass(_ className: String)`
* `getElementsByAttribute(_ key: String)` (and related methods)
* Element siblings: `siblingElements()`, `firstElementSibling()`, `lastElementSibling()`, `nextElementSibling()`, `previousElementSibling()`
* Graph: `parent()`, `children()`, `child(_ index: Int)`

# Element data
* `attr(_ key: Strin)` to get and `attr(_ key: String, _ value: String)` to set attributes
* `attributes()` to get all attributes
* `id()`, `className()` and `classNames()`
* `text()` to get and `text(_ value: String)` to set the text content
* `html()` to get and `html(_ value: String)` to set the inner HTML content
* `outerHtml()` to get the outer HTML value
* `data()` to get data content (e.g. of script and style tags)
* `tag()` and `tagName()`

### Manipulating HTML and text
* `append(_ html: String)`, `prepend(html: String)`
* `appendText(text: String)`, `prependText(text: String)`
* `appendElement(tagName: String)`, `prependElement(tagName: String)`
* `html(_ value: String)`












# Use selector syntax to find elements
### Problem
You want to find or manipulate elements using a CSS or jquery-like selector syntax.
### Solution
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
### Description
SwifSoup elements support a [CSS](https://www.w3.org/TR/2009/PR-css3-selectors-20091215/) (or [jquery](http://jquery.com)) like selector syntax to find matching elements, that allows very powerful and robust queries.

The `select` method is available in a `Document`, `Element`, or in `Elements`. It is contextual, so you can filter by selecting from a specific element, or by chaining select calls.

Select returns a list of `Elements` (as `Elements`), which provides a range of methods to extract and manipulate the results.
### Selector overview
* `tagname`: find elements by tag, e.g. `a`
* `ns|tag`: find elements by tag in a namespace, e.g. `fb|name` finds `<fb:name>` elements
* `#id`: find elements by ID, e.g. `#logo`
* `.class`: find elements by class name, e.g. `.masthead`
* `[attribute]`: elements with attribute, e.g. `[href]`
* `[^attr]`: elements with an attribute name prefix, e.g. `[^data-]` finds elements with HTML5 dataset attributes
* `[attr=value]`: elements with attribute value, e.g. `[width=500]` (also quotable, like `[data-name='launch sequence']`)
* `[attr^=value]`, `[attr$=value]`, `[attr*=value]`: elements with attributes that start with, end with, or contain the value, e.g. `[href*=/path/]`
* `[attr~=regex]`: elements with attribute values that match the regular expression; e.g. `img[src~=(?i)\.(png|jpe?g)]`
* `*`: all elements, e.g. `*`
### Selector combinations
* `el#id`: elements with ID, e.g. `div#logo`
* `el.class`: elements with class, e.g. `div.masthead`
* `el[attr]`: elements with attribute, e.g. `a[href]`
* Any combination, e.g. `a[href].highlight`
* ancestor `child`: child elements that descend from ancestor, e.g. `.body p` finds `p` elements anywhere under a block with class "body"
* `parent > child`: child elements that descend directly from parent, e.g. `div.content > p` finds p elements; and `body > *` finds the direct children of the body tag
* `siblingA + siblingB`: finds sibling B element immediately preceded by sibling A, e.g. `div.head + div`
* `siblingA ~ siblingX`: finds sibling X element preceded by sibling A, e.g. `h1 ~ p`
* `el`, `el`, `el`: group multiple selectors, find unique elements that match any of the selectors; e.g. `div.masthead`, `div.logo`

### Pseudo selectors
* `:lt(n)`: find elements whose sibling index (i.e. its position in the DOM tree relative to its parent) is less than n; e.g. `td:lt(3)`
* `:gt(n)`: find elements whose sibling index is greater than n; e.g. `div p:gt(2)`
* `:eq(n)`: find elements whose sibling index is equal to n; e.g. `form input:eq(1)`
* `:has(seletor)`: find elements that contain elements matching the selector; e.g. `div:has(p)`
* `:not(selector)`: find elements that do not match the selector; e.g. `div:not(.logo)`
* `:contains(text)`: find elements that contain the given text. The search is case-insensitive; e.g. `p:contains(swiftsoup)`
* `:containsOwn(text)`: find elements that directly contain the given text
* `:matches(regex)`: find elements whose text matches the specified regular expression; e.g. `div:matches((?i)login)`
* `:matchesOwn(regex)`: find elements whose own text matches the specified regular expression
* Note that the above indexed pseudo-selectors are 0-based, that is, the first element is at index 0, the second at 1, etc







## Author

Nabil Chatbi, scinfu@gmail.com

## Note
SwiftSoup was ported to Swift from Java [Jsoup](https://jsoup.org/) library.

## License

SwiftSoup is available under the MIT license. See the LICENSE file for more info.
