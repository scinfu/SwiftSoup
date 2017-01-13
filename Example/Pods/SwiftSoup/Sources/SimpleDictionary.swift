//
//  SimpleDictionary.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 30/10/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import Foundation

public class SimpleDictionary<KeyType: Hashable, ValueType> {

	public typealias DictionaryType = [KeyType: ValueType]
	public private(set) var values = DictionaryType()

	public init() {
	}

	public var count: Int {
		return values.count
	}

	public func remove(_ key: KeyType) {
		values.removeValue(forKey: key)
	}

	public func contains(_ key: KeyType) -> Bool {
		return self.values[key] != nil
	}

	public func put(_ value: ValueType, forKey key: KeyType) {
		self.values[key] = value
	}

	public func get(_ key: KeyType) -> ValueType? {
		return self.values[key]
	}

}
