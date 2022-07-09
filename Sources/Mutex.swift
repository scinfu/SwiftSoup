//
//  Mutex.swift
//  SwiftSoup
//
//  Created by xukun on 2022/3/31.
//  Copyright © 2022 Nabil Chatbi. All rights reserved.
//

import Foundation

final class Mutex: NSLocking {
    
    private var semaphore: DispatchSemaphore

    init() {
        semaphore = DispatchSemaphore(value: 1)
    }

    func lock() {
        semaphore.wait()
    }

    func unlock() {
        semaphore.signal()
    }
}
