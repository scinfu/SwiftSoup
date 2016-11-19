//
//  Entities.swift
//  SwifSoup
//
//  Created by Nabil Chatbi on 29/09/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import Foundation



/**
 * HTML entities, and escape routines.
 * Source: <a href="http://www.w3.org/TR/html5/named-character-references.html#named-character-references">W3C HTML
 * named character references</a>.
 */
public class Entities {
    static let entityPattern : Pattern = Pattern("^(\\w+)=(\\w+)(?:,(\\w+))?;(\\w+)$")
    static let empty = -1;
    static let emptyName = "";
    static let codepointRadix : Int = 36;
    
    
	public struct EscapeMode : Equatable{
        /** Restricted entities suitable for XHTML output: lt, gt, amp, and quot only. */
		public static let xhtml : EscapeMode = EscapeMode(file: "entities-xhtml.properties", size: 4, id: 0)
        /** Default HTML output entities. */
		public static let base : EscapeMode = EscapeMode(file: "entities-base.properties", size: 106, id: 1)
        /** Complete HTML entities. */
		public static let extended: EscapeMode = EscapeMode(file: "entities-full.properties", size: 2125, id: 2)
        
        fileprivate let value : Int ;
        
        // table of named references to their codepoints. sorted so we can binary search. built by BuildEntities.
        fileprivate var nameKeys : [String];
        fileprivate var codeVals : [Int] ; // limitation is the few references with multiple characters; those go into multipoints.
        
        // table of codepoints to named entities.
        fileprivate var codeKeys : [Int] // we don' support multicodepoints to single named value currently
        fileprivate var nameVals : [String] ;
        
        public static func == (left: EscapeMode, right: EscapeMode) -> Bool {
            return left.value == right.value
        }
        
        static func != (left: EscapeMode, right: EscapeMode) -> Bool {
            return left.value != right.value
        }
        
        init(file: String, size:Int ,id:Int) {
            nameKeys = [String](repeating: "", count: size)
            codeVals = [Int](repeating: 0, count: size)
            codeKeys = [Int](repeating: 0, count: size)
            nameVals = [String](repeating: "", count: size)
            value  = id
            
            
            let frameworkBundle = Bundle(for: Entities.self)
			var path = frameworkBundle.path(forResource:"SwiftSoup.bundle/"+file, ofType: "")
			if(path == nil){
				path = frameworkBundle.path(forResource:file, ofType: "")
			}
			if(path == nil){
				return
			}
			
            if let aStreamReader = StreamReader(path:path!) {
                defer
                {
                    aStreamReader.close()
                }
                
                var i = 0;
                while let entry = aStreamReader.nextLine() {
                    // NotNestedLessLess=10913,824;1887
                    let match = Entities.entityPattern.matcher(in: entry);
                    if (match.find())
                    {
                        let name = match.group(1)!;
                        let cp1 = Int(match.group(2)!,radix: codepointRadix)
                        //let cp2 = Int(Int.parseInt(s: match.group(3), radix: codepointRadix));
                        let cp2 = match.group(3) != nil ? Int(match.group(3)!,radix: codepointRadix) : empty;
                        let index = Int(match.group(4)!,radix: codepointRadix)
                        
                        nameKeys[i] = name;
                        codeVals[i] = cp1!;
                        codeKeys[index!] = cp1!;
                        nameVals[index!] = name;
                        
                        if (cp2 != empty) {
                            var s = String();
                            s.append(Character(UnicodeScalar(cp1!)!))
                            s.append(Character(UnicodeScalar(cp2!)!))
                            multipoints[name] = s
                        }
                        i += 1;
                    }
                }
            }
        }
        
        public func codepointForName(_ name: String) -> Int
        {
            let index = nameKeys.binarySearch(nameKeys,name)
            return index >= 0 ? codeVals[index] : empty;
        }
        
        public func nameForCodepoint(_ codepoint: Int )->String {
            //let ss = codeKeys.index(of: codepoint)
            let index = codeKeys.binarySearch(codeKeys,codepoint)
            if (index >= 0) {
                // the results are ordered so lower case versions of same codepoint come after uppercase, and we prefer to emit lower
                // (and binary search for same item with multi results is undefined
                return (index < nameVals.count-1 && codeKeys[index+1] == codepoint) ?
                    nameVals[index+1] : nameVals[index];
            }
            return emptyName;
        }
        
        private func size() -> Int {
            return nameKeys.count;
        }
        
    }
    
    private static var multipoints : Dictionary<String, String>  = Dictionary<String, String>(); // name -> multiple character references
    
    private init() {
    }
    
    /**
     * Check if the input is a known named entity
     * @param name the possible entity name (e.g. "lt" or "amp")
     * @return true if a known named entity
     */
    open static func isNamedEntity(_ name: String )->Bool {
        return (EscapeMode.extended.codepointForName(name) != empty);
    }
    
    /**
     * Check if the input is a known named entity in the base entity set.
     * @param name the possible entity name (e.g. "lt" or "amp")
     * @return true if a known named entity in the base set
     * @see #isNamedEntity(String)
     */
    open static func isBaseNamedEntity(_ name: String) -> Bool {
        return EscapeMode.base.codepointForName(name) != empty;
    }
    
    /**
     * Get the Character value of the named entity
     * @param name named entity (e.g. "lt" or "amp")
     * @return the Character value of the named entity (e.g. '{@literal <}' or '{@literal &}')
     * @deprecated does not support characters outside the BMP or multiple character names
     */
    open static func getCharacterByName(name: String) -> Character {
        return Character.convertFromIntegerLiteral(value:EscapeMode.extended.codepointForName(name));
    }
    
    /**
     * Get the character(s) represented by the named entitiy
     * @param name entity (e.g. "lt" or "amp")
     * @return the string value of the character(s) represented by this entity, or "" if not defined
     */
    open static func getByName(name: String)-> String {
        let val = multipoints[name];
        if (val != nil){return val!;}
        let codepoint = EscapeMode.extended.codepointForName(name);
        if (codepoint != empty)
        {
            return String(Character(UnicodeScalar(codepoint)!));
        }
        return emptyName;
    }
	
    open static func codepointsForName(_ name: String , codepoints: inout [UnicodeScalar]) -> Int {
		
		if let val: String = multipoints[name]
		{
			codepoints[0] = val.unicodeScalar(0);
			codepoints[1] = val.unicodeScalar(1);
            return 2;
        }
		
        let codepoint = EscapeMode.extended.codepointForName(name);
        if (codepoint != empty) {
            codepoints[0] = UnicodeScalar(codepoint)!;
            return 1;
        }
        return 0;
    }
    
    
    
    
    open static func escape(_ string: String,_ out: OutputSettings) -> String
    {
        let accum = StringBuilder();//string.characters.count * 2
        escape(accum, string, out, false, false, false);
        //        try {
        //
        //        } catch (IOException e) {
        //        throw new SerializationException(e); // doesn't happen
        //        }
        return accum.toString();
    }
    
    
    // this method is ugly, and does a lot. but other breakups cause rescanning and stringbuilder generations
    static func escape(_ accum: StringBuilder ,_ string: String,_ out: OutputSettings,_ inAttribute: Bool,_ normaliseWhite: Bool,_ stripLeadingWhite: Bool )
    {
        var lastWasWhite = false;
        var reachedNonWhite = false;
        let escapeMode : EscapeMode = out.escapeMode();
        let encoder : String.Encoding = out.encoder();
        //let length = UInt32(string.characters.count);
        
        var codePoint : UnicodeScalar;
        for ch in string.characters
        {
            codePoint = ch.unicodeScalar
            
            if (normaliseWhite) {
                if (codePoint.isWhitespace) {
                    if ((stripLeadingWhite && !reachedNonWhite) || lastWasWhite){
                        continue;
                    }
                    accum.append(" ");
                    lastWasWhite = true;
                    continue;
                } else {
                    lastWasWhite = false;
                    reachedNonWhite = true;
                }
            }
            
            // surrogate pairs, split implementation for efficiency on single char common case (saves creating strings, char[]):
            if (codePoint.value < Character.MIN_SUPPLEMENTARY_CODE_POINT) {
                let c = codePoint;
                // html specific and required escapes:
                switch (codePoint) {
                case "&":
                    accum.append("&amp;");
                    break;
                case UnicodeScalar(UInt32(0xA0))!:
                    if (escapeMode != EscapeMode.xhtml){
                        accum.append("&nbsp;");
                    }else{
                        accum.append("&#xa0;");
                    }
                    break;
                case "<":
                    // escape when in character data or when in a xml attribue val; not needed in html attr val
                    if (!inAttribute || escapeMode == EscapeMode.xhtml){
                        accum.append("&lt;");
                    }else{
                        accum.append(c);
                    }
                    break;
                case ">":
                    if (!inAttribute){
                        accum.append("&gt;");
                    }else{
                        accum.append(c);}
                    break;
                case "\"":
                    if (inAttribute){
                        accum.append("&quot;");
                    }else{
                        accum.append(c);
                    }
                    break;
                default:
                    if (canEncode(c, encoder)){
                        accum.append(c);
                    }
                    else{
                        appendEncoded(accum: accum, escapeMode: escapeMode, codePoint: codePoint);
                    }
                }
            } else {
                if (encoder.canEncode(String(codePoint))) // uses fallback encoder for simplicity
                {
                    accum.append(String(codePoint))
                }else{
                    appendEncoded(accum: accum, escapeMode: escapeMode, codePoint: codePoint);
                }
            }
        }
    }
    
    private static func appendEncoded(accum: StringBuilder, escapeMode: EscapeMode, codePoint: UnicodeScalar)
    {
        let name = escapeMode.nameForCodepoint(Int(codePoint.value));
        if (name != emptyName) // ok for identity check
        {accum.append("&").append(name).append(";");
        }else{
            accum.append("&#x").append(String.toHexString(n:Int(codePoint.value)) ).append(";");
        }
    }
    
    public static func unescape(_ string: String)throws-> String {
        return try unescape(string: string, strict: false);
    }
    
    /**
     * Unescape the input string.
     * @param string to un-HTML-escape
     * @param strict if "strict" (that is, requires trailing ';' char, otherwise that's optional)
     * @return unescaped string
     */
    public static func unescape(string: String, strict: Bool)throws -> String {
        return try Parser.unescapeEntities(string, strict);
    }
    
    /*
     * Provides a fast-path for Encoder.canEncode, which drastically improves performance on Android post JellyBean.
     * After KitKat, the implementation of canEncode degrades to the point of being useless. For non ASCII or UTF,
     * performance may be bad. We can add more encoders for common character sets that are impacted by performance
     * issues on Android if required.
     *
     * Benchmarks:     *
     * OLD toHtml() impl v New (fastpath) in millis
     * Wiki: 1895, 16
     * CNN: 6378, 55
     * Alterslash: 3013, 28
     * Jsoup: 167, 2
     */
    private static func canEncode(_ c: UnicodeScalar, _ fallback: String.Encoding)->Bool {
        // todo add more charset tests if impacted by Android's bad perf in canEncode
        switch (fallback)
        {
        case String.Encoding.ascii:
            return c.value < 0x80;
        case String.Encoding.utf8:
            return true; // real is:!(Character.isLowSurrogate(c) || Character.isHighSurrogate(c)); - but already check above
        default:
            return fallback.canEncode(String(Character(c)))
        }
    }
}
