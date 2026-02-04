//
//  CharacterReaderTest.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 12/10/16.
//

import XCTest
import SwiftSoup

class CharacterReaderTest: XCTestCase {
    func testConsume() {
        let r = CharacterReader("one")
        XCTAssertEqual(0, r.getPos())
        XCTAssertEqual("o", r.current())
        XCTAssertEqual("o", r.consume())
        XCTAssertEqual(1, r.getPos())
        XCTAssertEqual("n", r.current())
        XCTAssertEqual(1, r.getPos())
        XCTAssertEqual("n", r.consume())
        XCTAssertEqual("e", r.consume())
        XCTAssertTrue(r.isEmpty())
        XCTAssertEqual(CharacterReader.EOF, r.consume())
        XCTAssertTrue(r.isEmpty())
        XCTAssertEqual(CharacterReader.EOF, r.consume())
    }

    func testUnconsume() {
        let r = CharacterReader("one")
        XCTAssertEqual("o", r.consume())
        XCTAssertEqual("n", r.current())
        r.unconsume()
        XCTAssertEqual("o", r.current())

        XCTAssertEqual("o", r.consume())
        XCTAssertEqual("n", r.consume())
        XCTAssertEqual("e", r.consume())
        XCTAssertTrue(r.isEmpty())
        r.unconsume()
        XCTAssertFalse(r.isEmpty())
        XCTAssertEqual("e", r.current())
        XCTAssertEqual("e", r.consume())
        XCTAssertTrue(r.isEmpty())

        // Indexes beyond the end are not allowed in native indexing
        //
        // XCTAssertEqual(CharacterReader.EOF, r.consume())
        // r.unconsume()
        // XCTAssertTrue(r.isEmpty())
        // XCTAssertEqual(CharacterReader.EOF, r.current())
    }
    
    func testMultibyteUnconsume() {
        let r = CharacterReader("π>")
        XCTAssertEqual("π", r.consume())
        XCTAssertEqual(">", r.current())
        r.unconsume()
        XCTAssertEqual("π", r.current())
    }
    
    func testConsumeAsStringAsciiAndMultibyte() {
        let r = CharacterReader("abπ")
        XCTAssertEqual("a", r.consumeAsString())
        XCTAssertEqual("b", r.consumeAsString())
        XCTAssertEqual("π", r.consumeAsString())
        XCTAssertTrue(r.isEmpty())
    }
    
    func testAdvanceAsciiAndMultibyte() {
        let r = CharacterReader("aπb")
        XCTAssertEqual("a", r.current())
        r.advance()
        XCTAssertEqual("π", r.current())
        r.advance()
        XCTAssertEqual("b", r.current())
    }

    func testMark() {
        let r = CharacterReader("one")
        XCTAssertEqual("o", r.consume())
        r.markPos()
        XCTAssertEqual("n", r.consume())
        XCTAssertEqual("e", r.consume())
        XCTAssertTrue(r.isEmpty())
        r.rewindToMark()
        XCTAssertEqual("n", r.consume())
    }

    func testConsumeToEnd() {
        let input = "one two three"
        let r = CharacterReader(input)
        let toEnd = r.consumeToEnd()
        XCTAssertEqual(input, toEnd)
        XCTAssertTrue(r.isEmpty())
    }

    func testNextIndexOfChar() {
        let input = "blah blah"
        let r = CharacterReader(input)

        XCTAssertEqual(nil, r.nextIndexOf("x"))
        XCTAssertEqual(input.index(input.startIndex, offsetBy: 3), r.nextIndexOf("h"))
        let pull = String(decoding: r.consumeTo("h"), as: UTF8.self)
        XCTAssertEqual("bla", pull)
        XCTAssertEqual("h", r.consume())
        XCTAssertEqual(input.index(input.startIndex, offsetBy: 6), r.nextIndexOf("l"))
        XCTAssertEqual(" blah", r.consumeToEnd())
        XCTAssertEqual(nil, r.nextIndexOf("x"))
    }

    func testNextIndexOfString() {
        let input = "One Two something Two Three Four"
        let r = CharacterReader(input)

        XCTAssertEqual(nil, r.nextIndexOf("Foo"))
        XCTAssertEqual(input.index(input.startIndex, offsetBy: 4), r.nextIndexOf("Two"))
        XCTAssertEqual("One Two ", r.consumeTo("something"))
        XCTAssertEqual(input.index(input.startIndex, offsetBy: 18), r.nextIndexOf("Two"))
        XCTAssertEqual("something Two Three Four", r.consumeToEnd())
        XCTAssertEqual(nil, r.nextIndexOf("Two"))
    }

    func testNextIndexOfUnmatched() {
        let r = CharacterReader("<[[one]]")
        XCTAssertEqual(nil, r.nextIndexOf("]]>"))
    }

    func testConsumeToChar() {
        let r = CharacterReader("One Two Three")
        XCTAssertEqual("One ", r.consumeTo("T"))
        XCTAssertEqual("", r.consumeTo("T")) // on Two
        XCTAssertEqual("T", r.consume())
        XCTAssertEqual("wo ", r.consumeTo("T"))
        XCTAssertEqual("T", r.consume())
        XCTAssertEqual("hree", r.consumeTo("T")) // consume to end
    }
    
    func testConsumeToUnicodeScalarMultibyte() {
        let pi = "π".unicodeScalars.first!
        let r = CharacterReader("aπbπc")
        XCTAssertEqual("a", String(decoding: r.consumeTo(pi), as: UTF8.self))
        XCTAssertEqual("π", r.consume())
        XCTAssertEqual("b", String(decoding: r.consumeTo(pi), as: UTF8.self))
        XCTAssertEqual("π", r.consume())
        XCTAssertEqual("c", r.consumeToEnd())
    }

    func testConsumeToUnicodeScalarAscii() {
        let lt = "<".unicodeScalars.first!
        let r = CharacterReader("ab<cd")
        XCTAssertEqual("ab", String(decoding: r.consumeTo(lt), as: UTF8.self))
        XCTAssertEqual("<", r.consume())
        XCTAssertEqual("cd", r.consumeToEnd())
    }
    
    func testConsumeToStringMultibyte() {
        let r = CharacterReader("aπbπc")
        XCTAssertEqual("a", r.consumeTo("πb"))
        XCTAssertEqual("πb", r.consumeTo("πc"))
        XCTAssertEqual("πc", r.consumeToEnd())
    }

    func testConsumeToString() {
        let r = CharacterReader("One Two Two Four")
        XCTAssertEqual("One ", r.consumeTo("Two"))
        XCTAssertEqual("T", r.consume())
        XCTAssertEqual("wo ", r.consumeTo("Two"))
        XCTAssertEqual("T", r.consume())
        XCTAssertEqual("wo Four", r.consumeTo("Qux"))
    }

    func testAdvance() {
        let r = CharacterReader("One Two Three")
        XCTAssertEqual("O", r.consume())
        r.advance()
        XCTAssertEqual("e", r.consume())
    }

    func testConsumeToAny() {
        let r = CharacterReader("One 二 &bar; qux 三")
        XCTAssertEqual("One 二 ", String(decoding: r.consumeToAny(ParsingStrings(["&", ";"])), as: UTF8.self))
        XCTAssertTrue(r.matches("&"))
        XCTAssertTrue(r.matches("&bar;"))
        XCTAssertEqual("&", r.consume())
        XCTAssertEqual("bar", String(decoding: r.consumeToAny(ParsingStrings(["&", ";"])), as: UTF8.self))
        XCTAssertEqual(";", String(decoding: Array(r.consume().utf8), as: UTF8.self))
        XCTAssertEqual(" qux 三", String(decoding: r.consumeToAny(ParsingStrings(["&", ";"])), as: UTF8.self))
    }
    
    func testConsumeToAnyMultibyte() {
        let r = CharacterReader("若い\"")
        let value: ArraySlice<UInt8> = r.consumeToAny(ParsingStrings(["\"", UnicodeScalar.Ampersand, "\u{0000}"]))
        XCTAssertEqual(String(decoding: value, as: UTF8.self), "若い")
    }
    
    func testConsumeToAnySingleByteFastPathDoesNotSplitMultibyte() {
        let r = CharacterReader("a☃b")
        let value: ArraySlice<UInt8> = r.consumeToAny(ParsingStrings(["b", "<"]))
        XCTAssertEqual(String(decoding: value, as: UTF8.self), "a☃")
        XCTAssertEqual("b", r.consume())
    }

    func testConsumeDataFastNoNullStopsAtDelimiter() {
        let prefix = String(repeating: "a", count: 80)
        let input = prefix + "&rest"
        let r = CharacterReader(input)
        let value = r.consumeDataFastNoNull()
        XCTAssertEqual(String(decoding: value, as: UTF8.self), prefix)
        XCTAssertEqual("&", r.consume())
    }

    func testConsumeDataFastNoNullConsumesAllWhenNoDelimiter() {
        let input = String(repeating: "b", count: 96)
        let r = CharacterReader(input)
        let value = r.consumeDataFastNoNull()
        XCTAssertEqual(String(decoding: value, as: UTF8.self), input)
        XCTAssertTrue(r.isEmpty())
    }

    func testConsumeToAnyOfThreeWordScanStops() {
        let prefix = String(repeating: "x", count: 80)
        let input = prefix + "<rest"
        let r = CharacterReader(input)
        let value = r.consumeToAnyOfThree(UInt8(ascii: "&"), UInt8(ascii: "<"), UInt8(0))
        XCTAssertEqual(String(decoding: value, as: UTF8.self), prefix)
        XCTAssertEqual("<", r.consume())
    }

    func testConsumeToAnyOfFourWordScanStops() {
        let prefix = String(repeating: "y", count: 80)
        let input = prefix + ">rest"
        let r = CharacterReader(input)
        let value = r.consumeToAnyOfFour(UInt8(ascii: "<"), UInt8(ascii: ">"), UInt8(ascii: "&"), UInt8(0))
        XCTAssertEqual(String(decoding: value, as: UTF8.self), prefix)
        XCTAssertEqual(">", r.consume())
    }

    func testConsumeLetterSequence() {
        let r = CharacterReader("One &bar; qux")
        XCTAssertEqual("One", String(decoding: r.consumeLetterSequence(), as: UTF8.self))
        XCTAssertEqual(" &", r.consumeTo("bar;"))
        XCTAssertEqual("bar", String(decoding: r.consumeLetterSequence(), as: UTF8.self))
       XCTAssertEqual("; qux", r.consumeToEnd())
    }

    func testConsumeLetterThenDigitSequence() {
        let r = CharacterReader("One12 Two &bar; qux")
        XCTAssertEqual("One12", String(decoding: r.consumeLetterThenDigitSequence(), as: UTF8.self))
        XCTAssertEqual(" ", r.consume())
        XCTAssertEqual("Two", String(decoding: r.consumeLetterThenDigitSequence(), as: UTF8.self))
        XCTAssertEqual(" &bar; qux", r.consumeToEnd())
    }
    
    func testConsumeLetterSequenceMultibyte() {
        let r = CharacterReader("πβ123")
        XCTAssertEqual("πβ", String(decoding: r.consumeLetterSequence(), as: UTF8.self))
        XCTAssertEqual("123", r.consumeToEnd())
    }
    
    func testConsumeDigitSequenceMultibyte() {
        let r = CharacterReader("٣4π")
        XCTAssertEqual("٣4", String(decoding: r.consumeDigitSequence(), as: UTF8.self))
        XCTAssertEqual("π", r.consumeToEnd())
    }

    func testConsumeDigitSequenceAscii() {
        let r = CharacterReader("1234a")
        XCTAssertEqual("1234", String(decoding: r.consumeDigitSequence(), as: UTF8.self))
        XCTAssertEqual("a", r.consumeToEnd())
    }
    
    func testConsumeHexSequenceAscii() {
        let r = CharacterReader("0aFz")
        XCTAssertEqual("0aF", String(decoding: r.consumeHexSequence(), as: UTF8.self))
        XCTAssertEqual("z", r.consumeToEnd())
    }

    func testMatches() {
        let r = CharacterReader("One Two Three")
        XCTAssertTrue(r.matches("O"))
        XCTAssertTrue(r.matches("One Two Three"))
        XCTAssertTrue(r.matches("One"))
        XCTAssertFalse(r.matches("one"))
        XCTAssertEqual("O", r.consume())
        XCTAssertFalse(r.matches("One"))
        XCTAssertTrue(r.matches("ne Two Three"))
        XCTAssertFalse(r.matches("ne Two Three Four"))
        XCTAssertEqual("ne Two Three", r.consumeToEnd())
        XCTAssertFalse(r.matches("ne"))
    }
    
    func testMatchesNonAscii() {
        let r = CharacterReader("πβγ")
        XCTAssertTrue(r.matches("π"))
        XCTAssertTrue(r.matches("πβ"))
        XCTAssertFalse(r.matches("β"))
    }

    func testMatchesLetterAsciiAndMultibyte() {
        let r = CharacterReader("aπ1")
        XCTAssertTrue(r.matchesLetter())
        _ = r.consume()
        XCTAssertFalse(r.matchesLetter())
        _ = r.consume()
        XCTAssertFalse(r.matchesLetter())
    }
    
    func testMatchesDigitAsciiAndMultibyte() {
        let r = CharacterReader("1٣a")
        XCTAssertTrue(r.matchesDigit())
        _ = r.consume()
        XCTAssertFalse(r.matchesDigit())
        _ = r.consume()
        XCTAssertFalse(r.matchesDigit())
    }

    func testMatchesIgnoreCase() {
        let r = CharacterReader("One Two Three")
        XCTAssertTrue(r.matchesIgnoreCase("O"))
        XCTAssertTrue(r.matchesIgnoreCase("o"))
        XCTAssertTrue(r.matches("O"))
        XCTAssertFalse(r.matches("o"))
        XCTAssertTrue(r.matchesIgnoreCase("One Two Three"))
        XCTAssertTrue(r.matchesIgnoreCase("ONE two THREE"))
        XCTAssertTrue(r.matchesIgnoreCase("One"))
        XCTAssertTrue(r.matchesIgnoreCase("one"))
        XCTAssertEqual("O", r.consume())
        XCTAssertFalse(r.matchesIgnoreCase("One"))
        XCTAssertTrue(r.matchesIgnoreCase("NE Two Three"))
        XCTAssertFalse(r.matchesIgnoreCase("ne Two Three Four"))
        XCTAssertEqual("ne Two Three", r.consumeToEnd())
        XCTAssertFalse(r.matchesIgnoreCase("ne"))
    }

    func testContainsIgnoreCase() {
        let r = CharacterReader("One TWO three")
        XCTAssertTrue(r.containsIgnoreCase("two"))
        XCTAssertTrue(r.containsIgnoreCase("three"))
        // weird one: does not find one, because it scans for consistent case only
        XCTAssertFalse(r.containsIgnoreCase("one"))
    }

    func testContainsIgnoreCasePrefixSuffix() {
        let r = CharacterReader("<title>Test</TITLE>")
        XCTAssertTrue(r.containsIgnoreCase(prefix: UTF8Arrays.endTagStart, suffix: "title".utf8Array))
        let r2 = CharacterReader("<title>Test</BODY>")
        XCTAssertFalse(r2.containsIgnoreCase(prefix: UTF8Arrays.endTagStart, suffix: "title".utf8Array))
    }

    func testMatchesAny() {
        //let scan = [" ", "\n", "\t"]
        let r = CharacterReader("One\nTwo\tThree")
        XCTAssertFalse(r.matchesAny(" ", "\n", "\t"))
        XCTAssertEqual("One", String(decoding: r.consumeToAny(ParsingStrings([" ", "\n", "\t"])), as: UTF8.self))
        XCTAssertTrue(r.matchesAny(" ", "\n", "\t"))
        XCTAssertEqual("\n", r.consume())
        XCTAssertFalse(r.matchesAny(" ", "\n", "\t"))
    }

    func testMatchesAnyMultibyte() {
        let r = CharacterReader("πx")
        XCTAssertTrue(r.matchesAny("π"))
        _ = r.consume()
        XCTAssertFalse(r.matchesAny("π"))
    }

    func testConsumeDataStopsAtAmpersandAndLt() {
        let r = CharacterReader("ab&cd<ef")
        let data = r.consumeData()
        XCTAssertEqual("ab", String(decoding: data, as: UTF8.self))
        XCTAssertEqual("&", r.consume())
        let data2 = r.consumeData()
        XCTAssertEqual("cd", String(decoding: data2, as: UTF8.self))
        XCTAssertEqual("<", r.consume())
        let data3 = r.consumeData()
        XCTAssertEqual("ef", String(decoding: data3, as: UTF8.self))
    }

    func testConsumeDataStopsAtNullByte() {
        let bytes: [UInt8] = [0x61, 0x62, 0x00, 0x63, 0x64]
        let r = CharacterReader(bytes)
        let data = r.consumeData()
        XCTAssertEqual("ab", String(decoding: data, as: UTF8.self))
        XCTAssertEqual(UnicodeScalar(0x00), r.current())
        XCTAssertEqual(UnicodeScalar(0x00), r.consume())
        let data2 = r.consumeData()
        XCTAssertEqual("cd", String(decoding: data2, as: UTF8.self))
    }

    func testConsumeDataWordScanBoundary() {
        let prefix = String(repeating: "a", count: 80)
        let r = CharacterReader(prefix + "&rest")
        let data = r.consumeData()
        XCTAssertEqual(prefix, String(decoding: data, as: UTF8.self))
        XCTAssertEqual("&", r.consume())
    }

    func testConsumeDataWordScanBoundaryAligned() {
        let prefix = String(repeating: "a", count: 64)
        let r = CharacterReader(prefix + "<rest")
        let data = r.consumeData()
        XCTAssertEqual(prefix, String(decoding: data, as: UTF8.self))
        XCTAssertEqual("<", r.consume())
    }

    func testConsumeDataWordScanWithMultibytePrefix() {
        let prefix = String(repeating: "a", count: 70) + "π"
        let r = CharacterReader(prefix + "&rest")
        let data = r.consumeData()
        XCTAssertEqual(prefix, String(decoding: data, as: UTF8.self))
        XCTAssertEqual("&", r.consume())
    }

    func testConsumeDataWordScanNullByteLongInput() {
        let aByte = "a".utf8.first!
        let prefix = [UInt8](repeating: aByte, count: 72)
        let suffix = [UInt8](repeating: aByte, count: 16)
        let bytes = prefix + [0x00] + suffix + ["b".utf8.first!]
        let r = CharacterReader(bytes)
        let data = r.consumeData()
        XCTAssertEqual(prefix.count, data.count)
        XCTAssertEqual(UnicodeScalar(0x00), r.current())
        _ = r.consume()
        let data2 = r.consumeData()
        XCTAssertEqual(suffix.count + 1, data2.count)
        XCTAssertEqual(String(repeating: "a", count: suffix.count) + "b", String(decoding: data2, as: UTF8.self))
    }

    func testConsumeDataWordScanNoTerminatorsLong() {
        let prefix = String(repeating: "a", count: 96)
        let r = CharacterReader(prefix)
        let data = r.consumeData()
        XCTAssertEqual(prefix, String(decoding: data, as: UTF8.self))
        XCTAssertEqual(CharacterReader.EOF, r.current())
    }

    func testConsumeDataWordScanFindsTerminatorInsideWord() {
        var bytes = [UInt8](repeating: "a".utf8.first!, count: 96)
        bytes[48] = "&".utf8.first!
        bytes[70] = "<".utf8.first!
        let r = CharacterReader(bytes)
        let data = r.consumeData()
        XCTAssertEqual(String(repeating: "a", count: 48), String(decoding: data, as: UTF8.self))
        XCTAssertEqual("&", r.consume())
    }

    func testConsumeDataNoTerminators() {
        let r = CharacterReader("abcdef")
        let data = r.consumeData()
        XCTAssertEqual("abcdef", String(decoding: data, as: UTF8.self))
        XCTAssertEqual(CharacterReader.EOF, r.current())
    }

    func testCachesStrings() {
        let r = CharacterReader("Check\tCheck\tCheck\tCHOKE\tA string that is longer than 16 chars")
        let one = r.consumeTo("\t")
        XCTAssertEqual("\t", r.consume())
        let two = r.consumeTo("\t")
        XCTAssertEqual("\t", r.consume())
        let three = r.consumeTo("\t")
        XCTAssertEqual("\t", r.consume())
        let four = r.consumeTo("\t")
        XCTAssertEqual("\t", r.consume())
        let five = r.consumeTo("\t")

        XCTAssertEqual("Check", one)
        XCTAssertEqual("Check", two)
        XCTAssertEqual("Check", three)
        XCTAssertEqual("CHOKE", four)
        XCTAssertTrue(one == two)
        XCTAssertTrue(two == three)
        XCTAssertTrue(three != four)
        XCTAssertTrue(four != five)
        XCTAssertEqual(five, "A string that is longer than 16 chars")
    }

    func testRangeEquals() {
//        let r = CharacterReader("Check\tCheck\tCheck\tCHOKE")
//        XCTAssertTrue(r.rangeEquals(0, 5, "Check"))
//        XCTAssertFalse(r.rangeEquals(0, 5, "CHOKE"))
//        XCTAssertFalse(r.rangeEquals(0, 5, "Chec"))
//
//        XCTAssertTrue(r.rangeEquals(6, 5, "Check"))
//        XCTAssertFalse(r.rangeEquals(6, 5, "Chuck"))
//
//        XCTAssertTrue(r.rangeEquals(12, 5, "Check"))
//        XCTAssertFalse(r.rangeEquals(12, 5, "Cheeky"))
//
//        XCTAssertTrue(r.rangeEquals(18, 5, "CHOKE"))
//        XCTAssertFalse(r.rangeEquals(18, 5, "CHIKE"))
    }
    
    func testJavaScriptParsingHangRegression() throws {
        let expectation = XCTestExpectation(description: "SwiftSoup parse should complete")
        
        DispatchQueue.global().async {
            do {
                let html = """
                    <!DOCTYPE html>
                    <script>
                    <!--//-->
                    &
                    </script>
                """
                _ = try SwiftSoup.parse(html)
                expectation.fulfill() // Fulfill the expectation if parse completes
            } catch {
                XCTFail("Parsing failed with error: \(error)")
                expectation.fulfill() // Fulfill the expectation to not block the waiter in case of error
            }
        }
        
        // Wait for the expectation with a timeout of 3 seconds
        let result = XCTWaiter().wait(for: [expectation], timeout: 3.0)
        
        switch result {
        case .completed:
            // Parse completed within the timeout, the test passes
            break
        case .timedOut:
            // Parse did not complete within the timeout, the test fails
            XCTFail("Parsing took too long; hang detected")
        default:
            break
        }
    }
    
    func testURLCrashRegression() throws {
        let html = """
            <!DOCTYPE html>
            <body>
                <a href="https://secure.imagemaker360.com/Viewer/95.asp?id=181293idxIDX&Referer=&referefull="></a>
            </body>
        """
        _ = try SwiftSoup.parse(html)
    }

    func testMultibyteConsume() throws {
        let r = CharacterReader("-本文-")
        XCTAssertEqual(0, r.getPos())
        XCTAssertEqual("-", r.consume())
        XCTAssertEqual(1, r.getPos())
        XCTAssertEqual("本", r.current())
        XCTAssertEqual("本", r.consume())
        XCTAssertEqual(4, r.getPos())
        XCTAssertEqual("文", r.current())
        XCTAssertEqual("文", r.consume())
        XCTAssertEqual(7, r.getPos())
        XCTAssertEqual("-", r.consume())
    }
}
