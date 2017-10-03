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
    public static let EOF: Byte = Byte.max // 0xffff//Byte(65535)
    
    /// null
    public static let null: Byte = 0x00
    
    /// <
    public static let lessThan: Byte = 0x3c
    
    /// >
    public static let greaterThan: Byte = 0x3e
    
    /// \f
    public static let formfeed: Byte = 12
    
    /// replaces null character
    static  let replacementChar: Byte = Byte.max - 2  //  0xfffd//Byte(65533)
    
    /// "`"
    static  let backquote: Byte = 0x60
    
    /// "\\"
    static  let esc: Byte = 92
    
    /// ""
    static  let empty: Byte = 0
    
 
    public var uppercase: Byte{
        return self & 0x5f
    }
    
    public var lowercase: Byte{
        return self ^ 0x20
    }
    
}

//extension Bytes {
//    
//    public var uppercase: Bytes{
//        return self.map{$0.uppercase}
//    }
//    
//    public var lowercase: Bytes{
//        return self.map{$0.lowercase}
//    }
//    
//}

