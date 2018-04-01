//
//  OrderedSet.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 12/11/16.
//  Copyright © 2016 Nabil Chatbi. All rights reserved.
//
import Foundation

/// An ordered, unique collection of objects.
public class OrderedSet<T: Hashable> {
	public typealias Index = Int
	fileprivate var contents = [T: Index]() // Needs to have a value of Index instead of Void for fast removals
	fileprivate var sequencedContents = Array<UnsafeMutablePointer<T>>()

	/**
	Inititalizes an empty ordered set.
	- returns:     An empty ordered set.
	*/
	public init() { }

	deinit {
		removeAllObjects()
	}

	/**
	Initializes a new ordered set with the order and contents
	of sequence.
	If an object appears more than once in the sequence it will only appear
	once in the ordered set, at the position of its first occurance.
	- parameter    sequence:   The sequence to initialize the ordered set with.
	- returns:                 An initialized ordered set with the contents of sequence.
	*/
	public init<S: Sequence>(sequence: S) where S.Iterator.Element == T {
		for object in sequence {
			if contents[object] == nil {
				contents[object] = contents.count

				let pointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
				pointer.initialize(to: object)
				sequencedContents.append(pointer)
			}
		}
	}

	public required init(arrayLiteral elements: T...) {
		for object in elements {
			if contents[object] == nil {
				contents[object] = contents.count

				let pointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
				pointer.initialize(to: object)
				sequencedContents.append(pointer)
			}
		}
	}

	/**
	Locate the index of an object in the ordered set.
	It is preferable to use this method over the global find() for performance reasons.
	- parameter    object: The object to find the index for.
	- returns:             The index of the object, or nil if the object is not in the ordered set.
	*/
	public func index(of object: T) -> Index? {
		if let index = contents[object] {
			return index
		}

		return nil
	}

	/**
	Appends an object to the end of the ordered set.
	- parameter    object: The object to be appended.
	*/
	public func append(_ object: T) {

		if let lastIndex = index(of: object) {
			remove(object)
			insert(object, at: lastIndex)
		} else {
			contents[object] = contents.count
			let pointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
			pointer.initialize(to: object)
			sequencedContents.append(pointer)
		}
	}

	/**
	Appends a sequence of objects to the end of the ordered set.
	- parameter    sequence:   The sequence of objects to be appended.
	*/
	public func append<S: Sequence>(contentsOf sequence: S) where S.Iterator.Element == T {
		var gen = sequence.makeIterator()
		while let object: T = gen.next() {
			append(object)
		}
	}

	/**
	Removes an object from the ordered set.
	If the object exists in the ordered set, it will be removed.
	If it is not the last object in the ordered set, subsequent
	objects will be shifted down one position.
	- parameter    object: The object to be removed.
	*/
	public func remove(_ object: T) {
		if let index = contents[object] {
			contents[object] = nil
            #if !swift(>=4.1)
                sequencedContents[index].deallocate(capacity: 1)
            #else
                sequencedContents[index].deallocate()
            #endif
            
			sequencedContents.remove(at: index)

			for (object, i) in contents {
				if i < index {
					continue
				}

				contents[object] = i - 1
			}
		}
	}

	/**
	Removes the given objects from the ordered set.
	- parameter    objects:    The objects to be removed.
	*/
	public func remove<S: Sequence>(_ objects: S) where S.Iterator.Element == T {
		var gen = objects.makeIterator()
		while let object: T = gen.next() {
			remove(object)
		}
	}

	/**
	Removes an object at a given index.
	This method will cause a fatal error if you attempt to move an object to an index that is out of bounds.
	- parameter    index:  The index of the object to be removed.
	*/
	public func removeObject(at index: Index) {
		if index < 0 || index >= count {
			fatalError("Attempting to remove an object at an index that does not exist")
		}

		remove(sequencedContents[index].pointee)
	}

	/**
	Removes all objects in the ordered set.
	*/
	public func removeAllObjects() {
		contents.removeAll()

        for sequencedContent in sequencedContents {
            #if !swift(>=4.1)
            sequencedContent.deallocate(capacity: 1)
            #else
            sequencedContent.deallocate()
            #endif
        }
		sequencedContents.removeAll()
	}

	/**
	Swaps two objects contained within the ordered set.
	Both objects must exist within the set, or the swap will not occur.
	- parameter    first:  The first object to be swapped.
	- parameter    second: The second object to be swapped.
	*/
	public func swapObject(_ first: T, with second: T) {
		if let firstPosition = contents[first] {
			if let secondPosition = contents[second] {
				contents[first] = secondPosition
				contents[second] = firstPosition

				sequencedContents[firstPosition].pointee = second
				sequencedContents[secondPosition].pointee = first
			}
		}
	}

	/**
	Tests if the ordered set contains any objects within a sequence.
	- parameter    other:  The sequence to look for the intersection in.
	- returns:             Returns true if the sequence and set contain any equal objects, otherwise false.
	*/
	public func intersects<S: Sequence>(_ other: S) -> Bool where S.Iterator.Element == T {
		var gen = other.makeIterator()
		while let object: T = gen.next() {
			if contains(object) {
				return true
			}
		}

		return false
	}

	/**
	Tests if a the ordered set is a subset of another sequence.
	- parameter    sequence:   The sequence to check.
	- returns:                 true if the sequence contains all objects contained in the receiver, otherwise false.
	*/
	public func isSubset<S: Sequence>(of sequence: S) -> Bool where S.Iterator.Element == T {
		for (object, _) in contents {
			if !sequence.contains(object) {
				return false
			}
		}

		return true
	}

	/**
	Moves an object to a different index, shifting all objects in between the movement.
	This method is a no-op if the object doesn't exist in the set or the index is the
	same that the object is currently at.
	This method will cause a fatal error if you attempt to move an object to an index that is out of bounds.
	- parameter    object: The object to be moved
	- parameter    index:  The index that the object should be moved to.
	*/
	public func moveObject(_ object: T, toIndex index: Index) {
		if index < 0 || index >= count {
			fatalError("Attempting to move an object at an index that does not exist")
		}

		if let position = contents[object] {
			// Return if the client attempted to move to the current index
			if position == index {
				return
			}

			let adjustment = position > index ? -1 : 1

			var currentIndex = position
			while currentIndex != index {
				let nextIndex = currentIndex + adjustment

				let firstObject = sequencedContents[currentIndex].pointee
				let secondObject = sequencedContents[nextIndex].pointee

				sequencedContents[currentIndex].pointee = secondObject
				sequencedContents[nextIndex].pointee = firstObject

				contents[firstObject] = nextIndex
				contents[secondObject] = currentIndex

				currentIndex += adjustment
			}
		}
	}

	/**
	Moves an object from one index to a different index, shifting all objects in between the movement.
	This method is a no-op if the index is the same that the object is currently at.
	This method will cause a fatal error if you attempt to move an object fro man index that is out of bounds
	or to an index that is out of bounds.
	- parameter     index:      The index of the object to be moved.
	- parameter     toIndex:    The index that the object should be moved to.
	*/
	public func moveObject(at index: Index, to toIndex: Index) {
		if ((index < 0 || index >= count) || (toIndex < 0 || toIndex >= count)) {
			fatalError("Attempting to move an object at or to an index that does not exist")
		}

		moveObject(self[index], toIndex: toIndex)
	}

	/**
	Inserts an object at a given index, shifting all objects above it up one.
	This method will cause a fatal error if you attempt to insert the object out of bounds.
	If the object already exists in the OrderedSet, this operation is a no-op.
	- parameter    object:     The object to be inserted.
	- parameter    index:      The index to be inserted at.
	*/
	public func insert(_ object: T, at index: Index) {
		if index > count || index < 0 {
			fatalError("Attempting to insert an object at an index that does not exist")
		}

		if contents[object] != nil {
			return
		}

		// Append our object, then swap them until its at the end.
		append(object)

		for i in (index..<count-1).reversed() {
			swapObject(self[i], with: self[i+1])
		}
	}

	/**
	Inserts objects at a given index, shifting all objects above it up one.
	This method will cause a fatal error if you attempt to insert the objects out of bounds.
	If an object in objects already exists in the OrderedSet it will not be added. Objects that occur twice
	in the sequence will only be added once.
	- parameter    objects:    The objects to be inserted.
	- parameter    index:      The index to be inserted at.
	*/
	public func insert<S: Sequence>(_ objects: S, at index: Index) where S.Iterator.Element == T {
		if index > count || index < 0 {
			fatalError("Attempting to insert an object at an index that does not exist")
		}

		var addedObjectCount = 0

		for object in objects {
			if contents[object] == nil {
				let seqIdx = index + addedObjectCount
				let element = UnsafeMutablePointer<T>.allocate(capacity: 1)
				element.initialize(to: object)
				sequencedContents.insert(element, at: seqIdx)
				contents[object] = seqIdx
				addedObjectCount += 1
			}
		}

		// Now we'll remove duplicates and update the shifted objects position in the contents
		// dictionary.
		for i in index + addedObjectCount..<count {
			contents[sequencedContents[i].pointee] = i
		}
	}

	/// Returns the last object in the set, or `nil` if the set is empty.
	public var last: T? {
		return sequencedContents.last?.pointee
	}
}

extension OrderedSet: ExpressibleByArrayLiteral { }

extension OrderedSet where T: Comparable {}

extension OrderedSet {

	public var count: Int {
		return contents.count
	}

	public var isEmpty: Bool {
		return count == 0
	}

	public var first: T? {
		guard count > 0 else { return nil }
		return sequencedContents[0].pointee
	}

	public func index(after i: Int) -> Int {
		return sequencedContents.index(after: i)
	}

	public var startIndex: Int {
		return 0
	}

	public var endIndex: Int {
		return contents.count
	}

	public subscript(index: Index) -> T {
		get {
			return sequencedContents[index].pointee
		}

		set {
			let previousCount = contents.count
			contents[sequencedContents[index].pointee] = nil
			contents[newValue] = index

			// If the count is reduced we used an existing value, and need to sync up sequencedContents
			if contents.count == previousCount {
				sequencedContents[index].pointee = newValue
			} else {
				sequencedContents.remove(at: index)
			}
		}
	}

}

extension  OrderedSet: Sequence {
	public typealias Iterator = OrderedSetGenerator<T>

	public func makeIterator() -> Iterator {
		return OrderedSetGenerator(set: self)
	}
}

public struct OrderedSetGenerator<T: Hashable>: IteratorProtocol {
	public typealias Element = T
	private var generator: IndexingIterator<Array<UnsafeMutablePointer<T>>>

	public init(set: OrderedSet<T>) {
		generator = set.sequencedContents.makeIterator()
	}

	public mutating func next() -> Element? {
		return generator.next()?.pointee
	}
}

extension OrderedSetGenerator where T: Comparable {}

public func +<T, S: Sequence> (lhs: OrderedSet<T>, rhs: S) -> OrderedSet<T> where S.Iterator.Element == T {
	let joinedSet = lhs
	joinedSet.append(contentsOf: rhs)

	return joinedSet
}

public func +=<T, S: Sequence> (lhs: inout OrderedSet<T>, rhs: S) where S.Iterator.Element == T {
	lhs.append(contentsOf: rhs)
}

public func -<T, S: Sequence> (lhs: OrderedSet<T>, rhs: S) -> OrderedSet<T> where S.Iterator.Element == T {
	let purgedSet = lhs
	purgedSet.remove(rhs)

	return purgedSet
}

public func -=<T, S: Sequence> (lhs: inout OrderedSet<T>, rhs: S) where S.Iterator.Element == T {
	lhs.remove(rhs)
}

extension OrderedSet: Equatable { }

public func ==<T> (lhs: OrderedSet<T>, rhs: OrderedSet<T>) -> Bool {
	if lhs.count != rhs.count {
		return false
	}

	for object in lhs {
		if lhs.contents[object] != rhs.contents[object] {
			return false
		}
	}

	return true
}

extension OrderedSet: CustomStringConvertible {
	public var description: String {
		let children = map({ "\($0)" }).joined(separator: ", ")
		return "OrderedSet (\(count) object(s)): [\(children)]"
	}
}
