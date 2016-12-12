//
//  Exception.swift
//  SwifSoup
//
//  Created by Nabil Chatbi on 02/10/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import Foundation

enum ExceptionType {
    case IllegalArgumentException
    case IOException
    case XmlDeclaration
    case MalformedURLException
    case CloneNotSupportedException
    case SelectorParseException
}

enum Exception : Error {
    case Error(type:ExceptionType ,Message: String)
}


