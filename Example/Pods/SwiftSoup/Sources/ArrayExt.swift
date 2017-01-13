//
//  ArrayExt.swift
//  SwifSoup
//
//  Created by Nabil Chatbi on 05/10/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import Foundation

extension Array {
    func binarySearch<T: Comparable>(_ collection: [T], _ target: T) -> Int {

        let min = 0
        let max = collection.count - 1

        return binaryMakeGuess(min: min, max: max, target: target, collection: collection)

    }

    func binaryMakeGuess<T: Comparable>(min: Int, max: Int, target: T, collection: [T]) -> Int {

        let guess = (min + max) / 2

        if max < min {

            // illegal, guess not in array
            return -1

        } else if collection[guess] == target {

            // guess is correct
            return guess

        } else if collection[guess] > target {

            // guess is too high
            return binaryMakeGuess(min: min, max: guess - 1, target: target, collection: collection)

        } else {

            // array[guess] < target
            // guess is too low
            return binaryMakeGuess(min: guess + 1, max: max, target: target, collection: collection)

        }
    }
}

extension Array where Element : Equatable {
    func lastIndexOf(_ e: Element) -> Int {
        for pos in (0..<self.count).reversed() {
            let next = self[pos]
            if (next == e) {
                return pos
            }
        }
        return -1
    }
}
