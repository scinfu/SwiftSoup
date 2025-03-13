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


## Author

Nabil Chatbi, scinfu@gmail.com

## Note
SwiftSoup was ported to Swift from Java [Jsoup](https://jsoup.org/) library.

## License

SwiftSoup is available under the MIT license. See the LICENSE file for more info.
