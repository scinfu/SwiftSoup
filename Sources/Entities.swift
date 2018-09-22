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
    private static let empty = -1
    private static let emptyName = ""
    private static let codepointRadix: Int = 36

    public struct EscapeMode: Equatable {

        /** Restricted entities suitable for XHTML output: lt, gt, amp, and quot only. */
        public static let xhtml: EscapeMode = EscapeMode(string: Entities.xhtml, size: 4, id: 0)
        /** Default HTML output entities. */
        public static let base: EscapeMode = EscapeMode(string: Entities.base, size: 106, id: 1)
        /** Complete HTML entities. */
        public static let extended: EscapeMode = EscapeMode(string: Entities.full, size: 2125, id: 2)

        fileprivate let value: Int

        // table of named references to their codepoints. sorted so we can binary search. built by BuildEntities.
        fileprivate var nameKeys: [String]
        fileprivate var codeVals: [Int]  // limitation is the few references with multiple characters; those go into multipoints.

        // table of codepoints to named entities.
        fileprivate var codeKeys: [Int] // we don' support multicodepoints to single named value currently
        fileprivate var nameVals: [String]

        public static func == (left: EscapeMode, right: EscapeMode) -> Bool {
            return left.value == right.value
        }

        static func != (left: EscapeMode, right: EscapeMode) -> Bool {
            return left.value != right.value
        }

        private static let codeDelims: [UnicodeScalar]  = [",", ";"]

        init(string: String, size: Int, id: Int) {
            nameKeys = [String](repeating: "", count: size)
            codeVals = [Int](repeating: 0, count: size)
            codeKeys = [Int](repeating: 0, count: size)
            nameVals = [String](repeating: "", count: size)
            value  = id

            //Load()

            var i = 0

            let reader: CharacterReader = CharacterReader(string)

            while (!reader.isEmpty()) {
                // NotNestedLessLess=10913,824;1887

                let name: String = reader.consumeTo("=")
                reader.advance()
                let cp1: Int = Int(reader.consumeToAny(EscapeMode.codeDelims), radix: codepointRadix) ?? 0
                let codeDelim: UnicodeScalar = reader.current()
                reader.advance()
                let cp2: Int
                if (codeDelim == ",") {
                    cp2 = Int(reader.consumeTo(";"), radix: codepointRadix) ?? 0
                    reader.advance()
                } else {
                    cp2 = empty
                }
                let index: Int = Int(reader.consumeTo("\n"), radix: codepointRadix) ?? 0
                reader.advance()

                nameKeys[i] = name
                codeVals[i] = cp1
                codeKeys[index] = cp1
                nameVals[index] = name

                if (cp2 != empty) {
                    var s = String()
                    s.append(Character(UnicodeScalar(cp1)!))
                    s.append(Character(UnicodeScalar(cp2)!))
                    multipoints[name] = s
                }
                i = i + 1
            }
        }

//        init(string: String, size: Int, id: Int) {
//            nameKeys = [String](repeating: "", count: size)
//            codeVals = [Int](repeating: 0, count: size)
//            codeKeys = [Int](repeating: 0, count: size)
//            nameVals = [String](repeating: "", count: size)
//            value  = id
//            
//            let components = string.components(separatedBy: "\n")
//            
//            var i = 0
//            for entry  in components {
//                let match = Entities.entityPattern.matcher(in: entry)
//                if (match.find()) {
//                    let name = match.group(1)!
//                    let cp1 = Int(match.group(2)!, radix: codepointRadix)
//                    //let cp2 = Int(Int.parseInt(s: match.group(3), radix: codepointRadix))
//                    let cp2 = match.group(3) != nil ? Int(match.group(3)!, radix: codepointRadix) : empty
//                    let index = Int(match.group(4)!, radix: codepointRadix)
//                    
//                    nameKeys[i] = name
//                    codeVals[i] = cp1!
//                    codeKeys[index!] = cp1!
//                    nameVals[index!] = name
//                    
//                    if (cp2 != empty) {
//                        var s = String()
//                        s.append(Character(UnicodeScalar(cp1!)!))
//                        s.append(Character(UnicodeScalar(cp2!)!))
//                        multipoints[name] = s
//                    }
//                    i += 1
//                }
//            }
//        }

        public func codepointForName(_ name: String) -> Int {
//            for s in nameKeys {
//                if s == name {
//                    return codeVals[nameKeys.index(of: s)!]
//                }
//            }
            guard let index = nameKeys.index(of: name) else {
                return empty
            }
            return codeVals[index]
        }

        public func nameForCodepoint(_ codepoint: Int ) -> String {
            //let ss = codeKeys.index(of: codepoint)

            var index = -1
            for s in codeKeys {
                if s == codepoint {
                    index = codeKeys.index(of: codepoint)!
                }
            }

            if (index >= 0) {
                // the results are ordered so lower case versions of same codepoint come after uppercase, and we prefer to emit lower
                // (and binary search for same item with multi results is undefined
                return (index < nameVals.count-1 && codeKeys[index+1] == codepoint) ?
                    nameVals[index+1] : nameVals[index]
            }
            return emptyName
        }

        private func size() -> Int {
            return nameKeys.count
        }

    }

    private static var multipoints: Dictionary<String, String>  = Dictionary<String, String>() // name -> multiple character references

    private init() {
    }

    /**
     * Check if the input is a known named entity
     * @param name the possible entity name (e.g. "lt" or "amp")
     * @return true if a known named entity
     */
    public static func isNamedEntity(_ name: String ) -> Bool {
        return (EscapeMode.extended.codepointForName(name) != empty)
    }

    /**
     * Check if the input is a known named entity in the base entity set.
     * @param name the possible entity name (e.g. "lt" or "amp")
     * @return true if a known named entity in the base set
     * @see #isNamedEntity(String)
     */
    public static func isBaseNamedEntity(_ name: String) -> Bool {
        return EscapeMode.base.codepointForName(name) != empty
    }

    /**
     * Get the Character value of the named entity
     * @param name named entity (e.g. "lt" or "amp")
     * @return the Character value of the named entity (e.g. '{@literal <}' or '{@literal &}')
     * @deprecated does not support characters outside the BMP or multiple character names
     */
    public static func getCharacterByName(name: String) -> Character {
        return Character.convertFromIntegerLiteral(value: EscapeMode.extended.codepointForName(name))
    }

    /**
     * Get the character(s) represented by the named entitiy
     * @param name entity (e.g. "lt" or "amp")
     * @return the string value of the character(s) represented by this entity, or "" if not defined
     */
    public static func getByName(name: String) -> String {
        let val = multipoints[name]
        if (val != nil) {return val!}
        let codepoint = EscapeMode.extended.codepointForName(name)
        if (codepoint != empty) {
            return String(Character(UnicodeScalar(codepoint)!))
        }
        return emptyName
    }

    public static func codepointsForName(_ name: String, codepoints: inout [UnicodeScalar]) -> Int {

        if let val: String = multipoints[name] {
            codepoints[0] = val.unicodeScalar(0)
            codepoints[1] = val.unicodeScalar(1)
            return 2
        }

        let codepoint = EscapeMode.extended.codepointForName(name)
        if (codepoint != empty) {
            codepoints[0] = UnicodeScalar(codepoint)!
            return 1
        }
        return 0
    }

    public static func escape(_ string: String, _ encode: String.Encoding = .utf8 ) -> String {
        return Entities.escape(string, OutputSettings().charset(encode).escapeMode(Entities.EscapeMode.extended))
    }

    public static func escape(_ string: String, _ out: OutputSettings) -> String {
        let accum = StringBuilder()//string.characters.count * 2
        escape(accum, string, out, false, false, false)
        //        try {
        //
        //        } catch (IOException e) {
        //        throw new SerializationException(e) // doesn't happen
        //        }
        return accum.toString()
    }

    // this method is ugly, and does a lot. but other breakups cause rescanning and stringbuilder generations
    static func escape(_ accum: StringBuilder, _ string: String, _ out: OutputSettings, _ inAttribute: Bool, _ normaliseWhite: Bool, _ stripLeadingWhite: Bool ) {
        var lastWasWhite = false
        var reachedNonWhite = false
        let escapeMode: EscapeMode = out.escapeMode()
        let encoder: String.Encoding = out.encoder()
        //let length = UInt32(string.characters.count)

        var codePoint: UnicodeScalar
        for ch in string.unicodeScalars {
            codePoint = ch

            if (normaliseWhite) {
                if (codePoint.isWhitespace) {
                    if ((stripLeadingWhite && !reachedNonWhite) || lastWasWhite) {
                        continue
                    }
                    accum.append(UnicodeScalar.Space)
                    lastWasWhite = true
                    continue
                } else {
                    lastWasWhite = false
                    reachedNonWhite = true
                }
            }

            // surrogate pairs, split implementation for efficiency on single char common case (saves creating strings, char[]):
            if (codePoint.value < Character.MIN_SUPPLEMENTARY_CODE_POINT) {
                let c = codePoint
                // html specific and required escapes:
                switch (codePoint) {
                case UnicodeScalar.Ampersand:
                    accum.append("&amp;")
                    break
                case UnicodeScalar(UInt32(0xA0))!:
                    if (escapeMode != EscapeMode.xhtml) {
                        accum.append("&nbsp;")
                    } else {
                        accum.append("&#xa0;")
                    }
                    break
                case UnicodeScalar.LessThan:
                    // escape when in character data or when in a xml attribue val; not needed in html attr val
                    if (!inAttribute || escapeMode == EscapeMode.xhtml) {
                        accum.append("&lt;")
                    } else {
                        accum.append(c)
                    }
                    break
                case UnicodeScalar.GreaterThan:
                    if (!inAttribute) {
                        accum.append("&gt;")
                    } else {
                        accum.append(c)}
                    break
                case "\"":
                    if (inAttribute) {
                        accum.append("&quot;")
                    } else {
                        accum.append(c)
                    }
                    break
                default:
                    if (canEncode(c, encoder)) {
                        accum.append(c)
                    } else {
                        appendEncoded(accum: accum, escapeMode: escapeMode, codePoint: codePoint)
                    }
                }
            } else {
                if (encoder.canEncode(String(codePoint))) // uses fallback encoder for simplicity
                {
                    accum.append(String(codePoint))
                } else {
                    appendEncoded(accum: accum, escapeMode: escapeMode, codePoint: codePoint)
                }
            }
        }
    }

    private static func appendEncoded(accum: StringBuilder, escapeMode: EscapeMode, codePoint: UnicodeScalar) {
        let name = escapeMode.nameForCodepoint(Int(codePoint.value))
        if (name != emptyName) // ok for identity check
        {accum.append(UnicodeScalar.Ampersand).append(name).append(";")
        } else {
            accum.append("&#x").append(String.toHexString(n: Int(codePoint.value)) ).append(";")
        }
    }

    public static func unescape(_ string: String)throws-> String {
        return try unescape(string: string, strict: false)
    }

    /**
     * Unescape the input string.
     * @param string to un-HTML-escape
     * @param strict if "strict" (that is, requires trailing ';' char, otherwise that's optional)
     * @return unescaped string
     */
    public static func unescape(string: String, strict: Bool)throws -> String {
        return try Parser.unescapeEntities(string, strict)
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
    private static func canEncode(_ c: UnicodeScalar, _ fallback: String.Encoding) -> Bool {
        // todo add more charset tests if impacted by Android's bad perf in canEncode
        switch (fallback) {
        case String.Encoding.ascii:
            return c.value < 0x80
        case String.Encoding.utf8:
            return true // real is:!(Character.isLowSurrogate(c) || Character.isHighSurrogate(c)) - but already check above
        default:
            return fallback.canEncode(String(Character(c)))
        }
    }

    static let xhtml: String = "amp=12;1\ngt=1q;3\nlt=1o;2\nquot=y;0"

    static let base: String = "AElig=5i;1c\nAMP=12;2\nAacute=5d;17\nAcirc=5e;18\nAgrave=5c;16\nAring=5h;1b\nAtilde=5f;19\nAuml=5g;1a\nCOPY=4p;h\nCcedil=5j;1d\nETH=5s;1m\nEacute=5l;1f\nEcirc=5m;1g\nEgrave=5k;1e\nEuml=5n;1h\nGT=1q;6\nIacute=5p;1j\nIcirc=5q;1k\nIgrave=5o;1i\nIuml=5r;1l\nLT=1o;4\nNtilde=5t;1n\nOacute=5v;1p\nOcirc=5w;1q\nOgrave=5u;1o\nOslash=60;1u\nOtilde=5x;1r\nOuml=5y;1s\nQUOT=y;0\nREG=4u;n\nTHORN=66;20\nUacute=62;1w\nUcirc=63;1x\nUgrave=61;1v\nUuml=64;1y\nYacute=65;1z\naacute=69;23\nacirc=6a;24\nacute=50;u\naelig=6e;28\nagrave=68;22\namp=12;3\naring=6d;27\natilde=6b;25\nauml=6c;26\nbrvbar=4m;e\nccedil=6f;29\ncedil=54;y\ncent=4i;a\ncopy=4p;i\ncurren=4k;c\ndeg=4w;q\ndivide=6v;2p\neacute=6h;2b\necirc=6i;2c\negrave=6g;2a\neth=6o;2i\neuml=6j;2d\nfrac12=59;13\nfrac14=58;12\nfrac34=5a;14\ngt=1q;7\niacute=6l;2f\nicirc=6m;2g\niexcl=4h;9\nigrave=6k;2e\niquest=5b;15\niuml=6n;2h\nlaquo=4r;k\nlt=1o;5\nmacr=4v;p\nmicro=51;v\nmiddot=53;x\nnbsp=4g;8\nnot=4s;l\nntilde=6p;2j\noacute=6r;2l\nocirc=6s;2m\nograve=6q;2k\nordf=4q;j\nordm=56;10\noslash=6w;2q\notilde=6t;2n\nouml=6u;2o\npara=52;w\nplusmn=4x;r\npound=4j;b\nquot=y;1\nraquo=57;11\nreg=4u;o\nsect=4n;f\nshy=4t;m\nsup1=55;z\nsup2=4y;s\nsup3=4z;t\nszlig=67;21\nthorn=72;2w\ntimes=5z;1t\nuacute=6y;2s\nucirc=6z;2t\nugrave=6x;2r\numl=4o;g\nuuml=70;2u\nyacute=71;2v\nyen=4l;d\nyuml=73;2x"

    static let full: String = "AElig=5i;2v\nAMP=12;8\nAacute=5d;2p\nAbreve=76;4k\nAcirc=5e;2q\nAcy=sw;av\nAfr=2kn8;1kh\nAgrave=5c;2o\nAlpha=pd;8d\nAmacr=74;4i\nAnd=8cz;1e1\nAogon=78;4m\nAopf=2koo;1ls\nApplyFunction=6e9;ew\nAring=5h;2t\nAscr=2kkc;1jc\nAssign=6s4;s6\nAtilde=5f;2r\nAuml=5g;2s\nBackslash=6qe;o1\nBarv=8h3;1it\nBarwed=6x2;120\nBcy=sx;aw\nBecause=6r9;pw\nBernoullis=6jw;gn\nBeta=pe;8e\nBfr=2kn9;1ki\nBopf=2kop;1lt\nBreve=k8;82\nBscr=6jw;gp\nBumpeq=6ry;ro\nCHcy=tj;bi\nCOPY=4p;1q\nCacute=7a;4o\nCap=6vm;zz\nCapitalDifferentialD=6kl;h8\nCayleys=6jx;gq\nCcaron=7g;4u\nCcedil=5j;2w\nCcirc=7c;4q\nCconint=6r4;pn\nCdot=7e;4s\nCedilla=54;2e\nCenterDot=53;2b\nCfr=6jx;gr\nChi=pz;8y\nCircleDot=6u1;x8\nCircleMinus=6ty;x3\nCirclePlus=6tx;x1\nCircleTimes=6tz;x5\nClockwiseContourIntegral=6r6;pp\nCloseCurlyDoubleQuote=6cd;e0\nCloseCurlyQuote=6c9;dt\nColon=6rb;q1\nColone=8dw;1en\nCongruent=6sh;sn\nConint=6r3;pm\nContourIntegral=6r2;pi\nCopf=6iq;f7\nCoproduct=6q8;nq\nCounterClockwiseContourIntegral=6r7;pr\nCross=8bz;1d8\nCscr=2kke;1jd\nCup=6vn;100\nCupCap=6rx;rk\nDD=6kl;h9\nDDotrahd=841;184\nDJcy=si;ai\nDScy=sl;al\nDZcy=sv;au\nDagger=6ch;e7\nDarr=6n5;j5\nDashv=8h0;1ir\nDcaron=7i;4w\nDcy=t0;az\nDel=6pz;n9\nDelta=pg;8g\nDfr=2knb;1kj\nDiacriticalAcute=50;27\nDiacriticalDot=k9;84\nDiacriticalDoubleAcute=kd;8a\nDiacriticalGrave=2o;13\nDiacriticalTilde=kc;88\nDiamond=6v8;za\nDifferentialD=6km;ha\nDopf=2kor;1lu\nDot=4o;1n\nDotDot=6ho;f5\nDotEqual=6s0;rw\nDoubleContourIntegral=6r3;pl\nDoubleDot=4o;1m\nDoubleDownArrow=6oj;m0\nDoubleLeftArrow=6og;lq\nDoubleLeftRightArrow=6ok;m3\nDoubleLeftTee=8h0;1iq\nDoubleLongLeftArrow=7w8;17g\nDoubleLongLeftRightArrow=7wa;17m\nDoubleLongRightArrow=7w9;17j\nDoubleRightArrow=6oi;lw\nDoubleRightTee=6ug;xz\nDoubleUpArrow=6oh;lt\nDoubleUpDownArrow=6ol;m7\nDoubleVerticalBar=6qt;ov\nDownArrow=6mr;i8\nDownArrowBar=843;186\nDownArrowUpArrow=6ph;mn\nDownBreve=lt;8c\nDownLeftRightVector=85s;198\nDownLeftTeeVector=866;19m\nDownLeftVector=6nx;ke\nDownLeftVectorBar=85y;19e\nDownRightTeeVector=867;19n\nDownRightVector=6o1;kq\nDownRightVectorBar=85z;19f\nDownTee=6uc;xs\nDownTeeArrow=6nb;jh\nDownarrow=6oj;m1\nDscr=2kkf;1je\nDstrok=7k;4y\nENG=96;6g\nETH=5s;35\nEacute=5l;2y\nEcaron=7u;56\nEcirc=5m;2z\nEcy=tp;bo\nEdot=7q;52\nEfr=2knc;1kk\nEgrave=5k;2x\nElement=6q0;na\nEmacr=7m;50\nEmptySmallSquare=7i3;15x\nEmptyVerySmallSquare=7fv;150\nEogon=7s;54\nEopf=2kos;1lv\nEpsilon=ph;8h\nEqual=8dx;1eo\nEqualTilde=6rm;qp\nEquilibrium=6oc;li\nEscr=6k0;gu\nEsim=8dv;1em\nEta=pj;8j\nEuml=5n;30\nExists=6pv;mz\nExponentialE=6kn;hc\nFcy=tg;bf\nFfr=2knd;1kl\nFilledSmallSquare=7i4;15y\nFilledVerySmallSquare=7fu;14w\nFopf=2kot;1lw\nForAll=6ps;ms\nFouriertrf=6k1;gv\nFscr=6k1;gw\nGJcy=sj;aj\nGT=1q;r\nGamma=pf;8f\nGammad=rg;a5\nGbreve=7y;5a\nGcedil=82;5e\nGcirc=7w;58\nGcy=sz;ay\nGdot=80;5c\nGfr=2kne;1km\nGg=6vt;10c\nGopf=2kou;1lx\nGreaterEqual=6sl;sv\nGreaterEqualLess=6vv;10i\nGreaterFullEqual=6sn;t6\nGreaterGreater=8f6;1gh\nGreaterLess=6t3;ul\nGreaterSlantEqual=8e6;1f5\nGreaterTilde=6sz;ub\nGscr=2kki;1jf\nGt=6sr;tr\nHARDcy=tm;bl\nHacek=jr;80\nHat=2m;10\nHcirc=84;5f\nHfr=6j0;fe\nHilbertSpace=6iz;fa\nHopf=6j1;fg\nHorizontalLine=7b4;13i\nHscr=6iz;fc\nHstrok=86;5h\nHumpDownHump=6ry;rn\nHumpEqual=6rz;rs\nIEcy=t1;b0\nIJlig=8i;5s\nIOcy=sh;ah\nIacute=5p;32\nIcirc=5q;33\nIcy=t4;b3\nIdot=8g;5p\nIfr=6j5;fq\nIgrave=5o;31\nIm=6j5;fr\nImacr=8a;5l\nImaginaryI=6ko;hf\nImplies=6oi;ly\nInt=6r0;pf\nIntegral=6qz;pd\nIntersection=6v6;z4\nInvisibleComma=6eb;f0\nInvisibleTimes=6ea;ey\nIogon=8e;5n\nIopf=2kow;1ly\nIota=pl;8l\nIscr=6j4;fn\nItilde=88;5j\nIukcy=sm;am\nIuml=5r;34\nJcirc=8k;5u\nJcy=t5;b4\nJfr=2knh;1kn\nJopf=2kox;1lz\nJscr=2kkl;1jg\nJsercy=so;ao\nJukcy=sk;ak\nKHcy=th;bg\nKJcy=ss;as\nKappa=pm;8m\nKcedil=8m;5w\nKcy=t6;b5\nKfr=2kni;1ko\nKopf=2koy;1m0\nKscr=2kkm;1jh\nLJcy=sp;ap\nLT=1o;m\nLacute=8p;5z\nLambda=pn;8n\nLang=7vu;173\nLaplacetrf=6j6;fs\nLarr=6n2;j1\nLcaron=8t;63\nLcedil=8r;61\nLcy=t7;b6\nLeftAngleBracket=7vs;16x\nLeftArrow=6mo;hu\nLeftArrowBar=6p0;mj\nLeftArrowRightArrow=6o6;l3\nLeftCeiling=6x4;121\nLeftDoubleBracket=7vq;16t\nLeftDownTeeVector=869;19p\nLeftDownVector=6o3;kw\nLeftDownVectorBar=861;19h\nLeftFloor=6x6;125\nLeftRightArrow=6ms;ib\nLeftRightVector=85q;196\nLeftTee=6ub;xq\nLeftTeeArrow=6n8;ja\nLeftTeeVector=862;19i\nLeftTriangle=6uq;ya\nLeftTriangleBar=89b;1c0\nLeftTriangleEqual=6us;yg\nLeftUpDownVector=85t;199\nLeftUpTeeVector=868;19o\nLeftUpVector=6nz;kk\nLeftUpVectorBar=860;19g\nLeftVector=6nw;kb\nLeftVectorBar=85u;19a\nLeftarrow=6og;lr\nLeftrightarrow=6ok;m4\nLessEqualGreater=6vu;10e\nLessFullEqual=6sm;t0\nLessGreater=6t2;ui\nLessLess=8f5;1gf\nLessSlantEqual=8e5;1ez\nLessTilde=6sy;u8\nLfr=2knj;1kp\nLl=6vs;109\nLleftarrow=6oq;me\nLmidot=8v;65\nLongLeftArrow=7w5;177\nLongLeftRightArrow=7w7;17d\nLongRightArrow=7w6;17a\nLongleftarrow=7w8;17h\nLongleftrightarrow=7wa;17n\nLongrightarrow=7w9;17k\nLopf=2koz;1m1\nLowerLeftArrow=6mx;iq\nLowerRightArrow=6mw;in\nLscr=6j6;fu\nLsh=6nk;jv\nLstrok=8x;67\nLt=6sq;tl\nMap=83p;17v\nMcy=t8;b7\nMediumSpace=6e7;eu\nMellintrf=6k3;gx\nMfr=2knk;1kq\nMinusPlus=6qb;nv\nMopf=2kp0;1m2\nMscr=6k3;gz\nMu=po;8o\nNJcy=sq;aq\nNacute=8z;69\nNcaron=93;6d\nNcedil=91;6b\nNcy=t9;b8\nNegativeMediumSpace=6bv;dc\nNegativeThickSpace=6bv;dd\nNegativeThinSpace=6bv;de\nNegativeVeryThinSpace=6bv;db\nNestedGreaterGreater=6sr;tq\nNestedLessLess=6sq;tk\nNewLine=a;1\nNfr=2knl;1kr\nNoBreak=6e8;ev\nNonBreakingSpace=4g;1d\nNopf=6j9;fx\nNot=8h8;1ix\nNotCongruent=6si;sp\nNotCupCap=6st;tv\nNotDoubleVerticalBar=6qu;p0\nNotElement=6q1;ne\nNotEqual=6sg;sk\nNotEqualTilde=6rm,mw;qn\nNotExists=6pw;n1\nNotGreater=6sv;tz\nNotGreaterEqual=6sx;u5\nNotGreaterFullEqual=6sn,mw;t3\nNotGreaterGreater=6sr,mw;tn\nNotGreaterLess=6t5;uq\nNotGreaterSlantEqual=8e6,mw;1f2\nNotGreaterTilde=6t1;ug\nNotHumpDownHump=6ry,mw;rl\nNotHumpEqual=6rz,mw;rq\nNotLeftTriangle=6wa;113\nNotLeftTriangleBar=89b,mw;1bz\nNotLeftTriangleEqual=6wc;119\nNotLess=6su;tw\nNotLessEqual=6sw;u2\nNotLessGreater=6t4;uo\nNotLessLess=6sq,mw;th\nNotLessSlantEqual=8e5,mw;1ew\nNotLessTilde=6t0;ue\nNotNestedGreaterGreater=8f6,mw;1gg\nNotNestedLessLess=8f5,mw;1ge\nNotPrecedes=6tc;vb\nNotPrecedesEqual=8fj,mw;1gv\nNotPrecedesSlantEqual=6w0;10p\nNotReverseElement=6q4;nl\nNotRightTriangle=6wb;116\nNotRightTriangleBar=89c,mw;1c1\nNotRightTriangleEqual=6wd;11c\nNotSquareSubset=6tr,mw;wh\nNotSquareSubsetEqual=6w2;10t\nNotSquareSuperset=6ts,mw;wl\nNotSquareSupersetEqual=6w3;10v\nNotSubset=6te,6he;vh\nNotSubsetEqual=6tk;w0\nNotSucceeds=6td;ve\nNotSucceedsEqual=8fk,mw;1h1\nNotSucceedsSlantEqual=6w1;10r\nNotSucceedsTilde=6tb,mw;v7\nNotSuperset=6tf,6he;vm\nNotSupersetEqual=6tl;w3\nNotTilde=6rl;ql\nNotTildeEqual=6ro;qv\nNotTildeFullEqual=6rr;r1\nNotTildeTilde=6rt;r9\nNotVerticalBar=6qs;or\nNscr=2kkp;1ji\nNtilde=5t;36\nNu=pp;8p\nOElig=9e;6m\nOacute=5v;38\nOcirc=5w;39\nOcy=ta;b9\nOdblac=9c;6k\nOfr=2knm;1ks\nOgrave=5u;37\nOmacr=98;6i\nOmega=q1;90\nOmicron=pr;8r\nOopf=2kp2;1m3\nOpenCurlyDoubleQuote=6cc;dy\nOpenCurlyQuote=6c8;dr\nOr=8d0;1e2\nOscr=2kkq;1jj\nOslash=60;3d\nOtilde=5x;3a\nOtimes=8c7;1df\nOuml=5y;3b\nOverBar=6da;em\nOverBrace=732;13b\nOverBracket=71w;134\nOverParenthesis=730;139\nPartialD=6pu;mx\nPcy=tb;ba\nPfr=2knn;1kt\nPhi=py;8x\nPi=ps;8s\nPlusMinus=4x;22\nPoincareplane=6j0;fd\nPopf=6jd;g3\nPr=8fv;1hl\nPrecedes=6t6;us\nPrecedesEqual=8fj;1gy\nPrecedesSlantEqual=6t8;uy\nPrecedesTilde=6ta;v4\nPrime=6cz;eg\nProduct=6q7;no\nProportion=6rb;q0\nProportional=6ql;oa\nPscr=2kkr;1jk\nPsi=q0;8z\nQUOT=y;3\nQfr=2kno;1ku\nQopf=6je;g5\nQscr=2kks;1jl\nRBarr=840;183\nREG=4u;1x\nRacute=9g;6o\nRang=7vv;174\nRarr=6n4;j4\nRarrtl=846;187\nRcaron=9k;6s\nRcedil=9i;6q\nRcy=tc;bb\nRe=6jg;gb\nReverseElement=6q3;nh\nReverseEquilibrium=6ob;le\nReverseUpEquilibrium=86n;1a4\nRfr=6jg;ga\nRho=pt;8t\nRightAngleBracket=7vt;170\nRightArrow=6mq;i3\nRightArrowBar=6p1;ml\nRightArrowLeftArrow=6o4;ky\nRightCeiling=6x5;123\nRightDoubleBracket=7vr;16v\nRightDownTeeVector=865;19l\nRightDownVector=6o2;kt\nRightDownVectorBar=85x;19d\nRightFloor=6x7;127\nRightTee=6ua;xo\nRightTeeArrow=6na;je\nRightTeeVector=863;19j\nRightTriangle=6ur;yd\nRightTriangleBar=89c;1c2\nRightTriangleEqual=6ut;yk\nRightUpDownVector=85r;197\nRightUpTeeVector=864;19k\nRightUpVector=6ny;kh\nRightUpVectorBar=85w;19c\nRightVector=6o0;kn\nRightVectorBar=85v;19b\nRightarrow=6oi;lx\nRopf=6jh;gd\nRoundImplies=86o;1a6\nRrightarrow=6or;mg\nRscr=6jf;g7\nRsh=6nl;jx\nRuleDelayed=8ac;1cb\nSHCHcy=tl;bk\nSHcy=tk;bj\nSOFTcy=to;bn\nSacute=9m;6u\nSc=8fw;1hm\nScaron=9s;70\nScedil=9q;6y\nScirc=9o;6w\nScy=td;bc\nSfr=2knq;1kv\nShortDownArrow=6mr;i7\nShortLeftArrow=6mo;ht\nShortRightArrow=6mq;i2\nShortUpArrow=6mp;hy\nSigma=pv;8u\nSmallCircle=6qg;o6\nSopf=2kp6;1m4\nSqrt=6qi;o9\nSquare=7fl;14t\nSquareIntersection=6tv;ww\nSquareSubset=6tr;wi\nSquareSubsetEqual=6tt;wp\nSquareSuperset=6ts;wm\nSquareSupersetEqual=6tu;ws\nSquareUnion=6tw;wz\nSscr=2kku;1jm\nStar=6va;zf\nSub=6vk;zw\nSubset=6vk;zv\nSubsetEqual=6ti;vu\nSucceeds=6t7;uv\nSucceedsEqual=8fk;1h4\nSucceedsSlantEqual=6t9;v1\nSucceedsTilde=6tb;v8\nSuchThat=6q3;ni\nSum=6q9;ns\nSup=6vl;zy\nSuperset=6tf;vp\nSupersetEqual=6tj;vx\nSupset=6vl;zx\nTHORN=66;3j\nTRADE=6jm;gf\nTSHcy=sr;ar\nTScy=ti;bh\nTab=9;0\nTau=pw;8v\nTcaron=9w;74\nTcedil=9u;72\nTcy=te;bd\nTfr=2knr;1kw\nTherefore=6r8;pt\nTheta=pk;8k\nThickSpace=6e7,6bu;et\nThinSpace=6bt;d7\nTilde=6rg;q9\nTildeEqual=6rn;qs\nTildeFullEqual=6rp;qy\nTildeTilde=6rs;r4\nTopf=2kp7;1m5\nTripleDot=6hn;f3\nTscr=2kkv;1jn\nTstrok=9y;76\nUacute=62;3f\nUarr=6n3;j2\nUarrocir=85l;193\nUbrcy=su;at\nUbreve=a4;7c\nUcirc=63;3g\nUcy=tf;be\nUdblac=a8;7g\nUfr=2kns;1kx\nUgrave=61;3e\nUmacr=a2;7a\nUnderBar=2n;11\nUnderBrace=733;13c\nUnderBracket=71x;136\nUnderParenthesis=731;13a\nUnion=6v7;z8\nUnionPlus=6tq;wf\nUogon=aa;7i\nUopf=2kp8;1m6\nUpArrow=6mp;hz\nUpArrowBar=842;185\nUpArrowDownArrow=6o5;l1\nUpDownArrow=6mt;ie\nUpEquilibrium=86m;1a2\nUpTee=6ud;xv\nUpTeeArrow=6n9;jc\nUparrow=6oh;lu\nUpdownarrow=6ol;m8\nUpperLeftArrow=6mu;ih\nUpperRightArrow=6mv;ik\nUpsi=r6;9z\nUpsilon=px;8w\nUring=a6;7e\nUscr=2kkw;1jo\nUtilde=a0;78\nUuml=64;3h\nVDash=6uj;y3\nVbar=8h7;1iw\nVcy=sy;ax\nVdash=6uh;y1\nVdashl=8h2;1is\nVee=6v5;z3\nVerbar=6c6;dp\nVert=6c6;dq\nVerticalBar=6qr;on\nVerticalLine=3g;18\nVerticalSeparator=7rs;16o\nVerticalTilde=6rk;qi\nVeryThinSpace=6bu;d9\nVfr=2knt;1ky\nVopf=2kp9;1m7\nVscr=2kkx;1jp\nVvdash=6ui;y2\nWcirc=ac;7k\nWedge=6v4;z0\nWfr=2knu;1kz\nWopf=2kpa;1m8\nWscr=2kky;1jq\nXfr=2knv;1l0\nXi=pq;8q\nXopf=2kpb;1m9\nXscr=2kkz;1jr\nYAcy=tr;bq\nYIcy=sn;an\nYUcy=tq;bp\nYacute=65;3i\nYcirc=ae;7m\nYcy=tn;bm\nYfr=2knw;1l1\nYopf=2kpc;1ma\nYscr=2kl0;1js\nYuml=ag;7o\nZHcy=t2;b1\nZacute=ah;7p\nZcaron=al;7t\nZcy=t3;b2\nZdot=aj;7r\nZeroWidthSpace=6bv;df\nZeta=pi;8i\nZfr=6js;gl\nZopf=6jo;gi\nZscr=2kl1;1jt\naacute=69;3m\nabreve=77;4l\nac=6ri;qg\nacE=6ri,mr;qe\nacd=6rj;qh\nacirc=6a;3n\nacute=50;28\nacy=ts;br\naelig=6e;3r\naf=6e9;ex\nafr=2kny;1l2\nagrave=68;3l\nalefsym=6k5;h3\naleph=6k5;h4\nalpha=q9;92\namacr=75;4j\namalg=8cf;1dm\namp=12;9\nand=6qv;p6\nandand=8d1;1e3\nandd=8d8;1e9\nandslope=8d4;1e6\nandv=8d6;1e7\nang=6qo;oj\nange=884;1b1\nangle=6qo;oi\nangmsd=6qp;ol\nangmsdaa=888;1b5\nangmsdab=889;1b6\nangmsdac=88a;1b7\nangmsdad=88b;1b8\nangmsdae=88c;1b9\nangmsdaf=88d;1ba\nangmsdag=88e;1bb\nangmsdah=88f;1bc\nangrt=6qn;og\nangrtvb=6v2;yw\nangrtvbd=87x;1b0\nangsph=6qq;om\nangst=5h;2u\nangzarr=70c;12z\naogon=79;4n\naopf=2kpe;1mb\nap=6rs;r8\napE=8ds;1ej\napacir=8dr;1eh\nape=6ru;rd\napid=6rv;rf\napos=13;a\napprox=6rs;r5\napproxeq=6ru;rc\naring=6d;3q\nascr=2kl2;1ju\nast=16;e\nasymp=6rs;r6\nasympeq=6rx;rj\natilde=6b;3o\nauml=6c;3p\nawconint=6r7;ps\nawint=8b5;1cr\nbNot=8h9;1iy\nbackcong=6rw;rg\nbackepsilon=s6;af\nbackprime=6d1;ei\nbacksim=6rh;qc\nbacksimeq=6vh;zp\nbarvee=6v1;yv\nbarwed=6x1;11y\nbarwedge=6x1;11x\nbbrk=71x;137\nbbrktbrk=71y;138\nbcong=6rw;rh\nbcy=tt;bs\nbdquo=6ce;e4\nbecaus=6r9;py\nbecause=6r9;px\nbemptyv=88g;1bd\nbepsi=s6;ag\nbernou=6jw;go\nbeta=qa;93\nbeth=6k6;h5\nbetween=6ss;tt\nbfr=2knz;1l3\nbigcap=6v6;z5\nbigcirc=7hr;15s\nbigcup=6v7;z7\nbigodot=8ao;1cd\nbigoplus=8ap;1cf\nbigotimes=8aq;1ch\nbigsqcup=8au;1cl\nbigstar=7id;15z\nbigtriangledown=7gd;15e\nbigtriangleup=7g3;154\nbiguplus=8as;1cj\nbigvee=6v5;z1\nbigwedge=6v4;yy\nbkarow=83x;17x\nblacklozenge=8a3;1c9\nblacksquare=7fu;14x\nblacktriangle=7g4;156\nblacktriangledown=7ge;15g\nblacktriangleleft=7gi;15k\nblacktriangleright=7g8;15a\nblank=74z;13f\nblk12=7f6;14r\nblk14=7f5;14q\nblk34=7f7;14s\nblock=7ew;14p\nbne=1p,6hx;o\nbnequiv=6sh,6hx;sm\nbnot=6xc;12d\nbopf=2kpf;1mc\nbot=6ud;xx\nbottom=6ud;xu\nbowtie=6vc;zi\nboxDL=7dj;141\nboxDR=7dg;13y\nboxDl=7di;140\nboxDr=7df;13x\nboxH=7dc;13u\nboxHD=7dy;14g\nboxHU=7e1;14j\nboxHd=7dw;14e\nboxHu=7dz;14h\nboxUL=7dp;147\nboxUR=7dm;144\nboxUl=7do;146\nboxUr=7dl;143\nboxV=7dd;13v\nboxVH=7e4;14m\nboxVL=7dv;14d\nboxVR=7ds;14a\nboxVh=7e3;14l\nboxVl=7du;14c\nboxVr=7dr;149\nboxbox=895;1bw\nboxdL=7dh;13z\nboxdR=7de;13w\nboxdl=7bk;13m\nboxdr=7bg;13l\nboxh=7b4;13j\nboxhD=7dx;14f\nboxhU=7e0;14i\nboxhd=7cc;13r\nboxhu=7ck;13s\nboxminus=6u7;xi\nboxplus=6u6;xg\nboxtimes=6u8;xk\nboxuL=7dn;145\nboxuR=7dk;142\nboxul=7bs;13o\nboxur=7bo;13n\nboxv=7b6;13k\nboxvH=7e2;14k\nboxvL=7dt;14b\nboxvR=7dq;148\nboxvh=7cs;13t\nboxvl=7c4;13q\nboxvr=7bw;13p\nbprime=6d1;ej\nbreve=k8;83\nbrvbar=4m;1k\nbscr=2kl3;1jv\nbsemi=6dr;er\nbsim=6rh;qd\nbsime=6vh;zq\nbsol=2k;x\nbsolb=891;1bv\nbsolhsub=7uw;16r\nbull=6ci;e9\nbullet=6ci;e8\nbump=6ry;rp\nbumpE=8fi;1gu\nbumpe=6rz;ru\nbumpeq=6rz;rt\ncacute=7b;4p\ncap=6qx;pa\ncapand=8ck;1dq\ncapbrcup=8cp;1dv\ncapcap=8cr;1dx\ncapcup=8cn;1dt\ncapdot=8cg;1dn\ncaps=6qx,1e68;p9\ncaret=6dd;eo\ncaron=jr;81\nccaps=8ct;1dz\nccaron=7h;4v\nccedil=6f;3s\nccirc=7d;4r\nccups=8cs;1dy\nccupssm=8cw;1e0\ncdot=7f;4t\ncedil=54;2f\ncemptyv=88i;1bf\ncent=4i;1g\ncenterdot=53;2c\ncfr=2ko0;1l4\nchcy=uf;ce\ncheck=7pv;16j\ncheckmark=7pv;16i\nchi=qv;9s\ncir=7gr;15q\ncirE=88z;1bt\ncirc=jq;7z\ncirceq=6s7;sc\ncirclearrowleft=6nu;k6\ncirclearrowright=6nv;k8\ncircledR=4u;1w\ncircledS=79k;13g\ncircledast=6u3;xc\ncircledcirc=6u2;xa\ncircleddash=6u5;xe\ncire=6s7;sd\ncirfnint=8b4;1cq\ncirmid=8hb;1j0\ncirscir=88y;1bs\nclubs=7kz;168\nclubsuit=7kz;167\ncolon=1m;j\ncolone=6s4;s7\ncoloneq=6s4;s5\ncomma=18;g\ncommat=1s;u\ncomp=6pt;mv\ncompfn=6qg;o7\ncomplement=6pt;mu\ncomplexes=6iq;f6\ncong=6rp;qz\ncongdot=8dp;1ef\nconint=6r2;pj\ncopf=2kpg;1md\ncoprod=6q8;nr\ncopy=4p;1r\ncopysr=6jb;fz\ncrarr=6np;k1\ncross=7pz;16k\ncscr=2kl4;1jw\ncsub=8gf;1id\ncsube=8gh;1if\ncsup=8gg;1ie\ncsupe=8gi;1ig\nctdot=6wf;11g\ncudarrl=854;18x\ncudarrr=851;18u\ncuepr=6vy;10m\ncuesc=6vz;10o\ncularr=6nq;k3\ncularrp=859;190\ncup=6qy;pc\ncupbrcap=8co;1du\ncupcap=8cm;1ds\ncupcup=8cq;1dw\ncupdot=6tp;we\ncupor=8cl;1dr\ncups=6qy,1e68;pb\ncurarr=6nr;k5\ncurarrm=858;18z\ncurlyeqprec=6vy;10l\ncurlyeqsucc=6vz;10n\ncurlyvee=6vi;zr\ncurlywedge=6vj;zt\ncurren=4k;1i\ncurvearrowleft=6nq;k2\ncurvearrowright=6nr;k4\ncuvee=6vi;zs\ncuwed=6vj;zu\ncwconint=6r6;pq\ncwint=6r5;po\ncylcty=6y5;12u\ndArr=6oj;m2\ndHar=86d;19t\ndagger=6cg;e5\ndaleth=6k8;h7\ndarr=6mr;ia\ndash=6c0;dl\ndashv=6ub;xr\ndbkarow=83z;180\ndblac=kd;8b\ndcaron=7j;4x\ndcy=tw;bv\ndd=6km;hb\nddagger=6ch;e6\nddarr=6oa;ld\nddotseq=8dz;1ep\ndeg=4w;21\ndelta=qc;95\ndemptyv=88h;1be\ndfisht=873;1aj\ndfr=2ko1;1l5\ndharl=6o3;kx\ndharr=6o2;ku\ndiam=6v8;zc\ndiamond=6v8;zb\ndiamondsuit=7l2;16b\ndiams=7l2;16c\ndie=4o;1o\ndigamma=rh;a6\ndisin=6wi;11j\ndiv=6v;49\ndivide=6v;48\ndivideontimes=6vb;zg\ndivonx=6vb;zh\ndjcy=uq;co\ndlcorn=6xq;12n\ndlcrop=6x9;12a\ndollar=10;6\ndopf=2kph;1me\ndot=k9;85\ndoteq=6s0;rx\ndoteqdot=6s1;rz\ndotminus=6rc;q2\ndotplus=6qc;ny\ndotsquare=6u9;xm\ndoublebarwedge=6x2;11z\ndownarrow=6mr;i9\ndowndownarrows=6oa;lc\ndownharpoonleft=6o3;kv\ndownharpoonright=6o2;ks\ndrbkarow=840;182\ndrcorn=6xr;12p\ndrcrop=6x8;129\ndscr=2kl5;1jx\ndscy=ut;cr\ndsol=8ae;1cc\ndstrok=7l;4z\ndtdot=6wh;11i\ndtri=7gf;15j\ndtrif=7ge;15h\nduarr=6ph;mo\nduhar=86n;1a5\ndwangle=886;1b3\ndzcy=v3;d0\ndzigrarr=7wf;17r\neDDot=8dz;1eq\neDot=6s1;s0\neacute=6h;3u\neaster=8dq;1eg\necaron=7v;57\necir=6s6;sb\necirc=6i;3v\necolon=6s5;s9\necy=ul;ck\nedot=7r;53\nee=6kn;he\nefDot=6s2;s2\nefr=2ko2;1l6\neg=8ey;1g9\negrave=6g;3t\negs=8eu;1g5\negsdot=8ew;1g7\nel=8ex;1g8\nelinters=73b;13e\nell=6j7;fv\nels=8et;1g3\nelsdot=8ev;1g6\nemacr=7n;51\nempty=6px;n7\nemptyset=6px;n5\nemptyv=6px;n6\nemsp=6bn;d2\nemsp13=6bo;d3\nemsp14=6bp;d4\neng=97;6h\nensp=6bm;d1\neogon=7t;55\neopf=2kpi;1mf\nepar=6vp;103\neparsl=89v;1c6\neplus=8dt;1ek\nepsi=qd;97\nepsilon=qd;96\nepsiv=s5;ae\neqcirc=6s6;sa\neqcolon=6s5;s8\neqsim=6rm;qq\neqslantgtr=8eu;1g4\neqslantless=8et;1g2\nequals=1p;p\nequest=6sf;sj\nequiv=6sh;so\nequivDD=8e0;1er\neqvparsl=89x;1c8\nerDot=6s3;s4\nerarr=86p;1a7\nescr=6jz;gs\nesdot=6s0;ry\nesim=6rm;qr\neta=qf;99\neth=6o;41\neuml=6j;3w\neuro=6gc;f2\nexcl=x;2\nexist=6pv;n0\nexpectation=6k0;gt\nexponentiale=6kn;hd\nfallingdotseq=6s2;s1\nfcy=uc;cb\nfemale=7k0;163\nffilig=1dkz;1ja\nfflig=1dkw;1j7\nffllig=1dl0;1jb\nffr=2ko3;1l7\nfilig=1dkx;1j8\nfjlig=2u,2y;15\nflat=7l9;16e\nfllig=1dky;1j9\nfltns=7g1;153\nfnof=b6;7v\nfopf=2kpj;1mg\nforall=6ps;mt\nfork=6vo;102\nforkv=8gp;1in\nfpartint=8b1;1cp\nfrac12=59;2k\nfrac13=6kz;hh\nfrac14=58;2j\nfrac15=6l1;hj\nfrac16=6l5;hn\nfrac18=6l7;hp\nfrac23=6l0;hi\nfrac25=6l2;hk\nfrac34=5a;2m\nfrac35=6l3;hl\nfrac38=6l8;hq\nfrac45=6l4;hm\nfrac56=6l6;ho\nfrac58=6l9;hr\nfrac78=6la;hs\nfrasl=6dg;eq\nfrown=6xu;12r\nfscr=2kl7;1jy\ngE=6sn;t8\ngEl=8ek;1ft\ngacute=dx;7x\ngamma=qb;94\ngammad=rh;a7\ngap=8ee;1fh\ngbreve=7z;5b\ngcirc=7x;59\ngcy=tv;bu\ngdot=81;5d\nge=6sl;sx\ngel=6vv;10k\ngeq=6sl;sw\ngeqq=6sn;t7\ngeqslant=8e6;1f6\nges=8e6;1f7\ngescc=8fd;1gn\ngesdot=8e8;1f9\ngesdoto=8ea;1fb\ngesdotol=8ec;1fd\ngesl=6vv,1e68;10h\ngesles=8es;1g1\ngfr=2ko4;1l8\ngg=6sr;ts\nggg=6vt;10b\ngimel=6k7;h6\ngjcy=ur;cp\ngl=6t3;un\nglE=8eq;1fz\ngla=8f9;1gj\nglj=8f8;1gi\ngnE=6sp;tg\ngnap=8ei;1fp\ngnapprox=8ei;1fo\ngne=8eg;1fl\ngneq=8eg;1fk\ngneqq=6sp;tf\ngnsim=6w7;10y\ngopf=2kpk;1mh\ngrave=2o;14\ngscr=6iy;f9\ngsim=6sz;ud\ngsime=8em;1fv\ngsiml=8eo;1fx\ngt=1q;s\ngtcc=8fb;1gl\ngtcir=8e2;1et\ngtdot=6vr;107\ngtlPar=87p;1aw\ngtquest=8e4;1ev\ngtrapprox=8ee;1fg\ngtrarr=86w;1ad\ngtrdot=6vr;106\ngtreqless=6vv;10j\ngtreqqless=8ek;1fs\ngtrless=6t3;um\ngtrsim=6sz;uc\ngvertneqq=6sp,1e68;td\ngvnE=6sp,1e68;te\nhArr=6ok;m5\nhairsp=6bu;da\nhalf=59;2l\nhamilt=6iz;fb\nhardcy=ui;ch\nharr=6ms;id\nharrcir=85k;192\nharrw=6nh;js\nhbar=6j3;fl\nhcirc=85;5g\nhearts=7l1;16a\nheartsuit=7l1;169\nhellip=6cm;eb\nhercon=6ux;yr\nhfr=2ko5;1l9\nhksearow=84l;18i\nhkswarow=84m;18k\nhoarr=6pr;mr\nhomtht=6rf;q5\nhookleftarrow=6nd;jj\nhookrightarrow=6ne;jl\nhopf=2kpl;1mi\nhorbar=6c5;do\nhscr=2kl9;1jz\nhslash=6j3;fi\nhstrok=87;5i\nhybull=6df;ep\nhyphen=6c0;dk\niacute=6l;3y\nic=6eb;f1\nicirc=6m;3z\nicy=u0;bz\niecy=tx;bw\niexcl=4h;1f\niff=6ok;m6\nifr=2ko6;1la\nigrave=6k;3x\nii=6ko;hg\niiiint=8b0;1cn\niiint=6r1;pg\niinfin=89o;1c3\niiota=6jt;gm\nijlig=8j;5t\nimacr=8b;5m\nimage=6j5;fp\nimagline=6j4;fm\nimagpart=6j5;fo\nimath=8h;5r\nimof=6uv;yo\nimped=c5;7w\nin=6q0;nd\nincare=6it;f8\ninfin=6qm;of\ninfintie=89p;1c4\ninodot=8h;5q\nint=6qz;pe\nintcal=6uy;yt\nintegers=6jo;gh\nintercal=6uy;ys\nintlarhk=8bb;1cx\nintprod=8cc;1dk\niocy=up;cn\niogon=8f;5o\niopf=2kpm;1mj\niota=qh;9b\niprod=8cc;1dl\niquest=5b;2n\niscr=2kla;1k0\nisin=6q0;nc\nisinE=6wp;11r\nisindot=6wl;11n\nisins=6wk;11l\nisinsv=6wj;11k\nisinv=6q0;nb\nit=6ea;ez\nitilde=89;5k\niukcy=uu;cs\niuml=6n;40\njcirc=8l;5v\njcy=u1;c0\njfr=2ko7;1lb\njmath=fr;7y\njopf=2kpn;1mk\njscr=2klb;1k1\njsercy=uw;cu\njukcy=us;cq\nkappa=qi;9c\nkappav=s0;a9\nkcedil=8n;5x\nkcy=u2;c1\nkfr=2ko8;1lc\nkgreen=8o;5y\nkhcy=ud;cc\nkjcy=v0;cy\nkopf=2kpo;1ml\nkscr=2klc;1k2\nlAarr=6oq;mf\nlArr=6og;ls\nlAtail=84b;18a\nlBarr=83y;17z\nlE=6sm;t2\nlEg=8ej;1fr\nlHar=86a;19q\nlacute=8q;60\nlaemptyv=88k;1bh\nlagran=6j6;ft\nlambda=qj;9d\nlang=7vs;16z\nlangd=87l;1as\nlangle=7vs;16y\nlap=8ed;1ff\nlaquo=4r;1t\nlarr=6mo;hx\nlarrb=6p0;mk\nlarrbfs=84f;18e\nlarrfs=84d;18c\nlarrhk=6nd;jk\nlarrlp=6nf;jo\nlarrpl=855;18y\nlarrsim=86r;1a9\nlarrtl=6n6;j7\nlat=8ff;1gp\nlatail=849;188\nlate=8fh;1gt\nlates=8fh,1e68;1gs\nlbarr=83w;17w\nlbbrk=7si;16p\nlbrace=3f;16\nlbrack=2j;v\nlbrke=87f;1am\nlbrksld=87j;1aq\nlbrkslu=87h;1ao\nlcaron=8u;64\nlcedil=8s;62\nlceil=6x4;122\nlcub=3f;17\nlcy=u3;c2\nldca=852;18v\nldquo=6cc;dz\nldquor=6ce;e3\nldrdhar=86f;19v\nldrushar=85n;195\nldsh=6nm;jz\nle=6sk;st\nleftarrow=6mo;hv\nleftarrowtail=6n6;j6\nleftharpoondown=6nx;kd\nleftharpoonup=6nw;ka\nleftleftarrows=6o7;l6\nleftrightarrow=6ms;ic\nleftrightarrows=6o6;l4\nleftrightharpoons=6ob;lf\nleftrightsquigarrow=6nh;jr\nleftthreetimes=6vf;zl\nleg=6vu;10g\nleq=6sk;ss\nleqq=6sm;t1\nleqslant=8e5;1f0\nles=8e5;1f1\nlescc=8fc;1gm\nlesdot=8e7;1f8\nlesdoto=8e9;1fa\nlesdotor=8eb;1fc\nlesg=6vu,1e68;10d\nlesges=8er;1g0\nlessapprox=8ed;1fe\nlessdot=6vq;104\nlesseqgtr=6vu;10f\nlesseqqgtr=8ej;1fq\nlessgtr=6t2;uj\nlesssim=6sy;u9\nlfisht=870;1ag\nlfloor=6x6;126\nlfr=2ko9;1ld\nlg=6t2;uk\nlgE=8ep;1fy\nlhard=6nx;kf\nlharu=6nw;kc\nlharul=86i;19y\nlhblk=7es;14o\nljcy=ux;cv\nll=6sq;tm\nllarr=6o7;l7\nllcorner=6xq;12m\nllhard=86j;19z\nlltri=7i2;15w\nlmidot=8w;66\nlmoust=71s;131\nlmoustache=71s;130\nlnE=6so;tc\nlnap=8eh;1fn\nlnapprox=8eh;1fm\nlne=8ef;1fj\nlneq=8ef;1fi\nlneqq=6so;tb\nlnsim=6w6;10x\nloang=7vw;175\nloarr=6pp;mp\nlobrk=7vq;16u\nlongleftarrow=7w5;178\nlongleftrightarrow=7w7;17e\nlongmapsto=7wc;17p\nlongrightarrow=7w6;17b\nlooparrowleft=6nf;jn\nlooparrowright=6ng;jp\nlopar=879;1ak\nlopf=2kpp;1mm\nloplus=8bx;1d6\nlotimes=8c4;1dc\nlowast=6qf;o5\nlowbar=2n;12\nloz=7gq;15p\nlozenge=7gq;15o\nlozf=8a3;1ca\nlpar=14;b\nlparlt=87n;1au\nlrarr=6o6;l5\nlrcorner=6xr;12o\nlrhar=6ob;lg\nlrhard=86l;1a1\nlrm=6by;di\nlrtri=6v3;yx\nlsaquo=6d5;ek\nlscr=2kld;1k3\nlsh=6nk;jw\nlsim=6sy;ua\nlsime=8el;1fu\nlsimg=8en;1fw\nlsqb=2j;w\nlsquo=6c8;ds\nlsquor=6ca;dw\nlstrok=8y;68\nlt=1o;n\nltcc=8fa;1gk\nltcir=8e1;1es\nltdot=6vq;105\nlthree=6vf;zm\nltimes=6vd;zj\nltlarr=86u;1ac\nltquest=8e3;1eu\nltrPar=87q;1ax\nltri=7gj;15n\nltrie=6us;yi\nltrif=7gi;15l\nlurdshar=85m;194\nluruhar=86e;19u\nlvertneqq=6so,1e68;t9\nlvnE=6so,1e68;ta\nmDDot=6re;q4\nmacr=4v;20\nmale=7k2;164\nmalt=7q8;16m\nmaltese=7q8;16l\nmap=6na;jg\nmapsto=6na;jf\nmapstodown=6nb;ji\nmapstoleft=6n8;jb\nmapstoup=6n9;jd\nmarker=7fy;152\nmcomma=8bt;1d4\nmcy=u4;c3\nmdash=6c4;dn\nmeasuredangle=6qp;ok\nmfr=2koa;1le\nmho=6jr;gj\nmicro=51;29\nmid=6qr;oq\nmidast=16;d\nmidcir=8hc;1j1\nmiddot=53;2d\nminus=6qa;nu\nminusb=6u7;xj\nminusd=6rc;q3\nminusdu=8bu;1d5\nmlcp=8gr;1ip\nmldr=6cm;ec\nmnplus=6qb;nw\nmodels=6uf;xy\nmopf=2kpq;1mn\nmp=6qb;nx\nmscr=2kle;1k4\nmstpos=6ri;qf\nmu=qk;9e\nmultimap=6uw;yp\nmumap=6uw;yq\nnGg=6vt,mw;10a\nnGt=6sr,6he;tp\nnGtv=6sr,mw;to\nnLeftarrow=6od;lk\nnLeftrightarrow=6oe;lm\nnLl=6vs,mw;108\nnLt=6sq,6he;tj\nnLtv=6sq,mw;ti\nnRightarrow=6of;lo\nnVDash=6un;y7\nnVdash=6um;y6\nnabla=6pz;n8\nnacute=90;6a\nnang=6qo,6he;oh\nnap=6rt;rb\nnapE=8ds,mw;1ei\nnapid=6rv,mw;re\nnapos=95;6f\nnapprox=6rt;ra\nnatur=7la;16g\nnatural=7la;16f\nnaturals=6j9;fw\nnbsp=4g;1e\nnbump=6ry,mw;rm\nnbumpe=6rz,mw;rr\nncap=8cj;1dp\nncaron=94;6e\nncedil=92;6c\nncong=6rr;r2\nncongdot=8dp,mw;1ee\nncup=8ci;1do\nncy=u5;c4\nndash=6c3;dm\nne=6sg;sl\nneArr=6on;mb\nnearhk=84k;18h\nnearr=6mv;im\nnearrow=6mv;il\nnedot=6s0,mw;rv\nnequiv=6si;sq\nnesear=84o;18n\nnesim=6rm,mw;qo\nnexist=6pw;n3\nnexists=6pw;n2\nnfr=2kob;1lf\nngE=6sn,mw;t4\nnge=6sx;u7\nngeq=6sx;u6\nngeqq=6sn,mw;t5\nngeqslant=8e6,mw;1f3\nnges=8e6,mw;1f4\nngsim=6t1;uh\nngt=6sv;u1\nngtr=6sv;u0\nnhArr=6oe;ln\nnharr=6ni;ju\nnhpar=8he;1j3\nni=6q3;nk\nnis=6ws;11u\nnisd=6wq;11s\nniv=6q3;nj\nnjcy=uy;cw\nnlArr=6od;ll\nnlE=6sm,mw;sy\nnlarr=6my;iu\nnldr=6cl;ea\nnle=6sw;u4\nnleftarrow=6my;it\nnleftrightarrow=6ni;jt\nnleq=6sw;u3\nnleqq=6sm,mw;sz\nnleqslant=8e5,mw;1ex\nnles=8e5,mw;1ey\nnless=6su;tx\nnlsim=6t0;uf\nnlt=6su;ty\nnltri=6wa;115\nnltrie=6wc;11b\nnmid=6qs;ou\nnopf=2kpr;1mo\nnot=4s;1u\nnotin=6q1;ng\nnotinE=6wp,mw;11q\nnotindot=6wl,mw;11m\nnotinva=6q1;nf\nnotinvb=6wn;11p\nnotinvc=6wm;11o\nnotni=6q4;nn\nnotniva=6q4;nm\nnotnivb=6wu;11w\nnotnivc=6wt;11v\nnpar=6qu;p4\nnparallel=6qu;p2\nnparsl=8hp,6hx;1j5\nnpart=6pu,mw;mw\nnpolint=8b8;1cu\nnpr=6tc;vd\nnprcue=6w0;10q\nnpre=8fj,mw;1gw\nnprec=6tc;vc\nnpreceq=8fj,mw;1gx\nnrArr=6of;lp\nnrarr=6mz;iw\nnrarrc=84z,mw;18s\nnrarrw=6n1,mw;ix\nnrightarrow=6mz;iv\nnrtri=6wb;118\nnrtrie=6wd;11e\nnsc=6td;vg\nnsccue=6w1;10s\nnsce=8fk,mw;1h2\nnscr=2klf;1k5\nnshortmid=6qs;os\nnshortparallel=6qu;p1\nnsim=6rl;qm\nnsime=6ro;qx\nnsimeq=6ro;qw\nnsmid=6qs;ot\nnspar=6qu;p3\nnsqsube=6w2;10u\nnsqsupe=6w3;10w\nnsub=6tg;vs\nnsubE=8g5,mw;1hv\nnsube=6tk;w2\nnsubset=6te,6he;vi\nnsubseteq=6tk;w1\nnsubseteqq=8g5,mw;1hw\nnsucc=6td;vf\nnsucceq=8fk,mw;1h3\nnsup=6th;vt\nnsupE=8g6,mw;1hz\nnsupe=6tl;w5\nnsupset=6tf,6he;vn\nnsupseteq=6tl;w4\nnsupseteqq=8g6,mw;1i0\nntgl=6t5;ur\nntilde=6p;42\nntlg=6t4;up\nntriangleleft=6wa;114\nntrianglelefteq=6wc;11a\nntriangleright=6wb;117\nntrianglerighteq=6wd;11d\nnu=ql;9f\nnum=z;5\nnumero=6ja;fy\nnumsp=6br;d5\nnvDash=6ul;y5\nnvHarr=83o;17u\nnvap=6rx,6he;ri\nnvdash=6uk;y4\nnvge=6sl,6he;su\nnvgt=1q,6he;q\nnvinfin=89q;1c5\nnvlArr=83m;17s\nnvle=6sk,6he;sr\nnvlt=1o,6he;l\nnvltrie=6us,6he;yf\nnvrArr=83n;17t\nnvrtrie=6ut,6he;yj\nnvsim=6rg,6he;q6\nnwArr=6om;ma\nnwarhk=84j;18g\nnwarr=6mu;ij\nnwarrow=6mu;ii\nnwnear=84n;18m\noS=79k;13h\noacute=6r;44\noast=6u3;xd\nocir=6u2;xb\nocirc=6s;45\nocy=u6;c5\nodash=6u5;xf\nodblac=9d;6l\nodiv=8c8;1dg\nodot=6u1;x9\nodsold=88s;1bn\noelig=9f;6n\nofcir=88v;1bp\nofr=2koc;1lg\nogon=kb;87\nograve=6q;43\nogt=88x;1br\nohbar=88l;1bi\nohm=q1;91\noint=6r2;pk\nolarr=6nu;k7\nolcir=88u;1bo\nolcross=88r;1bm\noline=6da;en\nolt=88w;1bq\nomacr=99;6j\nomega=qx;9u\nomicron=qn;9h\nomid=88m;1bj\nominus=6ty;x4\noopf=2kps;1mp\nopar=88n;1bk\noperp=88p;1bl\noplus=6tx;x2\nor=6qw;p8\norarr=6nv;k9\nord=8d9;1ea\norder=6k4;h1\norderof=6k4;h0\nordf=4q;1s\nordm=56;2h\norigof=6uu;yn\noror=8d2;1e4\norslope=8d3;1e5\norv=8d7;1e8\noscr=6k4;h2\noslash=6w;4a\nosol=6u0;x7\notilde=6t;46\notimes=6tz;x6\notimesas=8c6;1de\nouml=6u;47\novbar=6yl;12x\npar=6qt;oz\npara=52;2a\nparallel=6qt;ox\nparsim=8hf;1j4\nparsl=8hp;1j6\npart=6pu;my\npcy=u7;c6\npercnt=11;7\nperiod=1a;h\npermil=6cw;ed\nperp=6ud;xw\npertenk=6cx;ee\npfr=2kod;1lh\nphi=qu;9r\nphiv=r9;a2\nphmmat=6k3;gy\nphone=7im;162\npi=qo;9i\npitchfork=6vo;101\npiv=ra;a4\nplanck=6j3;fj\nplanckh=6j2;fh\nplankv=6j3;fk\nplus=17;f\nplusacir=8bn;1cz\nplusb=6u6;xh\npluscir=8bm;1cy\nplusdo=6qc;nz\nplusdu=8bp;1d1\npluse=8du;1el\nplusmn=4x;23\nplussim=8bq;1d2\nplustwo=8br;1d3\npm=4x;24\npointint=8b9;1cv\npopf=2kpt;1mq\npound=4j;1h\npr=6t6;uu\nprE=8fn;1h7\nprap=8fr;1he\nprcue=6t8;v0\npre=8fj;1h0\nprec=6t6;ut\nprecapprox=8fr;1hd\npreccurlyeq=6t8;uz\npreceq=8fj;1gz\nprecnapprox=8ft;1hh\nprecneqq=8fp;1h9\nprecnsim=6w8;10z\nprecsim=6ta;v5\nprime=6cy;ef\nprimes=6jd;g2\nprnE=8fp;1ha\nprnap=8ft;1hi\nprnsim=6w8;110\nprod=6q7;np\nprofalar=6y6;12v\nprofline=6xe;12e\nprofsurf=6xf;12f\nprop=6ql;oe\npropto=6ql;oc\nprsim=6ta;v6\nprurel=6uo;y8\npscr=2klh;1k6\npsi=qw;9t\npuncsp=6bs;d6\nqfr=2koe;1li\nqint=8b0;1co\nqopf=2kpu;1mr\nqprime=6dz;es\nqscr=2kli;1k7\nquaternions=6j1;ff\nquatint=8ba;1cw\nquest=1r;t\nquesteq=6sf;si\nquot=y;4\nrAarr=6or;mh\nrArr=6oi;lz\nrAtail=84c;18b\nrBarr=83z;181\nrHar=86c;19s\nrace=6rh,mp;qb\nracute=9h;6p\nradic=6qi;o8\nraemptyv=88j;1bg\nrang=7vt;172\nrangd=87m;1at\nrange=885;1b2\nrangle=7vt;171\nraquo=57;2i\nrarr=6mq;i6\nrarrap=86t;1ab\nrarrb=6p1;mm\nrarrbfs=84g;18f\nrarrc=84z;18t\nrarrfs=84e;18d\nrarrhk=6ne;jm\nrarrlp=6ng;jq\nrarrpl=85h;191\nrarrsim=86s;1aa\nrarrtl=6n7;j9\nrarrw=6n1;iz\nratail=84a;189\nratio=6ra;pz\nrationals=6je;g4\nrbarr=83x;17y\nrbbrk=7sj;16q\nrbrace=3h;1b\nrbrack=2l;y\nrbrke=87g;1an\nrbrksld=87i;1ap\nrbrkslu=87k;1ar\nrcaron=9l;6t\nrcedil=9j;6r\nrceil=6x5;124\nrcub=3h;1c\nrcy=u8;c7\nrdca=853;18w\nrdldhar=86h;19x\nrdquo=6cd;e2\nrdquor=6cd;e1\nrdsh=6nn;k0\nreal=6jg;g9\nrealine=6jf;g6\nrealpart=6jg;g8\nreals=6jh;gc\nrect=7fx;151\nreg=4u;1y\nrfisht=871;1ah\nrfloor=6x7;128\nrfr=2kof;1lj\nrhard=6o1;kr\nrharu=6o0;ko\nrharul=86k;1a0\nrho=qp;9j\nrhov=s1;ab\nrightarrow=6mq;i4\nrightarrowtail=6n7;j8\nrightharpoondown=6o1;kp\nrightharpoonup=6o0;km\nrightleftarrows=6o4;kz\nrightleftharpoons=6oc;lh\nrightrightarrows=6o9;la\nrightsquigarrow=6n1;iy\nrightthreetimes=6vg;zn\nring=ka;86\nrisingdotseq=6s3;s3\nrlarr=6o4;l0\nrlhar=6oc;lj\nrlm=6bz;dj\nrmoust=71t;133\nrmoustache=71t;132\nrnmid=8ha;1iz\nroang=7vx;176\nroarr=6pq;mq\nrobrk=7vr;16w\nropar=87a;1al\nropf=2kpv;1ms\nroplus=8by;1d7\nrotimes=8c5;1dd\nrpar=15;c\nrpargt=87o;1av\nrppolint=8b6;1cs\nrrarr=6o9;lb\nrsaquo=6d6;el\nrscr=2klj;1k8\nrsh=6nl;jy\nrsqb=2l;z\nrsquo=6c9;dv\nrsquor=6c9;du\nrthree=6vg;zo\nrtimes=6ve;zk\nrtri=7g9;15d\nrtrie=6ut;ym\nrtrif=7g8;15b\nrtriltri=89a;1by\nruluhar=86g;19w\nrx=6ji;ge\nsacute=9n;6v\nsbquo=6ca;dx\nsc=6t7;ux\nscE=8fo;1h8\nscap=8fs;1hg\nscaron=9t;71\nsccue=6t9;v3\nsce=8fk;1h6\nscedil=9r;6z\nscirc=9p;6x\nscnE=8fq;1hc\nscnap=8fu;1hk\nscnsim=6w9;112\nscpolint=8b7;1ct\nscsim=6tb;va\nscy=u9;c8\nsdot=6v9;zd\nsdotb=6u9;xn\nsdote=8di;1ec\nseArr=6oo;mc\nsearhk=84l;18j\nsearr=6mw;ip\nsearrow=6mw;io\nsect=4n;1l\nsemi=1n;k\nseswar=84p;18p\nsetminus=6qe;o2\nsetmn=6qe;o4\nsext=7qu;16n\nsfr=2kog;1lk\nsfrown=6xu;12q\nsharp=7lb;16h\nshchcy=uh;cg\nshcy=ug;cf\nshortmid=6qr;oo\nshortparallel=6qt;ow\nshy=4t;1v\nsigma=qr;9n\nsigmaf=qq;9l\nsigmav=qq;9m\nsim=6rg;qa\nsimdot=8dm;1ed\nsime=6rn;qu\nsimeq=6rn;qt\nsimg=8f2;1gb\nsimgE=8f4;1gd\nsiml=8f1;1ga\nsimlE=8f3;1gc\nsimne=6rq;r0\nsimplus=8bo;1d0\nsimrarr=86q;1a8\nslarr=6mo;hw\nsmallsetminus=6qe;o0\nsmashp=8c3;1db\nsmeparsl=89w;1c7\nsmid=6qr;op\nsmile=6xv;12t\nsmt=8fe;1go\nsmte=8fg;1gr\nsmtes=8fg,1e68;1gq\nsoftcy=uk;cj\nsol=1b;i\nsolb=890;1bu\nsolbar=6yn;12y\nsopf=2kpw;1mt\nspades=7kw;166\nspadesuit=7kw;165\nspar=6qt;oy\nsqcap=6tv;wx\nsqcaps=6tv,1e68;wv\nsqcup=6tw;x0\nsqcups=6tw,1e68;wy\nsqsub=6tr;wk\nsqsube=6tt;wr\nsqsubset=6tr;wj\nsqsubseteq=6tt;wq\nsqsup=6ts;wo\nsqsupe=6tu;wu\nsqsupset=6ts;wn\nsqsupseteq=6tu;wt\nsqu=7fl;14v\nsquare=7fl;14u\nsquarf=7fu;14y\nsquf=7fu;14z\nsrarr=6mq;i5\nsscr=2klk;1k9\nssetmn=6qe;o3\nssmile=6xv;12s\nsstarf=6va;ze\nstar=7ie;161\nstarf=7id;160\nstraightepsilon=s5;ac\nstraightphi=r9;a0\nstrns=4v;1z\nsub=6te;vl\nsubE=8g5;1hy\nsubdot=8fx;1hn\nsube=6ti;vw\nsubedot=8g3;1ht\nsubmult=8g1;1hr\nsubnE=8gb;1i8\nsubne=6tm;w9\nsubplus=8fz;1hp\nsubrarr=86x;1ae\nsubset=6te;vk\nsubseteq=6ti;vv\nsubseteqq=8g5;1hx\nsubsetneq=6tm;w8\nsubsetneqq=8gb;1i7\nsubsim=8g7;1i3\nsubsub=8gl;1ij\nsubsup=8gj;1ih\nsucc=6t7;uw\nsuccapprox=8fs;1hf\nsucccurlyeq=6t9;v2\nsucceq=8fk;1h5\nsuccnapprox=8fu;1hj\nsuccneqq=8fq;1hb\nsuccnsim=6w9;111\nsuccsim=6tb;v9\nsum=6q9;nt\nsung=7l6;16d\nsup=6tf;vr\nsup1=55;2g\nsup2=4y;25\nsup3=4z;26\nsupE=8g6;1i2\nsupdot=8fy;1ho\nsupdsub=8go;1im\nsupe=6tj;vz\nsupedot=8g4;1hu\nsuphsol=7ux;16s\nsuphsub=8gn;1il\nsuplarr=86z;1af\nsupmult=8g2;1hs\nsupnE=8gc;1ic\nsupne=6tn;wd\nsupplus=8g0;1hq\nsupset=6tf;vq\nsupseteq=6tj;vy\nsupseteqq=8g6;1i1\nsupsetneq=6tn;wc\nsupsetneqq=8gc;1ib\nsupsim=8g8;1i4\nsupsub=8gk;1ii\nsupsup=8gm;1ik\nswArr=6op;md\nswarhk=84m;18l\nswarr=6mx;is\nswarrow=6mx;ir\nswnwar=84q;18r\nszlig=67;3k\ntarget=6xi;12h\ntau=qs;9o\ntbrk=71w;135\ntcaron=9x;75\ntcedil=9v;73\ntcy=ua;c9\ntdot=6hn;f4\ntelrec=6xh;12g\ntfr=2koh;1ll\nthere4=6r8;pv\ntherefore=6r8;pu\ntheta=qg;9a\nthetasym=r5;9v\nthetav=r5;9x\nthickapprox=6rs;r3\nthicksim=6rg;q7\nthinsp=6bt;d8\nthkap=6rs;r7\nthksim=6rg;q8\nthorn=72;4g\ntilde=kc;89\ntimes=5z;3c\ntimesb=6u8;xl\ntimesbar=8c1;1da\ntimesd=8c0;1d9\ntint=6r1;ph\ntoea=84o;18o\ntop=6uc;xt\ntopbot=6ye;12w\ntopcir=8hd;1j2\ntopf=2kpx;1mu\ntopfork=8gq;1io\ntosa=84p;18q\ntprime=6d0;eh\ntrade=6jm;gg\ntriangle=7g5;158\ntriangledown=7gf;15i\ntriangleleft=7gj;15m\ntrianglelefteq=6us;yh\ntriangleq=6sc;sg\ntriangleright=7g9;15c\ntrianglerighteq=6ut;yl\ntridot=7ho;15r\ntrie=6sc;sh\ntriminus=8ca;1di\ntriplus=8c9;1dh\ntrisb=899;1bx\ntritime=8cb;1dj\ntrpezium=736;13d\ntscr=2kll;1ka\ntscy=ue;cd\ntshcy=uz;cx\ntstrok=9z;77\ntwixt=6ss;tu\ntwoheadleftarrow=6n2;j0\ntwoheadrightarrow=6n4;j3\nuArr=6oh;lv\nuHar=86b;19r\nuacute=6y;4c\nuarr=6mp;i1\nubrcy=v2;cz\nubreve=a5;7d\nucirc=6z;4d\nucy=ub;ca\nudarr=6o5;l2\nudblac=a9;7h\nudhar=86m;1a3\nufisht=872;1ai\nufr=2koi;1lm\nugrave=6x;4b\nuharl=6nz;kl\nuharr=6ny;ki\nuhblk=7eo;14n\nulcorn=6xo;12j\nulcorner=6xo;12i\nulcrop=6xb;12c\nultri=7i0;15u\numacr=a3;7b\numl=4o;1p\nuogon=ab;7j\nuopf=2kpy;1mv\nuparrow=6mp;i0\nupdownarrow=6mt;if\nupharpoonleft=6nz;kj\nupharpoonright=6ny;kg\nuplus=6tq;wg\nupsi=qt;9q\nupsih=r6;9y\nupsilon=qt;9p\nupuparrows=6o8;l8\nurcorn=6xp;12l\nurcorner=6xp;12k\nurcrop=6xa;12b\nuring=a7;7f\nurtri=7i1;15v\nuscr=2klm;1kb\nutdot=6wg;11h\nutilde=a1;79\nutri=7g5;159\nutrif=7g4;157\nuuarr=6o8;l9\nuuml=70;4e\nuwangle=887;1b4\nvArr=6ol;m9\nvBar=8h4;1iu\nvBarv=8h5;1iv\nvDash=6ug;y0\nvangrt=87w;1az\nvarepsilon=s5;ad\nvarkappa=s0;a8\nvarnothing=6px;n4\nvarphi=r9;a1\nvarpi=ra;a3\nvarpropto=6ql;ob\nvarr=6mt;ig\nvarrho=s1;aa\nvarsigma=qq;9k\nvarsubsetneq=6tm,1e68;w6\nvarsubsetneqq=8gb,1e68;1i5\nvarsupsetneq=6tn,1e68;wa\nvarsupsetneqq=8gc,1e68;1i9\nvartheta=r5;9w\nvartriangleleft=6uq;y9\nvartriangleright=6ur;yc\nvcy=tu;bt\nvdash=6ua;xp\nvee=6qw;p7\nveebar=6uz;yu\nveeeq=6sa;sf\nvellip=6we;11f\nverbar=3g;19\nvert=3g;1a\nvfr=2koj;1ln\nvltri=6uq;yb\nvnsub=6te,6he;vj\nvnsup=6tf,6he;vo\nvopf=2kpz;1mw\nvprop=6ql;od\nvrtri=6ur;ye\nvscr=2kln;1kc\nvsubnE=8gb,1e68;1i6\nvsubne=6tm,1e68;w7\nvsupnE=8gc,1e68;1ia\nvsupne=6tn,1e68;wb\nvzigzag=87u;1ay\nwcirc=ad;7l\nwedbar=8db;1eb\nwedge=6qv;p5\nwedgeq=6s9;se\nweierp=6jc;g0\nwfr=2kok;1lo\nwopf=2kq0;1mx\nwp=6jc;g1\nwr=6rk;qk\nwreath=6rk;qj\nwscr=2klo;1kd\nxcap=6v6;z6\nxcirc=7hr;15t\nxcup=6v7;z9\nxdtri=7gd;15f\nxfr=2kol;1lp\nxhArr=7wa;17o\nxharr=7w7;17f\nxi=qm;9g\nxlArr=7w8;17i\nxlarr=7w5;179\nxmap=7wc;17q\nxnis=6wr;11t\nxodot=8ao;1ce\nxopf=2kq1;1my\nxoplus=8ap;1cg\nxotime=8aq;1ci\nxrArr=7w9;17l\nxrarr=7w6;17c\nxscr=2klp;1ke\nxsqcup=8au;1cm\nxuplus=8as;1ck\nxutri=7g3;155\nxvee=6v5;z2\nxwedge=6v4;yz\nyacute=71;4f\nyacy=un;cm\nycirc=af;7n\nycy=uj;ci\nyen=4l;1j\nyfr=2kom;1lq\nyicy=uv;ct\nyopf=2kq2;1mz\nyscr=2klq;1kf\nyucy=um;cl\nyuml=73;4h\nzacute=ai;7q\nzcaron=am;7u\nzcy=tz;by\nzdot=ak;7s\nzeetrf=6js;gk\nzeta=qe;98\nzfr=2kon;1lr\nzhcy=ty;bx\nzigrarr=6ot;mi\nzopf=2kq3;1n0\nzscr=2klr;1kg\nzwj=6bx;dh\nzwnj=6bw;dg"

}
