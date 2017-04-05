//
//  PlatformTypes.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 27/12/16.
//  Copyright © 2016 Nabil Chatbi. All rights reserved.
//

import Foundation

#if !os(Linux)
	typealias NCRegularExpression = NSRegularExpression
	typealias NCTextCheckingResult = NSTextCheckingResult
#else
	typealias NCRegularExpression = NSRegularExpression
	typealias NCTextCheckingResult = TextCheckingResult
#endif
