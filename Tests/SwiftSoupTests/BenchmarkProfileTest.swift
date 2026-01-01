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

    private func buildAtlasBenchmarkHTML(repeatCount: Int) -> String {
        let chunk = """
        <section class=\"atlas\" data-map=\"alpha\">
          <header>
            <h1>Atlas</h1>
            <p class=\"meta\"><time datetime=\"2024-01-01\">Jan 1</time> · <a href=\"/atlas\">Atlas</a></p>
          </header>
          <article class=\"content\">
            <p>Dense text with <em>emphasis</em>, <strong>strong</strong>, and <a href=\"/link\">links</a>.</p>
            <p>Second paragraph with <code>code</code> and <span class=\"highlight\">highlights</span>.</p>
            <ul class=\"bullets\">
              <li>One</li><li>Two</li><li>Three</li><li>Four</li><li>Five</li>
            </ul>
            <ol class=\"numbers\">
              <li>Alpha</li><li>Beta</li><li>Gamma</li><li>Delta</li><li>Epsilon</li>
            </ol>
          </article>
          <aside class=\"related\">
            <h2>Related</h2>
            <ul>
              <li><a href=\"/r1\">R1</a></li>
              <li><a href=\"/r2\">R2</a></li>
              <li><a href=\"/r3\">R3</a></li>
            </ul>
          </aside>
          <footer>
            <form action=\"/submit\" method=\"post\">
              <input type=\"text\" name=\"q\" value=\"swift\">
              <input type=\"checkbox\" name=\"x\" checked>
              <button type=\"submit\">Go</button>
            </form>
          </footer>
        </section>
        """

        return "<!doctype html><html><head><title>atlas</title></head><body>" +
            String(repeating: chunk, count: repeatCount) +
            "</body></html>"
    }

    private func buildHyperionBenchmarkHTML(repeatCount: Int) -> String {
        let paragraph = String(repeating: "Hyperion lorem ipsum dolor sit amet, consectetur adipiscing elit. ", count: 60)
        let chunk = """
        <div class=\"hyperion\" data-zone=\"outer\">
          <header class=\"hyperion-header\">
            <h1>Hyperion</h1>
            <p>\(paragraph)</p>
            <nav class=\"hyperion-nav\">
              <a href=\"/one\">One</a><a href=\"/two\">Two</a><a href=\"/three\">Three</a>
            </nav>
          </header>
          <section class=\"hyperion-body\">
            <article class=\"hyperion-article\" data-kind=\"primary\">
              <h2>Primary</h2>
              <p>\(paragraph)</p>
              <ul class=\"hyperion-items\">
                <li>Alpha</li><li>Beta</li><li>Gamma</li><li>Delta</li><li>Epsilon</li>
              </ul>
              <table class=\"hyperion-table\">
                <tr><td>1</td><td>2</td><td>3</td><td>4</td></tr>
                <tr><td>5</td><td>6</td><td>7</td><td>8</td></tr>
                <tr><td>9</td><td>10</td><td>11</td><td>12</td></tr>
              </table>
              <form action=\"/hyperion\" method=\"post\">
                <input type=\"text\" name=\"q\" value=\"swift\">
                <input type=\"checkbox\" name=\"x\" checked>
                <button type=\"submit\">Go</button>
              </form>
            </article>
            <article class=\"hyperion-article\" data-kind=\"secondary\">
              <h2>Secondary</h2>
              <p>\(paragraph)</p>
              <ol class=\"hyperion-numbers\">
                <li>One</li><li>Two</li><li>Three</li><li>Four</li><li>Five</li>
              </ol>
              <select name=\"mode\">
                <option>One</option>
                <option>Two</option>
                <option>Three</option>
              </select>
            </article>
          </section>
          <footer class=\"hyperion-footer\">
            <p>\(paragraph)</p>
          </footer>
        </div>
        """

        return "<!doctype html><html><head><title>hyperion</title></head><body>" +
            String(repeating: chunk, count: repeatCount) +
            "</body></html>"
    }

    private func buildLeviathanBenchmarkHTML(repeatCount: Int) -> String {
        let paragraph = String(repeating: "Leviathan lorem ipsum dolor sit amet, consectetur adipiscing elit. ", count: 90)
        let classBlob = "alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi omicron pi rho sigma tau"
        let chunk = """
        <section class=\"leviathan \(classBlob)\" data-pack=\"mega\" data-tier=\"42\" data-hash=\"abcdef0123456789\">
          <header class=\"leviathan-header \(classBlob)\">
            <h1>Leviathan</h1>
            <p class=\"lede \(classBlob)\">\(paragraph)</p>
            <nav class=\"leviathan-nav\">
              <a href=\"/l1\" rel=\"nofollow noopener\">One</a>
              <a href=\"/l2\" rel=\"nofollow noopener\">Two</a>
              <a href=\"/l3\" rel=\"nofollow noopener\">Three</a>
            </nav>
          </header>
          <article class=\"leviathan-article \(classBlob)\" data-kind=\"primary\">
            <p>\(paragraph)</p>
            <ul class=\"leviathan-list\">
              <li class=\"item a\">Alpha</li><li class=\"item b\">Beta</li><li class=\"item c\">Gamma</li>
              <li class=\"item d\">Delta</li><li class=\"item e\">Epsilon</li><li class=\"item f\">Zeta</li>
            </ul>
            <table class=\"leviathan-table\">
              <tr><td>1</td><td>2</td><td>3</td><td>4</td></tr>
              <tr><td>5</td><td>6</td><td>7</td><td>8</td></tr>
              <tr><td>9</td><td>10</td><td>11</td><td>12</td></tr>
            </table>
            <form action=\"/leviathan\" method=\"post\">
              <input type=\"text\" name=\"q\" value=\"swift soup parse speed\" class=\"\(classBlob)\">
              <input type=\"checkbox\" name=\"x\" checked>
              <button type=\"submit\">Go</button>
            </form>
          </article>
          <footer class=\"leviathan-footer\">
            <p>\(paragraph)</p>
          </footer>
        </section>
        """

        return "<!doctype html><html><head><title>leviathan</title></head><body>" +
            String(repeating: chunk, count: repeatCount) +
            "</body></html>"
    }

    private func buildGargantuaBenchmarkHTML(repeatCount: Int) -> String {
        let paragraph = String(repeating: "Gargantua lorem ipsum dolor sit amet, consectetur adipiscing elit. ", count: 120)
        let classBlob = "alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi omicron pi rho sigma tau"
        let chunk = """
        <section class=\"gargantua \(classBlob)\" data-pack=\"mega\" data-tier=\"42\" data-hash=\"abcdef0123456789\">
          <header class=\"gargantua-header \(classBlob)\">
            <h1>Gargantua</h1>
            <p class=\"lede \(classBlob)\">\(paragraph)</p>
            <nav class=\"gargantua-nav\">
              <a href=\"/g1\" rel=\"nofollow noopener\">One</a>
              <a href=\"/g2\" rel=\"nofollow noopener\">Two</a>
              <a href=\"/g3\" rel=\"nofollow noopener\">Three</a>
            </nav>
          </header>
          <article class=\"gargantua-article \(classBlob)\" data-kind=\"primary\">
            <p>\(paragraph)</p>
            <ul class=\"gargantua-list\">
              <li class=\"item a\">Alpha</li><li class=\"item b\">Beta</li><li class=\"item c\">Gamma</li>
              <li class=\"item d\">Delta</li><li class=\"item e\">Epsilon</li><li class=\"item f\">Zeta</li>
            </ul>
            <table class=\"gargantua-table\">
              <tr><td>1</td><td>2</td><td>3</td><td>4</td></tr>
              <tr><td>5</td><td>6</td><td>7</td><td>8</td></tr>
              <tr><td>9</td><td>10</td><td>11</td><td>12</td></tr>
            </table>
            <form action=\"/gargantua\" method=\"post\">
              <input type=\"text\" name=\"q\" value=\"swift soup parse speed\" class=\"\(classBlob)\">
              <input type=\"checkbox\" name=\"x\" checked>
              <button type=\"submit\">Go</button>
            </form>
          </article>
          <footer class=\"gargantua-footer\">
            <p>\(paragraph)</p>
          </footer>
        </section>
        """

        return "<!doctype html><html><head><title>gargantua</title></head><body>" +
            String(repeating: chunk, count: repeatCount) +
            "</body></html>"
    }

    private func buildBehemothBenchmarkHTML(repeatCount: Int) -> String {
        let paragraph = String(repeating: "Behemoth lorem ipsum dolor sit amet, consectetur adipiscing elit. ", count: 160)
        let classBlob = "alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi omicron pi rho sigma tau"
        let chunk = """
        <div class=\"behemoth \(classBlob)\" data-pack=\"ultra\" data-tier=\"84\" data-hash=\"0123456789abcdef\">
          <header class=\"behemoth-header\">
            <h1>Behemoth</h1>
            <p class=\"lede \(classBlob)\">\(paragraph)</p>
            <nav class=\"behemoth-nav\">
              <a href=\"/b1\" rel=\"nofollow noopener\">One</a>
              <a href=\"/b2\" rel=\"nofollow noopener\">Two</a>
              <a href=\"/b3\" rel=\"nofollow noopener\">Three</a>
              <a href=\"/b4\" rel=\"nofollow noopener\">Four</a>
            </nav>
          </header>
          <section class=\"behemoth-body\">
            <article class=\"behemoth-article\" data-kind=\"primary\">
              <h2>Primary</h2>
              <p>\(paragraph)</p>
              <ul class=\"behemoth-list\">
                <li class=\"item a\">Alpha</li><li class=\"item b\">Beta</li><li class=\"item c\">Gamma</li>
                <li class=\"item d\">Delta</li><li class=\"item e\">Epsilon</li><li class=\"item f\">Zeta</li>
                <li class=\"item g\">Eta</li><li class=\"item h\">Theta</li><li class=\"item i\">Iota</li>
              </ul>
              <table class=\"behemoth-table\">
                <tr><td>1</td><td>2</td><td>3</td><td>4</td><td>5</td></tr>
                <tr><td>6</td><td>7</td><td>8</td><td>9</td><td>10</td></tr>
                <tr><td>11</td><td>12</td><td>13</td><td>14</td><td>15</td></tr>
                <tr><td>16</td><td>17</td><td>18</td><td>19</td><td>20</td></tr>
              </table>
              <form action=\"/behemoth\" method=\"post\">
                <input type=\"text\" name=\"q\" value=\"swift soup parse speed\" class=\"\(classBlob)\">
                <input type=\"checkbox\" name=\"x\" checked>
                <button type=\"submit\">Go</button>
              </form>
            </article>
            <article class=\"behemoth-article\" data-kind=\"secondary\">
              <h2>Secondary</h2>
              <p>\(paragraph)</p>
              <ol class=\"behemoth-numbers\">
                <li>One</li><li>Two</li><li>Three</li><li>Four</li><li>Five</li>
              </ol>
              <select name=\"mode\">
                <option>One</option>
                <option>Two</option>
                <option>Three</option>
                <option>Four</option>
              </select>
            </article>
          </section>
          <footer class=\"behemoth-footer\">
            <p>\(paragraph)</p>
          </footer>
        </div>
        """

        return "<!doctype html><html><head><title>behemoth</title></head><body>" +
            String(repeating: chunk, count: repeatCount) +
            "</body></html>"
    }

    private func buildColossusBenchmarkHTML(repeatCount: Int) -> String {
        let paragraph = String(repeating: "Colossus lorem ipsum dolor sit amet, consectetur adipiscing elit. ", count: 120)
        let chunk = """
        <div class=\"colossus\">
          <section class=\"layer l1\">
            <div class=\"layer l2\">
              <div class=\"layer l3\">
                <div class=\"layer l4\">
                  <div class=\"layer l5\">
                    <p>\(paragraph)</p>
                    <p>\(paragraph)</p>
                    <p>\(paragraph)</p>
                    <div class=\"grid\">
                      <div class=\"cell\">A</div><div class=\"cell\">B</div><div class=\"cell\">C</div>
                      <div class=\"cell\">D</div><div class=\"cell\">E</div><div class=\"cell\">F</div>
                      <div class=\"cell\">G</div><div class=\"cell\">H</div><div class=\"cell\">I</div>
                    </div>
                    <ul class=\"list\">
                      <li>One</li><li>Two</li><li>Three</li><li>Four</li><li>Five</li>
                    </ul>
                  </div>
                </div>
              </div>
            </div>
          </section>
        </div>
        """

        return "<!doctype html><html><head><title>colossus</title></head><body>" +
            String(repeating: chunk, count: repeatCount) +
            "</body></html>"
    }

    private func buildNebulaBenchmarkHTML(repeatCount: Int) -> String {
        let paragraph = String(repeating: "Nebula lorem ipsum dolor sit amet, consectetur adipiscing elit. ", count: 220)
        let classBlob = "alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi omicron pi rho sigma tau"
        let chunk = """
        <section class=\"nebula \(classBlob)\" data-pack=\"ultra\" data-tier=\"128\" data-hash=\"abcdef0123456789\">
          <header class=\"nebula-header\">
            <h1>Nebula</h1>
            <p class=\"lede \(classBlob)\">\(paragraph)</p>
            <nav class=\"nebula-nav\">
              <a href=\"/n1\" rel=\"nofollow noopener\">One</a>
              <a href=\"/n2\" rel=\"nofollow noopener\">Two</a>
              <a href=\"/n3\" rel=\"nofollow noopener\">Three</a>
              <a href=\"/n4\" rel=\"nofollow noopener\">Four</a>
              <a href=\"/n5\" rel=\"nofollow noopener\">Five</a>
            </nav>
          </header>
          <section class=\"nebula-body\">
            <article class=\"nebula-article\" data-kind=\"primary\">
              <h2>Primary</h2>
              <p>\(paragraph)</p>
              <ul class=\"nebula-list\">
                <li class=\"item a\">Alpha</li><li class=\"item b\">Beta</li><li class=\"item c\">Gamma</li>
                <li class=\"item d\">Delta</li><li class=\"item e\">Epsilon</li><li class=\"item f\">Zeta</li>
                <li class=\"item g\">Eta</li><li class=\"item h\">Theta</li><li class=\"item i\">Iota</li>
                <li class=\"item j\">Kappa</li><li class=\"item k\">Lambda</li><li class=\"item l\">Mu</li>
              </ul>
              <table class=\"nebula-table\">
                <tr><td>1</td><td>2</td><td>3</td><td>4</td><td>5</td><td>6</td></tr>
                <tr><td>7</td><td>8</td><td>9</td><td>10</td><td>11</td><td>12</td></tr>
                <tr><td>13</td><td>14</td><td>15</td><td>16</td><td>17</td><td>18</td></tr>
                <tr><td>19</td><td>20</td><td>21</td><td>22</td><td>23</td><td>24</td></tr>
              </table>
              <form action=\"/nebula\" method=\"post\">
                <input type=\"text\" name=\"q\" value=\"swift soup parse speed\" class=\"\(classBlob)\">
                <input type=\"checkbox\" name=\"x\" checked>
                <input type=\"checkbox\" name=\"y\">
                <button type=\"submit\">Go</button>
              </form>
            </article>
            <article class=\"nebula-article\" data-kind=\"secondary\">
              <h2>Secondary</h2>
              <p>\(paragraph)</p>
              <ol class=\"nebula-numbers\">
                <li>One</li><li>Two</li><li>Three</li><li>Four</li><li>Five</li>
                <li>Six</li><li>Seven</li><li>Eight</li><li>Nine</li><li>Ten</li>
              </ol>
              <select name=\"mode\">
                <option>One</option>
                <option>Two</option>
                <option>Three</option>
                <option>Four</option>
                <option>Five</option>
              </select>
            </article>
          </section>
          <footer class=\"nebula-footer\">
            <p>\(paragraph)</p>
          </footer>
        </section>
        """

        return "<!doctype html><html><head><title>nebula</title></head><body>" +
            String(repeating: chunk, count: repeatCount) +
            "</body></html>"
    }

    private func buildScriptHeavyBenchmarkHTML(repeatCount: Int) -> String {
        let jsChunk = """
        const data = "&<tag>\\\\u003Cdiv\\\\u003E";
        const msg = "hello & goodbye";
        function demo(i) { return `<span>${i} &amp; ${i+1}</span>`; }
        // comment with & and < and > and </script> escaped
        const raw = "<\\\\/script>";
        """
        let scriptBody = String(repeating: jsChunk, count: 200)
        let styleChunk = """
        .card { color: #333; }
        .note::before { content: "&<"; }
        """
        let styleBody = String(repeating: styleChunk, count: 200)
        let chunk = """
        <section class=\"script-heavy\" data-kind=\"bench\">
          <h2>Script Heavy</h2>
          <p>Text before script.</p>
          <script>\(scriptBody)</script>
          <style>\(styleBody)</style>
          <p>Text after script.</p>
        </section>
        """
        return "<!doctype html><html><head><title>script-heavy</title></head><body>" +
            String(repeating: chunk, count: repeatCount) +
            "</body></html>"
    }

    private func buildRcdataHeavyBenchmarkHTML(repeatCount: Int) -> String {
        let textChunk = String(repeating: "RCDATA &amp; test &lt;textarea&gt; value; ", count: 400)
        let chunk = """
        <section class=\"rcdata-heavy\">
          <h2>RCDATA Heavy</h2>
          <textarea>\(textChunk)</textarea>
        </section>
        """
        return "<!doctype html><html><head><title>\(textChunk)</title></head><body>" +
            String(repeating: chunk, count: repeatCount) +
            "</body></html>"
    }

    private func buildEntityHeavyBenchmarkHTML(repeatCount: Int) -> String {
        let numericChunk = String(repeating: "&#65;&#66;&#67;&#97;&#98;&#99;&#169;&#174;&#8482; ", count: 200)
        let hexChunk = String(repeating: "&#x41;&#x42;&#x43;&#x61;&#x62;&#x63;&#xA9;&#xAE;&#x2122; ", count: 200)
        let attrChunk = String(repeating: " title=\"&#65;&#66;&#67; &amp; &#x61;&#x62;&#x63;\" ", count: 40)
        let chunk = """
        <section class=\"entity-heavy\" data-kind=\"bench\"\(attrChunk)>
          <h2>Entity Heavy</h2>
          <p>\(numericChunk)</p>
          <p>\(hexChunk)</p>
          <a href=\"/test?x=&#65;&#66;&#67;&y=&#x61;&#x62;&#x63;\">link</a>
        </section>
        """
        return "<!doctype html><html><head><title>entity-heavy</title></head><body>" +
            String(repeating: chunk, count: repeatCount) +
            "</body></html>"
    }

    private func buildEntityStormBenchmarkHTML(repeatCount: Int) -> String {
        let numericChunk = String(repeating: "&#65;&#66;&#67;&#97;&#98;&#99;&#169;&#174;&#8482; ", count: 800)
        let hexChunk = String(repeating: "&#x41;&#x42;&#x43;&#x61;&#x62;&#x63;&#xA9;&#xAE;&#x2122; ", count: 800)
        let attrChunk = String(repeating: " data-n=\"&#65;&#66;&#67;&#97;&#98;&#99;\" data-h=\"&#x41;&#x42;&#x43;&#x61;&#x62;&#x63;\" ", count: 80)
        let chunk = """
        <div class=\"entity-storm\"\(attrChunk)>
          \(numericChunk)
          \(hexChunk)
        </div>
        """

        return "<!doctype html><html><head><title>entity-storm</title></head><body>" +
            String(repeating: chunk, count: repeatCount) +
            "</body></html>"
    }

    private func buildEntityNamedBenchmarkHTML(repeatCount: Int) -> String {
        let namedChunk = String(repeating: "&amp; &lt; &gt; &quot; &apos; &nbsp; &copy; &reg; &trade; ", count: 600)
        let attrChunk = String(repeating: " data-x=\"&amp;&amp;&lt;&gt;&quot;&apos;&nbsp;&copy;&reg;&trade;\" ", count: 60)
        let chunk = """
        <section class=\"entity-named\" data-kind=\"bench\"\(attrChunk)>
          <h2>Entity Named</h2>
          <p>\(namedChunk)</p>
          <p>\(namedChunk)</p>
          <a href=\"/test?q=&amp;value=&lt;tag&gt;\">link</a>
        </section>
        """
        return "<!doctype html><html><head><title>entity-named</title></head><body>" +
            String(repeating: chunk, count: repeatCount) +
            "</body></html>"
    }

    private func buildEntityNamedStormBenchmarkHTML(repeatCount: Int) -> String {
        let namedChunk = String(repeating: "&amp; &lt; &gt; &quot; &apos; &nbsp; &copy; &reg; &trade; &hellip; &mdash; &ndash; &euro; &pound; &yen; &cent; ", count: 1200)
        let attrChunk = String(repeating: " data-x=\"&amp;&lt;&gt;&quot;&apos;&nbsp;&copy;&reg;&trade;&hellip;&mdash;&ndash;&euro;&pound;&yen;&cent;\" ", count: 120)
        let chunk = """
        <div class=\"entity-named-storm\"\(attrChunk)>
          \(namedChunk)
        </div>
        """

        return "<!doctype html><html><head><title>entity-named-storm</title></head><body>" +
            String(repeating: chunk, count: repeatCount) +
            "</body></html>"
    }

    private func buildEntityNamedExtendedBenchmarkHTML(repeatCount: Int) -> String {
        let extendedChunk = String(repeating: "&hellip; &mdash; &ndash; &lsquo; &rsquo; &ldquo; &rdquo; &euro; &pound; &yen; &cent; &frac12; &frac14; &frac34; &times; &divide; &micro; &para; &sect; &middot; &laquo; &raquo; ", count: 400)
        let attrChunk = String(repeating: " data-e=\"&hellip;&mdash;&ndash;&ldquo;&rdquo;&euro;&pound;&yen;&cent;\" ", count: 50)
        let chunk = """
        <section class=\"entity-named-extended\" data-kind=\"bench\"\(attrChunk)>
          <h2>Entity Named Extended</h2>
          <p>\(extendedChunk)</p>
          <p>\(extendedChunk)</p>
          <a href=\"/test?q=&hellip;&mdash;&ndash;\">link</a>
        </section>
        """
        return "<!doctype html><html><head><title>entity-named-extended</title></head><body>" +
            String(repeating: chunk, count: repeatCount) +
            "</body></html>"
    }

    private func buildAmpersandHeavyBenchmarkHTML(repeatCount: Int) -> String {
        let textChunk = String(repeating: "a & b & c & token=123 & value=abc & next=def ", count: 400)
        let attrChunk = String(repeating: " data-q=\"a&b&c&token=123&value=abc\" ", count: 40)
        let chunk = """
        <section class=\"ampersand-heavy\" data-kind=\"bench\"\(attrChunk)>
          <h2>Ampersand Heavy</h2>
          <p>\(textChunk)</p>
          <p>\(textChunk)</p>
          <a href=\"/test?q=a&b&c&token=123&value=abc\">link</a>
        </section>
        """
        return "<!doctype html><html><head><title>ampersand-heavy</title></head><body>" +
            String(repeating: chunk, count: repeatCount) +
            "</body></html>"
    }

    private func buildListHeavyBenchmarkHTML(repeatCount: Int) -> String {
        let liChunk = String(repeating: "<li class=\"item\">Item <span>inner</span></li>", count: 200)
        let nested = """
        <ul class=\"list\">
          \(liChunk)
          <li class=\"item nested\">
            <ul class=\"sub\">
              \(liChunk)
            </ul>
          </li>
          \(liChunk)
        </ul>
        """
        let chunk = """
        <section class=\"list-heavy\">
          <h2>List Heavy</h2>
          \(nested)
        </section>
        """
        return "<!doctype html><html><head><title>list-heavy</title></head><body>" +
            String(repeating: chunk, count: repeatCount) +
            "</body></html>"
    }

    private func buildAttributeHeavyBenchmarkHTML(repeatCount: Int) -> String {
        let attrValue = String(repeating: "data=1234567890&token=abcdef&v=1.0.0;", count: 40)
        let attrs = (0..<12).map { i in
            "data-k\(i)=\"\(attrValue)\""
        }.joined(separator: " ")
        let chunk = """
        <section class=\"attr-heavy\" data-kind=\"bench\" \(attrs)>
          <h2>Attribute Heavy</h2>
          <div class=\"card\" \(attrs)>
            <a href=\"/path?\(attrValue)\" \(attrs)>Link</a>
            <img src=\"/img?\(attrValue)\" alt=\"\(attrValue)\" \(attrs)>
          </div>
        </section>
        """
        return "<!doctype html><html><head><title>attribute-heavy</title></head><body>" +
            String(repeating: chunk, count: repeatCount) +
            "</body></html>"
    }

    private func buildAttributeMegaBenchmarkHTML(repeatCount: Int) -> String {
        let attrValue = String(repeating: "name=swift-soup&token=abcdef0123456789&v=1.0.0&mode=fast;", count: 80)
        let attrs = (0..<24).map { i in
            "data-mega-\(i)=\"\(attrValue)\""
        }.joined(separator: " ")
        let chunk = """
        <section class=\"attr-mega\" data-kind=\"bench\" \(attrs)>
          <div class=\"wrap\" \(attrs)>
            <a href=\"/path?\(attrValue)\" \(attrs)>Link</a>
            <img src=\"/img?\(attrValue)\" alt=\"\(attrValue)\" \(attrs)>
            <input type=\"text\" name=\"q\" value=\"\(attrValue)\" \(attrs)>
          </div>
        </section>
        """
        return "<!doctype html><html><head><title>attribute-mega</title></head><body>" +
            String(repeating: chunk, count: repeatCount) +
            "</body></html>"
    }

    private func buildAttributeStormBenchmarkHTML(repeatCount: Int) -> String {
        let attrValue = String(repeating: "a=1&b=2&c=3&d=4&token=abcdef;", count: 20)
        let attrs = (0..<32).map { i in
            "data-s\(i)=\"\(attrValue)\""
        }.joined(separator: " ")
        let chunk = """
        <section class=\"attr-storm\" data-kind=\"bench\" \(attrs)>
          <div class=\"wrap\" \(attrs)>
            <a href=\"/path?\(attrValue)\" \(attrs)>Link</a>
            <img src=\"/img?\(attrValue)\" alt=\"\(attrValue)\" \(attrs)>
            <input type=\"text\" name=\"q\" value=\"\(attrValue)\" \(attrs)>
            <span \(attrs)>\(attrValue)</span>
          </div>
        </section>
        """
        return "<!doctype html><html><head><title>attribute-storm</title></head><body>" +
            String(repeating: chunk, count: repeatCount) +
            "</body></html>"
    }

    private func buildQueryStringHeavyBenchmarkHTML(repeatCount: Int) -> String {
        let qsValue = String(repeating: "a=1&b=2&c=3&d=4&token=abcdef&mode=fast", count: 40)
        let attrs = (0..<16).map { i in
            "data-q\(i)=\"\(qsValue)\""
        }.joined(separator: " ")
        let chunk = """
        <section class=\"qs-heavy\" data-kind=\"bench\" \(attrs)>
          <a href=\"/path?\(qsValue)\" \(attrs)>Link</a>
          <img src=\"/img?\(qsValue)\" alt=\"\(qsValue)\" \(attrs)>
          <span \(attrs)>\(qsValue)</span>
        </section>
        """
        return "<!doctype html><html><head><title>qs-heavy</title></head><body>" +
            String(repeating: chunk, count: repeatCount) +
            "</body></html>"
    }

    private func buildDenseTextBenchmarkHTML(repeatCount: Int) -> String {
        let sentence = "Dense text with single spaces and no line breaks for normalization. "
        let paragraph = String(repeating: sentence, count: 400)
        let chunk = """
        <section class=\"dense-text\">
          <h2>Dense Text</h2>
          <p>\(paragraph)</p>
          <p>\(paragraph)</p>
          <p>\(paragraph)</p>
        </section>
        """
        return "<!doctype html><html><head><title>dense-text</title></head><body>" +
            String(repeating: chunk, count: repeatCount) +
            "</body></html>"
    }

    private func buildTableHeavyBenchmarkHTML(repeatCount: Int) -> String {
        let row = """
        <tr>
          <td>Alpha</td><td>Beta</td><td>Gamma</td><td>Delta</td><td>Epsilon</td>
        </tr>
        """
        let rows = String(repeating: row, count: 200)
        let table = """
        <table class=\"table-heavy\">
          <thead>\(row)</thead>
          <tbody>
            \(rows)
          </tbody>
        </table>
        """
        let chunk = """
        <section class=\"table-heavy\">
          <h2>Table Heavy</h2>
          \(table)
        </section>
        """
        return "<!doctype html><html><head><title>table-heavy</title></head><body>" +
            String(repeating: chunk, count: repeatCount) +
            "</body></html>"
    }

    private func buildDataHeavyBenchmarkHTML(repeatCount: Int) -> String {
        let sentence = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. "
        let paragraph = String(repeating: sentence, count: 800)
        let chunk = """
        <section class=\"data-heavy\">
          <h2>Data Heavy</h2>
          <p>\(paragraph)</p>
          <p>\(paragraph)</p>
          <p>\(paragraph)</p>
        </section>
        """
        return "<!doctype html><html><head><title>data-heavy</title></head><body>" +
            String(repeating: chunk, count: repeatCount) +
            "</body></html>"
    }

    private func buildPlainTextBenchmarkHTML(repeatCount: Int) -> String {
        let paragraph = String(repeating: "Plain text payload with minimal markup. ", count: 2000)
        let chunk = """
        <section class=\"plain-text\">
          <p>\(paragraph)</p>
        </section>
        """
        return "<!doctype html><html><head><title>plain-text</title></head><body>" +
            String(repeating: chunk, count: repeatCount) +
            "</body></html>"
    }

    private func buildDataStormBenchmarkHTML(repeatCount: Int) -> String {
        let sentence = "Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium. "
        let paragraph = String(repeating: sentence, count: 2000)
        let chunk = """
        <div class=\"data-storm\">
          <p>\(paragraph)</p>
          <p>\(paragraph)</p>
        </div>
        """

        return "<!doctype html><html><head><title>data-storm</title></head><body>" +
            String(repeating: chunk, count: repeatCount) +
            "</body></html>"
    }

    private func buildTagHeavyBenchmarkHTML(repeatCount: Int) -> String {
        let chunk = """
        <div>
          <p><span><b>Bold</b> and <i>italic</i> text.</span></p>
          <ul><li>One</li><li>Two</li><li>Three</li><li>Four</li></ul>
          <table><tr><td>A</td><td>B</td></tr><tr><td>C</td><td>D</td></tr></table>
          <form><input type=\"text\" value=\"x\"><button>Go</button></form>
        </div>
        """
        return "<!doctype html><html><head><title>tag-heavy</title></head><body>" +
            String(repeating: chunk, count: repeatCount) +
            "</body></html>"
    }

    private func buildCustomTagBenchmarkHTML(repeatCount: Int) -> String {
        let chunk = """
        <x-card data-id=\"1\">
          <x-row>
            <x-cell><y-label>Label</y-label><y-value>Value</y-value></x-cell>
            <x-cell><y-label>Label</y-label><y-value>Value</y-value></x-cell>
          </x-row>
          <x-row>
            <x-cell><y-label>Label</y-label><y-value>Value</y-value></x-cell>
            <x-cell><y-label>Label</y-label><y-value>Value</y-value></x-cell>
          </x-row>
        </x-card>
        """
        return "<!doctype html><html><head><title>custom-tags</title></head><body>" +
            String(repeating: chunk, count: repeatCount) +
            "</body></html>"
    }

    private func buildDeepNestingBenchmarkHTML(repeatCount: Int, depth: Int, withAttributes: Bool) -> String {
        guard repeatCount > 0, depth > 0 else {
            return ""
        }
        let openTag = withAttributes ? "<div class=\"nest\">" : "<div>"
        let open = String(repeating: openTag, count: depth)
        let close = String(repeating: "</div>", count: depth)
        let chunk = open + "<span>leaf</span>" + close
        return "<!doctype html><html><head><title>deep</title></head><body>" +
            String(repeating: chunk, count: repeatCount) +
            "</body></html>"
    }

    private func buildWhitespaceHeavyBenchmarkHTML(repeatCount: Int) -> String {
        let spacer = " \n\t\r\u{000C} "
        let chunk = """
        <div>\(spacer)<span>\(spacer)Text\(spacer)</span>\(spacer)</div>
        <p>\(spacer)Paragraph\(spacer)<em>\(spacer)em\(spacer)</em>\(spacer)</p>
        """
        return "<!doctype html><html><head><title>ws</title></head><body>" +
            String(repeating: chunk, count: repeatCount) +
            "</body></html>"
    }

    private func buildManabiReaderBenchmarkHTML(repeatCount: Int) -> String {
        let paragraph = "This is a paragraph with ruby <ruby>漢字<rt>かんじ</rt></ruby> and <em>emphasis</em>."
        let segment = """
        <span class=\"manabi-segment\" data-jmdict-entry-ids=\"[1,2,3]\" data-jmnedict-entry-ids=\"[4,5]\">
          \(paragraph)
        </span>
        """
        let section = """
        <div class=\"manabi-tracking-section\">
          <p>\(paragraph)</p>
          <p>\(segment)</p>
          <p style=\"display: none\">Hidden text</p>
          <p style=\"visibility: hidden\">Hidden text</p>
          <p type=\"hidden\">Hidden text</p>
          <img src=\"/img.png\" alt=\"image\">
        </div>
        """
        let body = """
        <div id=\"reader-title\">Reader Title</div>
        <div id=\"reader-byline\">Byline <span>Author</span></div>
        <div id=\"reader-content\">
          \(String(repeating: section, count: 3))
        </div>
        <script>var x = 1 &amp;&amp; 2;</script>
        <style>.hidden { display: none; }</style>
        """
        return "<!doctype html><html><head><title>manabi-reader</title></head><body>" +
            String(repeating: body, count: repeatCount) +
            "</body></html>"
    }

    private func exerciseSelectors(_ doc: Document) throws {
        let selectorFilter = ProcessInfo.processInfo.environment["SWIFTSOUP_BENCHMARK_SELECTOR_FILTER"]
        func shouldRun(_ label: String) -> Bool {
            guard let selectorFilter, !selectorFilter.isEmpty else { return true }
            return label.contains(selectorFilter)
        }

        if shouldRun("a[href]") { _ = try doc.select("a[href]") }
        if shouldRun("*") { _ = try doc.select("*") }
        if shouldRun("body *") { _ = try doc.select("body *") }
        if shouldRun("div.alpha span") { _ = try doc.select("div.alpha span") }
        if shouldRun("div.alpha.beta") { _ = try doc.select("div.alpha.beta") }
        if shouldRun(".alpha.beta") { _ = try doc.select(".alpha.beta") }
        if shouldRun("p.body em") { _ = try doc.select("p.body em") }
        if shouldRun("table td") { _ = try doc.select("table td") }
        if shouldRun("table th") { _ = try doc.select("table th") }
        if shouldRun("[data-x]") { _ = try doc.select("[data-x]") }
        if shouldRun("[data-section]") { _ = try doc.select("[data-section]") }
        if shouldRun("form input[type=text]") { _ = try doc.select("form input[type=text]") }
        if shouldRun("form input[type=checkbox]") { _ = try doc.select("form input[type=checkbox]") }
        if shouldRun("section .list li") { _ = try doc.select("section .list li") }
        if shouldRun("article .numbers li") { _ = try doc.select("article .numbers li") }
        if shouldRun("article .bullets li") { _ = try doc.select("article .bullets li") }
        if shouldRun("select option") { _ = try doc.select("select option") }
        if shouldRun("getElementById(node)") { _ = try doc.getElementById("node") }
        if shouldRun("a[href][rel]") { _ = try doc.select("a[href][rel]") }
        if shouldRun("section.hero[data-section=top]") { _ = try doc.select("section.hero[data-section=top]") }
        if shouldRun("div.alpha:contains(Paragraph)") { _ = try doc.select("div.alpha:contains(Paragraph)") }
        if shouldRun("p.body:contains(Paragraph)") { _ = try doc.select("p.body:contains(Paragraph)") }
        if shouldRun("section.hero:contains(Heading)") { _ = try doc.select("section.hero:contains(Heading)") }
        if shouldRun("section:has(form input[type=checkbox])") { _ = try doc.select("section:has(form input[type=checkbox])") }
        if shouldRun("article:has(.numbers li)") { _ = try doc.select("article:has(.numbers li)") }
        if shouldRun("div:has(a)") { _ = try doc.select("div:has(a)") }
        if shouldRun("section:has(h1)") { _ = try doc.select("section:has(h1)") }
        if shouldRun("div:has([data-x])") { _ = try doc.select("div:has([data-x])") }
        if shouldRun("article:has(.numbers)") { _ = try doc.select("article:has(.numbers)") }
    }

    private func exerciseClassSelectors(_ doc: Document) throws {
        _ = try doc.select(".alpha")
        _ = try doc.select(".beta")
        _ = try doc.select(".gamma")
        _ = try doc.select(".alpha.beta")
        _ = try doc.select("div.alpha")
        _ = try doc.select("section.alpha")
        _ = try doc.select("article.alpha.beta")
        _ = try doc.select(".list .item")
        _ = try doc.select(".list .item.active")
        _ = try doc.select(".titan-article")
        _ = try doc.select(".titan-article .numbers li")
        _ = try doc.select(".atlas .headline")
        _ = try doc.select(".atlas .summary")
        _ = try doc.select(".atlas .meta a")
    }

    private func exerciseAttributeSelectors(_ doc: Document) throws {
        _ = try doc.select("[href]")
        _ = try doc.select("[src]")
        _ = try doc.select("[data-x]")
        _ = try doc.select("[data-section]")
        _ = try doc.select("[data-kind]")
        _ = try doc.select("[data-tier]")
        _ = try doc.select("[role]")
        _ = try doc.select("[type]")
        _ = try doc.select("a[href]")
        _ = try doc.select("img[src]")
        _ = try doc.select("input[type=text]")
        _ = try doc.select("input[type=checkbox]")
        _ = try doc.select("article[data-kind=one]")
        _ = try doc.select("article[data-kind=two]")
        _ = try doc.select("section[data-map=alpha]")
        _ = try doc.select("div[data-tier=9]")
        _ = try doc.select("[href^=https]")
        _ = try doc.select("[href*=example]")
        _ = try doc.select("[href$=com]")
        _ = try doc.select("[data-section^=to]")
        _ = try doc.select("[data-section$=op]")
        _ = try doc.select("a[href][rel]")
        _ = try doc.select("section.hero[data-section=top]")
        _ = try doc.select("article.titan-article[data-kind=one]")
        _ = try doc.select("div#node.alpha[data-x=123]")
        _ = try doc.select(".omega-card[data-id=a]")
    }

    private final class ManabiVisibleTextExtractor: NodeVisitor {
        let accum: StringBuilder

        init(_ accum: StringBuilder) {
            self.accum = accum
        }

        func head(_ node: Node, _ depth: Int) {
            guard let textNode = node as? TextNode,
                  let parent = textNode.parent() as? Element else { return }
            do {
                let tagName = parent.tagName().lowercased()
                if tagName == "script" || tagName == "style" { return }
                if try parent.hasAttr("type") && parent.attr("type").lowercased() == "hidden" {
                    return
                }
                let style = try parent.attr("style").lowercased()
                if style.contains("display: none") || style.contains("visibility: hidden") {
                    return
                }
                accum.append(textNode.text().trimmingCharacters(in: .whitespacesAndNewlines) + " ")
            } catch {
                return
            }
        }

        func tail(_ node: Node, _ depth: Int) {}
    }

    private func exerciseManabiReaderOps(_ doc: Document) throws {
        if let head = doc.head() {
            try head.append("<style type='text/css' id='manabi-readability-styles'>.x{}</style>")
        }
        guard let body = doc.body() else { return }
        try body.addClass("readability-mode")

        if let title = try body.getElementById("reader-title") {
            let titleText = try title.text(trimAndNormaliseWhitespace: false)
            if !titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try title.wrap("<div></div>")
                if let wrapper = title.parent() {
                    try wrapper.addClass("manabi-tracking-section")
                    try wrapper.addClass("manabi-tracking-section-title")
                    try wrapper.attr("data-manabi-tracking-section-read", "true")
                    try wrapper.attr("data-manabi-tracking-section-kind", "title")
                }
            }
        }

        if let content = try body.getElementById("reader-content") {
            let segments = try content.getElementsByTag("manabi-segment")
            for segment in segments {
                _ = segment.dataset()["jmdict-entry-ids"]
                _ = segment.dataset()["jmnedict-entry-ids"]
            }

            let insertAfter = try content.getElementsByClass("manabi-tracking-section").last() ?? content
            let trackingFooter = try SwiftSoup.parseBodyFragment(
                "<div id='manabi-tracking-footer'></div>"
            ).getElementsByTag("div").first()!
            try insertAfter.after(node: trackingFooter)
            try trackingFooter.append("<button id='manabi-finished-reading-button'>Finish Reading</button>")
        }

        let accum = StringBuilder()
        let extractor = ManabiVisibleTextExtractor(accum)
        try body.traverse(extractor)
        _ = accum.toString()

        _ = try doc.outerHtmlUTF8()
    }

    func testParseBenchmarkProfile() throws {
        guard ProcessInfo.processInfo.environment["SWIFTSOUP_BENCHMARK"] == "1" else {
            return
        }

        let benchmarkFilter = ProcessInfo.processInfo.environment["SWIFTSOUP_BENCHMARK_SET"]?
            .lowercased()
            .split(whereSeparator: { $0 == "," || $0 == " " || $0 == ";" })
            .map(String.init) ?? []
        let benchmarkFilterSet = Set(benchmarkFilter)
        @inline(__always)
        func includeBenchmark(_ name: String) -> Bool {
            return benchmarkFilterSet.isEmpty || benchmarkFilterSet.contains(name)
        }

        let scale = max(1, envInt("SWIFTSOUP_BENCHMARK_SCALE", 1))
        func scaled(_ value: Int) -> Int {
            return value == 0 ? 0 : value * scale
        }

        let repeatCount = scaled(envInt("SWIFTSOUP_BENCHMARK_REPEAT", 1000))
        let largeRepeatCount = scaled(envInt("SWIFTSOUP_BENCHMARK_LARGE_REPEAT", 300))
        let hugeRepeatCount = scaled(envInt("SWIFTSOUP_BENCHMARK_HUGE_REPEAT", 80))
        let giantRepeatCount = scaled(envInt("SWIFTSOUP_BENCHMARK_GIANT_REPEAT", 40))
        let megaRepeatCount = scaled(envInt("SWIFTSOUP_BENCHMARK_MEGA_REPEAT", 2))
        let colossalRepeatCount = scaled(envInt("SWIFTSOUP_BENCHMARK_COLOSSAL_REPEAT", 4))
        let titanRepeatCount = scaled(envInt("SWIFTSOUP_BENCHMARK_TITAN_REPEAT", 2))
        let omegaRepeatCount = scaled(envInt("SWIFTSOUP_BENCHMARK_OMEGA_REPEAT", 2))
        let atlasRepeatCount = scaled(envInt("SWIFTSOUP_BENCHMARK_ATLAS_REPEAT", 2))
        let hyperionRepeatCount = scaled(envInt("SWIFTSOUP_BENCHMARK_HYPERION_REPEAT", 1))
        let gargantuaRepeatCount = scaled(envInt("SWIFTSOUP_BENCHMARK_GARGANTUA_REPEAT", 1))
        let leviathanRepeatCount = scaled(envInt("SWIFTSOUP_BENCHMARK_LEVIATHAN_REPEAT", 1))
        let behemothRepeatCount = scaled(envInt("SWIFTSOUP_BENCHMARK_BEHEMOTH_REPEAT", 1))
        let colossusRepeatCount = scaled(envInt("SWIFTSOUP_BENCHMARK_COLOSSUS_REPEAT", 2))
        let nebulaRepeatCount = scaled(envInt("SWIFTSOUP_BENCHMARK_NEBULA_REPEAT", 2))
        let scriptHeavyRepeatCount = scaled(envInt("SWIFTSOUP_BENCHMARK_SCRIPT_HEAVY_REPEAT", 2))
        let rcdataHeavyRepeatCount = scaled(envInt("SWIFTSOUP_BENCHMARK_RCDATA_HEAVY_REPEAT", 1))
        let entityHeavyRepeatCount = scaled(envInt("SWIFTSOUP_BENCHMARK_ENTITY_HEAVY_REPEAT", 2))
        let entityNamedRepeatCount = scaled(envInt("SWIFTSOUP_BENCHMARK_ENTITY_NAMED_REPEAT", 1))
        let entityNamedExtendedRepeatCount = scaled(envInt("SWIFTSOUP_BENCHMARK_ENTITY_NAMED_EXTENDED_REPEAT", 1))
        let entityNamedStormRepeatCount = scaled(envInt("SWIFTSOUP_BENCHMARK_ENTITY_NAMED_STORM_REPEAT", 1))
        let entityStormRepeatCount = scaled(envInt("SWIFTSOUP_BENCHMARK_ENTITY_STORM_REPEAT", 1))
        let ampersandHeavyRepeatCount = scaled(envInt("SWIFTSOUP_BENCHMARK_AMPERSAND_HEAVY_REPEAT", 1))
        let listHeavyRepeatCount = scaled(envInt("SWIFTSOUP_BENCHMARK_LIST_HEAVY_REPEAT", 2))
        let attributeHeavyRepeatCount = scaled(envInt("SWIFTSOUP_BENCHMARK_ATTRIBUTE_HEAVY_REPEAT", 2))
        let attributeMegaRepeatCount = scaled(envInt("SWIFTSOUP_BENCHMARK_ATTRIBUTE_MEGA_REPEAT", 1))
        let attributeStormRepeatCount = scaled(envInt("SWIFTSOUP_BENCHMARK_ATTRIBUTE_STORM_REPEAT", 1))
        let queryStringHeavyRepeatCount = scaled(envInt("SWIFTSOUP_BENCHMARK_QUERYSTRING_REPEAT", 1))
        let denseTextRepeatCount = scaled(envInt("SWIFTSOUP_BENCHMARK_DENSE_TEXT_REPEAT", 3))
        let tableHeavyRepeatCount = scaled(envInt("SWIFTSOUP_BENCHMARK_TABLE_HEAVY_REPEAT", 1))
        let dataHeavyRepeatCount = scaled(envInt("SWIFTSOUP_BENCHMARK_DATA_HEAVY_REPEAT", 3))
        let plainTextRepeatCount = scaled(envInt("SWIFTSOUP_BENCHMARK_PLAINTEXT_REPEAT", 1))
        let tagHeavyRepeatCount = scaled(envInt("SWIFTSOUP_BENCHMARK_TAG_HEAVY_REPEAT", 2))
        let dataStormRepeatCount = scaled(envInt("SWIFTSOUP_BENCHMARK_DATA_STORM_REPEAT", 1))
        let customTagRepeatCount = scaled(envInt("SWIFTSOUP_BENCHMARK_CUSTOM_TAG_REPEAT", 2))
        let deepNestRepeatCount = scaled(envInt("SWIFTSOUP_BENCHMARK_DEEP_NEST_REPEAT", 1))
        let deepNestDepth = max(1, envInt("SWIFTSOUP_BENCHMARK_DEEP_NEST_DEPTH", 200))
        let deepNestWithAttrs = envInt("SWIFTSOUP_BENCHMARK_DEEP_NEST_ATTRS", 1) != 0
        let whitespaceHeavyRepeatCount = scaled(envInt("SWIFTSOUP_BENCHMARK_WHITESPACE_HEAVY_REPEAT", 2))
        let manabiReaderRepeatCount = scaled(envInt("SWIFTSOUP_BENCHMARK_MANABI_REPEAT", 1))
        let warmupIterations = envInt("SWIFTSOUP_BENCHMARK_WARMUP", 5)
        let iterationsMultiplier = envInt("SWIFTSOUP_BENCHMARK_ITERATIONS_MULTIPLIER", 3)
        let iterations = envInt("SWIFTSOUP_BENCHMARK_ITERATIONS", 4860) * max(1, iterationsMultiplier)
        let textNodeTextEnabled = envInt("SWIFTSOUP_BENCHMARK_TEXTNODE_TEXT", 1) != 0
        let selectorRepeat = envInt("SWIFTSOUP_BENCHMARK_SELECTOR_REPEAT", 3)
        let selectorStressRepeat = envInt("SWIFTSOUP_BENCHMARK_SELECTOR_STRESS_REPEAT", 5)
        let attributeSelectorStressRepeat = envInt("SWIFTSOUP_BENCHMARK_ATTRIBUTE_SELECTOR_STRESS_REPEAT", 4)
        var inputs: [(data: Data, bytes: [UInt8])] = []
        var inputStrings: [String] = []
        if includeBenchmark("base") {
            let html = buildBenchmarkHTML(repeatCount: repeatCount)
            let data = Data(html.utf8)
            inputs.append((data: data, bytes: [UInt8](data)))
            inputStrings.append(html)
        }
        if includeBenchmark("large") {
            let htmlLarge = buildLargeBenchmarkHTML(repeatCount: largeRepeatCount)
            let largeData = Data(htmlLarge.utf8)
            inputs.append((data: largeData, bytes: [UInt8](largeData)))
            inputStrings.append(htmlLarge)
        }
        if includeBenchmark("huge"), hugeRepeatCount > 0 {
            let htmlHuge = buildHugeBenchmarkHTML(repeatCount: hugeRepeatCount)
            let hugeData = Data(htmlHuge.utf8)
            inputs.append((data: hugeData, bytes: [UInt8](hugeData)))
            inputStrings.append(htmlHuge)
        }
        if includeBenchmark("giant"), giantRepeatCount > 0 {
            let htmlGiant = buildGiantBenchmarkHTML(repeatCount: giantRepeatCount)
            let giantData = Data(htmlGiant.utf8)
            inputs.append((data: giantData, bytes: [UInt8](giantData)))
            inputStrings.append(htmlGiant)
        }
        if includeBenchmark("mega"), megaRepeatCount > 0 {
            let htmlMega = buildMegaBenchmarkHTML(repeatCount: megaRepeatCount)
            let megaData = Data(htmlMega.utf8)
            inputs.append((data: megaData, bytes: [UInt8](megaData)))
            inputStrings.append(htmlMega)
        }
        if includeBenchmark("colossal"), colossalRepeatCount > 0 {
            let htmlColossal = buildColossalBenchmarkHTML(repeatCount: colossalRepeatCount)
            let colossalData = Data(htmlColossal.utf8)
            inputs.append((data: colossalData, bytes: [UInt8](colossalData)))
            inputStrings.append(htmlColossal)
        }
        if includeBenchmark("titan"), titanRepeatCount > 0 {
            let htmlTitan = buildTitanBenchmarkHTML(repeatCount: titanRepeatCount)
            let titanData = Data(htmlTitan.utf8)
            inputs.append((data: titanData, bytes: [UInt8](titanData)))
            inputStrings.append(htmlTitan)
        }
        if includeBenchmark("omega"), omegaRepeatCount > 0 {
            let htmlOmega = buildOmegaBenchmarkHTML(repeatCount: omegaRepeatCount)
            let omegaData = Data(htmlOmega.utf8)
            inputs.append((data: omegaData, bytes: [UInt8](omegaData)))
            inputStrings.append(htmlOmega)
        }
        if includeBenchmark("atlas"), atlasRepeatCount > 0 {
            let htmlAtlas = buildAtlasBenchmarkHTML(repeatCount: atlasRepeatCount)
            let atlasData = Data(htmlAtlas.utf8)
            let atlasBytes = [UInt8](atlasData)
            inputs.append((data: atlasData, bytes: atlasBytes))
            inputStrings.append(htmlAtlas)
        }
        if includeBenchmark("hyperion"), hyperionRepeatCount > 0 {
            let htmlHyperion = buildHyperionBenchmarkHTML(repeatCount: hyperionRepeatCount)
            let hyperionData = Data(htmlHyperion.utf8)
            let hyperionBytes = [UInt8](hyperionData)
            inputs.append((data: hyperionData, bytes: hyperionBytes))
            inputStrings.append(htmlHyperion)
        }
        if includeBenchmark("gargantua"), gargantuaRepeatCount > 0 {
            let htmlGargantua = buildGargantuaBenchmarkHTML(repeatCount: gargantuaRepeatCount)
            let gargantuaData = Data(htmlGargantua.utf8)
            let gargantuaBytes = [UInt8](gargantuaData)
            inputs.append((data: gargantuaData, bytes: gargantuaBytes))
            inputStrings.append(htmlGargantua)
        }
        if includeBenchmark("leviathan"), leviathanRepeatCount > 0 {
            let htmlLeviathan = buildLeviathanBenchmarkHTML(repeatCount: leviathanRepeatCount)
            let leviathanData = Data(htmlLeviathan.utf8)
            let leviathanBytes = [UInt8](leviathanData)
            inputs.append((data: leviathanData, bytes: leviathanBytes))
            inputStrings.append(htmlLeviathan)
        }
        if includeBenchmark("behemoth"), behemothRepeatCount > 0 {
            let htmlBehemoth = buildBehemothBenchmarkHTML(repeatCount: behemothRepeatCount)
            let behemothData = Data(htmlBehemoth.utf8)
            let behemothBytes = [UInt8](behemothData)
            inputs.append((data: behemothData, bytes: behemothBytes))
            inputStrings.append(htmlBehemoth)
        }
        if includeBenchmark("colossus"), colossusRepeatCount > 0 {
            let htmlColossus = buildColossusBenchmarkHTML(repeatCount: colossusRepeatCount)
            let colossusData = Data(htmlColossus.utf8)
            let colossusBytes = [UInt8](colossusData)
            inputs.append((data: colossusData, bytes: colossusBytes))
            inputStrings.append(htmlColossus)
        }
        if includeBenchmark("nebula"), nebulaRepeatCount > 0 {
            let htmlNebula = buildNebulaBenchmarkHTML(repeatCount: nebulaRepeatCount)
            let nebulaData = Data(htmlNebula.utf8)
            let nebulaBytes = [UInt8](nebulaData)
            inputs.append((data: nebulaData, bytes: nebulaBytes))
            inputStrings.append(htmlNebula)
        }
        if includeBenchmark("script-heavy"), scriptHeavyRepeatCount > 0 {
            let htmlScriptHeavy = buildScriptHeavyBenchmarkHTML(repeatCount: scriptHeavyRepeatCount)
            let scriptHeavyData = Data(htmlScriptHeavy.utf8)
            let scriptHeavyBytes = [UInt8](scriptHeavyData)
            inputs.append((data: scriptHeavyData, bytes: scriptHeavyBytes))
            inputStrings.append(htmlScriptHeavy)
        }
        if includeBenchmark("rcdata-heavy"), rcdataHeavyRepeatCount > 0 {
            let htmlRcdataHeavy = buildRcdataHeavyBenchmarkHTML(repeatCount: rcdataHeavyRepeatCount)
            let rcdataHeavyData = Data(htmlRcdataHeavy.utf8)
            let rcdataHeavyBytes = [UInt8](rcdataHeavyData)
            inputs.append((data: rcdataHeavyData, bytes: rcdataHeavyBytes))
            inputStrings.append(htmlRcdataHeavy)
        }
        if includeBenchmark("entity-heavy"), entityHeavyRepeatCount > 0 {
            let htmlEntityHeavy = buildEntityHeavyBenchmarkHTML(repeatCount: entityHeavyRepeatCount)
            let entityHeavyData = Data(htmlEntityHeavy.utf8)
            let entityHeavyBytes = [UInt8](entityHeavyData)
            inputs.append((data: entityHeavyData, bytes: entityHeavyBytes))
            inputStrings.append(htmlEntityHeavy)
        }
        if includeBenchmark("entity-storm"), entityStormRepeatCount > 0 {
            let htmlEntityStorm = buildEntityStormBenchmarkHTML(repeatCount: entityStormRepeatCount)
            let entityStormData = Data(htmlEntityStorm.utf8)
            let entityStormBytes = [UInt8](entityStormData)
            inputs.append((data: entityStormData, bytes: entityStormBytes))
            inputStrings.append(htmlEntityStorm)
        }
        if includeBenchmark("entity-named"), entityNamedRepeatCount > 0 {
            let htmlEntityNamed = buildEntityNamedBenchmarkHTML(repeatCount: entityNamedRepeatCount)
            let entityNamedData = Data(htmlEntityNamed.utf8)
            let entityNamedBytes = [UInt8](entityNamedData)
            inputs.append((data: entityNamedData, bytes: entityNamedBytes))
            inputStrings.append(htmlEntityNamed)
        }
        if includeBenchmark("entity-named-storm"), entityNamedStormRepeatCount > 0 {
            let htmlEntityNamedStorm = buildEntityNamedStormBenchmarkHTML(repeatCount: entityNamedStormRepeatCount)
            let entityNamedStormData = Data(htmlEntityNamedStorm.utf8)
            let entityNamedStormBytes = [UInt8](entityNamedStormData)
            inputs.append((data: entityNamedStormData, bytes: entityNamedStormBytes))
            inputStrings.append(htmlEntityNamedStorm)
        }
        if includeBenchmark("entity-named-extended"), entityNamedExtendedRepeatCount > 0 {
            let htmlEntityNamedExtended = buildEntityNamedExtendedBenchmarkHTML(repeatCount: entityNamedExtendedRepeatCount)
            let entityNamedExtendedData = Data(htmlEntityNamedExtended.utf8)
            let entityNamedExtendedBytes = [UInt8](entityNamedExtendedData)
            inputs.append((data: entityNamedExtendedData, bytes: entityNamedExtendedBytes))
            inputStrings.append(htmlEntityNamedExtended)
        }
        if includeBenchmark("ampersand-heavy"), ampersandHeavyRepeatCount > 0 {
            let htmlAmpersandHeavy = buildAmpersandHeavyBenchmarkHTML(repeatCount: ampersandHeavyRepeatCount)
            let ampersandHeavyData = Data(htmlAmpersandHeavy.utf8)
            let ampersandHeavyBytes = [UInt8](ampersandHeavyData)
            inputs.append((data: ampersandHeavyData, bytes: ampersandHeavyBytes))
            inputStrings.append(htmlAmpersandHeavy)
        }
        if includeBenchmark("list-heavy"), listHeavyRepeatCount > 0 {
            let htmlListHeavy = buildListHeavyBenchmarkHTML(repeatCount: listHeavyRepeatCount)
            let listHeavyData = Data(htmlListHeavy.utf8)
            let listHeavyBytes = [UInt8](listHeavyData)
            inputs.append((data: listHeavyData, bytes: listHeavyBytes))
            inputStrings.append(htmlListHeavy)
        }
        if includeBenchmark("attribute-heavy"), attributeHeavyRepeatCount > 0 {
            let htmlAttributeHeavy = buildAttributeHeavyBenchmarkHTML(repeatCount: attributeHeavyRepeatCount)
            let attributeHeavyData = Data(htmlAttributeHeavy.utf8)
            let attributeHeavyBytes = [UInt8](attributeHeavyData)
            inputs.append((data: attributeHeavyData, bytes: attributeHeavyBytes))
            inputStrings.append(htmlAttributeHeavy)
        }
        if includeBenchmark("attribute-mega"), attributeMegaRepeatCount > 0 {
            let htmlAttributeMega = buildAttributeMegaBenchmarkHTML(repeatCount: attributeMegaRepeatCount)
            let attributeMegaData = Data(htmlAttributeMega.utf8)
            let attributeMegaBytes = [UInt8](attributeMegaData)
            inputs.append((data: attributeMegaData, bytes: attributeMegaBytes))
            inputStrings.append(htmlAttributeMega)
        }
        if includeBenchmark("attribute-storm"), attributeStormRepeatCount > 0 {
            let htmlAttributeStorm = buildAttributeStormBenchmarkHTML(repeatCount: attributeStormRepeatCount)
            let attributeStormData = Data(htmlAttributeStorm.utf8)
            let attributeStormBytes = [UInt8](attributeStormData)
            inputs.append((data: attributeStormData, bytes: attributeStormBytes))
            inputStrings.append(htmlAttributeStorm)
        }
        if includeBenchmark("querystring"), queryStringHeavyRepeatCount > 0 {
            let htmlQueryStringHeavy = buildQueryStringHeavyBenchmarkHTML(repeatCount: queryStringHeavyRepeatCount)
            let queryStringData = Data(htmlQueryStringHeavy.utf8)
            let queryStringBytes = [UInt8](queryStringData)
            inputs.append((data: queryStringData, bytes: queryStringBytes))
            inputStrings.append(htmlQueryStringHeavy)
        }
        if includeBenchmark("dense-text"), denseTextRepeatCount > 0 {
            let htmlDenseText = buildDenseTextBenchmarkHTML(repeatCount: denseTextRepeatCount)
            let denseTextData = Data(htmlDenseText.utf8)
            let denseTextBytes = [UInt8](denseTextData)
            inputs.append((data: denseTextData, bytes: denseTextBytes))
            inputStrings.append(htmlDenseText)
        }
        if includeBenchmark("table-heavy"), tableHeavyRepeatCount > 0 {
            let htmlTableHeavy = buildTableHeavyBenchmarkHTML(repeatCount: tableHeavyRepeatCount)
            let tableHeavyData = Data(htmlTableHeavy.utf8)
            let tableHeavyBytes = [UInt8](tableHeavyData)
            inputs.append((data: tableHeavyData, bytes: tableHeavyBytes))
            inputStrings.append(htmlTableHeavy)
        }
        if includeBenchmark("data-heavy"), dataHeavyRepeatCount > 0 {
            let htmlDataHeavy = buildDataHeavyBenchmarkHTML(repeatCount: dataHeavyRepeatCount)
            let dataHeavyData = Data(htmlDataHeavy.utf8)
            let dataHeavyBytes = [UInt8](dataHeavyData)
            inputs.append((data: dataHeavyData, bytes: dataHeavyBytes))
            inputStrings.append(htmlDataHeavy)
        }
        if includeBenchmark("plaintext"), plainTextRepeatCount > 0 {
            let htmlPlainText = buildPlainTextBenchmarkHTML(repeatCount: plainTextRepeatCount)
            let plainTextData = Data(htmlPlainText.utf8)
            let plainTextBytes = [UInt8](plainTextData)
            inputs.append((data: plainTextData, bytes: plainTextBytes))
            inputStrings.append(htmlPlainText)
        }
        if includeBenchmark("data-storm"), dataStormRepeatCount > 0 {
            let htmlDataStorm = buildDataStormBenchmarkHTML(repeatCount: dataStormRepeatCount)
            let dataStormData = Data(htmlDataStorm.utf8)
            let dataStormBytes = [UInt8](dataStormData)
            inputs.append((data: dataStormData, bytes: dataStormBytes))
            inputStrings.append(htmlDataStorm)
        }
        if includeBenchmark("tag-heavy"), tagHeavyRepeatCount > 0 {
            let htmlTagHeavy = buildTagHeavyBenchmarkHTML(repeatCount: tagHeavyRepeatCount)
            let tagHeavyData = Data(htmlTagHeavy.utf8)
            let tagHeavyBytes = [UInt8](tagHeavyData)
            inputs.append((data: tagHeavyData, bytes: tagHeavyBytes))
            inputStrings.append(htmlTagHeavy)
        }
        if includeBenchmark("custom-tag"), customTagRepeatCount > 0 {
            let htmlCustomTags = buildCustomTagBenchmarkHTML(repeatCount: customTagRepeatCount)
            let customTagData = Data(htmlCustomTags.utf8)
            let customTagBytes = [UInt8](customTagData)
            inputs.append((data: customTagData, bytes: customTagBytes))
            inputStrings.append(htmlCustomTags)
        }
        if includeBenchmark("deep-nest"), deepNestRepeatCount > 0 {
            let htmlDeepNest = buildDeepNestingBenchmarkHTML(
                repeatCount: deepNestRepeatCount,
                depth: deepNestDepth,
                withAttributes: deepNestWithAttrs
            )
            let deepNestData = Data(htmlDeepNest.utf8)
            let deepNestBytes = [UInt8](deepNestData)
            inputs.append((data: deepNestData, bytes: deepNestBytes))
            inputStrings.append(htmlDeepNest)
        }
        if includeBenchmark("whitespace-heavy"), whitespaceHeavyRepeatCount > 0 {
            let htmlWhitespace = buildWhitespaceHeavyBenchmarkHTML(repeatCount: whitespaceHeavyRepeatCount)
            let whitespaceData = Data(htmlWhitespace.utf8)
            let whitespaceBytes = [UInt8](whitespaceData)
            inputs.append((data: whitespaceData, bytes: whitespaceBytes))
            inputStrings.append(htmlWhitespace)
        }
        if includeBenchmark("manabi-reader"), manabiReaderRepeatCount > 0 {
            let htmlManabi = buildManabiReaderBenchmarkHTML(repeatCount: manabiReaderRepeatCount)
            let manabiData = Data(htmlManabi.utf8)
            let manabiBytes = [UInt8](manabiData)
            inputs.append((data: manabiData, bytes: manabiBytes))
            inputStrings.append(htmlManabi)
        }
        let fileLimit = envInt("SWIFTSOUP_BENCHMARK_FILE_LIMIT", 0)
        if includeBenchmark("files"), ProcessInfo.processInfo.environment["SWIFTSOUP_BENCHMARK_FILES"] != "0" {
            let cwd = FileManager.default.currentDirectoryPath
            let benchmarksURL = URL(fileURLWithPath: cwd).appendingPathComponent("Resources/benchmarks")
            if let files = try? FileManager.default.contentsOfDirectory(at: benchmarksURL, includingPropertiesForKeys: nil),
               !files.isEmpty {
                var htmlFiles = files.filter { $0.pathExtension.lowercased() == "html" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
                if fileLimit > 0, fileLimit < htmlFiles.count {
                    htmlFiles = Array(htmlFiles.prefix(fileLimit))
                }
                for file in htmlFiles {
                    if let fileData = FileManager.default.contents(atPath: file.path), !fileData.isEmpty {
                        inputs.append((data: fileData, bytes: [UInt8](fileData)))
                        if let fileString = String(data: fileData, encoding: .utf8) {
                            inputStrings.append(fileString)
                        }
                    }
                }
            }
        }

        Profiler.reset()
        let useFastParse = ProcessInfo.processInfo.environment["SWIFTSOUP_FAST_PARSE"] == "1"
        let skipSelectors = ProcessInfo.processInfo.environment["SWIFTSOUP_BENCHMARK_SKIP_SELECTORS"] == "1"
        let skipText = ProcessInfo.processInfo.environment["SWIFTSOUP_BENCHMARK_SKIP_TEXT"] == "1"
        let manabiReaderEnabled = includeBenchmark("manabi-reader")
        let parser: Parser? = {
            if useFastParse {
                let parser = Parser.htmlParser()
                parser.settings(ParseSettings(false, false, false))
                return parser
            }
            return nil
        }()
        if ProcessInfo.processInfo.environment["SWIFTSOUP_BENCHMARK_DISABLE_QUERY_CACHE"] == "1" {
            QueryParser.cache = nil
        }

        for _ in 0..<warmupIterations {
            for input in inputs {
                let doc: Document
                if let parser {
                    doc = try parser.parseInput(input.bytes, "")
                } else {
                    doc = try SwiftSoup.parse(input.data, "")
                }
                if !skipSelectors {
                    if selectorRepeat > 1 {
                        for _ in 0..<selectorRepeat {
                            try exerciseSelectors(doc)
                        }
                    } else {
                        try exerciseSelectors(doc)
                    }
                    if selectorStressRepeat > 0 {
                        for _ in 0..<selectorStressRepeat {
                            try exerciseClassSelectors(doc)
                        }
                    }
                    if attributeSelectorStressRepeat > 0 {
                        for _ in 0..<attributeSelectorStressRepeat {
                            try exerciseAttributeSelectors(doc)
                        }
                    }
                }
                if manabiReaderEnabled {
                    try exerciseManabiReaderOps(doc)
                }
                if !skipText {
                    _ = try doc.text()
                    if textNodeTextEnabled {
                        for node in doc.textNodes() {
                            _ = node.text()
                        }
                    }
                }
            }
            for htmlString in inputStrings {
                let doc = try SwiftSoup.parse(htmlString, "")
                if !skipSelectors {
                    if selectorRepeat > 1 {
                        for _ in 0..<selectorRepeat {
                            try exerciseSelectors(doc)
                        }
                    } else {
                        try exerciseSelectors(doc)
                    }
                    if selectorStressRepeat > 0 {
                        for _ in 0..<selectorStressRepeat {
                            try exerciseClassSelectors(doc)
                        }
                    }
                    if attributeSelectorStressRepeat > 0 {
                        for _ in 0..<attributeSelectorStressRepeat {
                            try exerciseAttributeSelectors(doc)
                        }
                    }
                }
                if manabiReaderEnabled {
                    try exerciseManabiReaderOps(doc)
                }
                if !skipText {
                    _ = try doc.text()
                    if textNodeTextEnabled {
                        for node in doc.textNodes() {
                            _ = node.text()
                        }
                    }
                }
            }
        }

        if iterations > 0 {
            let start = DispatchTime.now().uptimeNanoseconds
            do {
                for _ in 0..<iterations {
                    for input in inputs {
                        let doc: Document
                        if let parser {
                            doc = try parser.parseInput(input.bytes, "")
                        } else {
                            doc = try SwiftSoup.parse(input.data, "")
                        }
                        if !skipSelectors {
                            if selectorRepeat > 1 {
                                for _ in 0..<selectorRepeat {
                                    try exerciseSelectors(doc)
                                }
                            } else {
                                try exerciseSelectors(doc)
                            }
                            if selectorStressRepeat > 0 {
                                for _ in 0..<selectorStressRepeat {
                                    try exerciseClassSelectors(doc)
                                }
                            }
                            if attributeSelectorStressRepeat > 0 {
                                for _ in 0..<attributeSelectorStressRepeat {
                                    try exerciseAttributeSelectors(doc)
                                }
                            }
                        }
                        if manabiReaderEnabled {
                            try exerciseManabiReaderOps(doc)
                        }
                        if !skipText {
                            _ = try doc.text()
                            if textNodeTextEnabled {
                                for node in doc.textNodes() {
                                    _ = node.text()
                                }
                            }
                        }
                    }
                    for htmlString in inputStrings {
                        let doc = try SwiftSoup.parse(htmlString, "")
                        if !skipSelectors {
                            if selectorRepeat > 1 {
                                for _ in 0..<selectorRepeat {
                                    try exerciseSelectors(doc)
                                }
                            } else {
                                try exerciseSelectors(doc)
                            }
                            if selectorStressRepeat > 0 {
                                for _ in 0..<selectorStressRepeat {
                                    try exerciseClassSelectors(doc)
                                }
                            }
                            if attributeSelectorStressRepeat > 0 {
                                for _ in 0..<attributeSelectorStressRepeat {
                                    try exerciseAttributeSelectors(doc)
                                }
                            }
                        }
                        if manabiReaderEnabled {
                            try exerciseManabiReaderOps(doc)
                        }
                        if !skipText {
                            _ = try doc.text()
                            if textNodeTextEnabled {
                                for node in doc.textNodes() {
                                    _ = node.text()
                                }
                            }
                        }
                    }
                }
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
            let elapsed = DispatchTime.now().uptimeNanoseconds &- start
            let elapsedMs = Double(elapsed) / 1_000_000.0
            print("Benchmark elapsed: \(String(format: "%.2f", elapsedMs)) ms over \(iterations) iterations")
        }

        let report = Profiler.report(top: 40)
        if !report.isEmpty {
            print(report)
        }
    }
}
