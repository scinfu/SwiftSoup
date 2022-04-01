//
//  UnfairLock.swift
//  SwiftSoup
//
//  Created by xukun on 2022/3/31.
//  Copyright © 2022 Nabil Chatbi. All rights reserved.
//

import Foundation

@available(iOS 10.0, OSX 10.12, watchOS 3.0, tvOS 10.0, *)
final class UnfairLock: NSLocking {
    
    private let unfairLock: UnsafeMutablePointer<os_unfair_lock> = {
        let pointer = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
        pointer.initialize(to: os_unfair_lock())
        return pointer
    }()

    deinit {
        unfairLock.deinitialize(count: 1)
        unfairLock.deallocate()
    }

    func lock() {
        os_unfair_lock_lock(unfairLock)
    }

    func tryLock() -> Bool {
        os_unfair_lock_trylock(unfairLock)
    }

    func unlock() {
        os_unfair_lock_unlock(unfairLock)
    }
}
