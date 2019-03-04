//
//  BinarySearch.swift
//  SwiftSoup-iOS
//
//  Created by Garth Snyder on 2/28/19.
//  Copyright © 2019 Nabil Chatbi. All rights reserved.
//
//  Adapted from https://stackoverflow.com/questions/31904396/swift-binary-search-for-standard-array
//

import Foundation

extension Collection {
    
    /// Generalized binary search algorithm for ordered Collections
    ///
    /// Behavior is undefined if the collection is not properly sorted.
    ///
    /// This is only O(logN) for RandomAccessCollections; Collections in
    /// general may implement offsetting of indexes as an O(K) operation. (E.g.,
    /// Strings are like this).
    ///
    /// - Note: If you are using this for searching only (not insertion), you
    ///     must always test the element at the returned index to ensure that
    ///     it's a genuine match. If the element is not present in the array,
    ///     you will still get a valid index back that represents the location
    ///     where it should be inserted. Also check to be sure the returned
    ///     index isn't off the end of the collection.
    ///
    /// - Parameter predicate: Reports the ordering of a given Element relative
    ///     to the desired Element. Typically, this is <.
    ///
    /// - Returns: Index N such that the predicate is true for all elements up to
    ///     but not including N, and is false for all elements N and beyond

    func binarySearch(predicate: (Element) -> Bool) -> Index {
        var low = startIndex
        var high = endIndex
        while low != high {
            let mid = index(low, offsetBy: distance(from: low, to: high)/2)
            if predicate(self[mid]) {
                low = index(after: mid)
            } else {
                high = mid
            }
        }
        return low
    }

    /// Binary search lookup for ordered Collections using a KeyPath
    /// relative to Element.
    ///
    /// Behavior is undefined if the collection is not properly sorted.
    ///
    /// This is only O(logN) for RandomAccessCollections; Collections in
    /// general may implement offsetting of indexes as an O(K) operation. (E.g.,
    /// Strings are like this).
    ///
    /// - Note: If you are using this for searching only (not insertion), you
    ///     must always test the element at the returned index to ensure that
    ///     it's a genuine match. If the element is not present in the array,
    ///     you will still get a valid index back that represents the location
    ///     where it should be inserted. Also check to be sure the returned
    ///     index isn't off the end of the collection.
    ///
    /// - Parameter keyPath: KeyPath that extracts the Element value on which
    ///     the Collection is presorted. Must be Comparable and Equatable.
    ///     ordering is presumed to be <, however that is defined for the type.
    ///
    /// - Returns: The index of a matching element, or nil if not found. If
    ///     the return value is non-nil, it is always a valid index.

    func indexOfElement<T>(withValue value: T, atKeyPath keyPath: KeyPath<Element, T>) -> Index? where T: Comparable & Equatable {
        let ix = binarySearch { $0[keyPath: keyPath] < value }
        guard ix < endIndex else { return nil }
        guard self[ix][keyPath: keyPath] == value else { return nil }
        return ix
    }

    func element<T>(withValue value: T, atKeyPath keyPath: KeyPath<Element, T>) -> Element? where T: Comparable & Equatable {
        if let ix = indexOfElement(withValue: value, atKeyPath: keyPath) {
            return self[ix]
        }
        return nil
    }

    func elements<T>(withValue value: T, atKeyPath keyPath: KeyPath<Element, T>) -> [Element] where T: Comparable & Equatable {
        guard let start = indexOfElement(withValue: value, atKeyPath: keyPath) else { return [] }
        var end = index(after: start)
        while end < endIndex && self[end][keyPath: keyPath] == value {
            end = index(after: end)
        }
        return Array(self[start..<end])
    }
}
