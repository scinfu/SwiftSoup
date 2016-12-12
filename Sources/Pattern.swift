//
//  Regex.swift
//  SwifSoup
//
//  Created by Nabil Chatbi on 08/10/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import Foundation

public struct Pattern {
    public static let CASE_INSENSITIVE: Int = 0x02;
    let pattern: String
    
    init(_ pattern: String) {
        self.pattern = pattern
    }
    
    static public func compile(_ s: String)->Pattern
    {
        return Pattern(s)
    }
    static public func compile(_ s: String, _ op: Int)->Pattern
    {
        return Pattern(s)
    }
    
    func validate()throws
    {
         _ = try NSRegularExpression(pattern: self.pattern)
    }
    
    func matcher(in text: String) -> Matcher {
        do {
            let regex = try NSRegularExpression(pattern: self.pattern)
            let nsString = text as NSString
            let results = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
            
            return Matcher(results,text)
        } catch let error {
            print("invalid regex: \(error.localizedDescription)")
            return Matcher([],text)
        }
    }
    
    public func toString()->String{
        return pattern
    }
    
    public func split(_ input: String)->Array<String>
    {
        let m = matcher(in: input);
        var a = Array<String>()
//        for i in 0..<m.matches.count{
//            a.append(m.group(i)!)
//        }
		while m.find() {
			a.append(m.group(0)!)
		}
        return a
    }
}

public class  Matcher
{
    let matches :[NSTextCheckingResult]
    let string : String
    var index : Int = -1;
    
    public var count : Int { return matches.count}
    
    init(_ m:[NSTextCheckingResult],_ s: String)
    {
        matches = m
        string = s
    }
    
    @discardableResult
    public func find() -> Bool
    {
        index += 1;
        if(index < matches.count)
        {
            return true;
        }
        return false;
    }
    
    public func group(_ i: Int) -> String?
    {
        let b = matches[index]
        let c = b.rangeAt(i)
        if(c.location == NSNotFound) {return nil;}
		let result = (string as NSString).substring(with:c)
        return result
    }
    public func group() -> String?
    {
        return group(0)
    }
}
