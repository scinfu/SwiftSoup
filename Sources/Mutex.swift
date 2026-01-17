//
//  Mutex.swift
//  SwiftSoup
//

import Foundation

#if os(Windows)
import WinSDK
#endif


/// Provides a (fast) mutex intended for short code paths. Consider `NSLock` for
/// expensive code paths.
@usableFromInline
final class Mutex: NSLocking, @unchecked Sendable {
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
    private let unfairLock: UnsafeMutablePointer<os_unfair_lock> = {
        let pointer = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
        pointer.initialize(to: os_unfair_lock())
        return pointer
    }()

    deinit {
        unfairLock.deinitialize(count: 1)
        unfairLock.deallocate()
    }

    @usableFromInline
    func lock() {
        os_unfair_lock_lock(unfairLock)
    }

    @usableFromInline
    func tryLock() -> Bool {
        return os_unfair_lock_trylock(unfairLock)
    }

    @usableFromInline
    func unlock() {
        os_unfair_lock_unlock(unfairLock)
    }

#elseif os(Windows)
    private var mutex = CRITICAL_SECTION()

    init() {
        InitializeCriticalSection(&mutex)
    }

    deinit {
        DeleteCriticalSection(&mutex)
    }

    @usableFromInline
    func lock() {
        EnterCriticalSection(&mutex)
    }

    @usableFromInline
    func unlock() {
        LeaveCriticalSection(&mutex)
    }
#elseif os(FreeBSD)
    private var mutex:  pthread_mutex_t? = nil

    init() {
        var attr = pthread_mutexattr_t(bitPattern: 0)
        pthread_mutexattr_init(&attr)
    }

    deinit {
        pthread_mutex_destroy(&mutex)
    }

    @usableFromInline
    func lock() {
        pthread_mutex_lock(&mutex)
    }

    @usableFromInline
    func unlock() {
        pthread_mutex_unlock(&mutex)
    }
    
#else
    private var mutex = pthread_mutex_t()

    init() {
        pthread_mutex_init(&mutex, nil)
    }

    deinit {
        pthread_mutex_destroy(&mutex)
    }

    @usableFromInline
    func lock() {
        pthread_mutex_lock(&mutex)
    }

    @usableFromInline
    func unlock() {
        pthread_mutex_unlock(&mutex)
    }
#endif
}
