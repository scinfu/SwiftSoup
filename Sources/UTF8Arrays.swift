import Foundation

public enum UTF8Arrays {
    public static let whitespace = " ".utf8Array
    public static let newline = "\n".utf8Array
    public static let bang = "!".utf8Array
    public static let equalSign = "=".utf8Array
    public static let ampersand = "&".utf8Array
    public static let hyphen = "-".utf8Array
    public static let doubleHyphen = "--".utf8Array
    public static let doubleHyphenBang = "--!".utf8Array
    public static let underscore = "_".utf8Array
    public static let semicolon = ";".utf8Array
    public static let questionMark = "?".utf8Array
    public static let forwardSlash = "/".utf8Array
    public static let selfClosingTagEnd = " />".utf8Array
    public static let endTagStart = "</".utf8Array
    public static let tagStart = "<".utf8Array
    public static let tagStartBang = "<!".utf8Array
    public static let tagEnd = ">".utf8Array
    public static let attributeEqualsQuoteMark = "=\"".utf8Array
    public static let quoteMark = "\"".utf8Array
    public static let html = "html".utf8Array
    public static let head = "head".utf8Array
    public static let meta = "meta".utf8Array
    public static let body = "body".utf8Array
    public static let cite = "cite".utf8Array
    public static let a = "a".utf8Array
    public static let p = "p".utf8Array
    public static let div = "div".utf8Array
    public static let li = "li".utf8Array
    public static let span = "span".utf8Array
    public static let img = "img".utf8Array
    public static let dd = "dd".utf8Array
    public static let dt = "dt".utf8Array
    public static let dl = "dl".utf8Array
    public static let ol = "ol".utf8Array
    public static let ul = "ul".utf8Array
    public static let pre = "pre".utf8Array
    public static let listing = "listing".utf8Array
    public static let address = "address".utf8Array
    public static let article = "article".utf8Array
    public static let aside = "aside".utf8Array
    public static let blockquote = "blockquote".utf8Array
    public static let center = "center".utf8Array
    public static let dir = "dir".utf8Array
    public static let fieldset = "fieldset".utf8Array
    public static let figcaption = "figcaption".utf8Array
    public static let figure = "figure".utf8Array
    public static let footer = "footer".utf8Array
    public static let header = "header".utf8Array
    public static let hgroup = "hgroup".utf8Array
    public static let menu = "menu".utf8Array
    public static let nav = "nav".utf8Array
    public static let section = "section".utf8Array
    public static let summary = "summary".utf8Array
    public static let h1 = "h1".utf8Array
    public static let h2 = "h2".utf8Array
    public static let h3 = "h3".utf8Array
    public static let h4 = "h4".utf8Array
    public static let h5 = "h5".utf8Array
    public static let h6 = "h6".utf8Array
    public static let applet = "applet".utf8Array
    public static let marquee = "marquee".utf8Array
    public static let object = "object".utf8Array
    public static let action = "action".utf8Array
    public static let prompt = "prompt".utf8Array
    public static let comment = "comment".utf8Array
    public static let hash = "#".utf8Array
    public static let hashRoot = "#root".utf8Array
    public static let ruby = "ruby".utf8Array
    public static let rb = "rb".utf8Array
    public static let rp = "rp".utf8Array
    public static let rt = "rt".utf8Array
    public static let rtc = "rtc".utf8Array
    public static let page = "page".utf8Array
    public static let class_ = "class".utf8Array
    public static let table = "table".utf8Array
    public static let tbody = "tbody".utf8Array
    public static let th = "th".utf8Array
    public static let tr = "tr".utf8Array
    public static let td = "td".utf8Array
    public static let thead = "thead".utf8Array
    public static let tfoot = "tfoot".utf8Array
    public static let optgroup = "optgroup".utf8Array
    public static let select = "select".utf8Array
    public static let form = "form".utf8Array
    public static let plaintext = "plaintext".utf8Array
    public static let button = "button".utf8Array
    public static let image = "image".utf8Array
    public static let value = "value".utf8Array
    public static let input = "input".utf8Array
    public static let type = "type".utf8Array
    public static let hidden = "hidden".utf8Array
    public static let caption = "caption".utf8Array
    public static let hr = "hr".utf8Array
    public static let abbr = "abbr".utf8Array
    public static let svg = "svg".utf8Array
    public static let isindex = "isindex".utf8Array
    public static let label = "label".utf8Array
    public static let xmp = "xmp".utf8Array
    public static let textarea = "textarea".utf8Array
    public static let iframe = "iframe".utf8Array
    public static let noembed = "noembed".utf8Array
    public static let noframes = "noframes".utf8Array
    public static let noscript = "noscript".utf8Array
    public static let embed = "embed".utf8Array
    public static let option = "option".utf8Array
    public static let math = "math".utf8Array
    public static let data = "data".utf8Array
    public static let strong = "strong".utf8Array
    public static let sarcasm = "sarcasm".utf8Array // Huh
    public static let name = "name".utf8Array
    public static let i = "i".utf8Array
    public static let nobr = "nobr".utf8Array
    public static let col = "col".utf8Array
    public static let colgroup = "colgroup".utf8Array
    public static let em = "em".utf8Array
    public static let small = "small".utf8Array
    public static let frame = "frame".utf8Array
    public static let sub = "sub".utf8Array
    public static let sup = "sup".utf8Array
    public static let base = "base".utf8Array
    public static let time = "time".utf8Array
    public static let href = "href".utf8Array
    public static let meter = "meter".utf8Array
    public static let b = "b".utf8Array
    public static let style = "style".utf8Array
    public static let title = "title".utf8Array
    public static let script = "script".utf8Array
    public static let br = "br".utf8Array
    public static let frameset = "frameset".utf8Array
    public static let blobColon = "blob:".utf8Array
    public static let absPrefix = "abs:".utf8Array
    public static let true_ = "true".utf8Array
}

public enum UTF8ArraySlices {
    public static let whitespace = UTF8Arrays.whitespace[...]
    public static let bang = UTF8Arrays.bang[...]
    public static let equalSign = UTF8Arrays.equalSign[...]
    public static let ampersand = UTF8Arrays.ampersand[...]
    public static let hyphen = UTF8Arrays.hyphen[...]
    public static let doubleHyphen = UTF8Arrays.doubleHyphen[...]
    public static let doubleHyphenBang = UTF8Arrays.doubleHyphenBang[...]
    public static let underscore = UTF8Arrays.underscore[...]
    public static let semicolon = UTF8Arrays.semicolon[...]
    public static let questionMark = UTF8Arrays.questionMark[...]
    public static let forwardSlash = UTF8Arrays.forwardSlash[...]
    public static let selfClosingTagEnd = UTF8Arrays.selfClosingTagEnd[...]
    public static let endTagStart = UTF8Arrays.endTagStart[...]
    public static let tagStart = UTF8Arrays.tagStart[...]
    public static let tagStartBang = UTF8Arrays.tagStartBang[...]
    public static let tagEnd = UTF8Arrays.tagEnd[...]
    public static let attributeEqualsQuoteMark = UTF8Arrays.attributeEqualsQuoteMark[...]
    public static let quoteMark = UTF8Arrays.quoteMark[...]
    public static let html = UTF8Arrays.html[...]
    public static let head = UTF8Arrays.head[...]
    public static let meta = UTF8Arrays.meta[...]
    public static let body = UTF8Arrays.body[...]
    public static let cite = UTF8Arrays.cite[...]
    public static let abbr = UTF8Arrays.abbr[...]
    public static let data = UTF8Arrays.data[...]
    public static let strong = UTF8Arrays.strong[...]
    public static let sub = UTF8Arrays.sub[...]
    public static let sup = UTF8Arrays.sup[...]
    public static let b = UTF8Arrays.b[...]
    public static let i = UTF8Arrays.i[...]
    public static let meter = UTF8Arrays.meter[...]
    public static let a = UTF8Arrays.a[...]
    public static let p = UTF8Arrays.p[...]
    public static let li = UTF8Arrays.li[...]
    public static let em = UTF8Arrays.em[...]
    public static let time = UTF8Arrays.time[...]
    public static let small = UTF8Arrays.small[...]
    public static let span = UTF8Arrays.span[...]
    public static let img = UTF8Arrays.img[...]
    public static let action = UTF8Arrays.action[...]
    public static let prompt = UTF8Arrays.prompt[...]
    public static let comment = UTF8Arrays.comment[...]
    public static let hash = UTF8Arrays.hash[...]
    public static let hashRoot = UTF8Arrays.hashRoot[...]
    public static let ruby = UTF8Arrays.ruby[...]
    public static let rb = UTF8Arrays.rb[...]
    public static let rp = UTF8Arrays.rp[...]
    public static let rt = UTF8Arrays.rt[...]
    public static let rtc = UTF8Arrays.rtc[...]
    public static let page = UTF8Arrays.page[...]
    public static let dd = UTF8Arrays.dd[...]
    public static let dt = UTF8Arrays.dt[...]
    public static let dl = UTF8Arrays.dl[...]
    public static let ol = UTF8Arrays.ol[...]
    public static let ul = UTF8Arrays.ul[...]
    public static let pre = UTF8Arrays.pre[...]
    public static let listing = UTF8Arrays.listing[...]
    public static let address = UTF8Arrays.address[...]
    public static let article = UTF8Arrays.article[...]
    public static let aside = UTF8Arrays.aside[...]
    public static let blockquote = UTF8Arrays.blockquote[...]
    public static let center = UTF8Arrays.center[...]
    public static let dir = UTF8Arrays.dir[...]
    public static let fieldset = UTF8Arrays.fieldset[...]
    public static let figcaption = UTF8Arrays.figcaption[...]
    public static let figure = UTF8Arrays.figure[...]
    public static let footer = UTF8Arrays.footer[...]
    public static let header = UTF8Arrays.header[...]
    public static let hgroup = UTF8Arrays.hgroup[...]
    public static let menu = UTF8Arrays.menu[...]
    public static let nav = UTF8Arrays.nav[...]
    public static let section = UTF8Arrays.section[...]
    public static let summary = UTF8Arrays.summary[...]
    public static let h1 = UTF8Arrays.h1[...]
    public static let h2 = UTF8Arrays.h2[...]
    public static let h3 = UTF8Arrays.h3[...]
    public static let h4 = UTF8Arrays.h4[...]
    public static let h5 = UTF8Arrays.h5[...]
    public static let h6 = UTF8Arrays.h6[...]
    public static let applet = UTF8Arrays.applet[...]
    public static let marquee = UTF8Arrays.marquee[...]
    public static let object = UTF8Arrays.object[...]
    public static let class_ = UTF8Arrays.class_[...]
    public static let table = UTF8Arrays.table[...]
    public static let tbody = UTF8Arrays.tbody[...]
    public static let th = UTF8Arrays.th[...]
    public static let tr = UTF8Arrays.tr[...]
    public static let td = UTF8Arrays.td[...]
    public static let thead = UTF8Arrays.thead[...]
    public static let tfoot = UTF8Arrays.tfoot[...]
    public static let optgroup = UTF8Arrays.optgroup[...]
    public static let select = UTF8Arrays.select[...]
    public static let form = UTF8Arrays.form[...]
    public static let plaintext = UTF8Arrays.plaintext[...]
    public static let button = UTF8Arrays.button[...]
    public static let image = UTF8Arrays.image[...]
    public static let value = UTF8Arrays.value[...]
    public static let nobr = UTF8Arrays.nobr[...]
    public static let input = UTF8Arrays.input[...]
    public static let type = UTF8Arrays.type[...]
    public static let hidden = UTF8Arrays.hidden[...]
    public static let caption = UTF8Arrays.caption[...]
    public static let hr = UTF8Arrays.hr[...]
    public static let svg = UTF8Arrays.svg[...]
    public static let isindex = UTF8Arrays.isindex[...]
    public static let label = UTF8Arrays.label[...]
    public static let xmp = UTF8Arrays.xmp[...]
    public static let textarea = UTF8Arrays.textarea[...]
    public static let iframe = UTF8Arrays.iframe[...]
    public static let noembed = UTF8Arrays.noembed[...]
    public static let noframes = UTF8Arrays.noframes[...]
    public static let noscript = UTF8Arrays.noscript[...]
    public static let embed = UTF8Arrays.embed[...]
    public static let option = UTF8Arrays.option[...]
    public static let math = UTF8Arrays.math[...]
    public static let sarcasm = UTF8Arrays.sarcasm[...]
    public static let name = UTF8Arrays.name[...]
    public static let col = UTF8Arrays.col[...]
    public static let colgroup = UTF8Arrays.colgroup[...]
    public static let frame = UTF8Arrays.frame[...]
    public static let base = UTF8Arrays.base[...]
    public static let href = UTF8Arrays.href[...]
    public static let style = UTF8Arrays.style[...]
    public static let title = UTF8Arrays.title[...]
    public static let script = UTF8Arrays.script[...]
    public static let br = UTF8Arrays.br[...]
    public static let frameset = UTF8Arrays.frameset[...]
    public static let blobColon = UTF8Arrays.blobColon[...]
    public static let true_ = UTF8Arrays.true_[...]
}

extension Array where Element == UInt8 {
    /// Compares a region of self to a region of another UTF8 string, optionally case-insensitive (ASCII only).
    func regionMatches(
        ignoreCase: Bool,
        selfOffset: Int,
        other: [UInt8],
        otherOffset: Int,
        targetLength: Int
    ) -> Bool {
        // Bounds check
        if selfOffset < 0 || otherOffset < 0 ||
            selfOffset > self.count - targetLength ||
            otherOffset > other.count - targetLength {
            return false
        }
        for i in 0..<targetLength {
            var a = self[selfOffset + i]
            var b = other[otherOffset + i]
            if ignoreCase {
                // ASCII case folding (A-Z 65-90, a-z 97-122)
                if a >= 65 && a <= 90 { a += 32 }
                if b >= 65 && b <= 90 { b += 32 }
            }
            if a != b {
                return false
            }
        }
        return true
    }
}
