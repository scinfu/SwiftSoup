import Foundation
import XCTest
@testable import SwiftSoup

/// `<p>` scope checks read incrementally tracked stack positions, so every way of removing from the top of the stack
/// has to keep that tracking right. Each case closes elements through one of those paths and then asks a `<p>` scope
/// question, directly or through the next `<p>`.
final class HtmlStackTrackingTest: XCTestCase {
    func testParagraphScopeAfterRenamingAnOpenElement() throws {
        let parser = Parser.htmlParser()
        let document = try parser.parseInput("<p>a<button><span>b", "")
        document.outputSettings().prettyPrint(pretty: false)
        try XCTUnwrap(document.select("button").first()).tagName("i")
        try parser.getTreeBuilder().processEndTag("span")
        try parser.getTreeBuilder().processStartTag("p")
        XCTAssertEqual(try XCTUnwrap(document.body()).html(), "<p>a<i><span>b</span></i></p><p></p>")
    }

    func testSourceSerializationAfterStackRemovals() throws {
        let cases: [(html: String, body: String)] = [
            (#"<p>a<button><p>b</button>c<p>d"#,
             #"<p>a<button><p>b</button>c</p><p>d</p>"#),
            (#"<p>a<div>b</div><p>c"#,
             #"<p>a</p><div>b</div><p>c</p>"#),
            (#"<h1>a<p>b</h1><p>c<p>d"#,
             #"<h1>a<p>b</p></h1><p>c</p><p>d</p>"#),
            (#"<table><tr><td><p>a</td><td><p>b</table><p>c<p>d"#,
             #"<table><tr><td><p>a</td><td><p>b</table><p>c</p><p>d</p>"#),
            (#"<table><tr><td><p>a<tr><td><p>b<tbody><tr><td><button><p>c</table><p>d<p>e"#,
             #"<table><tr><td><p>a<tr><td><p>b<tbody><tr><td><button><p>c</table><p>d</p><p>e</p>"#),
            (#"<table><caption><p>a</caption><colgroup><col><tr><th><p>b</th></table><p>c"#,
             #"<table><caption><p>a</caption><colgroup><col><tr><th><p>b</th></table><p>c</p>"#),
            (#"<x-a><p>a<x-b><button><p>b</button>c</x-b><p>d</x-a><p>e<p>f"#,
             #"<x-a><p>a<x-b><button><p>b</button>c</x-b></p><p>d</p><p>e</p><p>f</p></x-a>"#),
            (#"<x-a>a</x-a><p>b<p>c"#,
             #"<x-a>a</x-a><p>b</p><p>c</p>"#),
            (#"<b><p>a</b>b<p>c"#,
             #"<b></b><p><b>a</b>b</p><p>c</p>"#),
            (#"<p><a><div>x</a>y<p>z"#,
             #"<p><a></a></p><div><a>x</a>y<p>z</p></div>"#),
            (#"<select><option>a<optgroup><option>b</select><p>c<p>d"#,
             #"<select><option>a<optgroup><option>b</select><p>c</p><p>d</p>"#),
            (#"<ul><li><p>a<li><p>b</ul><p>c"#,
             #"<ul><li><p>a<li><p>b</ul><p>c</p>"#),
            (#"<button><table><tr><td><p>a</table></button><p>b<p>c"#,
             #"<button><table><tr><td><p>a</table></button><p>b</p><p>c</p>"#),
            (#"<p>a<table><tr><td>b</td></tr></table>c<p>d"#,
             #"<p>a</p><table><tr><td>b</td></tr></table>c<p>d</p>"#),
        ]
        for (html, expected) in cases {
            let document = try SwiftSoup.parse(html)
            document.outputSettings().prettyPrint(pretty: false)
            XCTAssertEqual(try XCTUnwrap(document.body()).html(), expected, html)
            // Source-preserving serialization above checks lexical behavior.
            // Also compare the actual trees through both parser paths, with
            // source replay disabled when serializing either result.
            let untracked = try Parser.htmlParser().settings(ParseSettings(false, false, false)).parseInput(html, "")
            untracked.outputSettings().prettyPrint(pretty: false)
            XCTAssertEqual(try XCTUnwrap(document.body()).htmlUTF8WithoutSourceReuse(),
                           try XCTUnwrap(untracked.body()).htmlUTF8WithoutSourceReuse(), html)
        }
    }

    func testDeepTablesAndClosedParagraphsKeepTheirShape() throws {
        let depth = 3_000
        let tables = try SwiftSoup.parse(String(repeating: "<table><tr><td>", count: depth))
        let tableNodes = try tables.select("table").array()
        let cells = try tables.select("td").array()
        XCTAssertEqual(tableNodes.count, depth)
        XCTAssertEqual(cells.count, depth)
        for (table, cell) in zip(tableNodes.dropFirst(), cells) {
            XCTAssertTrue(table.parent() === cell)
        }
        let paragraphs = try SwiftSoup.parse(
            String(repeating: "<font>", count: depth) + String(repeating: "<p>x", count: depth))
        let fonts = try paragraphs.select("font").array()
        let ps = try paragraphs.select("p").array()
        XCTAssertEqual(fonts.count, depth)
        XCTAssertEqual(ps.count, depth)
        for (font, parent) in zip(fonts.dropFirst(), fonts) { XCTAssertTrue(font.parent() === parent) }
        for p in ps { XCTAssertTrue(p.parent() === fonts.last) }
    }

    /// SWIFTSOUP_STACK_PROFILE=1 swift test -c release --filter HtmlStackTrackingTest/testStackTrackingProfile
    func testStackTrackingProfile() throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["SWIFTSOUP_STACK_PROFILE"] == "1" else {
            throw XCTSkip("Set SWIFTSOUP_STACK_PROFILE=1 to measure parsing of deeply nested tables and paragraphs")
        }
        let depth = max(1, Int(environment["SWIFTSOUP_STACK_PROFILE_DEPTH"] ?? "5000") ?? 5000)
        let iterations = max(1, Int(environment["SWIFTSOUP_STACK_PROFILE_ITERATIONS"] ?? "5") ?? 5)
        let workloads = [
            ("tables", String(repeating: "<table><tr><td>", count: depth)),
            ("paragraphs", String(repeating: "<font>", count: depth) + String(repeating: "<p>x", count: depth)),
        ]
        for (name, html) in workloads {
            let start = DispatchTime.now().uptimeNanoseconds
            for _ in 0..<iterations { _ = try SwiftSoup.parse(html) }
            let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
            print("Stack tracking \(name) elapsed: \(elapsed) ms over \(iterations) iterations at depth \(depth)")
        }
    }
}
