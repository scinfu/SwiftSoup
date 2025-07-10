//
//  Exception.swift
//  SwifSoup
//
//  Created by Nabil Chatbi on 02/10/16.
//

import Foundation

public enum ExceptionType: Sendable {
    case IllegalArgumentException
    case IOException
    case XmlDeclaration
    case MalformedURLException
    case CloneNotSupportedException
    case SelectorParseException
}

public enum Exception: Error {
    case Error(type:ExceptionType, Message: String)
}
