//
//  TextUtil.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 03/11/16.
//  Copyright © 2016 Nabil Chatbi. All rights reserved.
//

import Foundation
@testable import SwiftSoup

class TextUtil {
	public static func stripNewlines(_ text: String) -> String {
        do {
            let regex = try NSRegularExpression(pattern: "\\n\\s*", options: .caseInsensitive)
            let str = regex.stringByReplacingMatches(in: text,
                                                     options: [],
                                                     range: NSRange(0..<text.count),
                                                     withTemplate: "")
            return str
        } catch {
            return ""
        }
	}
}

//extension String{
//	func replaceAll(of pattern:String,with replacement:String,options: NSRegularExpression.Options = []) -> String{
//		do{
//			let regex = try NSRegularExpression(pattern: pattern, options: [])
//			let range = NSRange(0..<self.utf16.count)
//			return regex.stringByReplacingMatches(in: self, options: [],
//			                                      range: range, withTemplate: replacement)
//		}catch{
//			NSLog("replaceAll error: \(error)")
//			return self
//		}
//	}
//	
//	func trim() -> String {
//		return trimmingCharacters(in: NSCharacterSet.whitespacesAndNewlines)
//	}
//}
