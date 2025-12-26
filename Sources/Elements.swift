//
//  Elements.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 20/10/16.
//

import Foundation

/// A list of ``Element``s, with methods that act on every element in the list.
///
/// To get an `Elements` object, use the ``Element/select(_:)-(String)`` method.
open class Elements: NSCopying {
	fileprivate var this: Array<Element> = Array<Element>()

	/// Base initializer.
	public init() {
	}
	/// Initialize with an array of elements.
	public init(_ a: Array<Element>) {
		this = a
	}
	/// Initialize with an ordered set of elements.
	public init(_ a: OrderedSet<Element>) {
		this.append(contentsOf: a)
	}


	/**
	 Creates a deep copy of these elements.
	 - returns: a deep copy
	*/
	public func copy(with zone: NSZone? = nil) -> Any {
		let clone: Elements = Elements()
		for e: Element in this {
			clone.add(e.copy() as! Element)
		}
		return clone
	}
	
	
	// MARK: Attribute methods
	
	/**
	 Get an attribute value from the first matched element that has the attribute.
	 - parameter attributeKey: The attribute key.
	 - returns: The attribute value from the first matched element that has the attribute.. If no elements were matched (isEmpty() == true),
	 or if the no elements have the attribute, returns empty string.
	 
	 - seealso: ``hasAttr(_:)``
	*/
	open func attr(_ attributeKey: String) throws -> String {
		for element in this {
			if (element.hasAttr(attributeKey)) {
				return try element.attr(attributeKey)
			}
		}
		return ""
	}

	/**
	 Checks if any of the matched elements have this attribute set.
	 - parameter attributeKey: attribute key
	 - returns: true if any of the elements have the attribute; false if none do.
	*/
	open func hasAttr(_ attributeKey: String) -> Bool {
		for element in this {
			if element.hasAttr(attributeKey) {return true}
		}
		return false
	}

	/**
	 Set an attribute on all matched elements.
	 - parameter attributeKey: attribute key
	 - parameter attributeValue: attribute value
	 - returns: this
	*/
	@discardableResult
	open func attr(_ attributeKey: String, _ attributeValue: String)throws->Elements {
		for element in this {
			try element.attr(attributeKey, attributeValue)
		}
		return self
	}

	/**
	 Remove an attribute from every matched element.
	 - parameter attributeKey: The attribute to remove.
	 - returns: this (for chaining)
	*/
	@discardableResult
	open func removeAttr(_ attributeKey: String) throws -> Elements {
		for  element in this {
			try element.removeAttr(attributeKey)
		}
		return self
	}

	/**
	 Add the class name to every matched element's `class` attribute.
	 - parameter className: class name to add
	 - returns: this
	*/
	@discardableResult
	open func addClass(_ className: String)throws->Elements {
		for  element in this {
			try element.addClass(className)
		}
		return self
	}

	/**
	 Remove the class name from every matched element's `class` attribute, if present.
	 - parameter className: class name to remove
	 - returns: this
	*/
	@discardableResult
	open func removeClass(_ className: String)throws->Elements {
		for element: Element in this {
			try element.removeClass(className)
		}
		return self
	}

	/**
	 Toggle the class name on every matched element's `class` attribute.
	 - parameter className: class name to add if missing, or remove if present, from every element.
	 - returns: this
	*/
	@discardableResult
	open func toggleClass(_ className: String)throws->Elements {
		for element: Element in this {
			try element.toggleClass(className)
		}
		return self
	}

	/**
	 Determine if any of the matched elements have this class name set in their `class` attribute.
	 - parameter className: class name to check for
	 - returns: true if any do, false if none do
	*/
	open func hasClass(_ className: String) -> Bool {
		for element: Element in this {
			if (element.hasClass(className)) {
				return true
			}
		}
		return false
	}
	
	
	// MARK: Queries
	
	/**
	 Get the form element's value of the first matched element.
	 - returns: The form element's value, or empty if not set.
	 - seealso: ``val()``
	*/
	open func val()throws->String {
		if (size() > 0) {
			return try first()!.val()
		}
		return ""
	}

	/**
	 Set the form element's value in each of the matched elements.
	 - parameter value: The value to set into each matched element
	 - returns: this (for chaining)
	*/
	@discardableResult
	open func val(_ value: String)throws->Elements {
		for element: Element in this {
			try element.val(value)
		}
		return self
	}

	/**
	 Get the combined text of all the matched elements.
	 
	 Note that it is possible to get repeats if the matched elements contain both parent elements and their own
	 children, as the ``Element/text(_:)`` method returns the combined text of a parent and all its children.
	 - returns: string of all text: unescaped and no HTML.
	 - seealso: ``Element/text(_:)``
	*/
	open func text(trimAndNormaliseWhitespace: Bool = true)throws->String {
		let sb: StringBuilder = StringBuilder()
		for element: Element in this {
			if !sb.isEmpty {
				sb.append(UTF8Arrays.whitespace)
			}
			sb.append(try element.text(trimAndNormaliseWhitespace: trimAndNormaliseWhitespace))
		}
		return sb.toString()
	}

	/// Check if an element has text
	open func hasText() -> Bool {
		for element: Element in this {
			if (element.hasText()) {
				return true
			}
		}
		return false
	}
	
	/**
	 Get the text content of each of the matched elements. If an element has no text, then it is not included in the
	 result.
	 
	 - returns: A list of each matched element's text content.
	 - seealso: ``Element/text(_:)``, ``Element/hasText()``, ``text(trimAndNormaliseWhitespace:)``
	 */
	public func eachText()throws->Array<String> {
		return try this.compactMap { $0.hasText() ? try $0.text() : nil }
	}
	
	/**
	 Get the combined inner HTML of all matched elements.
	 - returns: string of all element's inner HTML.
	 - seealso: ``text(trimAndNormaliseWhitespace:)``, ``outerHtml()``
	*/
	open func html()throws->String {
		let sb: StringBuilder = StringBuilder()
		for element: Element in this {
			if !sb.isEmpty {
				sb.append("\n")
			}
			sb.append(try element.html())
		}
		return sb.toString()
	}

	/**
	 Get the combined outer HTML of all matched elements.
	 - returns: string of all element's outer HTML.
	 - seealso: ``text(trimAndNormaliseWhitespace:)``, ``html()``
	*/
	open func outerHtml()throws->String {
		let sb: StringBuilder = StringBuilder()
		for element in this {
			if !sb.isEmpty {
				sb.append("\n")
			}
			sb.append(try element.outerHtml())
		}
		return sb.toString()
	}

	/**
	 Get the combined outer HTML of all matched elements. Alias of ``outerHtml()``.
	 - returns: string of all element's outer HTML.
	 - seealso: ``text(trimAndNormaliseWhitespace:)``, ``html()``
	*/
	open func toString()throws->String {
		return try outerHtml()
	}

	/**
	 Update the tag name of each matched element. For example, to change each `<i>` to a `<em>`, do
	 `doc.select("i").tagName("em")`.
	 
	 - parameter tagName: the new tag name
	 - returns: this, for chaining
	 - seealso: ``Element/tagName(_:)-(String)``
	*/
	@discardableResult
	open func tagName(_ tagName: String) throws -> Elements {
		for element: Element in this {
			try element.tagName(tagName)
		}
		return self
	}

	/**
	 Set the inner HTML of each matched element.
	 - parameter html: HTML to parse and set into each matched element.
	 - returns: this, for chaining
	 - seealso: ``Element/html(_:)-(String)``
	*/
	@discardableResult
	open func html(_ html: String)throws->Elements {
		for element: Element in this {
			try element.html(html)
		}
		return self
	}
	
	
	// MARK: Manipulations

	/**
	 Add the supplied HTML to the start of each matched element's inner HTML.
	 - parameter html: HTML to add inside each element, before the existing HTML
	 - returns: this, for chaining
	 - seealso ``Element/prepend(_:)``
	*/
	@discardableResult
	open func prepend(_ html: String)throws->Elements {
		for element: Element in this {
			try element.prepend(html)
		}
		return self
	}

	/**
	 Add the supplied HTML to the end of each matched element's inner HTML.
	 - parameter html: HTML to add inside each element, after the existing HTML
	 - returns: this, for chaining
	 - seealso: ``Element/append(_:)``
	*/
	@discardableResult
	open func append(_ html: String)throws->Elements {
		for element: Element in this {
			try element.append(html)
		}
		return self
	}

	/**
	 Insert the supplied HTML before each matched element's outer HTML.
	 - parameter html: HTML to insert before each element
	 - returns: this, for chaining
	 - seealso: ``Element/before(_:)-(String)``
	*/
	@discardableResult
	open func before(_ html: String)throws->Elements {
		for element: Element in this {
			try element.before(html)
		}
		return self
	}

	/**
	 Insert the supplied HTML after each matched element's outer HTML.
	 - parameter html: HTML to insert after each element
	 - returns: this, for chaining
	 - seealso: ``Element/after(_:)-(String)``
	*/
	@discardableResult
	open func after(_ html: String)throws->Elements {
		for element: Element in this {
			try element.after(html)
		}
		return self
	}

	/**
	 Wrap the supplied HTML around each matched elements.
	 
	 For example, with the input HTML:
	 ```html
	 <p><b>This</b> is <b>SwiftSoup</b></p>
	 ```
	 
	 The following call:
	 ```swift
	 doc.select("b").wrap("<i></i>")
	 ```
	 
	 produces:
	 ```html
	 <p><i><b>This</b></i> is <i><b>SwiftSoup</b></i></p>
	 ```
	 
	 - parameter html: HTML to wrap around each element, e.g. `<div class="head"></div>`. Can be arbitrarily deep.
	 - returns: this (for chaining)
	 - seealso: ``Element/wrap(_:)``
	*/
	@discardableResult
	open func wrap(_ html: String)throws->Elements {
		try Validate.notEmpty(string: html)
		for element: Element in this {
			try element.wrap(html)
		}
		return self
	}

	/**
	 Removes the matched elements from the DOM, and moves their children up into their parents. This has the effect of
	 dropping the elements but keeping their children.
	 
	 This is useful for e.g removing unwanted formatting elements but keeping their contents.
	 
	 E.g. given the HTML input:
	 ```html
	 <div><font>One</font> <font><a href="/">Two</a></font></div>
	 ```
	 
	 Using the call:
	 ```swift
	 doc.select("font").unwrap()
	 ```
	 
	 produces:
	 ```html
	 <div>One <a href="/">Two</a></div>
	 ```
	 
	 - returns: this (for chaining)
	 - seealso: ``Node/unwrap()``
	*/
	@discardableResult
	open func unwrap()throws->Elements {
		for element: Element in this {
			try element.unwrap()
		}
		return self
	}

	/**
	 Empty (remove all child nodes from) each matched element. This is similar to setting the inner HTML of each
	 element to nothing.
	 
	 E.g. given the HTML input:
	 ```html
	 <div><p>Hello <b>there</b></p> <p>now</p></div>
	 ```
	 
	 The following code:
	 ```swift
	 doc.select("p").empty()
	 ```
	 
	 produces:
	 ```html
	 <div><p></p> <p></p></div>
	 ```
	 
	 - returns: this, for chaining
	 - seealso: ``Element/empty()``, ``remove()``
	*/
	@discardableResult
	open func empty() -> Elements {
		for element: Element in this {
			element.empty()
		}
		return self
	}

	/**
	 Remove each matched element from the DOM. This is similar to setting the outer HTML of each element to nothing.
	 
	 E.g. with the HTML input:
	 ```html
	 <div><p>Hello</p> <p>there</p> <img /></div>
	 ```
	 
	 The following call:
	 ```swift
	 doc.select("p").remove()
	 ```
	 
	 produces:
	 ```html
	 <div> <img /></div>
	 ```
	 
	 - note: This method should not be used to clean user-submitted HTML; rather, use ``Cleaner`` to clean HTML.
	 - returns: this, for chaining
	 - seealso: ``Element/empty()``, ``empty()``
	*/
	@discardableResult
	open func remove()throws->Elements {
		for element in this {
			try element.remove()
		}
		return self
	}

	// MARK: Filters

	/**
	 Find matching elements within this element list.
	 - parameter query: A ``CssSelector`` query
	 - returns: the filtered list of elements, or an empty list if none match.
	*/
	open func select(_ query: String)throws->Elements {
		return try CssSelector.select(query, this)
	}

	/**
	 Find matching elements within this element list.
	 - parameter evaluator: A CSS evaluator.
	 - seealso: ``QueryParser``
	 - returns: the filtered list of elements, or an empty list if none match.
	*/
	open func select(_ evaluator: Evaluator)throws->Elements {
		return try CssSelector.select(evaluator, this)
	}

	/**
	 Remove elements from this list that match the ``CssSelector`` query.
	 
	 E.g. with the HTML input:
	 ```html
	 <div class=logo>One</div> <div>Two</div>
	 ```
	 
	 The following code:
	 ```swift
	doc.select("div").not(".logo")
	 ```
	 
	 produces an ``Elements`` instance containing:
	 ```html
	 <div>Two</div>
	 ```
	 
	 - parameter query: The selector query whose results should be removed from these elements
	 - returns: A new elements list that contains only the filtered results
	*/
	open func not(_ query: String)throws->Elements {
		let out: Elements = try CssSelector.select(query, this)
		return CssSelector.filterOut(this, out.this)
	}

	/**
	 Remove elements from this list that match the ``Evaluator``.
	 - parameter evaluator: The evaluator for the CSS selector query whose results should be removed from these elements.
	 - seealso: ``QueryParser``
	 - returns: A new elements list that contains only the filtered results.
	*/
	open func not(_ evaluator: Evaluator)throws->Elements {
		let out: Elements = try CssSelector.select(evaluator, this)
		return CssSelector.filterOut(this, out.this)
	}

	/**
	 Get the _nth_ matched element as an Elements object.
	 
	 - seealso: ``get(_:)`` to retrieve an Element.
	 - parameter index: the (zero-based) index of the element in the list to retain
	 - returns: Elements containing only the specified element, or, if that element did not exist, an empty list.
	*/
	open func eq(_ index: Int) -> Elements {
		return size() > index ? Elements([get(index)]) : Elements()
	}

	/**
	 Test if any of the matched elements match the supplied query.
	 
	 - parameter query: A selector
	 - returns: true if at least one element in the list matches the query.
	*/
	open func iS(_ query: String)throws->Bool {
		let eval: Evaluator = try QueryParser.parse(query)
		for  e: Element in this {
			if (try e.iS(eval)) {
				return true
			}
		}
		return false
	}
	
	/**
	 Test if any of the matched elements match the supplied query.
	 
	 - parameter eval: An evaluator
	 - returns: true if at least one element in the list matches the query.
	*/
	open func iS(_ eval: Evaluator)throws->Bool {
		for  e: Element in this {
			if (try e.iS(eval)) {
				return true
			}
		}
		return false
	}
	
	/**
	 Get all of the parents and ancestor elements of the matched elements.
	 - returns: all of the parents and ancestor elements of the matched elements
	*/

	open func parents() -> Elements {
		let combo: OrderedSet<Element> = OrderedSet<Element>()
		for e: Element in this {
			combo.append(contentsOf: e.parents().array())
		}
		return Elements(combo)
	}
	
	
	// MARK: List-like methods
	
	/**
	Get the first matched element.
	- returns: The first matched element, or `nil` if content is empty.
	*/
	open func first() -> Element? {
		return isEmpty() ? nil : get(0)
	}

	/// Check if the receiver contains no elemens.
	open func isEmpty() -> Bool {
		return array().isEmpty
	}

	/// Get the elements count.
	open func size() -> Int {
		return array().count
	}

	/**
	Get the last matched element.
	- returns: The last matched element, or `nil` if content is empty.
	*/
	open func last() -> Element? {
		return isEmpty() ? nil : get(size() - 1)
	}

	/**
	 Perform a depth-first traversal on each of the selected elements.
	 - parameter nodeVisitor: the visitor callbacks to perform on each node
	 - returns: this, for chaining
	*/
	@discardableResult
	open func traverse(_ nodeVisitor: NodeVisitor)throws->Elements {
		let traversor: NodeTraversor = NodeTraversor(nodeVisitor)
		for el: Element in this {
			try traversor.traverse(el)
		}
		return self
	}

	/**
	 Get the ``FormElement`` forms from the selected elements, if any.
	 - returns: a list of ``FormElement``s pulled from the matched elements. The list will be empty if the elements contain
	 no forms.
	*/
	open func forms()->Array<FormElement> {
		return this.compactMap { $0 as? FormElement }
	}

	/**
	 Appends the specified element to the end of this list.
	 
	 - parameter e: element to be appended to this list
	*/
	@inline(__always)
	open func add(_ e: Element) {
		this.append(e)
	}

	/**
	 Insert the specified element at index.
	*/
	@inline(__always)
	open func add(_ index: Int, _ element: Element) {
		this.insert(element, at: index)
	}

	/// Return element at index.
	/// - warning: Crashes if the index is out of bounds!
	@inline(__always)
	open func get(_ i: Int) -> Element {
		return this[i]
	}

	/// Returns all elements.
	open func array() -> Array<Element> {
		return this
	}
}


// MARK: - Equatable
extension Elements: Equatable {
	/// Returns a Boolean value indicating whether two values are equal.
	///
	/// Equality is the inverse of inequality. For any values `a` and `b`,
	/// `a == b` implies that `a != b` is `false`.
	///
	/// - Parameters:
	///   - lhs: A value to compare.
	///   - rhs: Another value to compare.
	public static func ==(lhs: Elements, rhs: Elements) -> Bool {
		return lhs.this == rhs.this
	}
}

// MARK: - RandomAccessCollection
extension Elements: RandomAccessCollection {
	public subscript(position: Int) -> Element {
		return this[position]
	}

	public var startIndex: Int {
		return this.startIndex
	}

	public var endIndex: Int {
		return this.endIndex
	}

	/// The number of Element objects in the collection.
	/// Equivalent to ``size()``.
	public var count: Int {
		return this.count
	}
}


// MARK: - IteratorProtocol
public struct ElementsIterator: IteratorProtocol {
	/// Elements reference
	let elements: Elements
	
	/// Current element index
	var index = 0

	/// Initializer
	init(_ countdown: Elements) {
		self.elements = countdown
	}

	/// Advances to the next element and returns it, or `nil` if no next element
	mutating public func next() -> Element? {
		let result = index < elements.size() ? elements.get(index) : nil
		index += 1
		return result
	}
}


// MARK: - Sequence
extension Elements: Sequence {
	/// Returns an iterator over the elements of this sequence.
	public func makeIterator() -> ElementsIterator {
		return ElementsIterator(self)
	}
}
