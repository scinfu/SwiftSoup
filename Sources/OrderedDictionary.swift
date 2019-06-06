//
//  LinkedHashMap.swift
//  SwifSoup
//
//  Created by Nabil Chatbi on 03/10/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import Foundation

public class OrderedDictionary<Key: Hashable, Value: Equatable>: MutableCollection, Hashable {

    /// Returns the position immediately after the given index.
    ///
    /// - Parameter i: A valid index of the collection. `i` must be less than
    ///   `endIndex`.
    /// - Returns: The index value immediately after `i`.
    public func index(after i: Int) -> Int {
        return _orderedKeys.index(after: i)
    }

    // ======================================================= //
    // MARK: - Type Aliases
    // ======================================================= //

    public typealias Element = (Key, Value)

    public typealias Index = Int

    // ======================================================= //
    // MARK: - Initialization
    // ======================================================= //

    public init() {}
    public init(count: Int) {}

    public init(elements: [Element]) {
        for (key, value) in elements {
            self[key] = value
        }
    }

    public func copy() -> Any {
        return copy(with: nil)
    }

    public func mutableCopy(with zone: NSZone? = nil) -> Any {
        return copy()
    }

    public func copy(with zone: NSZone? = nil) -> Any {
        let copy = OrderedDictionary<Key, Value>()
        //let copy = type(of:self).init()
        for element in orderedKeys {
            copy.put(value: valueForKey(key: element)!, forKey: element)
        }
        return copy
    }

    func clone() -> OrderedDictionary<Key, Value> {
        return copy() as! OrderedDictionary<Key, Value>
    }

    // ======================================================= //
    // MARK: - Accessing Keys & Values
    // ======================================================= //

    public var orderedKeys: [Key] {
        return _orderedKeys
    }

    public func keySet() -> [Key] {
        return _orderedKeys
    }

    public var orderedValues: [Value] {
        #if !swift(>=4.1)
            return _orderedKeys.flatMap { _keysToValues[$0] }
        #else
            return _orderedKeys.compactMap { _keysToValues[$0] }
        #endif
    }

    // ======================================================= //
    // MARK: - Managing Content Using Keys
    // ======================================================= //

    public subscript(key: Key) -> Value? {
        get {
            return valueForKey(key: key)
        }
        set(newValue) {
            if let newValue = newValue {
                updateValue(value: newValue, forKey: key)
            } else {
                removeValueForKey(key: key)
            }
        }
    }

    public func containsKey(key: Key) -> Bool {
        return _orderedKeys.contains(key)
    }

    public func valueForKey(key: Key) -> Value? {
        return _keysToValues[key]
    }

    public func get(key: Key) -> Value? {
        return valueForKey(key: key)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(_orderedKeys)
    }

    public func hashCode() -> Int {
        return hashValue
    }

    @discardableResult
    private func updateValue(value: Value, forKey key: Key) -> Value? {

        guard let currentValue = _keysToValues[key] else {
            _orderedKeys.append(key)
            _keysToValues[key] = value
            return nil
        }
        _keysToValues[key] = value
        return currentValue

//        if _orderedKeys.contains(key) {
//            guard let currentValue = _keysToValues[key] else {
//                fatalError("Inconsistency error occured in OrderedDictionary")
//            }
//
//            _keysToValues[key] = value
//
//            return currentValue
//        } else {
//            _orderedKeys.append(key)
//            _keysToValues[key] = value
//
//            return nil
//        }
    }

    public func put(value: Value, forKey key: Key) {
        self[key] = value
    }

    public func putAll(all: OrderedDictionary<Key, Value>) {
        for i in all.orderedKeys {
            put(value: all[i]!, forKey: i)
        }
    }

    @discardableResult
    public func removeValueForKey(key: Key) -> Value? {
        if let index = _orderedKeys.firstIndex(of: key) {
            guard let currentValue = _keysToValues[key] else {
                fatalError("Inconsistency error occured in OrderedDictionary")
            }

            _orderedKeys.remove(at: index)
            _keysToValues[key] = nil

            return currentValue
        } else {
            return nil
        }
    }

    @discardableResult
    public func remove(key: Key) -> Value? {
        return removeValueForKey(key: key)
    }

    public func removeAll(keepCapacity: Bool = true) {
        _orderedKeys.removeAll(keepingCapacity: keepCapacity)
        _keysToValues.removeAll(keepingCapacity: keepCapacity)
    }

    // ======================================================= //
    // MARK: - Managing Content Using Indexes
    // ======================================================= //

    public subscript(index: Index) -> Element {
        get {
            guard let element = elementAtIndex(index: index) else {
                fatalError("OrderedDictionary index out of range")
            }

            return element
        }
        set(newValue) {
            updateElement(element: newValue, atIndex: index)
        }
    }

    public func indexForKey(key: Key) -> Index? {
        return _orderedKeys.firstIndex(of: key)
    }

    public func elementAtIndex(index: Index) -> Element? {
        guard _orderedKeys.indices.contains(index) else { return nil }

        let key = _orderedKeys[index]

        guard let value = self._keysToValues[key] else {
            fatalError("Inconsistency error occured in OrderedDictionary")
        }

        return (key, value)
    }

    public func insertElementWithKey(key: Key, value: Value, atIndex index: Index) -> Value? {
        return insertElement(newElement: (key, value), atIndex: index)
    }

    public func insertElement(newElement: Element, atIndex index: Index) -> Value? {
        guard index >= 0 else {
            fatalError("Negative OrderedDictionary index is out of range")
        }

        guard index <= count else {
            fatalError("OrderedDictionary index out of range")
        }

        let (key, value) = newElement

        let adjustedIndex: Int
        let currentValue: Value?

        if let currentIndex = _orderedKeys.firstIndex(of: key) {
            currentValue = _keysToValues[key]
            adjustedIndex = (currentIndex < index - 1) ? index - 1 : index

            _orderedKeys.remove(at: currentIndex)
            _keysToValues[key] = nil
        } else {
            currentValue = nil
            adjustedIndex = index
        }

        _orderedKeys.insert(key, at: adjustedIndex)
        _keysToValues[key] = value

        return currentValue
    }

    @discardableResult
    public func updateElement(element: Element, atIndex index: Index) -> Element? {
        guard let currentElement = elementAtIndex(index: index) else {
            fatalError("OrderedDictionary index out of range")
        }

        let (newKey, newValue) = element

        _orderedKeys[index] = newKey
        _keysToValues[newKey] = newValue

        return currentElement
    }

    public func removeAtIndex(index: Index) -> Element? {
        if let element = elementAtIndex(index: index) {
            _orderedKeys.remove(at: index)
            _keysToValues.removeValue(forKey: element.0)

            return element
        } else {
            return nil
        }
    }

    // ======================================================= //
    // MARK: - CollectionType Conformance
    // ======================================================= //

    public var startIndex: Index {
        return _orderedKeys.startIndex
    }

    public var endIndex: Index {
        return _orderedKeys.endIndex
    }

    // ======================================================= //
    // MARK: - Internal Backing Store
    // ======================================================= //

    /// The backing store for the ordered keys.
    internal var _orderedKeys = [Key]()

    /// The backing store for the mapping of keys to values.
    internal var _keysToValues = [Key: Value]()

}

// ======================================================= //
// MARK: - Initializations from Literals
// ======================================================= //

//extension OrderedDictionary: ExpressibleByArrayLiteral {
//    
//    public convenience init(arrayLiteral elements: Element...) {
//        self.init(elements: elements)
//    }
//}
//
//extension OrderedDictionary: ExpressibleByDictionaryLiteral {
//    
//    public convenience init(dictionaryLiteral elements: Element...) {
//        self.init(elements: elements)
//    }
//    
//}

extension OrderedDictionary: LazySequenceProtocol {

    func generate() -> AnyIterator<Value> {
        var i = 0
        return AnyIterator {
            if (i >= self.orderedValues.count) {
                return nil
            }
            i += 1
            return self.orderedValues[i-1]
        }
    }

}

// ======================================================= //
// MARK: - Description
// ======================================================= //

extension OrderedDictionary: CustomStringConvertible, CustomDebugStringConvertible {

    public var description: String {
        return constructDescription(debug: false)
    }

    public var debugDescription: String {
        return constructDescription(debug: true)
    }

    private func constructDescription(debug: Bool) -> String {
        // The implementation of the description is inspired by zwaldowski's implementation of the ordered dictionary.
        // See http://bit.ly/1VL4JUR

        if isEmpty { return "[:]" }

        func descriptionForItem(item: Any) -> String {
            var description = ""

            if debug {
                debugPrint(item, separator: "", terminator: "", to: &description)
            } else {
                print(item, separator: "", terminator: "", to: &description)
            }

            return description
        }

        let bodyComponents = map({ (key: Key, value: Value) -> String in
            return descriptionForItem(item: key) + ": " + descriptionForItem(item: value)
        })

        let body = bodyComponents.joined(separator: ", ")

        return "[\(body)]"
    }

}

extension OrderedDictionary: Equatable {
	/// Returns a Boolean value indicating whether two values are equal.
	///
	/// Equality is the inverse of inequality. For any values `a` and `b`,
	/// `a == b` implies that `a != b` is `false`.
	///
	/// - Parameters:
	///   - lhs: A value to compare.
	///   - rhs: Another value to compare.
	public static func ==(lhs: OrderedDictionary<Key, Value>, rhs: OrderedDictionary<Key, Value>) -> Bool {
		if(lhs.count != rhs.count) {return false}
		return (lhs._orderedKeys == rhs._orderedKeys) && (lhs._keysToValues == rhs._keysToValues)
	}
}

//public func == <Key: Equatable, Value: Equatable>(lhs: OrderedDictionary<Key, Value>, rhs: OrderedDictionary<Key, Value>) -> Bool {
//    return lhs._orderedKeys == rhs._orderedKeys && lhs._keysToValues == rhs._keysToValues
//}

/**
 * Elements IteratorProtocol.
 */
public struct OrderedDictionaryIterator<Key: Hashable, Value: Equatable>: IteratorProtocol {

    /// Elements reference
    let orderedDictionary: OrderedDictionary<Key, Value>
    //current element index
    var index = 0

    /// Initializer
    init(_ od: OrderedDictionary<Key, Value>) {
        self.orderedDictionary = od
    }

    /// Advances to the next element and returns it, or `nil` if no next element
    mutating public func next() -> Value? {

        let result = index < orderedDictionary.orderedKeys.count ? orderedDictionary[orderedDictionary.orderedKeys[index]] : nil
        index += 1
        return result
    }
}

/**
 * Elements Extension Sequence.
 */
extension OrderedDictionary: Sequence {
    /// Returns an iterator over the elements of this sequence.
    func generate()->OrderedDictionaryIterator<Key, Value> {
        return OrderedDictionaryIterator(self)
    }
}
