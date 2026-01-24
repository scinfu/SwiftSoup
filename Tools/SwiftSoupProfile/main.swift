import Foundation
import SwiftSoup

func writeStderr(_ message: String) {
    if let data = message.data(using: .utf8) {
        FileHandle.standardError.write(data)
    }
}

#if canImport(Darwin)
func withAutoreleasepool(_ body: () throws -> Void) rethrows {
    try autoreleasepool {
        try body()
    }
}
#else
func withAutoreleasepool(_ body: () throws -> Void) rethrows {
    try body()
}
#endif

struct Options {
    var fixturesPath: String
    var includeText: Bool
    var repeatCount: Int
    var workload: Workload
    var workloadA: Workload?
    var workloadB: Workload?
    var abMode: Bool
    var iterations: Int
}

enum Workload: String {
    case fixtures
    case trimHeavy
    case selectorParse
    case attributeParse
    case parsingStringsSingleByte
    case parsingStringsTable
    case entitiesHeavy
    case consumeToAnySingleByte
    case manabiInjectionParse
    case manabiInjectionTraverse
    case manabiTagLookup
    case manabiSelect
    case manabiOuterHtml
    case textRawSingle
    case textRawTraverse
    case manabiOuterHtmlLarge
    case manabiOuterHtmlLargeNoPretty
    case manabiScriptStyleOuterHtmlNoPretty
    case manabiReaderCandidateLines
    case manabiReaderCandidateLinesLarge
    case manabiReaderPipeline
    case manabiReaderParseOnly
    case manabiTextLarge
    case attributeLookup
    case selectorTagLookup
    case selectorCacheHeavy
    case manabiSelectLarge
    case elementsAttributeLookup
    case fixturesOuterHtml
    case fixturesOuterHtmlNoPretty
    case fixturesOuterHtmlNoPrettyNoSourceRanges
    case fixturesInnerHtmlNoPretty
    case fixturesText
    case fixturesSelect
}

func parseOptions() -> Options {
    let args = ProcessInfo.processInfo.arguments
    var fixturesPath = ProcessInfo.processInfo.environment["READABILITY_FIXTURES"]
    var includeText = false
    var repeatCount = 1
    var workload: Workload = .fixtures
    var workloadA: Workload? = nil
    var workloadB: Workload? = nil
    var abMode = false
    var iterations = 200_000

    var i = 1
    while i < args.count {
        let arg = args[i]
        if arg == "--fixtures", i + 1 < args.count {
            fixturesPath = args[i + 1]
            i += 2
            continue
        } else if arg == "--text" {
            includeText = true
        } else if arg == "--ab" {
            abMode = true
        } else if arg == "--repeat", i + 1 < args.count {
            repeatCount = max(1, Int(args[i + 1]) ?? 1)
            i += 2
            continue
        } else if arg == "--workload-a", i + 1 < args.count {
            workloadA = Workload(rawValue: args[i + 1])
            i += 2
            continue
        } else if arg == "--workload-b", i + 1 < args.count {
            workloadB = Workload(rawValue: args[i + 1])
            i += 2
            continue
        } else if arg == "--workload", i + 1 < args.count {
            workload = Workload(rawValue: args[i + 1]) ?? .fixtures
            i += 2
            continue
        } else if arg == "--iterations", i + 1 < args.count {
            iterations = max(1, Int(args[i + 1]) ?? iterations)
            i += 2
            continue
        }
        i += 1
    }

    if workloadA != nil || workloadB != nil {
        abMode = true
        if workloadA == nil {
            workloadA = workload
        }
        if workloadB == nil {
            workloadB = workload
        }
    }

    if fixturesPath == nil || fixturesPath!.isEmpty {
        fixturesPath = "/Users/alex/Code/lake-of-fire/swift-readability/Tests/SwiftReadabilityTests/Fixtures"
    }

    return Options(
        fixturesPath: fixturesPath!,
        includeText: includeText,
        repeatCount: repeatCount,
        workload: workload,
        workloadA: workloadA,
        workloadB: workloadB,
        abMode: abMode,
        iterations: iterations
    )
}

func findSourceHTMLFiles(fixturesPath: String) -> [URL] {
    let root = URL(fileURLWithPath: fixturesPath)
    let testPages = root.appendingPathComponent("test-pages", isDirectory: true)
    guard let enumerator = FileManager.default.enumerator(
        at: testPages,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
    ) else {
        return []
    }

    var files: [URL] = []
    for case let url as URL in enumerator {
        if url.lastPathComponent == "source.html" {
            files.append(url)
        }
    }
    return files.sorted { $0.path < $1.path }
}

struct RunResult {
    let workload: Workload
    let duration: Double
    let totalBytes: Int
    let parsedCount: Int
}

@inline(__always)
func workloadNeedsFixtures(_ workload: Workload) -> Bool {
    switch workload {
    case .fixtures,
         .fixturesOuterHtml,
         .fixturesOuterHtmlNoPretty,
         .fixturesOuterHtmlNoPrettyNoSourceRanges,
         .fixturesInnerHtmlNoPretty,
         .fixturesText,
         .fixturesSelect:
        return true
    default:
        return false
    }
}

func runWorkload(_ workload: Workload, _ options: Options, _ files: [URL]) throws -> RunResult {
    Profiler.reset()
    let start = Date()
    var totalBytes = 0
    var parsedCount = 0

    switch workload {
case .fixtures:
    for _ in 0..<options.repeatCount {
        for url in files {
            withAutoreleasepool {
                do {
                    let data = try Data(contentsOf: url)
                    totalBytes += data.count
                    let doc = try SwiftSoup.parse(data, "")
                    if options.includeText {
                        _ = try doc.text()
                    }
                    parsedCount += 1
                } catch {
                    writeStderr("Error parsing \(url.path): \(error)\n")
                }
            }
        }
    }
case .trimHeavy:
    let sample = " \t\n  The quick brown fox jumps over the lazy dog  \n\t "
    let pool = Array(repeating: sample, count: 32)
    for _ in 0..<options.repeatCount {
        var idx = 0
        for _ in 0..<options.iterations {
            _ = pool[idx].trim()
            idx = (idx &+ 1) % pool.count
        }
    }
case .selectorParse:
    let doc = try SwiftSoup.parse("<div id='root'><p class='a b'>Hello</p><span data-x='1'></span></div>")
    let selectors = [
        "div > p.a",
        "div > p.a.b",
        "div#root span[data-x='1']",
        "div  >  p   ",
        "div > span[data-x]"
    ]
    for _ in 0..<options.repeatCount {
        var idx = 0
        for _ in 0..<options.iterations {
            _ = try doc.select(selectors[idx])
            idx = (idx &+ 1) % selectors.count
        }
    }
case .selectorCacheHeavy:
    let doc = try SwiftSoup.parseBodyFragment("<div id='root'><span data-x='1'></span></div>")
    let selectors = (0..<512).map { "div[data-x='\($0)'] span" }
    for _ in 0..<options.repeatCount {
        var idx = 0
        for _ in 0..<options.iterations {
            _ = try doc.select(selectors[idx])
            idx = (idx &+ 1) % selectors.count
        }
    }
case .attributeParse:
    let html = "<div id='root' data-a='1' data-b='2' class='a b c' title='hello world' aria-label='x'></div>"
    for _ in 0..<options.repeatCount {
        for _ in 0..<options.iterations {
            let doc = try SwiftSoup.parse(html)
            _ = try doc.select("div").first()?.getAttributes()
        }
    }
case .parsingStringsSingleByte:
    let parsingStrings = ParsingStrings([" ", ">", "€"])
    let one = [UInt8](arrayLiteral: 32)
    let slice = one[one.startIndex..<one.endIndex]
    for _ in 0..<options.repeatCount {
        for _ in 0..<options.iterations {
            _ = parsingStrings.contains(slice)
        }
    }
case .parsingStringsTable:
    let parsingStrings = ParsingStrings([" ", ">", "€"])
    for _ in 0..<options.repeatCount {
        for _ in 0..<options.iterations {
            _ = parsingStrings.contains(32)
        }
    }
case .entitiesHeavy:
    let entityChunk = "&amp;&lt;&gt;&quot;&#39;"
    let payload = String(repeating: entityChunk, count: 2000)
    let html = "<div>\(payload)</div>"
    for _ in 0..<options.repeatCount {
        for _ in 0..<options.iterations {
            _ = try SwiftSoup.parseBodyFragment(html)
        }
    }
case .consumeToAnySingleByte:
    let chars = ParsingStrings(["&", "<", ">"])
    let input = String(repeating: "a", count: 1024) + "&"
    let reader = CharacterReader(input)
    for _ in 0..<options.repeatCount {
        for _ in 0..<options.iterations {
            reader.pos = reader.input.startIndex
            _ = reader.consumeToAny(chars) as ArraySlice<UInt8>
        }
    }
case .manabiInjectionParse:
    let html = """
    <div class='entry'><ruby>漢字<rt>かんじ</rt></ruby>と<ruby data-manabi-generated='true'>仮名<rt>かな</rt></ruby>を学ぶ</div>
    <p class='line'>彼は「テスト」を受けた。</p>
    <span data-manabi-considered-inline='true'>サンプル</span>
    """
    for _ in 0..<options.repeatCount {
        for _ in 0..<options.iterations {
            _ = try SwiftSoup.parseBodyFragment(html)
        }
    }
case .manabiInjectionTraverse:
    let html = """
    <div class='entry'><ruby>漢字<rt>かんじ</rt></ruby>と<ruby data-manabi-generated='true'>仮名<rt>かな</rt></ruby>を学ぶ</div>
    <p class='line'>彼は「テスト」を受けた。</p>
    <span data-manabi-considered-inline='true'>サンプル</span>
    """
    for _ in 0..<options.repeatCount {
        for _ in 0..<options.iterations {
            let doc = try SwiftSoup.parseBodyFragment(html)
            guard let body = doc.body() else { continue }
            let ruby = try body.getElementsByTag("ruby")
            _ = ruby.size()
            _ = try body.text(trimAndNormaliseWhitespace: false)
            _ = try body.outerHtml()
        }
    }
case .manabiTagLookup:
    let html = """
    <div class='entry'><ruby>漢字<rt>かんじ</rt></ruby>と<ruby data-manabi-generated='true'>仮名<rt>かな</rt></ruby>を学ぶ</div>
    <p class='line'>彼は「テスト」を受けた。</p>
    <span data-manabi-considered-inline='true'>サンプル</span>
    """
    let doc = try SwiftSoup.parseBodyFragment(html)
    guard let body = doc.body() else { break }
    for _ in 0..<options.repeatCount {
        for _ in 0..<options.iterations {
            _ = try body.getElementsByTag("ruby")
            _ = try body.getElementsByTag("rt")
            _ = try body.getElementsByTag("rb")
            _ = try body.getElementsByTag("rp")
            _ = try body.getElementsByTag("span")
            _ = try body.getElementsByTag("div")
        }
    }
case .manabiSelect:
    let html = """
    <manabi-container>
      <manabi-sentence>漢字<manabi-surface>漢字</manabi-surface></manabi-sentence>
      <manabi-sentence>仮名<manabi-surface>仮名</manabi-surface></manabi-sentence>
    </manabi-container>
    """
    let doc = try SwiftSoup.parseBodyFragment(html)
    guard let body = doc.body() else { break }
    for _ in 0..<options.repeatCount {
        for _ in 0..<options.iterations {
            _ = try body.select("manabi-surface")
            _ = try body.select("manabi-sentence")
            _ = try body.select("manabi-container")
        }
    }
case .manabiOuterHtml:
    let html = """
    <div class='entry'><ruby>漢字<rt>かんじ</rt></ruby>と<ruby data-manabi-generated='true'>仮名<rt>かな</rt></ruby>を学ぶ</div>
    <p class='line'>彼は「テスト」を受けた。</p>
    <span data-manabi-considered-inline='true'>サンプル</span>
    """
    let doc = try SwiftSoup.parseBodyFragment(html)
    guard let body = doc.body() else { break }
    for _ in 0..<options.repeatCount {
        for _ in 0..<options.iterations {
            _ = try body.outerHtml()
        }
    }
case .textRawSingle:
    let html = "単純なテキストだけ"
    let doc = try SwiftSoup.parseBodyFragment(html)
    guard let body = doc.body() else { break }
    for _ in 0..<options.repeatCount {
        for _ in 0..<options.iterations {
            _ = try body.text(trimAndNormaliseWhitespace: false)
        }
    }
case .textRawTraverse:
    let html = """
    <div>単純なテキストだけ</div>
    <p>複数ノードのテキスト<span>断片</span>を含む</p>
    """
    let doc = try SwiftSoup.parseBodyFragment(html)
    guard let body = doc.body() else { break }
    for _ in 0..<options.repeatCount {
        for _ in 0..<options.iterations {
            _ = try body.text(trimAndNormaliseWhitespace: false)
        }
    }
case .manabiOuterHtmlLarge:
    let chunk = """
    <div class='entry'><ruby>漢字<rt>かんじ</rt></ruby>と<ruby data-manabi-generated='true'>仮名<rt>かな</rt></ruby>を学ぶ</div>
    <p class='line'>彼は「テスト」を受けた。</p>
    <span data-manabi-considered-inline='true'>サンプル</span>
    """
    let html = String(repeating: chunk, count: 200)
    let doc = try SwiftSoup.parseBodyFragment(html)
    guard let body = doc.body() else { break }
    for _ in 0..<options.repeatCount {
        for _ in 0..<options.iterations {
            _ = try body.outerHtml()
        }
    }
case .manabiOuterHtmlLargeNoPretty:
    let chunk = """
    <div class='entry'><ruby>漢字<rt>かんじ</rt></ruby>と<ruby data-manabi-generated='true'>仮名<rt>かな</rt></ruby>を学ぶ</div>
    <p class='line'>彼は「テスト」を受けた。</p>
    <span data-manabi-considered-inline='true'>サンプル</span>
    """
    let html = String(repeating: chunk, count: 200)
    let doc = try SwiftSoup.parseBodyFragment(html)
    doc.outputSettings().prettyPrint(pretty: false)
    guard let body = doc.body() else { break }
    for _ in 0..<options.repeatCount {
        for _ in 0..<options.iterations {
            _ = try body.outerHtml()
        }
    }
case .manabiScriptStyleOuterHtmlNoPretty:
    let chunk = """
    <script>var a=1<2&&b='&';function t(x){return x+1;}</script>
    <style>body{font-family:'a';}p::before{content:'<';}</style>
    <!-- comment -->
    <div>text &amp; more</div>
    """
    let html = String(repeating: chunk, count: 200)
    let doc = try SwiftSoup.parseBodyFragment(html)
    doc.outputSettings().prettyPrint(pretty: false)
    guard let body = doc.body() else { break }
    for _ in 0..<options.repeatCount {
        for _ in 0..<options.iterations {
            _ = try body.outerHtml()
        }
    }
case .manabiReaderCandidateLines:
    let chunk = """
    <div class="line"><span>日本語</span>の<ruby>勉強<rt>べんきょう</rt></ruby>をする。</div>
    <p class="line">彼は<strong>学校</strong>へ行った。</p>
    <div class="line"><a href="#">リンク</a>と<span>テキスト</span>が混在。</div>
    """
    let html = String(repeating: chunk, count: 200)
    let doc = try SwiftSoup.parseBodyFragment(html)
    doc.outputSettings().prettyPrint(pretty: false)
    guard let body = doc.body() else { break }
    let lines = try body.select("div.line, p.line")
    for _ in 0..<options.repeatCount {
        for _ in 0..<options.iterations {
            for line in lines {
                let candidateHTML = line.getChildNodes().compactMap { node in
                    if let textNode = node as? TextNode {
                        return textNode.getWholeText()
                    } else if let element = node as? Element {
                        return try? element.outerHtml()
                    }
                    return try? node.outerHtml()
                }.joined()
                _ = candidateHTML
            }
        }
    }
case .manabiReaderCandidateLinesLarge:
    let chunk = """
    <div class="line"><span>日本語</span>の<ruby>勉強<rt>べんきょう</rt></ruby>をする。<em>強調</em>や<code>code</code>も含む。</div>
    <p class="line">彼は<strong>学校</strong>へ行った。<span data-x="1">テスト</span>を受けた。</p>
    <div class="line"><a href="#">リンク</a>と<span>テキスト</span>が混在。<ruby>漢字<rt>かんじ</rt></ruby>多め。</div>
    <div class="line"><span>長い</span>文章で<sup>上</sup><sub>下</sub>や<span class="a b">class</span>を含む。</div>
    """
    let html = String(repeating: chunk, count: 150)
    let doc = try SwiftSoup.parseBodyFragment(html)
    doc.outputSettings().prettyPrint(pretty: false)
    guard let body = doc.body() else { break }
    let lines = try body.select("div.line, p.line")
    for _ in 0..<options.repeatCount {
        for _ in 0..<options.iterations {
            for line in lines {
                let candidateHTML = line.getChildNodes().compactMap { node in
                    if let textNode = node as? TextNode {
                        return textNode.getWholeText()
                    } else if let element = node as? Element {
                        return try? element.outerHtml()
                    }
                    return try? node.outerHtml()
                }.joined()
                _ = candidateHTML
            }
        }
    }
case .manabiReaderPipeline:
    let chunk = """
    <div class="line"><span>日本語</span>の<ruby>勉強<rt>べんきょう</rt></ruby>をする。<em>強調</em>や<code>code</code>も含む。</div>
    <p class="line">彼は<strong>学校</strong>へ行った。<span data-x="1">テスト</span>を受けた。</p>
    <div class="line"><a href="#">リンク</a>と<span>テキスト</span>が混在。<ruby>漢字<rt>かんじ</rt></ruby>多め。</div>
    """
    let html = String(repeating: chunk, count: 150)
    let doc = try SwiftSoup.parseBodyFragment(html)
    doc.outputSettings().prettyPrint(pretty: false)
    guard let body = doc.body() else { break }
    let lines = try body.select("div.line, p.line")
    for _ in 0..<options.repeatCount {
        for _ in 0..<options.iterations {
            for line in lines {
                let candidateHTML = line.getChildNodes().compactMap { node in
                    if let textNode = node as? TextNode {
                        return textNode.getWholeText()
                    } else if let element = node as? Element {
                        return try? element.outerHtml()
                    }
                    return try? node.outerHtml()
                }.joined()
                let fragment = try SwiftSoup.parseBodyFragment(candidateHTML)
                if let fragmentBody = fragment.body() {
                    _ = try fragmentBody.text(trimAndNormaliseWhitespace: false)
                    _ = try fragmentBody.select("ruby, a, span")
                    _ = try fragmentBody.outerHtml()
                }
            }
        }
    }
case .manabiReaderParseOnly:
    let chunk = """
    <div class="line"><span>日本語</span>の<ruby>勉強<rt>べんきょう</rt></ruby>をする。<em>強調</em>や<code>code</code>も含む。</div>
    <p class="line">彼は<strong>学校</strong>へ行った。<span data-x="1">テスト</span>を受けた。</p>
    <div class="line"><a href="#">リンク</a>と<span>テキスト</span>が混在。<ruby>漢字<rt>かんじ</rt></ruby>多め。</div>
    """
    let html = String(repeating: chunk, count: 150)
    for _ in 0..<options.repeatCount {
        for _ in 0..<options.iterations {
            _ = try SwiftSoup.parseBodyFragment(html)
        }
    }
case .manabiTextLarge:
    let chunk = """
    <div class='entry'>単純なテキストだけ<ruby>漢字<rt>かんじ</rt></ruby></div>
    <p class='line'>複数ノードのテキスト<span>断片</span>を含む</p>
    """
    let html = String(repeating: chunk, count: 200)
    let doc = try SwiftSoup.parseBodyFragment(html)
    guard let body = doc.body() else { break }
    for _ in 0..<options.repeatCount {
        for _ in 0..<options.iterations {
            _ = try body.text(trimAndNormaliseWhitespace: false)
        }
    }
case .attributeLookup:
    let html = """
    <a id="link-id" class="link primary" href="https://example.com" title="Example" data-x="y">Link</a>
    """
    let doc = try SwiftSoup.parseBodyFragment(html)
    guard let body = doc.body(), let link = try body.select("a").first() else { break }
    for _ in 0..<options.repeatCount {
        for _ in 0..<options.iterations {
            _ = try link.attr("href")
            _ = try link.attr("id")
            _ = try link.attr("class")
            _ = link.hasAttr("href")
            _ = link.hasAttr("data-x")
            _ = try link.attr("data-x")
        }
    }
case .selectorTagLookup:
    let html = """
    <div><p>One</p><span>Two</span><div>Three</div></div>
    """
    let doc = try SwiftSoup.parseBodyFragment(html)
    guard let body = doc.body() else { break }
    for _ in 0..<options.repeatCount {
        for _ in 0..<options.iterations {
            _ = try body.select("div")
            _ = try body.select("p")
            _ = try body.select("span")
        }
    }
case .manabiSelectLarge:
    let chunk = """
    <div class='entry'><ruby>漢字<rt>かんじ</rt></ruby>と<ruby data-manabi-generated='true'>仮名<rt>かな</rt></ruby>を学ぶ</div>
    <p class='line'>彼は「テスト」を受けた。</p>
    <span data-manabi-considered-inline='true'>サンプル</span>
    """
    let html = String(repeating: chunk, count: 200)
    let doc = try SwiftSoup.parseBodyFragment(html)
    guard let body = doc.body() else { break }
    for _ in 0..<options.repeatCount {
        for _ in 0..<options.iterations {
            _ = try body.select("ruby")
            _ = try body.select("rt")
            _ = try body.select("span")
            _ = try body.select("div")
        }
    }
case .elementsAttributeLookup:
    let html = """
    <div>
      <a id="link-id" class="link primary" href="https://example.com" title="Example" data-x="y">Link</a>
      <a class="secondary" href="/rel">Rel</a>
    </div>
    """
    let doc = try SwiftSoup.parseBodyFragment(html)
    guard let body = doc.body() else { break }
    let links = try body.getElementsByTag("a")
    for _ in 0..<options.repeatCount {
        for _ in 0..<options.iterations {
            _ = try links.attr("href")
            _ = links.hasAttr("class")
            _ = links.hasAttr("data-x")
        }
    }
case .fixturesOuterHtml:
    for _ in 0..<options.repeatCount {
        for url in files {
            withAutoreleasepool {
                do {
                    let data = try Data(contentsOf: url)
                    totalBytes += data.count
                    let doc = try SwiftSoup.parse(data, "")
                    _ = try doc.body()?.outerHtml()
                    parsedCount += 1
                } catch {
                    writeStderr("Error parsing \(url.path): \(error)\n")
                }
            }
        }
    }
case .fixturesOuterHtmlNoPretty:
    for _ in 0..<options.repeatCount {
        for url in files {
            withAutoreleasepool {
                do {
                    let data = try Data(contentsOf: url)
                    totalBytes += data.count
                    let doc = try SwiftSoup.parse(data, "")
                    doc.outputSettings().prettyPrint(pretty: false)
                    _ = try doc.body()?.outerHtml()
                    parsedCount += 1
                } catch {
                    writeStderr("Error parsing \(url.path): \(error)\n")
                }
            }
        }
    }
case .fixturesOuterHtmlNoPrettyNoSourceRanges:
    for _ in 0..<options.repeatCount {
        for url in files {
            withAutoreleasepool {
                do {
                    let data = try Data(contentsOf: url)
                    totalBytes += data.count
                    let parser = Parser.htmlParser()
                    parser.settings(ParseSettings(false, false, false))
                    let doc = try parser.parseInput([UInt8](data), "")
                    doc.outputSettings().prettyPrint(pretty: false)
                    _ = try doc.body()?.outerHtml()
                    parsedCount += 1
                } catch {
                    writeStderr("Error parsing \(url.path): \(error)\n")
                }
            }
        }
    }
case .fixturesInnerHtmlNoPretty:
    for _ in 0..<options.repeatCount {
        for url in files {
            withAutoreleasepool {
                do {
                    let data = try Data(contentsOf: url)
                    totalBytes += data.count
                    let doc = try SwiftSoup.parse(data, "")
                    doc.outputSettings().prettyPrint(pretty: false)
                    _ = try doc.body()?.html()
                    parsedCount += 1
                } catch {
                    writeStderr("Error parsing \(url.path): \(error)\n")
                }
            }
        }
    }
case .fixturesText:
    for _ in 0..<options.repeatCount {
        for url in files {
            withAutoreleasepool {
                do {
                    let data = try Data(contentsOf: url)
                    totalBytes += data.count
                    let doc = try SwiftSoup.parse(data, "")
                    _ = try doc.body()?.text()
                    parsedCount += 1
                } catch {
                    writeStderr("Error parsing \(url.path): \(error)\n")
                }
            }
        }
    }
case .fixturesSelect:
    for _ in 0..<options.repeatCount {
        for url in files {
            withAutoreleasepool {
                do {
                    let data = try Data(contentsOf: url)
                    totalBytes += data.count
                    let doc = try SwiftSoup.parse(data, "")
                    if let body = doc.body() {
                        _ = try body.select("p")
                        _ = try body.select("a")
                        _ = try body.select("img")
                    }
                    parsedCount += 1
                } catch {
                    writeStderr("Error parsing \(url.path): \(error)\n")
                }
            }
        }
    }
}

    let total = Date().timeIntervalSince(start)
    return RunResult(workload: workload, duration: total, totalBytes: totalBytes, parsedCount: parsedCount)
}

@inline(__always)
func printResult(_ result: RunResult, label: String? = nil) {
    let prefix = label.map { "\($0) " } ?? ""
    if result.workload == .fixtures {
        let mb = Double(result.totalBytes) / (1024.0 * 1024.0)
        print("\(prefix)Parsed \(result.parsedCount) files, \(String(format: "%.2f", mb)) MB in \(String(format: "%.2f", result.duration)) s")
    } else {
        print("\(prefix)Workload \(result.workload.rawValue) completed in \(String(format: "%.2f", result.duration)) s")
    }
}

let options = parseOptions()
let files = findSourceHTMLFiles(fixturesPath: options.fixturesPath)

let workloadsToCheck: [Workload] = options.abMode
    ? [options.workloadA ?? options.workload, options.workloadB ?? options.workload]
    : [options.workload]

if workloadsToCheck.contains(where: workloadNeedsFixtures), files.isEmpty {
    writeStderr("No source.html files found under: \(options.fixturesPath)\n")
    exit(1)
}

if options.abMode {
    let workloadA = options.workloadA ?? options.workload
    let workloadB = options.workloadB ?? options.workload
    do {
        let resultA = try runWorkload(workloadA, options, files)
        let resultB = try runWorkload(workloadB, options, files)
        printResult(resultA, label: "A:")
        printResult(resultB, label: "B:")
        let delta = resultB.duration - resultA.duration
        let pct = resultA.duration > 0 ? (delta / resultA.duration) * 100.0 : 0
        print("Δ: \(String(format: "%.2f", delta)) s (\(String(format: "%.1f", pct))%)")
    } catch {
        writeStderr("Error running workloads: \(error)\n")
        exit(1)
    }
} else {
    do {
        let result = try runWorkload(options.workload, options, files)
        printResult(result)
    } catch {
        writeStderr("Error running workload: \(error)\n")
        exit(1)
    }
}
print(Profiler.report(top: 40))
