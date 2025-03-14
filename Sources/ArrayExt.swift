//
//  ArrayExt.swift
//  SwifSoup
//
//  Created by Nabil Chatbi on 05/10/16.
//

import Foundation

extension Array where Element: Equatable {
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
