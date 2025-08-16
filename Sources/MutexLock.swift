//
//  MutexLock.swift
//  SwiftSoup
//
//  Created by Marc Haisenko on 2025-08-15, code by xukun on 2022/3/31.
//

import Foundation

final class MutexLock: NSLocking {
    
    private let locker: NSLocking
    
    init() {
#if os(iOS) || os(macOS) || os(watchOS) || os(tvOS)
        if #available(iOS 10.0, macOS 10.12, watchOS 3.0, tvOS 10.0, *) {
            locker = UnfairLock()
        } else {
            locker = Mutex()
        }
#else
        locker = Mutex()
#endif
    }
    
    func lock() {
        locker.lock()
    }
    
    func unlock() {
        locker.unlock()
    }
}
