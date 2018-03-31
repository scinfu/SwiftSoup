//
//  Elements.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 20/10/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//
/**
A list of {@link Element}s, with methods that act on every element in the list.
<p>
To get an {@code Elements} object, use the {@link Element#select(String)} method.
</p>
*/

import Foundation

//open typealias Elements = Array<Element>
//typealias E = Element
open class Elements: NSCopying {
	fileprivate var this: Array<Element> = Array<Element>()

	///base init
	public init() {
	}
	///Initialized with an array
	public init(_ a: Array<Element>) {
		this = a
	}
	///Initialized with an order set
	public init(_ a: OrderedSet<Element>) {
		this.append(contentsOf: a)
	}

	/**
	* Creates a deep copy of these elements.
	* @return a deep copy
	*/
	public func copy(with zone: NSZone? = nil) -> Any {
		let clone: Elements = Elements()
		for e: Element in this {
			clone.add(e.copy() as! Element)
		}
		return clone
	}

	// attribute methods
	/**
	Get an attribute value from the first matched element that has the attribute.
	@param attributeKey The attribute key.
	@return The attribute value from the first matched element that has the attribute.. If no elements were matched (isEmpty() == true),
	or if the no elements have the attribute, returns empty string.
	@see #hasAttr(String)
	*/
	open func attr(_ attributeKey: String)throws->String {
		for element in this {
			if (element.hasAttr(attributeKey)) {
				return try element.attr(attributeKey)
			}
		}
		return ""
	}

	/**
	Checks if any of the matched elements have this attribute set.
	@param attributeKey attribute key
	@return true if any of the elements have the attribute; false if none do.
	*/
	open func hasAttr(_ attributeKey: String) -> Bool {
		for element in this {
			if element.hasAttr(attributeKey) {return true}
		}
		return false
	}

	/**
	* Set an attribute on all matched elements.
	* @param attributeKey attribute key
	* @param attributeValue attribute value
	* @return this
	*/
    @discardableResult
	open func attr(_ attributeKey: String, _ attributeValue: String)throws->Elements {
		for element in this {
			try element.attr(attributeKey, attributeValue)
		}
		return self
	}

	/**
	* Remove an attribute from every matched element.
	* @param attributeKey The attribute to remove.
	* @return this (for chaining)
	*/
    @discardableResult
	open func removeAttr(_ attributeKey: String)throws->Elements {
		for  element in this {
			try element.removeAttr(attributeKey)
		}
		return self
	}

	/**
	Add the class name to every matched element's {@code class} attribute.
	@param className class name to add
	@return this
	*/
    @discardableResult
	open func addClass(_ className: String)throws->Elements {
		for  element in this {
			try element.addClass(className)
		}
		return self
	}

	/**
	Remove the class name from every matched element's {@code class} attribute, if present.
	@param className class name to remove
	@return this
	*/
    @discardableResult
	open func removeClass(_ className: String)throws->Elements {
		for element: Element in this {
			try element.removeClass(className)
		}
		return self
	}

	/**
	Toggle the class name on every matched element's {@code class} attribute.
	@param className class name to add if missing, or remove if present, from every element.
	@return this
	*/
    @discardableResult
	open func toggleClass(_ className: String)throws->Elements {
		for element: Element in this {
			try element.toggleClass(className)
		}
		return self
	}

	/**
	Determine if any of the matched elements have this class name set in their {@code class} attribute.
	@param className class name to check for
	@return true if any do, false if none do
	*/

	open func hasClass(_ className: String) -> Bool {
		for element: Element in this {
			if (element.hasClass(className)) {
				return true
			}
		}
		return false
	}

	/**
	* Get the form element's value of the first matched element.
	* @return The form element's value, or empty if not set.
	* @see Element#val()
	*/
	open func val()throws->String {
		if (size() > 0) {
			return try first()!.val()
		}
		return ""
	}

	/**
	* Set the form element's value in each of the matched elements.
	* @param value The value to set into each matched element
	* @return this (for chaining)
	*/
    @discardableResult
	open func val(_ value: String)throws->Elements {
		for element: Element in this {
			try element.val(value)
		}
		return self
	}

	/**
	* Get the combined text of all the matched elements.
	* <p>
	* Note that it is possible to get repeats if the matched elements contain both parent elements and their own
	* children, as the Element.text() method returns the combined text of a parent and all its children.
	* @return string of all text: unescaped and no HTML.
	* @see Element#text()
	*/
	open func text()throws->String {
		let sb: StringBuilder = StringBuilder()
		for element: Element in this {
			if (sb.length != 0) {
				sb.append(" ")
			}
			sb.append(try element.text())
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
	* Get the combined inner HTML of all matched elements.
	* @return string of all element's inner HTML.
	* @see #text()
	* @see #outerHtml()
	*/
	open func html()throws->String {
		let sb: StringBuilder = StringBuilder()
		for element: Element in this {
			if (sb.length != 0) {
				sb.append("\n")
			}
			sb.append(try element.html())
		}
		return sb.toString()
	}

	/**
	* Get the combined outer HTML of all matched elements.
	* @return string of all element's outer HTML.
	* @see #text()
	* @see #html()
	*/
	open func outerHtml()throws->String {
		let sb: StringBuilder = StringBuilder()
		for element in this {
			if (sb.length != 0) {
				sb.append("\n")
			}
			sb.append(try element.outerHtml())
		}
		return sb.toString()
	}

	/**
	* Get the combined outer HTML of all matched elements. Alias of {@link #outerHtml()}.
	* @return string of all element's outer HTML.
	* @see #text()
	* @see #html()
	*/

	open func toString()throws->String {
		return try outerHtml()
	}

	/**
	* Update the tag name of each matched element. For example, to change each {@code <i>} to a {@code <em>}, do
	* {@code doc.select("i").tagName("em");}
	* @param tagName the new tag name
	* @return this, for chaining
	* @see Element#tagName(String)
	*/
    @discardableResult
	open func tagName(_ tagName: String)throws->Elements {
		for element: Element in this {
			try element.tagName(tagName)
		}
		return self
	}

	/**
	* Set the inner HTML of each matched element.
	* @param html HTML to parse and set into each matched element.
	* @return this, for chaining
	* @see Element#html(String)
	*/
    @discardableResult
	open func html(_ html: String)throws->Elements {
		for element: Element in this {
			try element.html(html)
		}
		return self
	}

	/**
	* Add the supplied HTML to the start of each matched element's inner HTML.
	* @param html HTML to add inside each element, before the existing HTML
	* @return this, for chaining
	* @see Element#prepend(String)
	*/
    @discardableResult
	open func prepend(_ html: String)throws->Elements {
		for element: Element in this {
			try element.prepend(html)
		}
		return self
	}

	/**
	* Add the supplied HTML to the end of each matched element's inner HTML.
	* @param html HTML to add inside each element, after the existing HTML
	* @return this, for chaining
	* @see Element#append(String)
	*/
    @discardableResult
	open func append(_ html: String)throws->Elements {
		for element: Element in this {
			try element.append(html)
		}
		return self
	}

	/**
	* Insert the supplied HTML before each matched element's outer HTML.
	* @param html HTML to insert before each element
	* @return this, for chaining
	* @see Element#before(String)
	*/
    @discardableResult
	open func before(_ html: String)throws->Elements {
		for element: Element in this {
			try element.before(html)
		}
		return self
	}

	/**
	* Insert the supplied HTML after each matched element's outer HTML.
	* @param html HTML to insert after each element
	* @return this, for chaining
	* @see Element#after(String)
	*/
    @discardableResult
	open func after(_ html: String)throws->Elements {
		for element: Element in this {
			try element.after(html)
		}
		return self
	}

	/**
	Wrap the supplied HTML around each matched elements. For example, with HTML
	{@code <p><b>This</b> is <b>Jsoup</b></p>},
	<code>doc.select("b").wrap("&lt;i&gt;&lt;/i&gt;");</code>
	becomes {@code <p><i><b>This</b></i> is <i><b>jsoup</b></i></p>}
	@param html HTML to wrap around each element, e.g. {@code <div class="head"></div>}. Can be arbitrarily deep.
	@return this (for chaining)
	@see Element#wrap
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
	* Removes the matched elements from the DOM, and moves their children up into their parents. This has the effect of
	* dropping the elements but keeping their children.
	* <p>
	* This is useful for e.g removing unwanted formatting elements but keeping their contents.
	* </p>
	*
	* E.g. with HTML: <p>{@code <div><font>One</font> <font><a href="/">Two</a></font></div>}</p>
	* <p>{@code doc.select("font").unwrap();}</p>
	* <p>HTML = {@code <div>One <a href="/">Two</a></div>}</p>
	*
	* @return this (for chaining)
	* @see Node#unwrap
	*/
    @discardableResult
	open func unwrap()throws->Elements {
		for element: Element in this {
			try element.unwrap()
		}
		return self
	}

	/**
	* Empty (remove all child nodes from) each matched element. This is similar to setting the inner HTML of each
	* element to nothing.
	* <p>
	* E.g. HTML: {@code <div><p>Hello <b>there</b></p> <p>now</p></div>}<br>
	* <code>doc.select("p").empty();</code><br>
	* HTML = {@code <div><p></p> <p></p></div>}
	* @return this, for chaining
	* @see Element#empty()
	* @see #remove()
	*/
    @discardableResult
	open func empty() -> Elements {
		for element: Element in this {
			element.empty()
		}
		return self
	}

	/**
	* Remove each matched element from the DOM. This is similar to setting the outer HTML of each element to nothing.
	* <p>
	* E.g. HTML: {@code <div><p>Hello</p> <p>there</p> <img /></div>}<br>
	* <code>doc.select("p").remove();</code><br>
	* HTML = {@code <div> <img /></div>}
	* <p>
	* Note that this method should not be used to clean user-submitted HTML; rather, use {@link org.jsoup.safety.Cleaner} to clean HTML.
	* @return this, for chaining
	* @see Element#empty()
	* @see #empty()
	*/
    @discardableResult
	open func remove()throws->Elements {
		for element in this {
			try element.remove()
		}
		return self
	}

	// filters

	/**
	* Find matching elements within this element list.
	* @param query A {@link Selector} query
	* @return the filtered list of elements, or an empty list if none match.
	*/
	open func select(_ query: String)throws->Elements {
		return try Selector.select(query, this)
	}

	/**
	* Remove elements from this list that match the {@link Selector} query.
	* <p>
	* E.g. HTML: {@code <div class=logo>One</div> <div>Two</div>}<br>
	* <code>Elements divs = doc.select("div").not(".logo");</code><br>
	* Result: {@code divs: [<div>Two</div>]}
	* <p>
	* @param query the selector query whose results should be removed from these elements
	* @return a new elements list that contains only the filtered results
	*/
	open func not(_ query: String)throws->Elements {
		let out: Elements = try Selector.select(query, this)
		return Selector.filterOut(this, out.this)
	}

	/**
	* Get the <i>nth</i> matched element as an Elements object.
	* <p>
	* See also {@link #get(int)} to retrieve an Element.
	* @param index the (zero-based) index of the element in the list to retain
	* @return Elements containing only the specified element, or, if that element did not exist, an empty list.
	*/
	open func eq(_ index: Int) -> Elements {
		return size() > index ? Elements([get(index)]) : Elements()
	}

	/**
	* Test if any of the matched elements match the supplied query.
	* @param query A selector
	* @return true if at least one element in the list matches the query.
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
	* Get all of the parents and ancestor elements of the matched elements.
	* @return all of the parents and ancestor elements of the matched elements
	*/

	open func parents() -> Elements {
		let combo: OrderedSet<Element> = OrderedSet<Element>()
		for e: Element in this {
			combo.append(contentsOf: e.parents().array())
		}
		return Elements(combo)
	}

	// list-like methods
	/**
	Get the first matched element.
	@return The first matched element, or <code>null</code> if contents is empty.
	*/
	open func first() -> Element? {
		return isEmpty() ? nil : get(0)
	}

	/// Check if no element stored
	open func isEmpty() -> Bool {
		return array().count == 0
	}

	/// Count
	open func size() -> Int {
		return array().count
	}

	/**
	Get the last matched element.
	@return The last matched element, or <code>null</code> if contents is empty.
	*/
	open func last() -> Element? {
		return isEmpty() ? nil : get(size() - 1)
	}

	/**
	* Perform a depth-first traversal on each of the selected elements.
	* @param nodeVisitor the visitor callbacks to perform on each node
	* @return this, for chaining
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
	* Get the {@link FormElement} forms from the selected elements, if any.
	* @return a list of {@link FormElement}s pulled from the matched elements. The list will be empty if the elements contain
	* no forms.
	*/
	open func forms()->Array<FormElement> {
		var forms: Array<FormElement> = Array<FormElement>()
		for el: Element in this {
			if let el = el as? FormElement {
				forms.append(el)
			}
		}
		return forms
	}

	/**
	* Appends the specified element to the end of this list.
	*
	* @param e element to be appended to this list
	* @return <tt>true</tt> (as specified by {@link Collection#add})
	*/
	open func add(_ e: Element) {
		this.append(e)
	}

	/**
	* Insert the specified element at index.
	*/
	open func add(_ index: Int, _ element: Element) {
		this.insert(element, at: index)
	}

	/// Return element at index
	open func get(_ i: Int) -> Element {
		return this[i]
	}

	/// Returns all elements
	open func array()->Array<Element> {
		return this
	}
}

/**
* Elements extension Equatable.
*/
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

/**
* Elements IteratorProtocol.
*/
public struct ElementsIterator: IteratorProtocol {
	/// Elements reference
	let elements: Elements
	//current element index
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

/**
* Elements Extension Sequence.
*/
extension Elements: Sequence {
	/// Returns an iterator over the elements of this sequence.
	public func makeIterator() -> ElementsIterator {
		return ElementsIterator(self)
	}
}
