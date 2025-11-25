//
//  Validate.swift
//  SwifSoup
//
//  Created by Nabil Chatbi on 02/10/16.
//

import Foundation

public struct Validate {

    /**
     * Validates that the object is not `nil`
     * - parameter obj: object to test
     */
    public static func notNull(obj: Any?) throws {
        if (obj == nil) {
            throw Exception.Error(type: ExceptionType.IllegalArgumentException, Message: "Object must not be null")
        }
    }

    /**
     * Validates that the object is not `nil`
     * - parameter obj: object to test
     * - parameter msg: message to output if validation fails
     */
    public static func notNull(obj: AnyObject?, msg: String) throws {
        if (obj == nil) {
            throw Exception.Error(type: ExceptionType.IllegalArgumentException, Message: msg)
        }
    }

    /**
     * Validates that the value is true
     * - parameter val: object to test
     */
    public static func isTrue(val: Bool) throws {
        if (!val) {
            throw Exception.Error(type: ExceptionType.IllegalArgumentException, Message: "Must be true")
        }
    }

    /**
     * Validates that the value is true
     * - parameter val: object to test
     * - parameter msg: message to output if validation fails
     */
    public static func isTrue(val: Bool, msg: String) throws {
        if (!val) {
            throw Exception.Error(type: ExceptionType.IllegalArgumentException, Message: msg)
        }
    }

    /**
     * Validates that the value is false
     * - parameter val: object to test
     */
    public static func isFalse(val: Bool) throws {
        if (val) {
            throw Exception.Error(type: ExceptionType.IllegalArgumentException, Message: "Must be false")
        }
    }

    /**
     * Validates that the value is false
     * - parameter val: object to test
     * - parameter msg: message to output if validation fails
     */
    public static func isFalse(val: Bool, msg: String) throws {
        if (val) {
            throw Exception.Error(type: ExceptionType.IllegalArgumentException, Message: msg)
        }
    }

    /**
     * Validates that the array contains no `nil` elements
     * - parameter objects: the array to test
     */
    public static func noNullElements(objects: [AnyObject?]) throws {
        try noNullElements(objects: objects, msg: "Array must not contain any null objects")
    }

    /**
     * Validates that the array contains no `nil` elements
     * - parameter objects: the array to test
     * - parameter msg: message to output if validation fails
     */
    public static func noNullElements(objects: [AnyObject?], msg: String) throws {
        for obj in objects {
            if (obj == nil) {
                throw Exception.Error(type: ExceptionType.IllegalArgumentException, Message: msg)
            }
        }
    }

    /**
     * Validates that the string is not empty
     * - parameter string: the string to test
     */
    public static func notEmpty<T: Collection>(string: T?) throws where T.Element == UInt8 {
        if string?.isEmpty ?? true {
            throw Exception.Error(type: ExceptionType.IllegalArgumentException, Message: "String must not be empty")
        }

    }
    
    public static func notEmpty(string: String?) throws {
        try notEmpty(string: string?.utf8Array)
    }

    /**
     * Validates that the string is not empty
     * - parameter string: the string to test
     * - parameter msg: message to output if validation fails
     */
   public static func notEmpty(string: [UInt8]?, msg: String ) throws {
       if string?.isEmpty ?? true {
            throw Exception.Error(type: ExceptionType.IllegalArgumentException, Message: msg)
        }
    }
    
    public static func notEmpty(string: String?, msg: String) throws {
        try notEmpty(string: string?.utf8Array, msg: msg)
    }

    /**
     Cause a failure.
     - parameter msg: message to output.
     */
    public static func fail(msg: String) throws {
        throw Exception.Error(type: ExceptionType.IllegalArgumentException, Message: msg)
    }

    /**
     Helper
     */
    public static func exception(msg: String) throws {
        throw Exception.Error(type: ExceptionType.IllegalArgumentException, Message: msg)
    }
}
