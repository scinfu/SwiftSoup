<p align="center" >
  <img src="https://raw.githubusercontent.com/scinfu/SwiftSoup/master/swiftsoup.png" alt="SwiftSoup" title="SwiftSoup">
</p>

![Platform OS X | iOS | tvOS | watchOS | Linux](https://img.shields.io/badge/platform-Linux%20%7C%20OS%20X%20%7C%20iOS%20%7C%20tvOS%20%7C%20watchOS-orange.svg)
[![SPM compatible](https://img.shields.io/badge/SPM-compatible-4BC51D.svg?style=flat)](https://github.com/apple/swift-package-manager)
![🐧 linux: ready](https://img.shields.io/badge/%F0%9F%90%A7%20linux-ready-red.svg)
![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)
[![Build Status](https://travis-ci.org/scinfu/SwiftSoup.svg?branch=master)](https://travis-ci.org/scinfu/SwiftSoup)
[![Version](https://img.shields.io/cocoapods/v/SwiftSoup.svg?style=flat)](http://cocoapods.org/pods/SwiftSoup)
[![License](https://img.shields.io/cocoapods/l/SwiftSoup.svg?style=flat)](http://cocoapods.org/pods/SwiftSoup)
[![Twitter](https://img.shields.io/badge/twitter-@scinfu-blue.svg?style=flat)](http://twitter.com/scinfu)

---

SwiftSoup is a pure Swift library designed for seamless HTML parsing and manipulation across multiple platforms, including macOS, iOS, tvOS, watchOS, and Linux. It offers an intuitive API that leverages the best aspects of DOM traversal, CSS selectors, and jQuery-like methods for effortless data extraction and transformation. Built to conform to the **WHATWG HTML5 specification**, SwiftSoup ensures that parsed HTML is structured just like modern browsers do.

### Key Features:
- **Parse and scrape** HTML from a URL, file, or string.
- **Find and extract** data using DOM traversal or CSS selectors.
- **Modify HTML** elements, attributes, and text dynamically.
- **Sanitize user-submitted content** using a safe whitelist to prevent XSS attacks.
- **Generate clean and well-structured HTML** output.

SwiftSoup is designed to handle all types of HTML—whether perfectly structured or messy tag soup—ensuring a logical and reliable parse tree in every scenario.

---

## Swift
Swift 5 ```>=2.0.0```

Swift 4.2 ```1.7.4```

## Installation

### Cocoapods
SwiftSoup is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'SwiftSoup'
```
### Carthage
SwiftSoup is also available through [Carthage](https://github.com/Carthage/Carthage). To install
it, simply add the following line to your Cartfile:

```ruby
github "scinfu/SwiftSoup"
```
### Swift Package Manager
SwiftSoup is also available through [Swift Package Manager](https://github.com/apple/swift-package-manager).
To install it, simply add the dependency to your Package.Swift file:

```swift
...
dependencies: [
    .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.0"),
],
targets: [
    .target( name: "YourTarget", dependencies: ["SwiftSoup"]),
]
...
```
---
## Usage Examples

### Parse an HTML Document

```swift
import SwiftSoup

let html = """
<html><head><title>Example</title></head>
<body><p>Hello, SwiftSoup!</p></body></html>
"""

let document: Document = try SwiftSoup.parse(html)
print(try document.title()) // Output: Example
```

---

### Select Elements with CSS Query

```swift
let html = """
<html><body>
<p class='message'>SwiftSoup is powerful!</p>
<p class='message'>Parsing HTML in Swift</p>
</body></html>
"""

let document = try SwiftSoup.parse(html)
let messages = try document.select("p.message")

for message in messages {
    print(try message.text())
}
// Output:
// SwiftSoup is powerful!
// Parsing HTML in Swift
```

---

### Extract Text and Attributes

```swift
let html = "<a href='https://example.com'>Visit the site</a>"
let document = try SwiftSoup.parse(html)
let link = try document.select("a").first()

if let link = link {
    print(try link.text()) // Output: Visit the site
    print(try link.attr("href")) // Output: https://example.com
}
```

---

### Modify the DOM

```swift
var document = try SwiftSoup.parse("<div id='content'></div>")
let div = try document.select("#content").first()
try div?.append("<p>New content added!</p>")
print(try document.html())
// Output:
// <html><head></head><body><div id="content"><p>New content added!</p></div></body></html>
```

---

### Clean HTML for Security (Whitelist)

```swift
let dirtyHtml = "<script>alert('Hacked!')</script><b>Important text</b>"
let cleanHtml = try SwiftSoup.clean(dirtyHtml, Whitelist.basic())
print(cleanHtml) // Output: <b>Important text</b>
```

---
### Use CSS selectors to find elements
(from [jsoup](https://jsoup.org/cookbook/extracting-data/selector-syntax))

#### Selector overview

- `tagname`: find elements by tag, e.g. `div`
- `#id`: find elements by ID, e.g. `#logo`
- `.class`: find elements by class name, e.g. `.masthead`
- `[attribute]`: elements with attribute, e.g. `[href]`
- `[^attrPrefix]`: elements with an attribute name prefix, e.g. `[^data-]` finds elements with HTML5 dataset attributes
- `[attr=value]`: elements with attribute value, e.g. `[width=500]` (also quotable, like `[data-name='launch sequence']`)
- `[attr^=value]`, `[attr$=value]`, `[attr*=value]`: elements with attributes that start with, end with, or contain the value, e.g. `[href*=/path/]`
- `[attr~=regex]`: elements with attribute values that match the regular expression; e.g. `img[src~=(?i)\.(png|jpe?g)]`
- `*`: all elements, e.g. `*`
- `[*]` selects elements that have any attribute. e.g. `p[*]` finds paragraphs with at least one attribute, and `p:not([*])` finds those with no attributes.
- `ns|tag`: find elements by tag in a namespace prefix, e.g. `dc|name` finds `<dc:name>` elements
- `*|tag`: find elements by tag in any namespace prefix, e.g. `*|name` finds `<dc:name>` and `<name>` elements
- `:empty`: selects elements that have no children (ignoring blank text nodes, comments, etc.); e.g. `li:empty`

#### Selector combinations

- `el#id`: elements with ID, e.g. `div#logo`
- `el.class`: elements with class, e.g. `div.masthead`
- `el[attr]`: elements with attribute, e.g. `a[href]`
- Any combination, e.g. `a[href].highlight`
- `ancestor child`: child elements that descend from ancestor, e.g. `.body p` finds `p` elements anywhere under a block with class "body"
- `parent > child`: child elements that descend directly from parent, e.g. `div.content > p` finds `p` elements; and `body > *` finds the direct children of the body tag
- `siblingA + siblingB`: finds sibling B element immediately preceded by sibling A, e.g. `div.head + div`
- `siblingA ~ siblingX`: finds sibling X element preceded by sibling A, e.g. `h1 ~ p`
- `el, el, el`: group multiple selectors, find unique elements that match any of the selectors; e.g. `div.masthead, div.logo`

#### Pseudo selectors

- `:has(selector)`: find elements that contain elements matching the selector; e.g. `div:has(p)`
- `:is(selector)`: find elements that match any of the selectors in the selector list; e.g. `:is(h1, h2, h3, h4, h5, h6)` finds any heading element
- `:not(selector)`: find elements that do not match the selector; e.g. `div:not(.logo)`
- `:lt(n)`: find elements whose sibling index (i.e. its position in the DOM tree relative to its parent) is less than `n`; e.g. `td:lt(3)`
- `:gt(n)`: find elements whose sibling index is greater than `n`; e.g. `div p:gt(2)`
- `:eq(n)`: find elements whose sibling index is equal to `n`; e.g. `form input:eq(1)`
- Note that the above indexed pseudo-selectors are 0-based, that is, the first element is at index 0, the second at 1, etc

#### Text content pseudo selectors

- `:contains(text)`: find elements that contain (directly or via children) the given normalized text. The search is case-insensitive; e.g. `div:contains(jsoup)`
- `:containsOwn(text)`: find elements whose own text directly contains the given text. e.g. `p:containsOwn(jsoup)`
- `:containsData(text)`: selects elements that contain the specified data (e.g. within `<script>`, `<style>`, or comments); e.g. `script:containsData(jsoup)`
- `:containsWholeText(text)`: selects elements that contain the exact, non-normalized whole text (case sensitive, preserving whitespace/newlines); e.g. `p:containsWholeText(jsoup The Java HTML Parser)`
- `:containsWholeOwnText(text)`: selects elements whose own text exactly matches the given non-normalized text (case sensitive); e.g. `p:containsWholeOwnText(jsoup The Java HTML Parser)`
- `:matches(regex)`: find elements whose text matches the specified regular expression; e.g. `div:matches((?i)login)`
- `:matchesOwn(regex)`: find elements whose own text matches the specified regular expression
- `:matchesWholeText(regex)`: selects elements whose entire, non-normalized text matches the specified regex; e.g. `div:matchesWholeText(\d{3}-\d{2}-\d{4})`
- `:matchesWholeOwnText(regex)`: selects elements whose own non-normalized text matches the regex; e.g. `span:matchesWholeOwnText(\w+)`

#### Structural pseudo selectors

- `:root`: selects the root element of the document (in HTML, the `<html>` element); e.g. `:root`
- `:nth-child(an+b)`: selects elements with an+b–1 preceding siblings; supports expressions like `2n+1` for odd elements; e.g. `tr:nth-child(2n+1)`
- `:nth-last-child(an+b)`: selects elements with an+b–1 following siblings; e.g. `tr:nth-last-child(-n+2)`
- `:nth-of-type(an+b)`: selects elements based on their position among siblings of the same type; e.g. `img:nth-of-type(2n+1)`
- `:nth-last-of-type(an+b)`: selects elements based on their position among siblings of the same type, counting from the end; e.g. `img:nth-last-of-type(2n+1)`
- `:first-child`: selects elements that are the first child of their parent; e.g. `div > p:first-child`
- `:last-child`: selects elements that are the last child of their parent; e.g. `ol > li:last-child`
- `:first-of-type`: selects the first element of its type among its siblings; e.g. `dl dt:first-of-type`
- `:last-of-type`: selects the last element of its type among its siblings; e.g. `tr > td:last-of-type`
- `:only-child`: selects elements that are the only child of their parent; e.g. `div:only-child`
- `:only-of-type`: selects elements that are the only element of their type among their siblings; e.g. `span:only-of-type`

#### Optimize repeated queries

To speed up queries that are done repeatedly, consider parsing the query upfront and passing an `Evaluator` instead of query string.
Since `Evaluator` instances are immutable they are safe to store in (static) properties or pass across isolation boundaries. 

```swift
let elements: Elements = …
let eval = try QueryParser.parse("div > p")
for element in elements {
    print(try element.select(eval).text())
}
```

---

## Author

Nabil Chatbi, scinfu@gmail.com

Current maintainer: Alex Ehlke, available for hire for SwiftSoup related work or other iOS projects: alex dot ehlke at gmail

## Note
SwiftSoup was ported to Swift from Java [Jsoup](https://jsoup.org/) library.

## License

SwiftSoup is available under the MIT license. See the [LICENSE](https://github.com/scinfu/SwiftSoup/blob/master/LICENSE) file for more info.
