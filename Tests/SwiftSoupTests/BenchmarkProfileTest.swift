import XCTest
import SwiftSoup

final class BenchmarkProfileTest: XCTestCase {
    private func envInt(_ key: String, _ defaultValue: Int) -> Int {
        if let value = ProcessInfo.processInfo.environment[key], let parsed = Int(value) {
            return parsed
        }
        return defaultValue
    }

    private func buildBenchmarkHTML(repeatCount: Int) -> String {
        let chunk = """
        <div class=\"alpha beta\" data-x=\"123\" data-y='abc' data-z=foo id=\"node\">
          <span class=inner data-k=\"v&amp;v\">text</span>
          <a href=\"https://example.com?q=1&x=2\" rel=\"nofollow noopener\">link</a>
          <p class=\"body\">Paragraph <em>emphasis</em> and <strong>strong</strong>.</p>
        </div>
        """

        return "<!doctype html><html><head><title>t</title></head><body>" +
            String(repeating: chunk, count: repeatCount) +
            "</body></html>"
    }
    
    private func buildLargeBenchmarkHTML(repeatCount: Int) -> String {
        let chunk = """
        <section class=\"hero\" data-section=\"top\">
          <h1>Heading</h1>
          <p>Intro <span>with <b>bold</b> and <i>italic</i></span> text.</p>
          <ul class=\"list\">
            <li>Item 1</li><li>Item 2</li><li>Item 3</li><li>Item 4</li>
          </ul>
          <table class=\"grid\">
            <thead><tr><th>A</th><th>B</th><th>C</th></tr></thead>
            <tbody>
              <tr><td>1</td><td>2</td><td>3</td></tr>
              <tr><td>4</td><td>5</td><td>6</td></tr>
              <tr><td>7</td><td>8</td><td>9</td></tr>
            </tbody>
          </table>
          <form action=\"/submit\" method=\"post\">
            <input type=\"text\" name=\"q\" value=\"swift\">
            <input type=\"checkbox\" name=\"x\" checked>
            <button type=\"submit\">Go</button>
          </form>
        </section>
        """
        
        return "<!doctype html><html><head><title>big</title></head><body>" +
            String(repeating: chunk, count: repeatCount) +
            "</body></html>"
    }

    private func buildHugeBenchmarkHTML(repeatCount: Int) -> String {
        let chunk = """
        <article class=\"post\" data-id=\"42\">
          <header>
            <h1>Title</h1>
            <p class=\"meta\"><time datetime=\"2024-01-01\">Jan 1</time> · <a href=\"/author\">Author</a></p>
          </header>
          <section class=\"content\">
            <p>Longer text with <em>emphasis</em>, <strong>strong</strong>, and <a href=\"/link\">links</a>.</p>
            <p>Second paragraph with <code>code</code> and <span class=\"highlight\">highlights</span>.</p>
            <ul class=\"bullets\">
              <li>One</li><li>Two</li><li>Three</li><li>Four</li><li>Five</li>
            </ul>
            <ol class=\"numbers\">
              <li>Alpha</li><li>Beta</li><li>Gamma</li><li>Delta</li><li>Epsilon</li>
            </ol>
          </section>
          <aside class=\"related\">
            <h2>Related</h2>
            <ul>
              <li><a href=\"/r1\">R1</a></li>
              <li><a href=\"/r2\">R2</a></li>
              <li><a href=\"/r3\">R3</a></li>
            </ul>
          </aside>
          <footer>
            <form action=\"/subscribe\" method=\"post\">
              <input type=\"email\" name=\"email\" value=\"user@example.com\">
              <button type=\"submit\">Subscribe</button>
            </form>
          </footer>
        </article>
        """

        return "<!doctype html><html><head><title>huge</title></head><body>" +
            String(repeating: chunk, count: repeatCount) +
            "</body></html>"
    }

    private func buildGiantBenchmarkHTML(repeatCount: Int) -> String {
        let chunk = """
        <main class=\"page\">
          <header class=\"site-header\">
            <nav class=\"nav\">
              <ul><li><a href=\"/\">Home</a></li><li><a href=\"/docs\">Docs</a></li></ul>
            </nav>
          </header>
          <section class=\"content\">
            <article>
              <h1>Big Title</h1>
              <p>Paragraph with <em>em</em> and <strong>strong</strong>.</p>
              <table class=\"data\">
                <thead><tr><th>A</th><th>B</th><th>C</th></tr></thead>
                <tbody>
                  <tr><td>1</td><td>2</td><td>3</td></tr>
                  <tr><td>4</td><td>5</td><td>6</td></tr>
                </tbody>
              </table>
              <form action=\"/submit\" method=\"post\">
                <select name=\"x\">
                  <optgroup label=\"g1\">
                    <option>One</option>
                    <option>Two</option>
                  </optgroup>
                  <optgroup label=\"g2\">
                    <option>Three</option>
                    <option>Four</option>
                  </optgroup>
                </select>
                <input type=\"text\" name=\"q\" value=\"swift\">
                <button type=\"submit\">Go</button>
              </form>
            </article>
          </section>
          <footer class=\"site-footer\">
            <p>Footer</p>
          </footer>
        </main>
        """

        return "<!doctype html><html><head><title>giant</title></head><body>" +
            String(repeating: chunk, count: repeatCount) +
            "</body></html>"
    }

    private func buildMegaBenchmarkHTML(repeatCount: Int) -> String {
        let chunk = """
        <div class=\"grid\">
          <div class=\"row\">
            <div class=\"col\">
              <article class=\"card\" data-id=\"99\">
                <h2>Title</h2>
                <p>Text with <a href=\"/x\">link</a> and <span class=\"badge\">badge</span>.</p>
                <ul class=\"meta\">
                  <li><time datetime=\"2024-01-01\">Jan 1</time></li>
                  <li><span class=\"tag\">swift</span></li>
                </ul>
                <table class=\"matrix\">
                  <tr><td>1</td><td>2</td><td>3</td></tr>
                  <tr><td>4</td><td>5</td><td>6</td></tr>
                </table>
                <form action=\"/send\" method=\"post\">
                  <input type=\"text\" name=\"q\" value=\"bench\">
                  <input type=\"checkbox\" name=\"x\" checked>
                  <button type=\"submit\">Go</button>
                </form>
              </article>
            </div>
            <div class=\"col\">
              <article class=\"card\" data-id=\"100\">
                <h2>Title</h2>
                <p>More text with <a href=\"/y\">link</a> and <span class=\"badge\">badge</span>.</p>
                <ul class=\"meta\">
                  <li><time datetime=\"2024-01-02\">Jan 2</time></li>
                  <li><span class=\"tag\">html</span></li>
                </ul>
                <table class=\"matrix\">
                  <tr><td>7</td><td>8</td><td>9</td></tr>
                  <tr><td>10</td><td>11</td><td>12</td></tr>
                </table>
                <form action=\"/send\" method=\"post\">
                  <input type=\"text\" name=\"q\" value=\"bench2\">
                  <input type=\"checkbox\" name=\"y\" checked>
                  <button type=\"submit\">Go</button>
                </form>
              </article>
            </div>
          </div>
        </div>
        """

        return "<!doctype html><html><head><title>mega</title></head><body>" +
            String(repeating: chunk, count: repeatCount) +
            "</body></html>"
    }

    private func buildColossalBenchmarkHTML(repeatCount: Int) -> String {
        let textBlock = String(repeating: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. ", count: 20)
        let chunk = """
        <SECTION class=\"colossal\" data-kind=\"bench\" data-id=\"777\">
          <HEADER>
            <H2>Colossal Title</H2>
            <P>\(textBlock)</P>
          </HEADER>
          <DIV class=\"content\">
            <ARTICLE class=\"entry\" data-entry=\"a\">
              <H3>Entry A</H3>
              <P>\(textBlock)</P>
              <UL class=\"items\">
                <LI>One <EM>alpha</EM></LI>
                <LI>Two <STRONG>beta</STRONG></LI>
                <LI>Three <SPAN class=\"tag\">gamma</SPAN></LI>
              </UL>
              <TABLE class=\"data\">
                <TR><TD>1</TD><TD>2</TD><TD>3</TD></TR>
                <TR><TD>4</TD><TD>5</TD><TD>6</TD></TR>
                <TR><TD>7</TD><TD>8</TD><TD>9</TD></TR>
              </TABLE>
              <FORM action=\"/post\" method=\"post\">
                <INPUT type=\"text\" name=\"q\" value=\"swift\">
                <INPUT type=\"checkbox\" name=\"ok\" checked>
                <BUTTON type=\"submit\">Send</BUTTON>
              </FORM>
            </ARTICLE>
            <ARTICLE class=\"entry\" data-entry=\"b\">
              <H3>Entry B</H3>
              <P>\(textBlock)</P>
              <OL class=\"nums\">
                <LI>First</LI>
                <LI>Second</LI>
                <LI>Third</LI>
              </OL>
              <SELECT name=\"x\">
                <OPTGROUP label=\"g1\">
                  <OPTION>One</OPTION>
                  <OPTION>Two</OPTION>
                </OPTGROUP>
                <OPTGROUP label=\"g2\">
                  <OPTION>Three</OPTION>
                  <OPTION>Four</OPTION>
                </OPTGROUP>
              </SELECT>
            </ARTICLE>
          </DIV>
          <FOOTER>
            <P>\(textBlock)</P>
          </FOOTER>
        </SECTION>
        """

        return "<!doctype html><html><head><title>colossal</title></head><body>" +
            String(repeating: chunk, count: repeatCount) +
            "</body></html>"
    }

    private func buildTitanBenchmarkHTML(repeatCount: Int) -> String {
        let paragraph = String(repeating: "Sed ut perspiciatis unde omnis iste natus error sit voluptatem. ", count: 30)
        let chunk = """
        <div class=\"titan\" data-tier=\"9\">
          <header class=\"titan-header\">
            <h1>Massive Document</h1>
            <nav class=\"links\">
              <a href=\"/a\">A</a><a href=\"/b\">B</a><a href=\"/c\">C</a>
            </nav>
          </header>
          <section class=\"titan-body\">
            <article class=\"titan-article\" data-kind=\"one\">
              <h2>Article One</h2>
              <p>\(paragraph)</p>
              <ul class=\"items\">
                <li>Alpha <span class=\"note\">note</span></li>
                <li>Beta <span class=\"note\">note</span></li>
                <li>Gamma <span class=\"note\">note</span></li>
                <li>Delta <span class=\"note\">note</span></li>
              </ul>
              <table class=\"matrix\">
                <tr><td>1</td><td>2</td><td>3</td><td>4</td></tr>
                <tr><td>5</td><td>6</td><td>7</td><td>8</td></tr>
                <tr><td>9</td><td>10</td><td>11</td><td>12</td></tr>
              </table>
              <form action=\"/search\" method=\"get\">
                <input type=\"text\" name=\"q\" value=\"swift\">
                <input type=\"checkbox\" name=\"opt\" checked>
                <button type=\"submit\">Go</button>
              </form>
            </article>
            <article class=\"titan-article\" data-kind=\"two\">
              <h2>Article Two</h2>
              <p>\(paragraph)</p>
              <ol class=\"numbers\">
                <li>One</li><li>Two</li><li>Three</li><li>Four</li><li>Five</li>
              </ol>
              <select name=\"mode\">
                <option>One</option>
                <option>Two</option>
                <option>Three</option>
              </select>
            </article>
          </section>
          <footer class=\"titan-footer\">
            <p>\(paragraph)</p>
          </footer>
        </div>
        """

        return "<!doctype html><html><head><title>titan</title></head><body>" +
            String(repeating: chunk, count: repeatCount) +
            "</body></html>"
    }

    private func buildOmegaBenchmarkHTML(repeatCount: Int) -> String {
        let paragraph = String(repeating: "At vero eos et accusamus et iusto odio dignissimos ducimus. ", count: 40)
        let chunk = """
        <div class=\"omega\" data-rank=\"10\">
          <header class=\"omega-header\">
            <h1>Omega</h1>
            <p>\(paragraph)</p>
          </header>
          <section class=\"omega-grid\">
            <div class=\"omega-row\">
              <div class=\"omega-col\">
                <article class=\"omega-card\" data-id=\"a\">
                  <h2>Alpha</h2>
                  <p>\(paragraph)</p>
                  <ul class=\"omega-list\">
                    <li>One</li><li>Two</li><li>Three</li><li>Four</li><li>Five</li>
                  </ul>
                  <table class=\"omega-table\">
                    <tr><td>1</td><td>2</td><td>3</td><td>4</td></tr>
                    <tr><td>5</td><td>6</td><td>7</td><td>8</td></tr>
                    <tr><td>9</td><td>10</td><td>11</td><td>12</td></tr>
                  </table>
                  <form action=\"/omega\" method=\"post\">
                    <input type=\"text\" name=\"q\" value=\"omega\">
                    <input type=\"checkbox\" name=\"ok\" checked>
                    <button type=\"submit\">Send</button>
                  </form>
                </article>
              </div>
              <div class=\"omega-col\">
                <article class=\"omega-card\" data-id=\"b\">
                  <h2>Beta</h2>
                  <p>\(paragraph)</p>
                  <ol class=\"omega-list\">
                    <li>A</li><li>B</li><li>C</li><li>D</li><li>E</li>
                  </ol>
                  <select name=\"pick\">
                    <option>One</option>
                    <option>Two</option>
                    <option>Three</option>
                  </select>
                </article>
              </div>
            </div>
          </section>
          <footer class=\"omega-footer\">
            <p>\(paragraph)</p>
          </footer>
        </div>
        """

        return "<!doctype html><html><head><title>omega</title></head><body>" +
            String(repeating: chunk, count: repeatCount) +
            "</body></html>"
    }

    private func exerciseSelectors(_ doc: Document) throws {
        _ = try doc.select("a[href]")
        _ = try doc.select("div.alpha span")
        _ = try doc.select("p.body em")
        _ = try doc.select("table td")
        _ = try doc.select("table th")
        _ = try doc.select("[data-x]")
        _ = try doc.select("[data-section]")
        _ = try doc.select("form input[type=text]")
        _ = try doc.select("form input[type=checkbox]")
        _ = try doc.select("section .list li")
        _ = try doc.select("article .numbers li")
        _ = try doc.select("article .bullets li")
        _ = try doc.select("select option")
        _ = try doc.getElementById("node")
    }

    func testParseBenchmarkProfile() throws {
        guard ProcessInfo.processInfo.environment["SWIFTSOUP_BENCHMARK"] == "1" else {
            return
        }

        let repeatCount = envInt("SWIFTSOUP_BENCHMARK_REPEAT", 1000)
        let largeRepeatCount = envInt("SWIFTSOUP_BENCHMARK_LARGE_REPEAT", 300)
        let hugeRepeatCount = envInt("SWIFTSOUP_BENCHMARK_HUGE_REPEAT", 80)
        let giantRepeatCount = envInt("SWIFTSOUP_BENCHMARK_GIANT_REPEAT", 40)
        let megaRepeatCount = envInt("SWIFTSOUP_BENCHMARK_MEGA_REPEAT", 0)
        let colossalRepeatCount = envInt("SWIFTSOUP_BENCHMARK_COLOSSAL_REPEAT", 2)
        let titanRepeatCount = envInt("SWIFTSOUP_BENCHMARK_TITAN_REPEAT", 1)
        let omegaRepeatCount = envInt("SWIFTSOUP_BENCHMARK_OMEGA_REPEAT", 1)
        let warmupIterations = envInt("SWIFTSOUP_BENCHMARK_WARMUP", 5)
        let iterations = envInt("SWIFTSOUP_BENCHMARK_ITERATIONS", 540)
        let html = buildBenchmarkHTML(repeatCount: repeatCount)
        let htmlLarge = buildLargeBenchmarkHTML(repeatCount: largeRepeatCount)
        let htmlHuge = buildHugeBenchmarkHTML(repeatCount: hugeRepeatCount)
        let htmlGiant = buildGiantBenchmarkHTML(repeatCount: giantRepeatCount)
        let htmlMega = buildMegaBenchmarkHTML(repeatCount: megaRepeatCount)
        let htmlColossal = buildColossalBenchmarkHTML(repeatCount: colossalRepeatCount)
        let htmlTitan = buildTitanBenchmarkHTML(repeatCount: titanRepeatCount)
        let htmlOmega = buildOmegaBenchmarkHTML(repeatCount: omegaRepeatCount)
        let data = Data(html.utf8)
        let bytes = [UInt8](data)
        let largeData = Data(htmlLarge.utf8)
        let largeBytes = [UInt8](largeData)
        var inputs: [(data: Data, bytes: [UInt8])] = [
            (data: data, bytes: bytes),
            (data: largeData, bytes: largeBytes)
        ]
        if hugeRepeatCount > 0 {
            let hugeData = Data(htmlHuge.utf8)
            let hugeBytes = [UInt8](hugeData)
            inputs.append((data: hugeData, bytes: hugeBytes))
        }
        if giantRepeatCount > 0 {
            let giantData = Data(htmlGiant.utf8)
            let giantBytes = [UInt8](giantData)
            inputs.append((data: giantData, bytes: giantBytes))
        }
        if megaRepeatCount > 0 {
            let megaData = Data(htmlMega.utf8)
            let megaBytes = [UInt8](megaData)
            inputs.append((data: megaData, bytes: megaBytes))
        }
        if colossalRepeatCount > 0 {
            let colossalData = Data(htmlColossal.utf8)
            let colossalBytes = [UInt8](colossalData)
            inputs.append((data: colossalData, bytes: colossalBytes))
        }
        if titanRepeatCount > 0 {
            let titanData = Data(htmlTitan.utf8)
            let titanBytes = [UInt8](titanData)
            inputs.append((data: titanData, bytes: titanBytes))
        }
        if omegaRepeatCount > 0 {
            let omegaData = Data(htmlOmega.utf8)
            let omegaBytes = [UInt8](omegaData)
            inputs.append((data: omegaData, bytes: omegaBytes))
        }

        Profiler.reset()
        let useFastParse = ProcessInfo.processInfo.environment["SWIFTSOUP_FAST_PARSE"] == "1"
        let parser: Parser? = {
            if useFastParse {
                let parser = Parser.htmlParser()
                parser.settings(ParseSettings(false, false, false))
                return parser
            }
            return nil
        }()

        for _ in 0..<warmupIterations {
            for input in inputs {
                let doc: Document
                if let parser {
                    doc = try parser.parseInput(input.bytes, "")
                } else {
                    doc = try SwiftSoup.parse(input.data, "")
                }
                try exerciseSelectors(doc)
                _ = try doc.text()
            }
        }

        measure {
            do {
                for _ in 0..<iterations {
                    for input in inputs {
                        let doc: Document
                        if let parser {
                            doc = try parser.parseInput(input.bytes, "")
                        } else {
                            doc = try SwiftSoup.parse(input.data, "")
                        }
                        try exerciseSelectors(doc)
                        _ = try doc.text()
                    }
                }
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }

        let report = Profiler.report(top: 40)
        if !report.isEmpty {
            print(report)
        }
    }
}
