//
//  Byte+SwiftSoup.swift
//  Pods
//
//  Created by Nabil on 05/07/17.
//
//

import Foundation

extension Byte {
    /// EOF
    public static let EOF: Byte = 0xffff//Byte(65535)
    
    /// null
    public static let null: Byte = 0x00
    
    /// <
    public static let lessThan: Byte = 0x3c
    
    /// >
    public static let greaterThan: Byte = 0x3e
    
    /// \f
    public static let formfeed: Byte = 12
    
    /// replaces null character
    static  let replacementChar: Byte = 0xfffd//Byte(65533)
    
    /// "`"
    static  let backquote: Byte = 0x60
    
 
    public var uppercase: Byte{
        return self & 0x5f
    }
    
    public var lowercase: Byte{
        return self ^ 0x20
    }
    
    
    
}
