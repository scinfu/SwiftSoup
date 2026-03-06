//
//  ElementQuery.swift
//  SwiftSoup
//
//  A common query interface shared by Element and Elements.
//

/// A protocol that unifies the read-only query API shared by ``Element`` and ``Elements``.
///
/// Use this protocol to write generic code that accepts either a single element or a collection
/// of elements without duplicating logic:
///
/// ```swift
/// func extractLinks(_ source: some ElementQuery) throws -> [String] {
///     try source.select("a[href]").map { try $0.attr("href") }
/// }
///
/// // Works with both:
/// let linksFromElement = try extractLinks(doc.body()!)
/// let linksFromElements = try extractLinks(doc.select("div.content"))
/// ```
///
/// On ``Element``, methods operate on that element (and its descendants where noted).
/// On ``Elements``, they typically operate on the first matched element or aggregate across
/// all matched elements.
public protocol ElementQuery {
    /// Get an attribute value from the first matched element that has the attribute.
    ///
    /// - parameter attributeKey: The attribute key.
    /// - returns: The attribute value, or an empty string if no elements have the attribute.
    func attr(_ attributeKey: String) throws -> String

    /// Check if any of the matched elements have this attribute defined.
    ///
    /// - parameter attributeKey: The attribute key to check for.
    /// - returns: `true` if any element has the attribute.
    func hasAttr(_ attributeKey: String) -> Bool

    /// Check if any of the matched elements have this class name set in their `class` attribute.
    ///
    /// - parameter className: The class name to check for.
    /// - returns: `true` if any element has the class.
    func hasClass(_ className: String) -> Bool

    /// Get the form element's value of the first matched element.
    ///
    /// - returns: The form element's value, or an empty string if not set.
    func val() throws -> String

    /// Get the combined text of the matched elements.
    ///
    /// - parameter trimAndNormaliseWhitespace: Whether to normalize whitespace. Defaults to `true`.
    /// - returns: The combined text content.
    func text(trimAndNormaliseWhitespace: Bool) throws -> String

    /// Check if any of the matched elements have non-empty text content.
    ///
    /// - returns: `true` if any element has text.
    func hasText() -> Bool

    /// Get the inner HTML of the matched elements.
    ///
    /// - returns: The combined inner HTML.
    func html() throws -> String

    /// Get the outer HTML of the matched elements.
    ///
    /// - returns: The combined outer HTML.
    func outerHtml() throws -> String

    /// Find elements matching a CSS selector query.
    ///
    /// - parameter cssQuery: A CSS selector string.
    /// - returns: The matched elements.
    func select(_ cssQuery: String) throws -> Elements

    /// Find elements matching an evaluator.
    ///
    /// - parameter evaluator: An evaluator from ``QueryParser``.
    /// - returns: The matched elements.
    func select(_ evaluator: Evaluator) throws -> Elements
}

extension ElementQuery {
    /// Get the combined text content with default whitespace normalization.
    ///
    /// Convenience overload that calls ``text(trimAndNormaliseWhitespace:)`` with `true`.
    public func text() throws -> String {
        return try text(trimAndNormaliseWhitespace: true)
    }
}

// MARK: - Conformances

extension Element: ElementQuery {}
extension Elements: ElementQuery {}
