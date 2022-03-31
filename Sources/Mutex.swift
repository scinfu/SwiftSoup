//
//  Mutex.swift
//  SwiftSoup
//
//  Created by xukun on 2022/3/31.
//  Copyright © 2022 Nabil Chatbi. All rights reserved.
//

import Foundation

final class Mutex: NSLocking {
    
    private var mutex = pthread_mutex_t()

    init() {
        pthread_mutex_init(&mutex, nil)
    }

    deinit {
        pthread_mutex_destroy(&mutex)
    }

    func lock() {
        pthread_mutex_lock(&mutex)
    }

    func unlock() {
        pthread_mutex_unlock(&mutex)
    }
}
