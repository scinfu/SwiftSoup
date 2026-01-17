#if canImport(CLibxml2) || canImport(libxml2)
import Foundation
#if canImport(CLibxml2)
@preconcurrency import CLibxml2
#elseif canImport(libxml2)
@preconcurrency import libxml2
#endif
import SwiftSoupCLibxml2Scan
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

enum Libxml2BackendError: Error {
    case parseFailed
}

private enum Libxml2FallbackReason: String {
    case compatModeDisabled
    case preserveCaseSettings
    case noTagDelimiter
    case containsNull
    case commentDashDashDash
    case malformedTag
    case nonAsciiTagName
    case namespacedTag
    case noscriptTag
    case tableHeuristics
    case headBodyPlacement
    case formattingMismatch
    case voidEndTag
    case nonAsciiAttributeName
    case malformedAttribute
    case rawTextUnterminated
    case parseFailed
    case unknown
}

private final class Libxml2FallbackStats: @unchecked Sendable {
    static let enabled: Bool = {
        let value = ProcessInfo.processInfo.environment["SWIFTSOUP_LIBXML2_STATS"]?.lowercased()
        return value == "1" || value == "true" || value == "yes"
    }()

    static let shared = Libxml2FallbackStats()
    static let sampleEnabled: Bool = {
        let value = ProcessInfo.processInfo.environment["SWIFTSOUP_LIBXML2_STATS_SAMPLES"]?.lowercased()
        return value == "1" || value == "true" || value == "yes"
    }()

    private let lock = NSLock()
    private var parseCount = 0
    private var libxmlCount = 0
    private var fallbackCount = 0
    private var reasons: [Libxml2FallbackReason: Int] = [:]
    private var samples: [Libxml2FallbackReason: [String]] = [:]

    private init() {}

    func recordParse() {
        lock.lock()
        parseCount += 1
        lock.unlock()
    }

    func recordLibxmlUsed() {
        lock.lock()
        libxmlCount += 1
        lock.unlock()
    }

    func recordFallback(_ reason: Libxml2FallbackReason, sample: String? = nil) {
        lock.lock()
        fallbackCount += 1
        reasons[reason, default: 0] += 1
        if Self.sampleEnabled, let sample {
            var list = samples[reason, default: []]
            if list.count < 3 {
                list.append(sample)
                samples[reason] = list
            }
        }
        lock.unlock()
    }

    func report() -> String {
        lock.lock()
        let total = parseCount
        let libxml = libxmlCount
        let fallback = fallbackCount
        let sorted = reasons.sorted { $0.value > $1.value }
        let samplesSnapshot = samples
        lock.unlock()

        guard total > 0 else { return "" }
        var lines: [String] = []
        lines.append("Libxml2 fallback stats: parses=\(total), libxml2=\(libxml), fallback=\(fallback)\n")
        for (reason, count) in sorted {
            lines.append(" - \(reason.rawValue): \(count)\n")
            if let sampleList = samplesSnapshot[reason], !sampleList.isEmpty {
                for sample in sampleList {
                    lines.append("   sample: \(sample)\n")
                }
            }
        }
        return lines.joined()
    }

    static let installReporter: Void = {
        guard enabled else { return }
        #if canImport(Darwin)
        atexit {
            let report = Libxml2FallbackStats.shared.report()
            if !report.isEmpty {
                fputs(report, stderr)
            }
        }
        #elseif canImport(Glibc)
        atexit {
            let report = Libxml2FallbackStats.shared.report()
            if !report.isEmpty {
                fputs(report, stderr)
            }
        }
        #endif
    }()
}

final class Libxml2TreeBuilder: TreeBuilder {
    let skipSwiftSoupFallbacks: Bool

    init(skipSwiftSoupFallbacks: Bool) {
        self.skipSwiftSoupFallbacks = skipSwiftSoupFallbacks
        super.init()
    }

    override func defaultSettings() -> ParseSettings {
        return ParseSettings.htmlDefault
    }

    @discardableResult
    override func process(_ token: Token) throws -> Bool {
        return false
    }

    override func parse(
        _ input: [UInt8],
        _ baseUri: [UInt8],
        _ errors: ParseErrorList,
        _ settings: ParseSettings
    ) throws -> Document {
        return try Libxml2Backend.parseHTML(
            input,
            baseUri: baseUri,
            settings: settings,
            errors: errors,
            builder: self
        )
    }
}

final class Libxml2XmlTreeBuilder: TreeBuilder {
    let skipSwiftSoupFallbacks: Bool

    init(skipSwiftSoupFallbacks: Bool) {
        self.skipSwiftSoupFallbacks = skipSwiftSoupFallbacks
        super.init()
    }

    override func defaultSettings() -> ParseSettings {
        return ParseSettings.preserveCase
    }

    override func parse(
        _ input: [UInt8],
        _ baseUri: [UInt8],
        _ errors: ParseErrorList,
        _ settings: ParseSettings
    ) throws -> Document {
        return try Libxml2Backend.parseXML(
            input,
            baseUri: baseUri,
            settings: settings,
            errors: errors,
            builder: self
        )
    }
}

final class Libxml2AttributeCollector: TreeBuilder {
    struct StartTagEntry {
        var tagName: [UInt8]
        var attributes: Attributes
    }

    var startTags: [StartTagEntry] = []

    override func defaultSettings() -> ParseSettings {
        return ParseSettings.htmlDefault
    }

    @discardableResult
    override func process(_ token: Token) throws -> Bool {
        if token.isStartTag() {
            let start = token.asStartTag()
            guard let name = start.normalName() else { return true }
            let attrs = Attributes()
            let incoming = start.getAttributes()
            incoming.ensureMaterialized()
            for attr in incoming.asList() {
                let rawKey = attr.getKeyUTF8()
                let key: [UInt8]
                if rawKey.first == UTF8Arrays.forwardSlash.first, rawKey.count > 1 {
                    key = Array(rawKey.dropFirst())
                } else {
                    key = rawKey
                }
                let value = attr.getValueUTF8()
                if attr.isBooleanAttribute() {
                    if value.isEmpty {
                        if let booleanAttr = try? BooleanAttribute(key: key) {
                            attrs.put(attribute: booleanAttr)
                        }
                    } else if let clone = try? Attribute(key: key, value: value) {
                        attrs.put(attribute: clone)
                    }
                } else if let clone = try? Attribute(key: key, value: value) {
                    attrs.put(attribute: clone)
                }
            }
            startTags.append(StartTagEntry(tagName: name, attributes: attrs))
        }
        return true
    }
}

private struct HtmlScanHints {
    private struct OccurrenceQueue {
        var values: [Bool] = []
        var index: Int = 0

        mutating func append(_ value: Bool) {
            values.append(value)
        }

        mutating func consume() -> Bool? {
            guard index < values.count else { return nil }
            let value = values[index]
            index += 1
            return value
        }
    }

    private var selfClosingOccurrences: [[UInt8]: OccurrenceQueue] = [:]
    private var booleanAttributeOccurrences: [OccurrenceQueue]

    init() {
        booleanAttributeOccurrences = Array(repeating: OccurrenceQueue(), count: booleanAttributeNames.count)
    }

    init(html: [UInt8], settings: ParseSettings) {
        self.init()
        scan(html, settings: settings)
    }

    mutating func consumeSelfClosing(for tagName: [UInt8]) -> Bool {
        guard var queue = selfClosingOccurrences[tagName] else { return false }
        guard let value = queue.consume() else { return false }
        selfClosingOccurrences[tagName] = queue
        return value
    }

    mutating func consumeBooleanAttribute(for attrName: [UInt8]) -> Bool {
        guard let index = booleanAttributeIndex(for: attrName[...]) else { return false }
        return consumeBooleanAttribute(index: index)
    }

    mutating func consumeBooleanAttribute(index: Int) -> Bool {
        var queue = booleanAttributeOccurrences[index]
        guard let value = queue.consume() else { return false }
        booleanAttributeOccurrences[index] = queue
        return value
    }

    mutating func consumeBooleanAttributeOptional(index: Int) -> Bool? {
        var queue = booleanAttributeOccurrences[index]
        guard let value = queue.consume() else { return nil }
        booleanAttributeOccurrences[index] = queue
        return value
    }

    fileprivate mutating func recordSelfClosing(tagName: [UInt8], isSelfClosing: Bool) {
        var queue = selfClosingOccurrences[tagName, default: OccurrenceQueue()]
        queue.append(isSelfClosing)
        selfClosingOccurrences[tagName] = queue
    }

    fileprivate mutating func recordBooleanAttribute(index: Int, isBoolean: Bool) {
        booleanAttributeOccurrences[index].append(isBoolean)
    }

    @inline(__always)
    private func isWhitespace(_ byte: UInt8) -> Bool {
        return isWhitespaceTable[Int(byte)]
    }

    @inline(__always)
    private func isNameStart(_ byte: UInt8) -> Bool {
        return isNameStartTable[Int(byte)]
    }

    @inline(__always)
    private func isNameChar(_ byte: UInt8) -> Bool {
        return isNameCharTable[Int(byte)]
    }

    fileprivate mutating func scan(_ bytes: [UInt8], settings: ParseSettings) {
        if scanUsingC(bytes, settings: settings) {
            return
        }
        let count = bytes.count
        let preserveTagCase = settings.preservesTagCase()
        var i = 0
        var lowerNameBuffer: [UInt8] = []
        lowerNameBuffer.reserveCapacity(32)
        bytes.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            @inline(__always)
            func advanceToNextTag(from start: Int) -> Int? {
                let remaining = count - start
                if remaining <= 0 {
                    return nil
                }
                guard let found = memchr(base.advanced(by: start), 0x3C, remaining) else {
                    return nil
                }
                return Int(bitPattern: found) - Int(bitPattern: base)
            }
            while i < count {
                if base[i] != 0x3C { // <
                    if let next = advanceToNextTag(from: i + 1) {
                        i = next
                    } else {
                        break
                    }
                    continue
                }
                if i + 1 >= count {
                    break
                }
                let next = base[i + 1]
                if next == 0x21 { // !
                    if i + 3 < count && base[i + 2] == 0x2D && base[i + 3] == 0x2D { // <!--
                        var j = i + 4
                        while j + 2 < count {
                            if base[j] == 0x2D && base[j + 1] == 0x2D && base[j + 2] == 0x3E {
                                i = j + 3
                                break
                            }
                            j += 1
                        }
                        if j + 2 >= count {
                            break
                        }
                        continue
                    }
                    var j = i + 2
                    while j < count && base[j] != 0x3E {
                        j += 1
                    }
                    i = min(j + 1, count)
                    continue
                }
                if next == 0x2F { // /
                    var j = i + 2
                    while j < count && base[j] != 0x3E {
                        j += 1
                    }
                    i = min(j + 1, count)
                    continue
                }
                if next == 0x3F { // ?
                    var j = i + 2
                    while j + 1 < count {
                        if base[j] == 0x3F && base[j + 1] == 0x3E {
                            i = j + 2
                            break
                        }
                        j += 1
                    }
                    if j + 1 >= count {
                        break
                    }
                    continue
                }
                if !isNameChar(next) {
                    i += 1
                    continue
                }
                let nameStart = i + 1
                var nameEnd = nameStart
                var sawUppercase = false
                while nameEnd < count && isNameChar(base[nameEnd]) {
                    let b = base[nameEnd]
                    if b >= 0x41 && b <= 0x5A {
                        sawUppercase = true
                    }
                    nameEnd += 1
                }
                if nameEnd == nameStart {
                    i += 1
                    continue
                }
                let tagId = Token.Tag.tagIdForAsciiLowercaseBytes(base, nameStart, nameEnd)
                var j = nameEnd
                var isSelfClosing = false
                var quote: UInt8? = nil
                var lastNonWhitespace: UInt8? = nil
                while j < count {
                    let byte = base[j]
                    if let q = quote {
                        if byte == q {
                            quote = nil
                        }
                    } else {
                        if byte == 0x22 || byte == 0x27 { // " or '
                            quote = byte
                        } else if byte == 0x3E { // >
                            if lastNonWhitespace == 0x2F {
                                isSelfClosing = true
                            }
                            break
                        } else if !isWhitespace(byte) {
                            lastNonWhitespace = byte
                        }
                    }
                    j += 1
                }
                if preserveTagCase {
                    let normalizedName = settings.normalizeTag(Array(bytes[nameStart..<nameEnd]))
                    recordSelfClosing(tagName: normalizedName, isSelfClosing: isSelfClosing)
                } else if tagId == nil {
                    let lowerNameArray: [UInt8]
                    if sawUppercase {
                        lowerNameBuffer.removeAll(keepingCapacity: true)
                        var offset = nameStart
                        while offset < nameEnd {
                            let b = base[offset]
                            lowerNameBuffer.append(asciiLower(b))
                            offset += 1
                        }
                        lowerNameArray = lowerNameBuffer
                    } else {
                        lowerNameArray = Array(bytes[nameStart..<nameEnd])
                    }
                    recordSelfClosing(tagName: lowerNameArray, isSelfClosing: isSelfClosing)
                }

                var attrIndex = nameEnd
                while attrIndex < count {
                    while attrIndex < count && isWhitespace(base[attrIndex]) {
                        attrIndex += 1
                    }
                    if attrIndex >= count {
                        break
                    }
                    if base[attrIndex] == 0x3E { // >
                        attrIndex += 1
                        break
                    }
                    if base[attrIndex] == 0x2F && attrIndex + 1 < count && base[attrIndex + 1] == 0x3E { // />
                        attrIndex += 2
                        break
                    }
                    let attrStart = attrIndex
                    while attrIndex < count
                            && !isWhitespace(base[attrIndex])
                            && base[attrIndex] != 0x3D
                            && base[attrIndex] != 0x3E
                            && base[attrIndex] != 0x2F {
                        attrIndex += 1
                    }
                    if attrStart == attrIndex {
                        break
                    }
                    let booleanIndex = booleanAttributeIndex(bytes: base, start: attrStart, end: attrIndex)
                    while attrIndex < count && isWhitespace(base[attrIndex]) {
                        attrIndex += 1
                    }
                    if attrIndex < count && base[attrIndex] == 0x3D { // =
                        attrIndex += 1
                        while attrIndex < count && isWhitespace(base[attrIndex]) {
                            attrIndex += 1
                        }
                        if attrIndex >= count {
                            break
                        }
                        if base[attrIndex] == 0x22 || base[attrIndex] == 0x27 {
                            let quote = base[attrIndex]
                            attrIndex += 1
                            while attrIndex < count && base[attrIndex] != quote {
                                attrIndex += 1
                            }
                            if attrIndex < count {
                                attrIndex += 1
                            }
                        } else {
                            while attrIndex < count && !isWhitespace(base[attrIndex]) && base[attrIndex] != 0x3E {
                                attrIndex += 1
                            }
                        }
                        if let booleanIndex {
                            recordBooleanAttribute(index: booleanIndex, isBoolean: false)
                        }
                    } else {
                        if let booleanIndex {
                            recordBooleanAttribute(index: booleanIndex, isBoolean: true)
                        }
                    }
                }
                i = min(j + 1, count)
            }
        }
    }
}

@usableFromInline
final class Libxml2LazyState {
    let input: [UInt8]
    let baseUri: [UInt8]
    let settings: ParseSettings
    let errors: ParseErrorList
    let forceLibxml2: Bool
    let fastScan: Bool

    init(
        input: [UInt8],
        baseUri: [UInt8],
        settings: ParseSettings,
        errors: ParseErrorList,
        forceLibxml2: Bool,
        fastScan: Bool
    ) {
        self.input = input
        self.baseUri = baseUri
        self.settings = settings
        self.errors = errors
        self.forceLibxml2 = forceLibxml2
        self.fastScan = fastScan
    }
}

private struct HtmlScanHintsCContext {
    var hints: HtmlScanHints
    var lowerNameBuffer: [UInt8]

    init(hints: HtmlScanHints) {
        self.hints = hints
        self.lowerNameBuffer = []
        self.lowerNameBuffer.reserveCapacity(32)
    }
}

@inline(__always)
private func scanHintsCEnabled(settings: ParseSettings) -> Bool {
    return !settings.preservesTagCase()
}

@inline(__always)
private func fallbackCEnabled() -> Bool {
    return true
}

@inline(__always)
private func booleanHintsEnabled() -> Bool {
    return true
}

@inline(__always)
private func booleanCollectEnabled() -> Bool {
    return false
}

private let swiftsoupRecordSelfClosing: swiftsoup_record_selfclosing_fn = { name, length, isSelfClosing, ctx in
    guard let name, let ctx, length > 0 else { return }
    let ctxPtr = ctx.assumingMemoryBound(to: HtmlScanHintsCContext.self)
    let lengthInt = Int(length)
    if Token.Tag.tagIdForAsciiLowercaseBytes(name, 0, lengthInt) != nil {
        return
    }
    var lowerNameBuffer = ctxPtr.pointee.lowerNameBuffer
    lowerNameBuffer.removeAll(keepingCapacity: true)
    lowerNameBuffer.reserveCapacity(lengthInt)
    var i = 0
    while i < lengthInt {
        lowerNameBuffer.append(asciiLower(name[i]))
        i += 1
    }
    ctxPtr.pointee.lowerNameBuffer = lowerNameBuffer
    ctxPtr.pointee.hints.recordSelfClosing(tagName: lowerNameBuffer, isSelfClosing: isSelfClosing != 0)
}

private let swiftsoupRecordSelfClosingLowercase: swiftsoup_record_selfclosing_fn = { name, length, isSelfClosing, ctx in
    guard let name, let ctx, length > 0 else { return }
    let ctxPtr = ctx.assumingMemoryBound(to: HtmlScanHintsCContext.self)
    let lengthInt = Int(length)
    if Token.Tag.tagIdForAsciiLowercaseBytes(name, 0, lengthInt) != nil {
        return
    }
    let lowerName = Array(UnsafeBufferPointer(start: name, count: lengthInt))
    ctxPtr.pointee.hints.recordSelfClosing(tagName: lowerName, isSelfClosing: isSelfClosing != 0)
}

private let swiftsoupRecordBoolean: swiftsoup_record_boolean_index_fn = { index, isBoolean, ctx in
    guard let ctx, index >= 0 else { return }
    let ctxPtr = ctx.assumingMemoryBound(to: HtmlScanHintsCContext.self)
    ctxPtr.pointee.hints.recordBooleanAttribute(index: Int(index), isBoolean: isBoolean != 0)
}

@inline(__always)
private func recordBooleanPairs(_ pairs: UnsafePointer<Int32>?, _ count: Int32, _ hints: inout HtmlScanHints) {
    guard let pairs, count > 0 else { return }
    var i = 0
    while i < count {
        let base = i * 2
        let index = Int(pairs[base])
        let isBoolean = pairs[base + 1] != 0
        hints.recordBooleanAttribute(index: index, isBoolean: isBoolean)
        i += 1
    }
}

private extension HtmlScanHints {
    mutating func scanUsingC(_ bytes: [UInt8], settings: ParseSettings) -> Bool {
        guard scanHintsCEnabled(settings: settings) else { return false }
        var ctx = HtmlScanHintsCContext(hints: self)
        bytes.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            withUnsafeMutablePointer(to: &ctx) { ctxPtr in
                if booleanHintsEnabled() {
                    if booleanCollectEnabled() {
                        var pairs: UnsafeMutablePointer<Int32>? = nil
                        var count: Int32 = 0
                        swiftsoup_scan_hints_collect(
                            base,
                            Int32(buffer.count),
                            swiftsoupRecordSelfClosing,
                            ctxPtr,
                            &pairs,
                            &count
                        )
                        if let pairs {
                            recordBooleanPairs(UnsafePointer(pairs), count, &ctxPtr.pointee.hints)
                            swiftsoup_free_int32(pairs)
                        }
                    } else {
                        swiftsoup_scan_hints(
                            base,
                            Int32(buffer.count),
                            swiftsoupRecordSelfClosing,
                            swiftsoupRecordBoolean,
                            ctxPtr
                        )
                    }
                } else {
                    swiftsoup_scan_hints(
                        base,
                        Int32(buffer.count),
                        swiftsoupRecordSelfClosing,
                        nil,
                        ctxPtr
                    )
                }
            }
        }
        self = ctx.hints
        return true
    }
}

private let booleanAttributeNames = Attribute.booleanAttributes.multiByteChars
private let booleanAttributeMaxLength = booleanAttributeNames.map { $0.count }.max() ?? 0
private let booleanAttributeLengthLookup: [Bool] = {
    var lookup = [Bool](repeating: false, count: booleanAttributeMaxLength + 1)
    for entry in booleanAttributeNames {
        lookup[entry.count] = true
    }
    return lookup
}()
private let booleanAttributeBuckets: [[Int]] = {
    var buckets = Array(repeating: [Int](), count: 128)
    for (index, entry) in booleanAttributeNames.enumerated() {
        if let first = entry.first, first < 0x80 {
            buckets[Int(first)].append(index)
        }
    }
    return buckets
}()

@inline(__always)
private func asciiLower(_ b: UInt8) -> UInt8 {
    return asciiLowerTable[Int(b)]
}

@inline(__always)
private func equalsAsciiLower(_ slice: ArraySlice<UInt8>, _ target: [UInt8]) -> Bool {
    if slice.count != target.count {
        return false
    }
    var idx = 0
    var i = slice.startIndex
    let end = slice.endIndex
    while i < end {
        let byte = slice[i]
        if byte >= 0x80 {
            return false
        }
        if asciiLower(byte) != target[idx] {
            return false
        }
        idx += 1
        i = slice.index(after: i)
    }
    return true
}

@inline(__always)
private func equalsIgnoreCaseAscii(_ lhs: [UInt8], _ rhs: [UInt8]) -> Bool {
    if lhs.count != rhs.count {
        return false
    }
    var i = 0
    while i < lhs.count {
        let a = lhs[i]
        let b = rhs[i]
        if a >= 0x80 || b >= 0x80 {
            return false
        }
        if asciiLower(a) != asciiLower(b) {
            return false
        }
        i += 1
    }
    return true
}

@inline(__always)
private func booleanAttributeIndex(for slice: ArraySlice<UInt8>) -> Int? {
    let length = slice.count
    if length >= booleanAttributeLengthLookup.count || !booleanAttributeLengthLookup[length] {
        return nil
    }
    guard let first = slice.first else { return nil }
    if first >= 0x80 {
        return nil
    }
    let bucketIndex = Int(asciiLower(first))
    guard bucketIndex < booleanAttributeBuckets.count else { return nil }
    for index in booleanAttributeBuckets[bucketIndex] {
        let entry = booleanAttributeNames[index]
        if entry.count != length {
            continue
        }
        if equalsAsciiLower(slice, entry) {
            return index
        }
    }
    return nil
}

@inline(__always)
private func booleanAttributeIndex(bytes: UnsafePointer<UInt8>, start: Int, end: Int) -> Int? {
    let length = end - start
    if length <= 0 || length >= booleanAttributeLengthLookup.count || !booleanAttributeLengthLookup[length] {
        return nil
    }
    let first = bytes[start]
    if first >= 0x80 {
        return nil
    }
    let bucketIndex = Int(asciiLower(first))
    guard bucketIndex < booleanAttributeBuckets.count else { return nil }
    for index in booleanAttributeBuckets[bucketIndex] {
        let entry = booleanAttributeNames[index]
        if entry.count != length {
            continue
        }
        var matches = true
        var offset = 0
        while offset < length {
            let b = bytes[start + offset]
            if b >= 0x80 || asciiLower(b) != entry[offset] {
                matches = false
                break
            }
            offset += 1
        }
        if matches {
            return index
        }
    }
    return nil
}

@inline(__always)
private func fallbackReason(from cReason: swiftsoup_fallback_reason) -> Libxml2FallbackReason? {
    switch cReason {
    case SWIFTSOUP_FALLBACK_NONE:
        return nil
    case SWIFTSOUP_FALLBACK_NO_TAG_DELIMITER:
        return .noTagDelimiter
    case SWIFTSOUP_FALLBACK_CONTAINS_NULL:
        return .containsNull
    case SWIFTSOUP_FALLBACK_COMMENT_DASH_DASH_DASH:
        return .commentDashDashDash
    case SWIFTSOUP_FALLBACK_MALFORMED_TAG:
        return .malformedTag
    case SWIFTSOUP_FALLBACK_NON_ASCII_TAG_NAME:
        return .nonAsciiTagName
    case SWIFTSOUP_FALLBACK_NAMESPACED_TAG:
        return .namespacedTag
    case SWIFTSOUP_FALLBACK_TABLE_HEURISTICS:
        return .tableHeuristics
    case SWIFTSOUP_FALLBACK_HEAD_BODY_PLACEMENT:
        return .headBodyPlacement
    case SWIFTSOUP_FALLBACK_FORMATTING_MISMATCH:
        return .formattingMismatch
    case SWIFTSOUP_FALLBACK_VOID_END_TAG:
        return .voidEndTag
    case SWIFTSOUP_FALLBACK_NON_ASCII_ATTRIBUTE_NAME:
        return .nonAsciiAttributeName
    case SWIFTSOUP_FALLBACK_MALFORMED_ATTRIBUTE:
        return .malformedAttribute
    case SWIFTSOUP_FALLBACK_RAW_TEXT_UNTERMINATED:
        return .rawTextUnterminated
    default:
        return .unknown
    }
}

private enum Libxml2ScanTags {
    static let table: [UInt8] = [0x74, 0x61, 0x62, 0x6C, 0x65]
    static let tbody: [UInt8] = [0x74, 0x62, 0x6F, 0x64, 0x79]
    static let thead: [UInt8] = [0x74, 0x68, 0x65, 0x61, 0x64]
    static let tfoot: [UInt8] = [0x74, 0x66, 0x6F, 0x6F, 0x74]
    static let tr: [UInt8] = [0x74, 0x72]
    static let td: [UInt8] = [0x74, 0x64]
    static let th: [UInt8] = [0x74, 0x68]
    static let p: [UInt8] = [0x70]
    static let area: [UInt8] = [0x61, 0x72, 0x65, 0x61]
    static let base: [UInt8] = [0x62, 0x61, 0x73, 0x65]
    static let br: [UInt8] = [0x62, 0x72]
    static let caption: [UInt8] = [0x63, 0x61, 0x70, 0x74, 0x69, 0x6F, 0x6E]
    static let colgroup: [UInt8] = [0x63, 0x6F, 0x6C, 0x67, 0x72, 0x6F, 0x75, 0x70]
    static let col: [UInt8] = [0x63, 0x6F, 0x6C]
    static let embed: [UInt8] = [0x65, 0x6D, 0x62, 0x65, 0x64]
    static let hgroup: [UInt8] = [0x68, 0x67, 0x72, 0x6F, 0x75, 0x70]
    static let hr: [UInt8] = [0x68, 0x72]
    static let img: [UInt8] = [0x69, 0x6D, 0x67]
    static let input: [UInt8] = [0x69, 0x6E, 0x70, 0x75, 0x74]
    static let link: [UInt8] = [0x6C, 0x69, 0x6E, 0x6B]
    static let meta: [UInt8] = [0x6D, 0x65, 0x74, 0x61]
    static let param: [UInt8] = [0x70, 0x61, 0x72, 0x61, 0x6D]
    static let script: [UInt8] = [0x73, 0x63, 0x72, 0x69, 0x70, 0x74]
    static let source: [UInt8] = [0x73, 0x6F, 0x75, 0x72, 0x63, 0x65]
    static let style: [UInt8] = [0x73, 0x74, 0x79, 0x6C, 0x65]
    static let select: [UInt8] = [0x73, 0x65, 0x6C, 0x65, 0x63, 0x74]
    static let textarea: [UInt8] = [0x74, 0x65, 0x78, 0x74, 0x61, 0x72, 0x65, 0x61]
    static let title: [UInt8] = [0x74, 0x69, 0x74, 0x6C, 0x65]
    static let track: [UInt8] = [0x74, 0x72, 0x61, 0x63, 0x6B]
    static let wbr: [UInt8] = [0x77, 0x62, 0x72]
}

private let asciiLowerTable: [UInt8] = {
    var table = [UInt8](repeating: 0, count: 256)
    for i in 0..<256 {
        let b = UInt8(i)
        table[i] = (b >= 65 && b <= 90) ? (b + 32) : b
    }
    return table
}()

private let isWhitespaceTable: [Bool] = {
    var table = [Bool](repeating: false, count: 256)
    table[0x20] = true
    table[0x09] = true
    table[0x0A] = true
    table[0x0D] = true
    return table
}()

private let isNameStartTable: [Bool] = {
    var table = [Bool](repeating: false, count: 256)
    for i in 65...90 { table[i] = true }
    for i in 97...122 { table[i] = true }
    table[0x3A] = true
    table[0x5F] = true
    return table
}()

private let isNameCharTable: [Bool] = {
    var table = isNameStartTable
    for i in 48...57 { table[i] = true }
    table[0x2D] = true
    table[0x2E] = true
    return table
}()

enum Libxml2Backend {
    private static let initialized: Void = {
        xmlInitParser()
    }()
    private static let fragmentWrapperPrefix: [UInt8] = Array("<html><body>".utf8)
    private static let fragmentWrapperSuffix: [UInt8] = Array("</body></html>".utf8)
    private static let xmlFragmentWrapperPrefix: [UInt8] = Array("<root>".utf8)
    private static let xmlFragmentWrapperSuffix: [UInt8] = Array("</root>".utf8)

    private struct Libxml2StartTagOverrides {
        var attributes: [UnsafeMutableRawPointer: Attributes]
        var tagNames: [UnsafeMutableRawPointer: [UInt8]]
    }
    private static let rawTextTagNames: [[UInt8]] = [
        UTF8Arrays.script,
        UTF8Arrays.style,
        UTF8Arrays.textarea,
        UTF8Arrays.xmp,
        UTF8Arrays.plaintext,
        UTF8Arrays.title
    ]

    @inline(__always)
    private static func sampleSnippet(_ bytes: [UInt8]) -> String {
        let limit = min(bytes.count, 200)
        let prefix = bytes.prefix(limit)
        let text = String(decoding: prefix, as: UTF8.self)
        return limit < bytes.count ? "\(text)…" : text
    }

    private static let ltEntityBytes: [UInt8] = [0x26, 0x6C, 0x74, 0x3B] // "&lt;"
    private static let htmlVoidTags: Set<[UInt8]> = Set([
        "meta", "link", "base", "frame", "img", "br", "wbr", "embed", "hr", "input", "keygen", "col",
        "command", "device", "area", "basefont", "bgsound", "menuitem", "param", "source", "track"
    ].map { $0.utf8Array })

    private static func hasLeadingHtmlComment(_ input: [UInt8]) -> Bool {
        var i = 0
        while i < input.count, input[i].isWhitespace {
            i += 1
        }
        guard i + 3 < input.count else { return false }
        return input[i] == 0x3C && input[i + 1] == 0x21 && input[i + 2] == 0x2D && input[i + 3] == 0x2D
    }

#if canImport(CLibxml2) || canImport(libxml2)
    @inline(__always)
    private static func normalizeTagName(_ rawName: [UInt8], settings: ParseSettings) -> [UInt8] {
        return containsUppercaseAscii(rawName) ? settings.normalizeTag(rawName) : rawName
    }

    @inline(__always)
    private static func isAsciiLetter(_ b: UInt8) -> Bool {
        return (b >= 0x41 && b <= 0x5A) || (b >= 0x61 && b <= 0x7A)
    }

    private static func sanitizeHtmlInputForLibxml2(_ input: [UInt8]) -> [UInt8] {
        var output: [UInt8]? = nil
        var i = 0
        if input.count >= 3, input[0] == 0xEF, input[1] == 0xBB, input[2] == 0xBF {
            var scratch: [UInt8] = []
            scratch.reserveCapacity(input.count)
            output = scratch
            i = 3
        }
        var lowerNameBuffer: [UInt8] = []
        lowerNameBuffer.reserveCapacity(16)
        while i < input.count {
            let b = input[i]
            if b == 0x3C { // '<'
                if i + 1 < input.count, input[i + 1] == 0x2F { // '</'
                    var j = i + 2
                    while j < input.count && isWhitespaceTable[Int(input[j])] {
                        j += 1
                    }
                    let nameStart = j
                    while j < input.count && isNameCharTable[Int(input[j])] {
                        j += 1
                    }
                    if nameStart < j {
                        let rawName = input[nameStart..<j]
                        var sawUppercase = false
                        for byte in rawName {
                            if byte >= 0x41 && byte <= 0x5A {
                                sawUppercase = true
                                break
                            }
                        }
                        let name: [UInt8]
                        if sawUppercase {
                            lowerNameBuffer.removeAll(keepingCapacity: true)
                            lowerNameBuffer.reserveCapacity(rawName.count)
                            for byte in rawName {
                                lowerNameBuffer.append(asciiLowerTable[Int(byte)])
                            }
                            name = lowerNameBuffer
                        } else {
                            name = Array(rawName)
                        }
                        if htmlVoidTags.contains(name) {
                            if output == nil {
                                var scratch: [UInt8] = []
                                scratch.reserveCapacity(input.count + 8)
                                if i > 0 {
                                    scratch.append(contentsOf: input[0..<i])
                                }
                                output = scratch
                            }
                            while j < input.count && input[j] != 0x3E {
                                j += 1
                            }
                            i = min(j + 1, input.count)
                            continue
                        }
                    }
                }
                let next = (i + 1 < input.count) ? input[i + 1] : nil
                let nextNext = (i + 2 < input.count) ? input[i + 2] : nil
                if shouldEscapeTagOpen(next: next, nextNext: nextNext) {
                    if output == nil {
                        var scratch: [UInt8] = []
                        scratch.reserveCapacity(input.count + 8)
                        if i > 0 {
                            scratch.append(contentsOf: input[0..<i])
                        }
                        output = scratch
                    }
                    output?.append(contentsOf: ltEntityBytes)
                    i += 1
                    continue
                }
            }
            if output != nil {
                output?.append(b)
            }
            i += 1
        }
        return output ?? input
    }

    private static func sanitizeXmlInputForLibxml2(_ input: [UInt8], settings: ParseSettings) -> [UInt8] {
        let (stripped, strippedChanged) = stripUnmatchedXmlEndTags(input, settings: settings)
        guard !stripped.isEmpty else { return stripped }
        var output: [UInt8] = []
        output.reserveCapacity(stripped.count + 16)
        var inTag = false
        var quote: UInt8? = nil
        var changed = false
        var i = 0
        while i < stripped.count {
            let b = stripped[i]
            if !inTag {
                if b == 0x3C { // '<'
                    inTag = true
                    quote = nil
                }
                output.append(b)
                i += 1
                continue
            }
            if let q = quote {
                output.append(b)
                if b == q {
                    quote = nil
                }
                i += 1
                continue
            }
            if b == 0x22 || b == 0x27 { // '"' or '\''
                quote = b
                output.append(b)
                i += 1
                continue
            }
            if b == 0x3E { // '>'
                inTag = false
                output.append(b)
                i += 1
                continue
            }
            if b == 0x3D { // '='
                output.append(b)
                i += 1
                while i < stripped.count && isWhitespaceTable[Int(stripped[i])] {
                    output.append(stripped[i])
                    i += 1
                }
                if i >= stripped.count {
                    break
                }
                let next = stripped[i]
                if next == 0x22 || next == 0x27 { // already quoted
                    continue
                }
                if next == 0x3E { // end tag
                    continue
                }
                if next == 0x2F && i + 1 < stripped.count && stripped[i + 1] == 0x3E { // />
                    continue
                }
                // Unquoted attribute value; quote it until whitespace or tag end.
                output.append(0x22) // "
                var k = i
                while k < stripped.count {
                    let c = stripped[k]
                    if isWhitespaceTable[Int(c)] || c == 0x3E { break }
                    if c == 0x2F && k + 1 < stripped.count && stripped[k + 1] == 0x3E { break }
                    output.append(c)
                    k += 1
                }
                output.append(0x22)
                changed = true
                i = k
                continue
            }
            output.append(b)
            i += 1
        }
        return (changed || strippedChanged) ? output : input
    }

    private static func stripUnmatchedXmlEndTags(_ input: [UInt8], settings: ParseSettings) -> ([UInt8], Bool) {
        guard !input.isEmpty else { return (input, false) }
        var output: [UInt8] = []
        output.reserveCapacity(input.count)
        var stack: [[UInt8]] = []
        var i = 0
        var changed = false

        @inline(__always)
        func normalized(_ name: [UInt8]) -> [UInt8] {
            return containsUppercaseAscii(name) ? settings.normalizeTag(name) : name
        }

        @inline(__always)
        func scanTagEnd(from start: Int) -> Int {
            var idx = start
            var quote: UInt8? = nil
            while idx < input.count {
                let b = input[idx]
                if let q = quote {
                    if b == q { quote = nil }
                } else {
                    if b == 0x22 || b == 0x27 {
                        quote = b
                    } else if b == 0x3E {
                        return idx + 1
                    }
                }
                idx += 1
            }
            return input.count
        }

        @inline(__always)
        func isSelfClosingTag(start: Int, end: Int) -> Bool {
            var idx = end - 1
            while idx > start && isWhitespaceTable[Int(input[idx])] {
                idx -= 1
            }
            return idx > start && input[idx] == 0x2F
        }

        while i < input.count {
            let b = input[i]
            if b != 0x3C { // '<'
                output.append(b)
                i += 1
                continue
            }
            if i + 1 >= input.count {
                output.append(b)
                break
            }
            let next = input[i + 1]
            if next == 0x21 { // '!' comment/cdata/doctype
                if i + 3 < input.count && input[i + 2] == 0x2D && input[i + 3] == 0x2D { // <!--
                    var j = i + 4
                    while j + 2 < input.count {
                        if input[j] == 0x2D && input[j + 1] == 0x2D && input[j + 2] == 0x3E {
                            j += 3
                            break
                        }
                        j += 1
                    }
                    let end = min(j, input.count)
                    output.append(contentsOf: input[i..<end])
                    i = end
                    continue
                }
                if i + 8 < input.count,
                   input[i + 2] == 0x5B,
                   input[i + 3] == 0x43,
                   input[i + 4] == 0x44,
                   input[i + 5] == 0x41,
                   input[i + 6] == 0x54,
                   input[i + 7] == 0x41,
                   input[i + 8] == 0x5B { // <![CDATA[
                    var j = i + 9
                    while j + 2 < input.count {
                        if input[j] == 0x5D && input[j + 1] == 0x5D && input[j + 2] == 0x3E {
                            j += 3
                            break
                        }
                        j += 1
                    }
                    let end = min(j, input.count)
                    output.append(contentsOf: input[i..<end])
                    i = end
                    continue
                }
                let end = scanTagEnd(from: i + 2)
                output.append(contentsOf: input[i..<end])
                i = end
                continue
            }
            if next == 0x3F { // '?'
                var j = i + 2
                while j + 1 < input.count {
                    if input[j] == 0x3F && input[j + 1] == 0x3E {
                        j += 2
                        break
                    }
                    j += 1
                }
                let end = min(j, input.count)
                output.append(contentsOf: input[i..<end])
                i = end
                continue
            }
            if next == 0x2F { // end tag
                var j = i + 2
                while j < input.count && isWhitespaceTable[Int(input[j])] {
                    j += 1
                }
                let nameStart = j
                while j < input.count && isNameCharTable[Int(input[j])] {
                    j += 1
                }
                let tagEnd = scanTagEnd(from: j)
                if nameStart == j {
                    output.append(contentsOf: input[i..<tagEnd])
                    i = tagEnd
                    continue
                }
                let rawName = Array(input[nameStart..<j])
                let name = normalized(rawName)
                if let idx = stack.lastIndex(of: name) {
                    stack.removeSubrange(idx..<stack.count)
                    output.append(contentsOf: input[i..<tagEnd])
                } else {
                    changed = true
                }
                i = tagEnd
                continue
            }
            if !isNameCharTable[Int(next)] {
                output.append(b)
                i += 1
                continue
            }
            var j = i + 1
            while j < input.count && isNameCharTable[Int(input[j])] {
                j += 1
            }
            let nameBytes = Array(input[(i + 1)..<j])
            let tagEnd = scanTagEnd(from: j)
            if !isSelfClosingTag(start: i + 1, end: tagEnd - 1), !nameBytes.isEmpty {
                stack.append(normalized(nameBytes))
            }
            output.append(contentsOf: input[i..<tagEnd])
            i = tagEnd
        }

        return changed ? (output, true) : (input, false)
    }

    private static func containsEndTagForHtmlVoidTags(_ input: [UInt8]) -> Bool {
        guard !input.isEmpty else { return false }
        var i = 0

        @inline(__always)
        func scanTagEnd(from start: Int) -> Int {
            var idx = start
            var quote: UInt8? = nil
            while idx < input.count {
                let b = input[idx]
                if let q = quote {
                    if b == q { quote = nil }
                } else {
                    if b == 0x22 || b == 0x27 {
                        quote = b
                    } else if b == 0x3E {
                        return idx + 1
                    }
                }
                idx += 1
            }
            return input.count
        }

        @inline(__always)
        func loweredAscii(_ bytes: [UInt8]) -> [UInt8] {
            var lowered = bytes
            for idx in lowered.indices {
                lowered[idx] = asciiLowerTable[Int(lowered[idx])]
            }
            return lowered
        }

        while i < input.count {
            let b = input[i]
            if b != 0x3C { // '<'
                i += 1
                continue
            }
            if i + 1 >= input.count {
                return false
            }
            let next = input[i + 1]
            if next == 0x21 { // '!' comment/cdata/doctype
                if i + 3 < input.count && input[i + 2] == 0x2D && input[i + 3] == 0x2D { // <!--
                    var j = i + 4
                    while j + 2 < input.count {
                        if input[j] == 0x2D && input[j + 1] == 0x2D && input[j + 2] == 0x3E {
                            j += 3
                            break
                        }
                        j += 1
                    }
                    i = min(j, input.count)
                    continue
                }
                if i + 8 < input.count,
                   input[i + 2] == 0x5B,
                   input[i + 3] == 0x43,
                   input[i + 4] == 0x44,
                   input[i + 5] == 0x41,
                   input[i + 6] == 0x54,
                   input[i + 7] == 0x41,
                   input[i + 8] == 0x5B { // <![CDATA[
                    var j = i + 9
                    while j + 2 < input.count {
                        if input[j] == 0x5D && input[j + 1] == 0x5D && input[j + 2] == 0x3E {
                            j += 3
                            break
                        }
                        j += 1
                    }
                    i = min(j, input.count)
                    continue
                }
                i = scanTagEnd(from: i + 2)
                continue
            }
            if next == 0x3F { // '?'
                var j = i + 2
                while j + 1 < input.count {
                    if input[j] == 0x3F && input[j + 1] == 0x3E {
                        j += 2
                        break
                    }
                    j += 1
                }
                i = min(j, input.count)
                continue
            }
            if next == 0x2F { // end tag
                var j = i + 2
                while j < input.count && isWhitespaceTable[Int(input[j])] {
                    j += 1
                }
                let nameStart = j
                while j < input.count && isNameCharTable[Int(input[j])] {
                    j += 1
                }
                let tagEnd = scanTagEnd(from: j)
                if nameStart < j {
                    let rawName = Array(input[nameStart..<j])
                    let name = containsUppercaseAscii(rawName) ? loweredAscii(rawName) : rawName
                    if htmlVoidTags.contains(name) {
                        return true
                    }
                }
                i = tagEnd
                continue
            }
            i += 1
        }
        return false
    }

    private static func containsHtmlCommentDashDashDash(_ input: [UInt8]) -> Bool {
        guard input.count >= 5 else { return false }
        let limit = input.count - 4
        var i = 0
        while i < limit {
            if input[i] == 0x3C, // '<'
               input[i + 1] == 0x21, // '!'
               input[i + 2] == 0x2D, // '-'
               input[i + 3] == 0x2D, // '-'
               input[i + 4] == 0x2D { // '-'
                return true
            }
            i += 1
        }
        return false
    }

    private static func containsHtmlCdata(_ input: [UInt8]) -> Bool {
        guard input.count >= 9 else { return false }
        let limit = input.count - 8
        var i = 0
        while i < limit {
            if input[i] == 0x3C, // '<'
               input[i + 1] == 0x21, // '!'
               input[i + 2] == 0x5B, // '['
               input[i + 3] == 0x43, // 'C'
               input[i + 4] == 0x44, // 'D'
               input[i + 5] == 0x41, // 'A'
               input[i + 6] == 0x54, // 'T'
               input[i + 7] == 0x41, // 'A'
               input[i + 8] == 0x5B { // '['
                return true
            }
            i += 1
        }
        return false
    }

    private static func containsConditionalComment(_ input: [UInt8]) -> Bool {
        guard input.count >= 7 else { return false }
        let needle: [UInt8] = [0x3C, 0x21, 0x2D, 0x2D, 0x5B, 0x69, 0x66] // "<!--[if"
        let limit = input.count - needle.count
        var i = 0
        while i <= limit {
            if input[i] == needle[0],
               input[i + 1] == needle[1],
               input[i + 2] == needle[2],
               input[i + 3] == needle[3],
               input[i + 4] == needle[4],
               (input[i + 5] | 0x20) == needle[5],
               (input[i + 6] | 0x20) == needle[6] {
                return true
            }
            i += 1
        }
        return false
    }

    private static func containsXmlnsAttribute(_ input: [UInt8]) -> Bool {
        guard input.count >= 5 else { return false }
        let needle: [UInt8] = [0x78, 0x6D, 0x6C, 0x6E, 0x73] // "xmlns"
        let limit = input.count - needle.count
        var i = 0
        while i <= limit {
            if (input[i] | 0x20) == needle[0],
               (input[i + 1] | 0x20) == needle[1],
               (input[i + 2] | 0x20) == needle[2],
               (input[i + 3] | 0x20) == needle[3],
               (input[i + 4] | 0x20) == needle[4] {
                return true
            }
            i += 1
        }
        return false
    }

    private static func containsAnchorWithParagraph(_ input: [UInt8]) -> Bool {
        guard input.count >= 4 else { return false }
        var inAnchor = false
        var sawParagraphInAnchor = false
        var i = 0
        let count = input.count
        while i + 2 < count {
            if input[i] == 0x3C { // '<'
                let next = input[i + 1]
                let tagStart = i + (next == 0x2F ? 2 : 1)
                if tagStart < count {
                    let b = input[tagStart] | 0x20
                    if next == 0x2F {
                        if b == 0x61 { // </a>
                            if inAnchor && sawParagraphInAnchor {
                                return true
                            }
                            inAnchor = false
                            sawParagraphInAnchor = false
                        }
                    } else {
                        if b == 0x61 { // <a>
                            inAnchor = true
                            sawParagraphInAnchor = false
                        } else if b == 0x70, inAnchor { // <p> inside <a>
                            sawParagraphInAnchor = true
                        }
                    }
                }
            }
            i += 1
        }
        return false
    }

    @inline(__always)
    private static func shouldEscapeTagOpen(next: UInt8?, nextNext: UInt8?) -> Bool {
        guard let next else { return true }
        if next.isWhitespace || next == 0x3E { // ">" or whitespace
            return true
        }
        if next == 0x2F { // "/"
            guard let nextNext else { return true }
            if nextNext.isWhitespace || nextNext == 0x3E {
                return true
            }
            return !isAsciiLetter(nextNext)
        }
        if next == 0x21 || next == 0x3F { // "!" or "?"
            return false
        }
        return !isAsciiLetter(next)
    }

    @inline(__always)
    private static func tagForName(_ name: [UInt8]) -> Tag? {
        return try? Tag.valueOfNormalized(name, isSelfClosing: false)
    }

    private static func xmlDeclarationFromInput(
        _ input: [UInt8],
        baseUri: [UInt8],
        settings: ParseSettings
    ) -> XmlDeclaration? {
        guard !input.isEmpty else { return nil }
        var i = 0
        while i < input.count, input[i].isWhitespace {
            i += 1
        }
        guard i + 4 < input.count else { return nil }
        guard input[i] == 0x3C, input[i + 1] == 0x3F else { return nil } // <?
        let x = input[i + 2]
        let m = input[i + 3]
        let l = input[i + 4]
        guard x == 0x78 && m == 0x6D && l == 0x6C else {
            return nil
        }
        var end = i + 5
        while end + 1 < input.count {
            if input[end] == 0x3F && input[end + 1] == 0x3E {
                break
            }
            end += 1
        }
        guard end + 1 < input.count else { return nil }
        let attrStart = i + 5
        if attrStart > end { return nil }
        var attrs = Array(input[attrStart..<end])
        if !attrs.isEmpty {
            attrs = attrs.trim()
        }
        var tagBytes: [UInt8] = []
        tagBytes.reserveCapacity(attrs.count + 8)
        tagBytes.append(contentsOf: UTF8Arrays.tagStart)
        tagBytes.append(contentsOf: "xml".utf8Array)
        if !attrs.isEmpty {
            tagBytes.append(0x20)
            tagBytes.append(contentsOf: attrs)
        }
        tagBytes.append(contentsOf: UTF8Arrays.tagEnd)

        let collector = Libxml2AttributeCollector()
        collector.initialiseParse(tagBytes, baseUri, ParseErrorList.noTracking(), settings)
        _ = try? collector.runParser()
        let declName = "xml".utf8Array
        let declaration = XmlDeclaration(declName, baseUri, false)
        if let entry = collector.startTags.first {
            for attr in entry.attributes.asList() {
                _ = try? declaration.attr(attr.getKeyUTF8(), attr.getValueUTF8())
            }
        }
        return declaration
    }

    @inline(__always)
    private static func isScriptOrStyleParent(_ parent: xmlNodePtr?) -> Bool {
        guard let parent, parent.pointee.type == XML_ELEMENT_NODE else { return false }
        let name = bytesFromXmlChar(parent.pointee.name)
        return name == UTF8Arrays.script || name == UTF8Arrays.style
    }

    private static func preserveWhitespace(_ node: xmlNodePtr?, settings: ParseSettings) -> Bool {
        guard let node else { return false }
        guard let parent = node.pointee.parent, parent.pointee.type == XML_ELEMENT_NODE else { return false }
        let parentName = normalizeTagName(qualifiedName(for: parent), settings: settings)
        if let tag = tagForName(parentName), tag.preserveWhitespace() {
            return true
        }
        if let grand = parent.pointee.parent, grand.pointee.type == XML_ELEMENT_NODE {
            let grandName = normalizeTagName(qualifiedName(for: grand), settings: settings)
            if let tag = tagForName(grandName), tag.preserveWhitespace() {
                return true
            }
        }
        return false
    }

    private static func collectTextLibxml2Trimmed(
        from root: xmlNodePtr?,
        settings: ParseSettings,
        accum: StringBuilder
    ) -> (lastWasWhite: Bool, sawWhitespace: Bool) {
        var lastWasWhite = false
        var sawWhitespace = false
        guard let root else { return (false, false) }
        var stack: [xmlNodePtr] = [root]
        while let node = stack.popLast() {
            let type = node.pointee.type
            switch type {
            case XML_TEXT_NODE, XML_CDATA_SECTION_NODE:
                if isScriptOrStyleParent(node.pointee.parent) {
                    break
                }
                let text = bytesFromXmlChar(node.pointee.content)
                if text.isEmpty {
                    break
                }
                if preserveWhitespace(node, settings: settings) {
                    accum.append(text)
                    if let last = text.last {
                        lastWasWhite = (last == TokeniserStateVars.spaceByte)
                    }
                    break
                }
                StringUtil.appendNormalisedWhitespace(
                    accum,
                    string: text[...],
                    stripLeading: accum.isEmpty || lastWasWhite,
                    lastWasWhite: &lastWasWhite,
                    sawWhitespace: &sawWhitespace
                )
            case XML_ELEMENT_NODE:
                let name = normalizeTagName(qualifiedName(for: node), settings: settings)
                if let tag = tagForName(name) {
                    if !accum.isEmpty && (tag.isBlock() || Tag.isBr(tag)) && !lastWasWhite {
                        accum.append(UTF8Arrays.whitespace)
                        lastWasWhite = true
                        sawWhitespace = true
                    }
                }
                if let child = node.pointee.children {
                    var children: [xmlNodePtr] = []
                    var cursor: xmlNodePtr? = child
                    while let current = cursor {
                        children.append(current)
                        cursor = current.pointee.next
                    }
                    if !children.isEmpty {
                        for childNode in children.reversed() {
                            stack.append(childNode)
                        }
                    }
                }
            default:
                if let child = node.pointee.children {
                    var children: [xmlNodePtr] = []
                    var cursor: xmlNodePtr? = child
                    while let current = cursor {
                        children.append(current)
                        cursor = current.pointee.next
                    }
                    if !children.isEmpty {
                        for childNode in children.reversed() {
                            stack.append(childNode)
                        }
                    }
                }
            }
        }
        return (lastWasWhite, sawWhitespace)
    }

    private static func collectTextLibxml2Raw(
        from root: xmlNodePtr?,
        settings: ParseSettings,
        accum: StringBuilder
    ) {
        guard let root else { return }
        var stack: [xmlNodePtr] = [root]
        while let node = stack.popLast() {
            let type = node.pointee.type
            switch type {
            case XML_TEXT_NODE, XML_CDATA_SECTION_NODE:
                if isScriptOrStyleParent(node.pointee.parent) {
                    break
                }
                let text = bytesFromXmlChar(node.pointee.content)
                if !text.isEmpty {
                    accum.append(text)
                }
            case XML_ELEMENT_NODE:
                let name = normalizeTagName(qualifiedName(for: node), settings: settings)
                if let tag = tagForName(name), Tag.isBr(tag), !TextNode.lastCharIsWhitespace(accum) {
                    accum.append(UTF8Arrays.whitespace)
                }
                if let child = node.pointee.children {
                    var children: [xmlNodePtr] = []
                    var cursor: xmlNodePtr? = child
                    while let current = cursor {
                        children.append(current)
                        cursor = current.pointee.next
                    }
                    if !children.isEmpty {
                        for childNode in children.reversed() {
                            stack.append(childNode)
                        }
                    }
                }
            default:
                if let child = node.pointee.children {
                    var children: [xmlNodePtr] = []
                    var cursor: xmlNodePtr? = child
                    while let current = cursor {
                        children.append(current)
                        cursor = current.pointee.next
                    }
                    if !children.isEmpty {
                        for childNode in children.reversed() {
                            stack.append(childNode)
                        }
                    }
                }
            }
        }
    }

    private static func textFromLibxml2DocPtr(
        _ docPtr: htmlDocPtr,
        settings: ParseSettings,
        trim: Bool
    ) -> [UInt8] {
        let root = docPtr.pointee.children
        let accum = StringBuilder()
        if trim {
            let (lastWasWhite, sawWhitespace) = collectTextLibxml2Trimmed(
                from: root,
                settings: settings,
                accum: accum
            )
            if sawWhitespace, let first = accum.buffer.first, first.isWhitespace {
                return Array(accum.buffer.trim())
            }
            if sawWhitespace, lastWasWhite {
                accum.trimTrailingWhitespace()
            }
            return Array(accum.buffer)
        }
        collectTextLibxml2Raw(from: root, settings: settings, accum: accum)
        return Array(accum.buffer)
    }

    static func textFromLibxml2Document(_ doc: Document, trim: Bool) -> [UInt8]? {
        guard let state = doc.libxml2LazyState else { return nil }
        guard let docPtr = doc.libxml2DocPtr else { return nil }
        return textFromLibxml2DocPtr(docPtr, settings: state.settings, trim: trim)
    }

    static func textFromLibxml2Node(_ element: Element, trim: Bool) -> [UInt8]? {
        let doc = element.ownerDocument()
        let context = doc?.libxml2Context ?? element.libxml2Context
        if let doc {
            guard doc.isLibxml2Backend else { return nil }
            if doc.libxml2BackedDirty {
                return nil
            }
        } else {
            guard context != nil else { return nil }
        }
        guard let nodePtr = element.libxml2NodePtr else { return nil }
        let settings = doc?.treeBuilder?.settings ?? context?.settings ?? ParseSettings.htmlDefault
        return textFromLibxml2NodePtr(nodePtr, settings: settings, trim: trim)
    }

    static func ownTextFromLibxml2Node(_ element: Element) -> [UInt8]? {
        let doc = element.ownerDocument()
        let context = doc?.libxml2Context ?? element.libxml2Context
        if let doc {
            guard doc.isLibxml2Backend else { return nil }
            if doc.libxml2BackedDirty {
                return nil
            }
        } else {
            guard context != nil else { return nil }
        }
        guard let nodePtr = element.libxml2NodePtr else { return nil }
        let settings = doc?.treeBuilder?.settings ?? context?.settings ?? ParseSettings.htmlDefault
        return ownTextFromLibxml2NodePtr(nodePtr, settings: settings, element: element)
    }

    static func textFromLibxml2Doc(_ doc: Document, trim: Bool) -> [UInt8]? {
        guard let docPtr = doc.libxml2DocPtr else { return nil }
        let settings = doc.treeBuilder?.settings ?? ParseSettings.htmlDefault
        return textFromLibxml2DocPtr(docPtr, settings: settings, trim: trim)
    }

    private static func textFromLibxml2NodePtr(
        _ nodePtr: xmlNodePtr,
        settings: ParseSettings,
        trim: Bool
    ) -> [UInt8] {
        let accum = StringBuilder()
        if trim {
            let (lastWasWhite, sawWhitespace) = collectTextLibxml2Trimmed(
                from: nodePtr,
                settings: settings,
                accum: accum
            )
            if sawWhitespace, let first = accum.buffer.first, first.isWhitespace {
                return Array(accum.buffer.trim())
            }
            if sawWhitespace, lastWasWhite {
                accum.trimTrailingWhitespace()
            }
            return Array(accum.buffer)
        }
        collectTextLibxml2Raw(from: nodePtr, settings: settings, accum: accum)
        return Array(accum.buffer)
    }

    private static func ownTextFromLibxml2NodePtr(
        _ nodePtr: xmlNodePtr,
        settings: ParseSettings,
        element: Element
    ) -> [UInt8] {
        let accum = StringBuilder()
        let preserveWhitespace = Element.preserveWhitespace(element)
        var cursor: xmlNodePtr? = nodePtr.pointee.children
        while let current = cursor {
            switch current.pointee.type {
            case XML_TEXT_NODE, XML_CDATA_SECTION_NODE, XML_ENTITY_REF_NODE:
                let content = libxml2NodeContent(current)
                if preserveWhitespace {
                    accum.append(content)
                } else {
                    StringUtil.appendNormalisedWhitespace(
                        accum,
                        string: content,
                        stripLeading: TextNode.lastCharIsWhitespace(accum)
                    )
                }
            case XML_ELEMENT_NODE:
                if let name = current.pointee.name {
                    let tagName = bytesFromXmlChar(name)
                    if equalsIgnoreCaseAscii(tagName, UTF8Arrays.br),
                       !TextNode.lastCharIsWhitespace(accum) {
                        accum.append(UTF8Arrays.whitespace)
                    }
                }
            default:
                break
            }
            cursor = current.pointee.next
        }
        if let first = accum.buffer.first, first.isWhitespace {
            return Array(accum.buffer.trim())
        }
        accum.trimTrailingWhitespace()
        return Array(accum.buffer)
    }

    private static func buildStartTagOverrides(
        input: [UInt8],
        baseUri: [UInt8],
        settings: ParseSettings,
        docPtr: xmlDocPtr
    ) -> Libxml2StartTagOverrides {
        let collector = Libxml2AttributeCollector()
        collector.initialiseParse(input, baseUri, ParseErrorList.noTracking(), settings)
        try? collector.runParser()
        let entries = collector.startTags
        guard !entries.isEmpty else {
            return Libxml2StartTagOverrides(attributes: [:], tagNames: [:])
        }

        var attributes: [UnsafeMutableRawPointer: Attributes] = [:]
        attributes.reserveCapacity(entries.count)
        var tagNames: [UnsafeMutableRawPointer: [UInt8]] = [:]
        tagNames.reserveCapacity(entries.count)

        var queuesByName: [[UInt8]: [Int]] = [:]
        queuesByName.reserveCapacity(min(64, entries.count))
        var queuesByLocal: [[UInt8]: [Int]] = [:]
        queuesByLocal.reserveCapacity(min(64, entries.count))
        for (idx, entry) in entries.enumerated() {
            queuesByName[entry.tagName, default: []].append(idx)
            if let local = localName(from: entry.tagName) {
                queuesByLocal[local, default: []].append(idx)
            }
        }
        var used = [Bool](repeating: false, count: entries.count)

        var stack: [xmlNodePtr] = []
        if let root = docPtr.pointee.children {
            var cursor: xmlNodePtr? = root
            var roots: [xmlNodePtr] = []
            while let node = cursor {
                roots.append(node)
                cursor = node.pointee.next
            }
            for node in roots.reversed() {
                stack.append(node)
            }
        }

        while let node = stack.popLast() {
            if node.pointee.type == XML_ELEMENT_NODE {
                let name = normalizeTagName(qualifiedName(for: node), settings: settings)
                var matchedIndex: Int? = nil
                if var list = queuesByName[name], !list.isEmpty {
                    while let idx = list.first {
                        list.removeFirst()
                        if !used[idx] {
                            matchedIndex = idx
                            break
                        }
                    }
                    queuesByName[name] = list
                }
                if matchedIndex == nil, !name.contains(0x3A) {
                    if var list = queuesByLocal[name], !list.isEmpty {
                        while let idx = list.first {
                            list.removeFirst()
                            if !used[idx] {
                                matchedIndex = idx
                                break
                            }
                        }
                        queuesByLocal[name] = list
                    }
                }
                if let matchedIndex {
                    used[matchedIndex] = true
                    let entry = entries[matchedIndex]
                    let key = UnsafeMutableRawPointer(node)
                    attributes[key] = entry.attributes
                    tagNames[key] = entry.tagName
                }
            }
            if let child = node.pointee.children {
                var children: [xmlNodePtr] = []
                var cursor: xmlNodePtr? = child
                while let current = cursor {
                    children.append(current)
                    cursor = current.pointee.next
                }
                if !children.isEmpty {
                    for childNode in children.reversed() {
                        stack.append(childNode)
                    }
                }
            }
        }

        return Libxml2StartTagOverrides(attributes: attributes, tagNames: tagNames)
    }

    private static func buildExplicitBooleanAttributes(
        docPtr: xmlDocPtr,
        settings: ParseSettings,
        hints: inout HtmlScanHints
    ) -> [UnsafeMutableRawPointer: Set<[UInt8]>] {
        var explicit: [UnsafeMutableRawPointer: Set<[UInt8]>] = [:]

        var stack: [xmlNodePtr] = []
        if let root = docPtr.pointee.children {
            var cursor: xmlNodePtr? = root
            var roots: [xmlNodePtr] = []
            while let node = cursor {
                roots.append(node)
                cursor = node.pointee.next
            }
            for node in roots.reversed() {
                stack.append(node)
            }
        }

        while let node = stack.popLast() {
            if node.pointee.type == XML_ELEMENT_NODE {
                var explicitSet: Set<[UInt8]> = []
                if var attr = node.pointee.properties {
                    while true {
                        let rawAttrName = qualifiedName(for: attr)
                        let attrName = containsUppercaseAscii(rawAttrName) ? settings.normalizeAttribute(rawAttrName) : rawAttrName
                        if let booleanIndex = booleanAttributeIndex(for: attrName[...]),
                           let isBoolean = hints.consumeBooleanAttributeOptional(index: booleanIndex),
                           !isBoolean {
                            explicitSet.insert(attrName)
                        }
                        guard let next = attr.pointee.next else { break }
                        attr = next
                    }
                }
                if !explicitSet.isEmpty {
                    explicit[UnsafeMutableRawPointer(node)] = explicitSet
                }
            }
            if let child = node.pointee.children {
                var children: [xmlNodePtr] = []
                var cursor: xmlNodePtr? = child
                while let current = cursor {
                    children.append(current)
                    cursor = current.pointee.next
                }
                if !children.isEmpty {
                    for childNode in children.reversed() {
                        stack.append(childNode)
                    }
                }
            }
        }

        return explicit
    }

    @inline(__always)
    private static func localName(from tagName: [UInt8]) -> [UInt8]? {
        guard let idx = tagName.lastIndex(of: 0x3A) else { return nil }
        let next = tagName.index(after: idx)
        guard next < tagName.endIndex else { return nil }
        return Array(tagName[next...])
    }

    @inline(__always)
    private static func shouldBuildTagNameOverridesForNamespaces(_ input: [UInt8]) -> Bool {
        guard !input.isEmpty else { return false }
        var i = 0
        while i < input.count {
            if input[i] != 0x3C { // '<'
                i += 1
                continue
            }
            if i + 1 >= input.count {
                return false
            }
            let next = input[i + 1]
            if next == 0x21 || next == 0x3F { // ! or ?
                i += 2
                while i < input.count && input[i] != 0x3E {
                    i += 1
                }
                i += 1
                continue
            }
            var j = i + 1
            if next == 0x2F { // '/'
                j += 1
            }
            if j >= input.count || !isNameCharTable[Int(input[j])] {
                i += 1
                continue
            }
            while j < input.count && isNameCharTable[Int(input[j])] {
                if input[j] == 0x3A { // ':'
                    return true
                }
                j += 1
            }
            i = j
        }
        return false
    }

    @inline(__always)
    private static func shouldBuildAttributeOverrides(
        _ input: [UInt8],
        preserveCase: Bool
    ) -> Bool {
        guard !input.isEmpty else { return false }
        if preserveCase {
            return true
        }
        var inTag = false
        var quote: UInt8? = nil
        var i = 0
        while i < input.count {
            let b = input[i]
            if !inTag {
                if b == 0x3C { // '<'
                    let next = (i + 1 < input.count) ? input[i + 1] : nil
                    let nextNext = (i + 2 < input.count) ? input[i + 2] : nil
                    if shouldEscapeTagOpen(next: next, nextNext: nextNext) {
                        i += 1
                        continue
                    }
                    inTag = true
                    quote = nil
                }
                i += 1
                continue
            }
            if let q = quote {
                if b == q {
                    quote = nil
                }
                i += 1
                continue
            }
            if b == 0x22 || b == 0x27 { // '"' or '\''
                quote = b
                i += 1
                continue
            }
            if b == 0x3E { // '>'
                inTag = false
                i += 1
                continue
            }
            if b == 0x2F { // '/'
                let prev = i > 0 ? input[i - 1] : nil
                if let prev, isWhitespaceTable[Int(prev)] || prev == 0x22 || prev == 0x27 {
                    if i + 1 < input.count {
                        let next = input[i + 1]
                        if isAsciiLetter(next) {
                            return true
                        }
                    }
                }
            }
            i += 1
        }
        return false
    }

    @inline(__always)
    static func hydrateChildrenIfNeeded(_ parent: Node) {
        let doc = parent.ownerDocument()
        let context = doc?.libxml2Context ?? parent.libxml2Context
        if let doc {
            guard doc.isLibxml2Backend else { return }
        } else {
            guard context != nil else { return }
        }
        if !(parent is Document) && !(parent is Element) {
            return
        }
        if !(parent is Document), parent.libxml2NodePtr == nil {
            return
        }
        if parent.libxml2Context == nil, let context {
            parent.libxml2Context = context
        }
        if parent.libxml2ChildrenHydrated {
            return
        }
        parent.libxml2ChildrenHydrated = true
        parent._childNodes.removeAll(keepingCapacity: true)
        guard let docPtr = doc?.libxml2DocPtr ?? context?.docPtr else { return }

        let builder = doc?.treeBuilder as? Libxml2TreeBuilder
        builder?.beginBulkAppend()
        defer { builder?.endBulkAppend() }
        let settings = builder?.settings ?? context?.settings ?? ParseSettings.htmlDefault
        let baseUri = parent.baseUri ?? doc?.baseUri ?? context?.baseUri ?? []

        var children: [Node] = []
        if parent is Document, let doc, doc.parsedAsXml,
           let original = doc.libxml2OriginalInput,
           let decl = xmlDeclarationFromInput(original, baseUri: baseUri, settings: settings) {
            decl.treeBuilder = doc.treeBuilder
            decl.parentNode = parent
            decl.setSiblingIndex(children.count)
            decl.libxml2Context = context
            children.append(decl)
        }

        if parent is Document, let dtd = xmlGetIntSubset(docPtr) {
            let rawName = bytesFromXmlChar(dtd.pointee.name)
            let name = containsUppercaseAscii(rawName) ? settings.normalizeTag(rawName) : rawName
            let publicId = bytesFromXmlChar(dtd.pointee.ExternalID)
            let systemId = bytesFromXmlChar(dtd.pointee.SystemID)
            let doctype = DocumentType(name, publicId, systemId, baseUri)
            doctype.treeBuilder = doc?.treeBuilder
            doctype.parentNode = parent
            doctype.setSiblingIndex(children.count)
            doctype.libxml2Context = context
            children.append(doctype)
        }

        let startNode: xmlNodePtr?
        if let element = parent as? Element, !(parent is Document) {
            startNode = element.libxml2NodePtr?.pointee.children
        } else {
            var root = docPtr.pointee.children
            if let node = root,
               node.pointee.type == XML_DOCUMENT_NODE || node.pointee.type == XML_HTML_DOCUMENT_NODE {
                root = node.pointee.children
            }
            if root == nil {
                root = xmlDocGetRootElement(docPtr)
            }
            startNode = root
        }

        var current = startNode
        while let node = current {
            let wrapped = wrapNodeFromLibxml2(
                node,
                doc: doc,
                context: context,
                parent: parent,
                settings: settings,
                baseUri: baseUri
            )
            if let wrapped {
                var seen = Set<ObjectIdentifier>()
                var cursor: Node? = parent
                var wouldCycle = false
                while let node = cursor {
                    if node === wrapped {
                        wouldCycle = true
                        break
                    }
                    let id = ObjectIdentifier(node)
                    if seen.contains(id) {
                        break
                    }
                    seen.insert(id)
                    cursor = node.parentNode
                }
                if wouldCycle {
                    current = node.pointee.next
                    continue
                }
                if wrapped.treeBuilder == nil {
                    wrapped.treeBuilder = doc?.treeBuilder
                }
                wrapped.setSiblingIndex(children.count)
                if let element = wrapped as? Element {
                    let wasSuppressed = element.suppressQueryIndexDirty
                    element.suppressQueryIndexDirty = true
                    if wrapped.parentNode !== parent {
                        wrapped.parentNode = nil
                    }
                    wrapped.parentNode = parent
                    element.suppressQueryIndexDirty = wasSuppressed
                } else {
                    if wrapped.parentNode !== parent {
                        wrapped.parentNode = nil
                    }
                    wrapped.parentNode = parent
                }
                children.append(wrapped)
            }
            current = node.pointee.next
        }
        parent._childNodes = children
    }

    @inline(__always)
    static func hydrateAttributesIfNeeded(_ element: Element) {
        let doc = element.ownerDocument()
        let context = doc?.libxml2Context ?? element.libxml2Context
        if let doc {
            guard doc.isLibxml2Backend else { return }
        } else {
            guard context != nil else { return }
        }
        if element.libxml2Context == nil, let context {
            element.libxml2Context = context
        }
        if element.libxml2AttributesHydrated {
            return
        }
        element.libxml2AttributesHydrated = true
        guard let nodePtr = element.libxml2NodePtr,
              let docPtr = doc?.libxml2DocPtr ?? context?.docPtr else { return }
        if let overrides = doc?.libxml2AttributeOverrides ?? context?.attributeOverrides,
           let override = overrides[UnsafeMutableRawPointer(nodePtr)] {
            override.ownerElement = element
            element.attributes = override
            return
        }
        let settings = doc?.treeBuilder?.settings ?? context?.settings ?? ParseSettings.htmlDefault

        let attributes = Attributes()
        attributes.ownerElement = element
        let explicitMap = doc?.libxml2ExplicitBooleanAttributes ?? context?.explicitBooleanAttributes
        element.withLibxml2DirtySuppressed {
            if var attr = nodePtr.pointee.properties {
                while true {
                    let rawAttrName = qualifiedName(for: attr)
                    let attrName = containsUppercaseAscii(rawAttrName) ? settings.normalizeAttribute(rawAttrName) : rawAttrName
                    let booleanIndex = booleanAttributeIndex(for: attrName[...])
                    let explicitBoolean = explicitMap?[UnsafeMutableRawPointer(nodePtr)]?.contains(attrName) ?? false
                    var isBoolean = false
                    var value: [UInt8]? = nil
                    if let _ = booleanIndex {
                        if explicitBoolean {
                            isBoolean = false
                        } else if attr.pointee.children == nil {
                            isBoolean = true
                        } else {
                            if let child = attr.pointee.children,
                               child.pointee.next == nil,
                               (child.pointee.type == XML_TEXT_NODE || child.pointee.type == XML_ENTITY_REF_NODE),
                               let contentPtr = child.pointee.content {
                                value = bytesFromXmlChar(contentPtr)
                            } else {
                                let valuePtr = xmlNodeListGetString(docPtr, attr.pointee.children, 1)
                                value = bytesFromXmlChar(valuePtr)
                                if let valuePtr {
                                    xmlFree(valuePtr)
                                }
                            }
                            if let value, equalsIgnoreCaseAscii(attrName, value) {
                                isBoolean = true
                            }
                        }
                    } else if attr.pointee.children == nil {
                        isBoolean = true
                    }
                    if isBoolean {
                        if let booleanAttr = try? BooleanAttribute(key: attrName) {
                            attributes.put(attribute: booleanAttr)
                        }
                    } else {
                        if value == nil {
                            if let child = attr.pointee.children,
                               child.pointee.next == nil,
                               (child.pointee.type == XML_TEXT_NODE || child.pointee.type == XML_ENTITY_REF_NODE),
                               let contentPtr = child.pointee.content {
                                value = bytesFromXmlChar(contentPtr)
                            } else {
                                let valuePtr = xmlNodeListGetString(docPtr, attr.pointee.children, 1)
                                value = bytesFromXmlChar(valuePtr)
                                if let valuePtr {
                                    xmlFree(valuePtr)
                                }
                            }
                        }
                        if let value {
                            try? attributes.put(attrName, value)
                        }
                    }
                    guard let next = attr.pointee.next else { break }
                    attr = next
                }
            }
        }
        element._attributes = attributes
    }

    private static func wrapNodeFromLibxml2(
        _ node: xmlNodePtr,
        doc: Document,
        parent: Node,
        settings: ParseSettings,
        baseUri: [UInt8]
    ) -> Node? {
        guard let context = doc.libxml2Context else {
            return wrapNodeFromLibxml2(
                node,
                doc: doc,
                context: nil,
                parent: parent,
                settings: settings,
                baseUri: baseUri
            )
        }
        return wrapNodeFromLibxml2(
            node,
            doc: doc,
            context: context,
            parent: parent,
            settings: settings,
            baseUri: baseUri
        )
    }

    private static func wrapNodeFromLibxml2(
        _ node: xmlNodePtr,
        doc: Document?,
        context: Libxml2DocumentContext?,
        parent: Node,
        settings: ParseSettings,
        baseUri: [UInt8]
    ) -> Node? {
        if let existingPtr = node.pointee._private {
            let existing = Unmanaged<Node>.fromOpaque(existingPtr).takeUnretainedValue()
            if existing.libxml2NodePtr != node || (doc != nil && existing.ownerDocument() !== doc) {
                node.pointee._private = nil
            } else {
                if existing.treeBuilder == nil {
                    existing.treeBuilder = doc?.treeBuilder
                }
                if existing === parent {
                    if existing.libxml2Context == nil {
                        existing.libxml2Context = context
                    }
                    cacheNode(existing, nodePtr: node, context: context, doc: doc)
                    return existing
                }
                if existing.parentNode !== parent {
                    var cursor: Node? = parent
                    while let node = cursor {
                        if node === existing {
                            return existing
                        }
                        cursor = node.parentNode
                    }
                    if let element = existing as? Element {
                        let wasSuppressed = element.suppressQueryIndexDirty
                        element.suppressQueryIndexDirty = true
                        existing.parentNode = parent
                        element.suppressQueryIndexDirty = wasSuppressed
                    } else {
                        existing.parentNode = parent
                    }
                }
                if existing.libxml2Context == nil {
                    existing.libxml2Context = context
                }
                cacheNode(existing, nodePtr: node, context: context, doc: doc)
                return existing
            }
        }

        let type = node.pointee.type
        switch type {
        case XML_ELEMENT_NODE:
            let overrideName = doc?.libxml2TagNameOverrides?[UnsafeMutableRawPointer(node)]
            let rawName = overrideName ?? qualifiedName(for: node)
            let normalizedName = containsUppercaseAscii(rawName) ? settings.normalizeTag(rawName) : rawName
            let isUnknown = !Tag.isKnownTag(normalizedName)
            let hasChildren = node.pointee.children != nil
            let shouldSelfClose = isUnknown && !hasChildren
            guard let tag = try? Tag.valueOfNormalized(normalizedName, isSelfClosing: shouldSelfClose) else {
                return nil
            }
            let element: Element
            if normalizedName == UTF8Arrays.form {
                element = FormElement(tag, baseUri, skipChildReserve: true)
            } else {
                element = Element(tag, baseUri, skipChildReserve: true)
            }
            element.libxml2NodePtr = node
            element.libxml2Context = context
            node.pointee._private = Unmanaged.passUnretained(element).toOpaque()
            element.treeBuilder = doc?.treeBuilder
            cacheNode(element, nodePtr: node, context: context, doc: doc)
            return element
        case XML_TEXT_NODE, XML_CDATA_SECTION_NODE, XML_ENTITY_REF_NODE:
            let content = libxml2NodeContent(node)
            if content.isEmpty {
                return nil
            }
            let isScriptOrStyle = isScriptOrStyleParent(parent)
            let textNode: Node
            if isScriptOrStyle {
                textNode = DataNode(content, baseUri)
            } else {
                textNode = TextNode(content, baseUri)
            }
            textNode.libxml2NodePtr = node
            textNode.libxml2Context = context
            node.pointee._private = Unmanaged.passUnretained(textNode).toOpaque()
            textNode.treeBuilder = doc?.treeBuilder
            cacheNode(textNode, nodePtr: node, context: context, doc: doc)
            return textNode
        case XML_COMMENT_NODE:
            let content = libxml2NodeContent(node)
            let comment = Comment(content, baseUri)
            comment.libxml2NodePtr = node
            comment.libxml2Context = context
            node.pointee._private = Unmanaged.passUnretained(comment).toOpaque()
            comment.treeBuilder = doc?.treeBuilder
            cacheNode(comment, nodePtr: node, context: context, doc: doc)
            return comment
        case XML_PI_NODE:
            let name = bytesFromXmlChar(node.pointee.name)
            let normalizedName = containsUppercaseAscii(name) ? settings.normalizeTag(name) : name
            let declaration = XmlDeclaration(normalizedName, baseUri, false)
                if let contentPtr = node.pointee.content {
                    let content = String(decoding: bytesFromXmlChar(contentPtr), as: UTF8.self)
                    let base = String(decoding: baseUri, as: UTF8.self)
                    if let tempDoc = try? Parser.xmlParser(.swiftSoup).parseInput("<" + declaration.name() + " " + content + ">", base),
                       let el = tempDoc.childNodes.first as? Element {
                        declaration.getAttributes()?.addAll(incoming: el.getAttributes())
                    }
                }
            declaration.libxml2NodePtr = node
            declaration.libxml2Context = context
            node.pointee._private = Unmanaged.passUnretained(declaration).toOpaque()
            declaration.treeBuilder = doc?.treeBuilder
            cacheNode(declaration, nodePtr: node, context: context, doc: doc)
            return declaration
        default:
            return nil
        }
    }

    private static func libxml2NodeContent(_ node: xmlNodePtr) -> [UInt8] {
        if let contentPtr = node.pointee.content {
            return bytesFromXmlChar(contentPtr)
        }
        let contentPtr = xmlNodeGetContent(node)
        let content = bytesFromXmlChar(contentPtr)
        if let contentPtr {
            xmlFree(contentPtr)
        }
        return content
    }

    @inline(__always)
    static func findFirstElementPtrByTagName(
        _ tag: [UInt8],
        docPtr: xmlDocPtr,
        settings: ParseSettings
    ) -> xmlNodePtr? {
        guard let root = xmlDocGetRootElement(docPtr) else { return nil }
        var stack: [xmlNodePtr] = [root]
        while let node = stack.popLast() {
            if node.pointee.type == XML_ELEMENT_NODE {
                let rawName = qualifiedName(for: node)
                let normalizedName = containsUppercaseAscii(rawName) ? settings.normalizeTag(rawName) : rawName
                if normalizedName == tag {
                    return node
                }
            }
            if let child = node.pointee.children {
                var cursor: xmlNodePtr? = child
                var children: [xmlNodePtr] = []
                while let current = cursor {
                    children.append(current)
                    cursor = current.pointee.next
                }
                if !children.isEmpty {
                    for childNode in children.reversed() {
                        stack.append(childNode)
                    }
                }
            }
        }
        return nil
    }

    @inline(__always)
    private static func cacheNode(_ node: Node, nodePtr: xmlNodePtr, context: Libxml2DocumentContext?, doc: Document?) {
        if let context {
            if context.nodeCache == nil {
                context.nodeCache = [:]
            }
            context.nodeCache?[UnsafeMutableRawPointer(nodePtr)] = node
            if let doc {
                doc.libxml2NodeCache = context.nodeCache
            }
            return
        }
        if let doc {
            if doc.libxml2NodeCache == nil {
                doc.libxml2NodeCache = [:]
            }
            doc.libxml2NodeCache?[UnsafeMutableRawPointer(nodePtr)] = node
        }
    }

    @inline(__always)
    private static func cacheNode(_ node: Node, nodePtr: xmlNodePtr, doc: Document) {
        cacheNode(node, nodePtr: nodePtr, context: doc.libxml2Context, doc: doc)
    }

    @inline(__always)
    static func wrapNodeForSelection(
        _ node: xmlNodePtr,
        doc: Document
    ) -> Node? {
        guard let parent = resolveParentWrapper(node, doc: doc) else { return nil }
        let settings = doc.treeBuilder?.settings ?? ParseSettings.htmlDefault
        let baseUri = parent.baseUri ?? doc.baseUri ?? []
        guard let wrapped = wrapNodeFromLibxml2(node, doc: doc, parent: parent, settings: settings, baseUri: baseUri) else {
            return nil
        }
        let index = libxml2SiblingIndex(node, parent: parent, doc: doc)
        wrapped.setSiblingIndex(index)
        if wrapped.parentNode !== parent {
            var seen = Set<ObjectIdentifier>()
            var cursor: Node? = parent
            var wouldCycle = false
            while let node = cursor {
                if node === wrapped {
                    wouldCycle = true
                    break
                }
                let id = ObjectIdentifier(node)
                if seen.contains(id) {
                    break
                }
                seen.insert(id)
                cursor = node.parentNode
            }
            if !wouldCycle {
                if let element = wrapped as? Element {
                    let wasSuppressed = element.suppressQueryIndexDirty
                    element.suppressQueryIndexDirty = true
                    wrapped.parentNode = parent
                    element.suppressQueryIndexDirty = wasSuppressed
                } else {
                    wrapped.parentNode = parent
                }
            }
        }
        return wrapped
    }

    @inline(__always)
    static func wrapNodeForSelectionFast(
        _ node: xmlNodePtr,
        doc: Document
    ) -> Node? {
        let settings = doc.treeBuilder?.settings ?? ParseSettings.htmlDefault
        let baseUri = doc.baseUri ?? []
        let parentWrapper: Node
        if let parentPtr = node.pointee.parent,
           parentPtr.pointee.type == XML_ELEMENT_NODE {
            parentWrapper = wrapNodeForSelectionFast(parentPtr, doc: doc) ?? doc
        } else {
            parentWrapper = doc
        }
        return wrapNodeFromLibxml2(node, doc: doc, parent: parentWrapper, settings: settings, baseUri: baseUri)
    }

    @inline(__always)
    private static func traverseSubtree(
        start: xmlNodePtr,
        _ visit: (xmlNodePtr) -> Void
    ) {
        var stack: [xmlNodePtr] = [start]
        while let current = stack.popLast() {
            visit(current)
            if let child = current.pointee.children {
                var children: [xmlNodePtr] = []
                var cursor: xmlNodePtr? = child
                while let node = cursor {
                    children.append(node)
                    cursor = node.pointee.next
                }
                if !children.isEmpty {
                    for node in children.reversed() {
                        stack.append(node)
                    }
                }
            }
        }
    }

    @inline(__always)
    static func isSelectableNodeFast(
        _ node: xmlNodePtr,
        doc: Document
    ) -> Bool {
        switch node.pointee.type {
        case XML_ELEMENT_NODE, XML_COMMENT_NODE, XML_PI_NODE:
            return true
        case XML_TEXT_NODE, XML_CDATA_SECTION_NODE, XML_ENTITY_REF_NODE:
            let content = libxml2NodeContent(node)
            return !content.isEmpty
        default:
            return false
        }
    }

    @inline(__always)
    private static func classAttrHasClass(
        _ classAttr: [UInt8],
        _ className: [UInt8]
    ) -> Bool {
        let len = classAttr.count
        let wantLen = className.count
        if len == 0 || len < wantLen || wantLen == 0 {
            return false
        }
        if len == wantLen {
            return className.equalsIgnoreCase(string: classAttr)
        }

        @inline(__always)
        func equalsIgnoreCaseSlice(_ bytes: [UInt8], _ start: Int, _ length: Int, _ other: [UInt8]) -> Bool {
            if length != other.count { return false }
            var i = 0
            while i < length {
                let b = bytes[start + i]
                let o = other[i]
                let lowerB = (b >= 65 && b <= 90) ? (b &+ 32) : b
                let lowerO = (o >= 65 && o <= 90) ? (o &+ 32) : o
                if lowerB != lowerO {
                    return false
                }
                i &+= 1
            }
            return true
        }

        var i = 0
        var tokenStart = 0
        var inToken = false
        while i < len {
            let b = classAttr[i]
            if b.isWhitespace {
                if inToken {
                    let tokenLen = i - tokenStart
                    if tokenLen == wantLen && equalsIgnoreCaseSlice(classAttr, tokenStart, tokenLen, className) {
                        return true
                    }
                    inToken = false
                }
            } else if !inToken {
                inToken = true
                tokenStart = i
            }
            i &+= 1
        }
        if inToken {
            let tokenLen = len - tokenStart
            if tokenLen == wantLen && equalsIgnoreCaseSlice(classAttr, tokenStart, tokenLen, className) {
                return true
            }
        }
        return false
    }

    @inline(__always)
    static func collectElementsByClassName(
        start: xmlNodePtr?,
        className: [UInt8],
        doc: Document
    ) -> Elements {
        guard let start else { return Elements() }
        guard !className.isEmpty else { return Elements() }
        let output = Elements()
        output.reserveCapacity(64)
        let attrName = "class".utf8Array + [0]
        attrName.withUnsafeBufferPointer { buf in
            guard let base = buf.baseAddress else { return }
            let attrPtr = base.withMemoryRebound(to: xmlChar.self, capacity: buf.count) { $0 }
            traverseSubtree(start: start) { current in
                if current.pointee.type == XML_ELEMENT_NODE {
                    if let value = xmlGetProp(current, attrPtr) {
                        let classAttr = bytesFromXmlChar(value)
                        xmlFree(value)
                        if classAttrHasClass(classAttr, className),
                           let element = wrapNodeForSelectionFast(current, doc: doc) as? Element {
                            output.add(element)
                        }
                    }
                }
            }
        }
        return output
    }

    @inline(__always)
    static func collectElementsByAttributeName(
        start: xmlNodePtr?,
        key: [UInt8],
        doc: Document
    ) -> Elements {
        guard let start else { return Elements() }
        guard !key.isEmpty else { return Elements() }
        let output = Elements()
        output.reserveCapacity(64)
        let attrName = key + [0]
        attrName.withUnsafeBufferPointer { buf in
            guard let base = buf.baseAddress else { return }
            let attrPtr = base.withMemoryRebound(to: xmlChar.self, capacity: buf.count) { $0 }
            traverseSubtree(start: start) { current in
                if current.pointee.type == XML_ELEMENT_NODE {
                    if xmlHasProp(current, attrPtr) != nil,
                       let element = wrapNodeForSelectionFast(current, doc: doc) as? Element {
                        output.add(element)
                    }
                }
            }
        }
        return output
    }

    @inline(__always)
    static func collectElementsByAttributeValue(
        start: xmlNodePtr?,
        key: [UInt8],
        value: [UInt8],
        doc: Document
    ) -> Elements {
        guard let start else { return Elements() }
        guard !key.isEmpty else { return Elements() }
        let output = Elements()
        output.reserveCapacity(64)
        let attrName = key + [0]
        attrName.withUnsafeBufferPointer { buf in
            guard let base = buf.baseAddress else { return }
            let attrPtr = base.withMemoryRebound(to: xmlChar.self, capacity: buf.count) { $0 }
            traverseSubtree(start: start) { current in
                if current.pointee.type == XML_ELEMENT_NODE {
                    if let valuePtr = xmlGetProp(current, attrPtr) {
                        let rawValue = bytesFromXmlChar(valuePtr)
                        xmlFree(valuePtr)
                        let needsTrim = (rawValue.first?.isWhitespace ?? false) || (rawValue.last?.isWhitespace ?? false)
                        let candidate = needsTrim ? rawValue.trim() : rawValue
                        if value.equalsIgnoreCase(string: candidate),
                           let element = wrapNodeForSelectionFast(current, doc: doc) as? Element {
                            output.add(element)
                        }
                    }
                }
            }
        }
        return output
    }

    @inline(__always)
    static func collectElementsByAttributeValueNot(
        start: xmlNodePtr?,
        key: [UInt8],
        value: [UInt8],
        doc: Document
    ) -> Elements {
        guard let start else { return Elements() }
        guard !key.isEmpty else { return Elements() }
        let output = Elements()
        output.reserveCapacity(64)
        let attrName = key + [0]
        attrName.withUnsafeBufferPointer { buf in
            guard let base = buf.baseAddress else { return }
            let attrPtr = base.withMemoryRebound(to: xmlChar.self, capacity: buf.count) { $0 }
            traverseSubtree(start: start) { current in
                if current.pointee.type == XML_ELEMENT_NODE {
                    if let valuePtr = xmlGetProp(current, attrPtr) {
                        let rawValue = bytesFromXmlChar(valuePtr)
                        xmlFree(valuePtr)
                        if !value.equalsIgnoreCase(string: rawValue),
                           let element = wrapNodeForSelectionFast(current, doc: doc) as? Element {
                            output.add(element)
                        }
                    } else if let element = wrapNodeForSelectionFast(current, doc: doc) as? Element {
                        output.add(element)
                    }
                }
            }
        }
        return output
    }

    @inline(__always)
    static func collectElementsByAttributeValueStarting(
        start: xmlNodePtr?,
        key: [UInt8],
        value: [UInt8],
        valueLower: String,
        doc: Document
    ) -> Elements {
        guard let start else { return Elements() }
        guard !key.isEmpty else { return Elements() }
        let output = Elements()
        output.reserveCapacity(64)
        let attrName = key + [0]
        let valueIsAscii = StringUtil.isAscii(value)
        attrName.withUnsafeBufferPointer { buf in
            guard let base = buf.baseAddress else { return }
            let attrPtr = base.withMemoryRebound(to: xmlChar.self, capacity: buf.count) { $0 }
            traverseSubtree(start: start) { current in
                if current.pointee.type == XML_ELEMENT_NODE {
                    if let valuePtr = xmlGetProp(current, attrPtr) {
                        let rawValue = bytesFromXmlChar(valuePtr)
                        xmlFree(valuePtr)
                        let matches: Bool
                        if valueIsAscii, StringUtil.isAscii(rawValue) {
                            matches = StringUtil.hasPrefixLowercaseAscii(rawValue, value)
                        } else {
                            matches = String(decoding: rawValue, as: UTF8.self).lowercased().hasPrefix(valueLower)
                        }
                        if matches, let element = wrapNodeForSelectionFast(current, doc: doc) as? Element {
                            output.add(element)
                        }
                    }
                }
            }
        }
        return output
    }

    @inline(__always)
    static func collectElementsByAttributeValueEnding(
        start: xmlNodePtr?,
        key: [UInt8],
        value: [UInt8],
        valueLower: String,
        doc: Document
    ) -> Elements {
        guard let start else { return Elements() }
        guard !key.isEmpty else { return Elements() }
        let output = Elements()
        output.reserveCapacity(64)
        let attrName = key + [0]
        let valueIsAscii = StringUtil.isAscii(value)
        attrName.withUnsafeBufferPointer { buf in
            guard let base = buf.baseAddress else { return }
            let attrPtr = base.withMemoryRebound(to: xmlChar.self, capacity: buf.count) { $0 }
            traverseSubtree(start: start) { current in
                if current.pointee.type == XML_ELEMENT_NODE {
                    if let valuePtr = xmlGetProp(current, attrPtr) {
                        let rawValue = bytesFromXmlChar(valuePtr)
                        xmlFree(valuePtr)
                        let matches: Bool
                        if valueIsAscii, StringUtil.isAscii(rawValue) {
                            matches = StringUtil.hasSuffixLowercaseAscii(rawValue, value)
                        } else {
                            matches = String(decoding: rawValue, as: UTF8.self).lowercased().hasSuffix(valueLower)
                        }
                        if matches, let element = wrapNodeForSelectionFast(current, doc: doc) as? Element {
                            output.add(element)
                        }
                    }
                }
            }
        }
        return output
    }

    @inline(__always)
    static func collectElementsByAttributeValueContaining(
        start: xmlNodePtr?,
        key: [UInt8],
        value: [UInt8],
        valueLower: String,
        doc: Document
    ) -> Elements {
        guard let start else { return Elements() }
        guard !key.isEmpty else { return Elements() }
        let output = Elements()
        output.reserveCapacity(64)
        let attrName = key + [0]
        let valueIsAscii = StringUtil.isAscii(value)
        attrName.withUnsafeBufferPointer { buf in
            guard let base = buf.baseAddress else { return }
            let attrPtr = base.withMemoryRebound(to: xmlChar.self, capacity: buf.count) { $0 }
            traverseSubtree(start: start) { current in
                if current.pointee.type == XML_ELEMENT_NODE {
                    if let valuePtr = xmlGetProp(current, attrPtr) {
                        let rawValue = bytesFromXmlChar(valuePtr)
                        xmlFree(valuePtr)
                        let matches: Bool
                        if valueIsAscii, StringUtil.isAscii(rawValue) {
                            matches = StringUtil.containsLowercaseAscii(rawValue, value)
                        } else {
                            matches = String(decoding: rawValue, as: UTF8.self).lowercased().contains(valueLower)
                        }
                        if matches, let element = wrapNodeForSelectionFast(current, doc: doc) as? Element {
                            output.add(element)
                        }
                    }
                }
            }
        }
        return output
    }

    @inline(__always)
    static func collectElementsByAttributeNamePrefix(
        start: xmlNodePtr?,
        keyPrefix: [UInt8],
        doc: Document
    ) -> Elements {
        guard let start else { return Elements() }
        guard !keyPrefix.isEmpty else { return Elements() }
        let output = Elements()
        output.reserveCapacity(64)
        traverseSubtree(start: start) { current in
            if current.pointee.type == XML_ELEMENT_NODE {
                var attr = current.pointee.properties
                var found = false
                while let property = attr {
                    let name = bytesFromXmlChar(property.pointee.name)
                    if StringUtil.hasPrefixLowercaseAscii(name, keyPrefix) {
                        found = true
                        break
                    }
                    attr = property.pointee.next
                }
                if found, let element = wrapNodeForSelectionFast(current, doc: doc) as? Element {
                    output.add(element)
                }
            }
        }
        return output
    }

    @inline(__always)
    static func findFirstElementById(
        start: xmlNodePtr?,
        id: [UInt8],
        doc: Document
    ) -> Element? {
        guard let start else { return nil }
        guard !id.isEmpty else { return nil }
        var stack: [xmlNodePtr] = [start]
        while let current = stack.popLast() {
            if current.pointee.type == XML_ELEMENT_NODE {
                let match: Element? = "id".utf8CString.withUnsafeBufferPointer { buf in
                    guard let base = buf.baseAddress else { return nil }
                    return base.withMemoryRebound(to: xmlChar.self, capacity: buf.count) { ptr in
                        guard let attr = xmlGetProp(current, ptr) else { return nil }
                        let value = bytesFromXmlChar(attr)
                        xmlFree(attr)
                        if value == id {
                            return wrapNodeForSelectionFast(current, doc: doc) as? Element
                        }
                        return nil
                    }
                }
                if let match {
                    return match
                }
            }
            if let child = current.pointee.children {
                var children: [xmlNodePtr] = []
                var cursor: xmlNodePtr? = child
                while let node = cursor {
                    children.append(node)
                    cursor = node.pointee.next
                }
                if !children.isEmpty {
                    for node in children.reversed() {
                        stack.append(node)
                    }
                }
            }
        }
        return nil
    }

    @inline(__always)
    static func collectElementsByTagName(
        start: xmlNodePtr?,
        tag: [UInt8],
        settings: ParseSettings,
        doc: Document
    ) -> Elements {
        guard let start else { return Elements() }
        guard !tag.isEmpty else { return Elements() }
        let colonIndex = tag.firstIndex(of: 0x3A)
        let prefixSlice = colonIndex.map { tag[..<$0] }
        let localSlice = colonIndex.map { tag[tag.index(after: $0)...] }
        let tagCString: [UInt8] = tag + [0]
        let output = Elements()
        output.reserveCapacity(128)
        traverseSubtree(start: start) { current in
            if current.pointee.type == XML_ELEMENT_NODE {
                let hasPrefix = current.pointee.ns?.pointee.prefix != nil
                if hasPrefix {
                    if let prefixSlice, let localSlice, let ns = current.pointee.ns, let prefixPtr = ns.pointee.prefix {
                        if cStringEqualsLowercase(prefixPtr, prefixSlice),
                           cStringEqualsLowercase(current.pointee.name, localSlice),
                           let element = wrapNodeForSelectionFast(current, doc: doc) as? Element {
                            output.add(element)
                        }
                    }
                } else if colonIndex == nil {
                    let matches = tagCString.withUnsafeBufferPointer { buf -> Bool in
                        guard let base = buf.baseAddress else { return false }
                        return base.withMemoryRebound(to: xmlChar.self, capacity: buf.count) { ptr in
                            xmlStrcasecmp(current.pointee.name, ptr) == 0
                        }
                    }
                    if matches, let element = wrapNodeForSelectionFast(current, doc: doc) as? Element {
                        output.add(element)
                    }
                } else {
                    let rawName = qualifiedName(for: current)
                    let normalizedName = containsUppercaseAscii(rawName) ? settings.normalizeTag(rawName) : rawName
                    if normalizedName == tag, let element = wrapNodeForSelectionFast(current, doc: doc) as? Element {
                        output.add(element)
                    }
                }
            }
        }
        return output
    }

    @inline(__always)
    static func collectElementsByTagNames(
        start: xmlNodePtr?,
        tags: [[UInt8]],
        doc: Document
    ) -> Elements {
        guard let start else { return Elements() }
        guard !tags.isEmpty else { return Elements() }
        let output = Elements()
        output.reserveCapacity(128)
        traverseSubtree(start: start) { current in
            if current.pointee.type == XML_ELEMENT_NODE {
                if current.pointee.ns?.pointee.prefix == nil,
                   cStringEqualsAnyLowercase(current.pointee.name, tags),
                   let element = wrapNodeForSelectionFast(current, doc: doc) as? Element {
                    output.add(element)
                }
            }
        }
        return output
    }

    @inline(__always)
    static func collectAllElements(
        start: xmlNodePtr?,
        doc: Document,
        includeSelf: Bool
    ) -> Elements {
        guard let start else { return Elements() }
        let output = Elements()
        output.reserveCapacity(128)
        var skipFirst = !includeSelf
        traverseSubtree(start: start) { current in
            if skipFirst {
                skipFirst = false
                return
            }
            if current.pointee.type == XML_ELEMENT_NODE,
               let element = wrapNodeForSelectionFast(current, doc: doc) as? Element {
                output.add(element)
            }
        }
        return output
    }


    @inline(__always)
    static func parentWrapperForSelection(
        _ node: xmlNodePtr,
        doc: Document
    ) -> Node? {
        guard let parentPtr = node.pointee.parent else { return doc }
        if parentPtr.pointee.type == XML_DOCUMENT_NODE || parentPtr.pointee.type == XML_HTML_DOCUMENT_NODE {
            return doc
        }
        if let existingPtr = parentPtr.pointee._private {
            let existing = Unmanaged<Node>.fromOpaque(existingPtr).takeUnretainedValue()
            if existing.libxml2NodePtr == parentPtr, existing.ownerDocument() === doc {
                return existing
            }
            parentPtr.pointee._private = nil
        }
        return wrapNodeForSelection(parentPtr, doc: doc)
    }

    private static func resolveParentWrapper(_ node: xmlNodePtr, doc: Document) -> Node? {
        guard let parentPtr = node.pointee.parent else { return doc }
        if parentPtr.pointee.type == XML_DOCUMENT_NODE || parentPtr.pointee.type == XML_HTML_DOCUMENT_NODE {
            return doc
        }
        if let existingPtr = parentPtr.pointee._private {
            let existing = Unmanaged<Node>.fromOpaque(existingPtr).takeUnretainedValue()
            if existing.libxml2NodePtr == parentPtr, existing.ownerDocument() === doc {
                return existing
            }
            parentPtr.pointee._private = nil
        }
        return wrapNodeForSelection(parentPtr, doc: doc)
    }

    private static func libxml2SiblingIndex(
        _ node: xmlNodePtr,
        parent: Node,
        doc: Document
    ) -> Int {
        var count = 0
        var cursor = node.pointee.prev
        while let current = cursor {
            if libxml2NodeIsRepresented(current) {
                count += 1
            }
            cursor = current.pointee.prev
        }
        if parent is Document, let docPtr = doc.libxml2DocPtr, xmlGetIntSubset(docPtr) != nil {
            count += 1
        }
        return count
    }

    private static func libxml2NodeIsRepresented(_ node: xmlNodePtr) -> Bool {
        switch node.pointee.type {
        case XML_ELEMENT_NODE:
            return true
        case XML_TEXT_NODE, XML_CDATA_SECTION_NODE, XML_ENTITY_REF_NODE:
            let content = libxml2NodeContent(node)
            return !content.isEmpty
        case XML_COMMENT_NODE:
            return true
        case XML_PI_NODE:
            return true
        default:
            return false
        }
    }
#endif

    static func parseHTML(
        _ input: [UInt8],
        baseUri: [UInt8],
        settings: ParseSettings,
        errors: ParseErrorList,
        builder: Libxml2TreeBuilder
    ) throws -> Document {
        _ = initialized
        if Libxml2FallbackStats.enabled {
            _ = Libxml2FallbackStats.installReporter
            Libxml2FallbackStats.shared.recordParse()
        }

        #if PROFILE
        let _p = Profiler.start("Libxml2.parseHTML")
        defer { Profiler.end("Libxml2.parseHTML", _p) }
        #endif

        let skipSwiftSoupFallbacks = builder.skipSwiftSoupFallbacks
        #if PROFILE
        let pSanitize = Profiler.start("Libxml2.sanitizeHtml")
        #endif
        let sanitizedInput = skipSwiftSoupFallbacks ? input : sanitizeHtmlInputForLibxml2(input)
        #if PROFILE
        Profiler.end("Libxml2.sanitizeHtml", pSanitize)
        #endif

        var hints: HtmlScanHints
        var scanHints = HtmlScanHints()
        var reason: Libxml2FallbackReason? = nil
        #if PROFILE
        let pScan = Profiler.start("Libxml2.scanFallback")
        #endif
        let hasVoidEndTag = containsEndTagForHtmlVoidTags(input)
        let hasCommentDashDashDash = containsHtmlCommentDashDashDash(input)
        let hasCdata = containsHtmlCdata(input)
        if hasLeadingHtmlComment(sanitizedInput) {
            #if PROFILE
            Profiler.end("Libxml2.scanFallback", pScan)
            #endif
            reason = .formattingMismatch
            let fallbackBuilder = HtmlTreeBuilder()
            let parsed = try fallbackBuilder.parse(input, baseUri, errors, settings)
#if canImport(CLibxml2) || canImport(libxml2)
            parsed.libxml2Preferred = true
            attachLibxml2Document(parsed)
#endif
            return parsed
        }
        var shouldFallback: Bool
        if hasVoidEndTag || hasCommentDashDashDash || hasCdata {
            reason = .formattingMismatch
            shouldFallback = true
        } else {
            shouldFallback = shouldFallbackToSwiftSoup(
                sanitizedInput,
                reason: &reason,
                recordReason: Libxml2FallbackStats.enabled,
                hints: &scanHints
            )
        }
        #if PROFILE
        Profiler.end("Libxml2.scanFallback", pScan)
        #endif
        if shouldFallback {
            if Libxml2FallbackStats.enabled {
                let sample = Libxml2FallbackStats.sampleEnabled ? sampleSnippet(input) : nil
                Libxml2FallbackStats.shared.recordFallback(reason ?? .unknown, sample: sample)
            }
            let fallbackBuilder = HtmlTreeBuilder()
            let parsed = try fallbackBuilder.parse(input, baseUri, errors, settings)
#if canImport(CLibxml2) || canImport(libxml2)
            parsed.libxml2Preferred = true
            attachLibxml2Document(parsed)
#endif
            return parsed
        }
        hints = scanHints
        let explicitBooleanHints = booleanHintsEnabled() ? hints : nil
        let options = Int32(
            HTML_PARSE_RECOVER.rawValue
                | HTML_PARSE_NOERROR.rawValue
                | HTML_PARSE_NOWARNING.rawValue
                | HTML_PARSE_NONET.rawValue
                | HTML_PARSE_COMPACT.rawValue
                | HTML_PARSE_NODEFDTD.rawValue
        )
        let baseUriString = baseUri.isEmpty ? nil : String(decoding: baseUri, as: UTF8.self)
        let encoding = "UTF-8"
        #if PROFILE
        let pRead = Profiler.start("Libxml2.htmlReadMemory")
        #endif
        let docPtr: htmlDocPtr? = sanitizedInput.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return nil }
            let cString = baseAddress.assumingMemoryBound(to: CChar.self)
            return encoding.withCString { encodingPtr in
                if let baseUriString {
                    return baseUriString.withCString { url in
                        htmlReadMemory(cString, Int32(rawBuffer.count), url, encodingPtr, options)
                    }
                }
                return htmlReadMemory(cString, Int32(rawBuffer.count), nil, encodingPtr, options)
            }
        }
        #if PROFILE
        Profiler.end("Libxml2.htmlReadMemory", pRead)
        #endif
        guard let docPtr else {
            let fallbackBuilder = HtmlTreeBuilder()
            return try fallbackBuilder.parse(input, baseUri, errors, settings)
        }
        var docPtrToFree: htmlDocPtr? = docPtr
        defer {
            if let docPtrToFree {
                xmlFreeDoc(docPtrToFree)
            }
        }
        builder.errors = errors
        builder.settings = settings
        builder.tracksSourceRanges = false
        builder.tracksErrors = errors.getMaxSize() > 0

        let doc = Document(baseUri)
#if canImport(CLibxml2) || canImport(libxml2)
        let context = Libxml2DocumentContext(docPtr: docPtr, settings: settings, baseUri: baseUri)
        context.document = doc
        doc.parserBackend = .libxml2(swiftSoupParityMode: skipSwiftSoupFallbacks ? .libxml2Only : .swiftSoupParity)
        doc.libxml2DocPtr = docPtr
        doc.libxml2BackedDirty = false
        doc.libxml2ChildrenHydrated = false
        doc._childNodes.removeAll(keepingCapacity: true)
        doc.libxml2Preferred = true
        let preserveCase = settings.preservesTagCase() || settings.preservesAttributeCase()
        let shouldBuildOverrides = skipSwiftSoupFallbacks
            || shouldBuildAttributeOverrides(input, preserveCase: preserveCase)
            || shouldBuildTagNameOverridesForNamespaces(input)
        if shouldBuildOverrides {
            let overrides = buildStartTagOverrides(
                input: sanitizedInput,
                baseUri: baseUri,
                settings: settings,
                docPtr: docPtr
            )
            context.attributeOverrides = overrides.attributes
            context.tagNameOverrides = overrides.tagNames
            doc.libxml2AttributeOverrides = overrides.attributes
            doc.libxml2TagNameOverrides = overrides.tagNames
        } else {
            context.attributeOverrides = nil
            doc.libxml2AttributeOverrides = nil
            context.tagNameOverrides = nil
            doc.libxml2TagNameOverrides = nil
        }
        doc.libxml2Context = context
        doc.libxml2OriginalInput = nil
#endif
        builder.doc = doc
        doc.treeBuilder = builder
        var sawBase = false
        var sawTable = false
        var sawNoscript = false
        var sawFrameset = false
        _ = try buildDocument(
            doc: doc,
            docPtr: docPtr,
            baseUri: baseUri,
            settings: settings,
            builder: builder,
            hints: &hints,
            sawBase: &sawBase,
            sawTable: &sawTable,
            sawNoscript: &sawNoscript,
            sawFrameset: &sawFrameset,
            bindLibxml2Nodes: true,
            attributeOverrides: context.attributeOverrides,
            tagNameOverrides: context.tagNameOverrides
        )
        if sawNoscript {
            try normalizeNoscriptInHead(in: doc, baseUri: baseUri, builder: builder)
        }
        try doc.normalise()
        try normalizeBodyPlacement(in: doc)
        if sawFrameset {
            try normalizeFrameset(in: doc)
        }
        if sawBase {
            try applyBaseUriFromFirstBaseTag(in: doc)
        }
        if sawTable {
            try normalizeTables(in: doc, baseUri: baseUri, builder: builder)
        }
        let hasExplicitParagraph = hasExplicitParagraphStartTag(input)
        try normalizeImplicitParagraphs(in: doc, allowUnwrap: !hasExplicitParagraph)
        if booleanHintsEnabled(), var explicitHints = explicitBooleanHints {
            let explicit = buildExplicitBooleanAttributes(docPtr: docPtr, settings: settings, hints: &explicitHints)
            if !explicit.isEmpty {
                context.explicitBooleanAttributes = explicit
                doc.libxml2ExplicitBooleanAttributes = explicit
            }
        }
        if skipSwiftSoupFallbacks {
            doc.libxml2BackedDirty = true
        }
        doc.markQueryIndexesDirty()
        markLibxml2Hydrated(doc, markAttributes: false)
        if skipSwiftSoupFallbacks {
            docPtrToFree = nil
        }
        if Libxml2FallbackStats.enabled {
            Libxml2FallbackStats.shared.recordLibxmlUsed()
        }
        docPtrToFree = nil
        return doc
    }

    static func parseHtmlFragmentLibxml2Only(
        _ fragment: [UInt8],
        context: Element?,
        baseUri: [UInt8]
    ) throws -> [Node]? {
        guard let context,
              let doc = context.ownerDocument(),
              doc.libxml2SkipSwiftSoupFallbacks,
              let docPtr = doc.libxml2DocPtr else {
            return nil
        }
        let settings = doc.treeBuilder?.settings ?? doc.libxml2Context?.settings ?? ParseSettings.htmlDefault
        let wrapped = fragmentWrapperPrefix + fragment + fragmentWrapperSuffix
        let options = Int32(
            HTML_PARSE_RECOVER.rawValue
                | HTML_PARSE_NOERROR.rawValue
                | HTML_PARSE_NOWARNING.rawValue
                | HTML_PARSE_NONET.rawValue
                | HTML_PARSE_COMPACT.rawValue
                | HTML_PARSE_NODEFDTD.rawValue
        )
        let baseUriString = baseUri.isEmpty ? nil : String(decoding: baseUri, as: UTF8.self)
        let encoding = "UTF-8"
        let fragmentDocPtr: htmlDocPtr? = wrapped.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return nil }
            let cString = baseAddress.assumingMemoryBound(to: CChar.self)
            return encoding.withCString { encodingPtr in
                if let baseUriString {
                    return baseUriString.withCString { url in
                        htmlReadMemory(cString, Int32(rawBuffer.count), url, encodingPtr, options)
                    }
                }
                return htmlReadMemory(cString, Int32(rawBuffer.count), nil, encodingPtr, options)
            }
        }
        guard let fragmentDocPtr else { return nil }
        defer { xmlFreeDoc(fragmentDocPtr) }
        guard let bodyPtr = findFirstElementPtrByTagName(
            UTF8Arrays.body,
            docPtr: fragmentDocPtr,
            settings: settings
        ) else {
            return []
        }
        var nodes: [Node] = []
        var cursor: xmlNodePtr? = bodyPtr.pointee.children
        while let current = cursor {
            if libxml2NodeIsRepresented(current),
               let copied = xmlDocCopyNode(current, docPtr, 1) {
                if let wrappedNode = wrapNodeFromLibxml2(
                    copied,
                    doc: doc,
                    parent: doc,
                    settings: settings,
                    baseUri: baseUri
                ) {
                    wrappedNode.parentNode = nil
                    wrappedNode.setSiblingIndex(0)
                    nodes.append(wrappedNode)
                } else {
                    xmlFreeNode(copied)
                }
            }
            cursor = current.pointee.next
        }
        return nodes
    }

    static func parseXmlFragmentLibxml2Only(
        _ fragment: [UInt8],
        baseUri: [UInt8]
    ) throws -> [Node]? {
        let settings = ParseSettings.preserveCase
        let sanitizedInput = sanitizeXmlInputForLibxml2(fragment, settings: settings)
        let wrapped = xmlFragmentWrapperPrefix + sanitizedInput + xmlFragmentWrapperSuffix
        let options = Int32(
            XML_PARSE_RECOVER.rawValue
                | XML_PARSE_NOERROR.rawValue
                | XML_PARSE_NOWARNING.rawValue
                | XML_PARSE_NONET.rawValue
                | XML_PARSE_COMPACT.rawValue
        )
        let baseUriString = baseUri.isEmpty ? nil : String(decoding: baseUri, as: UTF8.self)
        let encoding = "UTF-8"
        let fragmentDocPtr: xmlDocPtr? = wrapped.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return nil }
            let cString = baseAddress.assumingMemoryBound(to: CChar.self)
            return encoding.withCString { encodingPtr in
                if let baseUriString {
                    return baseUriString.withCString { url in
                        xmlReadMemory(cString, Int32(rawBuffer.count), url, encodingPtr, options)
                    }
                }
                return xmlReadMemory(cString, Int32(rawBuffer.count), nil, encodingPtr, options)
            }
        }
        guard let fragmentDocPtr else { return nil }

        let doc = Document(baseUri)
        doc.parsedAsXml = true
        doc.outputSettings().syntax(syntax: OutputSettings.Syntax.xml)
        let context = Libxml2DocumentContext(docPtr: fragmentDocPtr, settings: settings, baseUri: baseUri)
        context.document = doc
        doc.parserBackend = .libxml2(swiftSoupParityMode: .libxml2Only)
        doc.libxml2DocPtr = fragmentDocPtr
        doc.libxml2BackedDirty = false
        doc.libxml2ChildrenHydrated = false
        doc.libxml2Preferred = true
        doc.libxml2Context = context
        doc._childNodes.removeAll(keepingCapacity: true)

        guard let rootPtr = xmlDocGetRootElement(fragmentDocPtr) else { return [] }
        var nodes: [Node] = []
        var cursor: xmlNodePtr? = rootPtr.pointee.children
        while let current = cursor {
            if libxml2NodeIsRepresented(current),
               let wrappedNode = wrapNodeFromLibxml2(
                    current,
                    doc: doc,
                    parent: doc,
                    settings: settings,
                    baseUri: baseUri
               ) {
                wrappedNode.parentNode = nil
                wrappedNode.setSiblingIndex(0)
                nodes.append(wrappedNode)
            }
            cursor = current.pointee.next
        }
        return nodes
    }

    static func parseHTMLFragment(
        _ input: [UInt8],
        context: Element?,
        baseUri: [UInt8],
        settings: ParseSettings,
        errors: ParseErrorList,
        builder: Libxml2TreeBuilder
    ) throws -> [Node] {
        _ = initialized

        let rawWrapperTag = context?.tagNameNormalUTF8()
        let wrapperTag: [UInt8]
        if let rawWrapperTag,
           !rawWrapperTag.isEmpty,
           rawWrapperTag != UTF8Arrays.hashRoot {
            wrapperTag = rawWrapperTag
        } else {
            wrapperTag = UTF8Arrays.body
        }
        var wrapped: [UInt8] = []
        wrapped.reserveCapacity(input.count + wrapperTag.count * 2 + 5)
        wrapped.append(contentsOf: UTF8Arrays.tagStart)
        wrapped.append(contentsOf: wrapperTag)
        wrapped.append(contentsOf: UTF8Arrays.tagEnd)
        wrapped.append(contentsOf: input)
        wrapped.append(contentsOf: UTF8Arrays.endTagStart)
        wrapped.append(contentsOf: wrapperTag)
        wrapped.append(contentsOf: UTF8Arrays.tagEnd)

        let sanitizedWrapped = builder.skipSwiftSoupFallbacks ? wrapped : sanitizeHtmlInputForLibxml2(wrapped)
        let options = Int32(
            HTML_PARSE_RECOVER.rawValue
                | HTML_PARSE_NOERROR.rawValue
                | HTML_PARSE_NOWARNING.rawValue
                | HTML_PARSE_NONET.rawValue
                | HTML_PARSE_COMPACT.rawValue
                | HTML_PARSE_NODEFDTD.rawValue
        )
        let baseUriString = baseUri.isEmpty ? nil : String(decoding: baseUri, as: UTF8.self)
        let encoding = "UTF-8"
        let docPtr: htmlDocPtr? = sanitizedWrapped.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return nil }
            let cString = baseAddress.assumingMemoryBound(to: CChar.self)
            return encoding.withCString { encodingPtr in
                if let baseUriString {
                    return baseUriString.withCString { url in
                        htmlReadMemory(cString, Int32(rawBuffer.count), url, encodingPtr, options)
                    }
                }
                return htmlReadMemory(cString, Int32(rawBuffer.count), nil, encodingPtr, options)
            }
        }
        guard let docPtr else {
            throw Libxml2BackendError.parseFailed
        }
        defer { xmlFreeDoc(docPtr) }

        builder.errors = errors
        builder.settings = settings
        builder.tracksSourceRanges = false
        builder.tracksErrors = errors.getMaxSize() > 0

        let doc = Document(baseUri)
        builder.doc = doc
        doc.treeBuilder = builder

        let attributeOverrides: [UnsafeMutableRawPointer: Attributes]?
        let tagNameOverrides: [UnsafeMutableRawPointer: [UInt8]]?
        let preserveCase = settings.preservesTagCase() || settings.preservesAttributeCase()
        if !builder.skipSwiftSoupFallbacks
            && (shouldBuildAttributeOverrides(wrapped, preserveCase: preserveCase)
                || shouldBuildTagNameOverridesForNamespaces(wrapped)) {
            let overrides = buildStartTagOverrides(
                input: sanitizedWrapped,
                baseUri: baseUri,
                settings: settings,
                docPtr: docPtr
            )
            attributeOverrides = overrides.attributes
            tagNameOverrides = overrides.tagNames
        } else {
            attributeOverrides = nil
            tagNameOverrides = nil
        }
        var hints: HtmlScanHints
        if builder.skipSwiftSoupFallbacks {
            hints = HtmlScanHints()
        } else {
            hints = HtmlScanHints(html: sanitizedWrapped, settings: settings)
        }
        var sawBase = false
        var sawTable = false
        var sawNoscript = false
        var sawFrameset = false
        builder.beginBulkAppend()
        defer { builder.endBulkAppend() }
        if let root = docPtr.pointee.children {
            try buildChildren(
                from: root,
                parent: doc,
                docPtr: docPtr,
                baseUri: baseUri,
                settings: settings,
                builder: builder,
                hints: &hints,
                sawBase: &sawBase,
                sawTable: &sawTable,
                sawNoscript: &sawNoscript,
                sawFrameset: &sawFrameset,
                bindLibxml2Nodes: false,
                attributeOverrides: attributeOverrides,
                tagNameOverrides: tagNameOverrides
            )
        }

        let wrapperName = String(decoding: wrapperTag, as: UTF8.self)
        if let wrapper = try? doc.getElementsByTag(wrapperName).first() {
            return wrapper.getChildNodes()
        }
        return doc.getChildNodes()
    }

    static func materializeLazyDocument(_ doc: Document, state: Libxml2LazyState) {
        guard let docPtr = doc.libxml2DocPtr else { return }
        let builder = doc.treeBuilder as? Libxml2TreeBuilder
            ?? Libxml2TreeBuilder(skipSwiftSoupFallbacks: doc.libxml2SkipSwiftSoupFallbacks)
        builder.errors = state.errors
        builder.settings = state.settings
        builder.tracksSourceRanges = false
        builder.tracksErrors = state.errors.getMaxSize() > 0
        builder.doc = doc
        doc.treeBuilder = builder

        func fallbackToSwiftSoup(_ reason: Libxml2FallbackReason?) {
            if Libxml2FallbackStats.enabled {
                let sample = Libxml2FallbackStats.sampleEnabled ? sampleSnippet(state.input) : nil
                Libxml2FallbackStats.shared.recordFallback(reason ?? .unknown, sample: sample)
            }
            let fallbackBuilder = HtmlTreeBuilder()
            if let parsed = try? fallbackBuilder.parse(state.input, state.baseUri, state.errors, state.settings) {
                if let docPtr = doc.libxml2DocPtr {
                    xmlFreeDoc(docPtr)
                    doc.libxml2DocPtr = nil
                }
                doc.libxml2BackedDirty = true
                doc.adopt(from: parsed, builder: fallbackBuilder)
            }
        }

        do {
            let skipSwiftSoupFallbacks = doc.libxml2SkipSwiftSoupFallbacks
            var hints: HtmlScanHints
            if skipSwiftSoupFallbacks {
                hints = HtmlScanHints()
            } else if state.forceLibxml2 || state.fastScan {
                hints = HtmlScanHints(html: state.input, settings: state.settings)
            } else {
                var scanHints = HtmlScanHints()
                var reason: Libxml2FallbackReason? = nil
                let shouldFallback = shouldFallbackToSwiftSoup(
                    state.input,
                    reason: &reason,
                    recordReason: Libxml2FallbackStats.enabled,
                    hints: &scanHints
                )
                if shouldFallback {
                    fallbackToSwiftSoup(reason)
                    return
                }
                hints = scanHints
            }
            let explicitBooleanHints = booleanHintsEnabled() ? hints : nil

            var sawBase = false
            var sawTable = false
            var sawNoscript = false
            var sawFrameset = false
            let doc = try buildDocument(
                doc: doc,
                docPtr: docPtr,
                baseUri: state.baseUri,
                settings: state.settings,
                builder: builder,
                hints: &hints,
                sawBase: &sawBase,
                sawTable: &sawTable,
                sawNoscript: &sawNoscript,
                sawFrameset: &sawFrameset,
                attributeOverrides: doc.libxml2AttributeOverrides,
                tagNameOverrides: doc.libxml2TagNameOverrides
            )
            if !skipSwiftSoupFallbacks {
                if sawNoscript {
                    try normalizeNoscriptInHead(in: doc, baseUri: state.baseUri, builder: builder)
                }
                try doc.normalise()
                try normalizeBodyPlacement(in: doc)
                if sawFrameset {
                    try normalizeFrameset(in: doc)
                }
                if sawBase {
                    try applyBaseUriFromFirstBaseTag(in: doc)
                }
                if sawTable {
                    try normalizeTables(in: doc, baseUri: state.baseUri, builder: builder)
                }
                if booleanHintsEnabled(), var explicitHints = explicitBooleanHints {
                    let explicit = buildExplicitBooleanAttributes(docPtr: docPtr, settings: state.settings, hints: &explicitHints)
                    if !explicit.isEmpty {
                        doc.libxml2Context?.explicitBooleanAttributes = explicit
                        doc.libxml2ExplicitBooleanAttributes = explicit
                    }
                }
            }
            if Libxml2FallbackStats.enabled {
                Libxml2FallbackStats.shared.recordLibxmlUsed()
            }
        } catch {
            if !doc.libxml2SkipSwiftSoupFallbacks {
                fallbackToSwiftSoup(nil)
            }
        }
    }

    static func parseXML(
        _ input: [UInt8],
        baseUri: [UInt8],
        settings: ParseSettings,
        errors: ParseErrorList,
        builder: Libxml2XmlTreeBuilder
    ) throws -> Document {
        _ = initialized

        let sanitizedInput = sanitizeXmlInputForLibxml2(input, settings: settings)
        if !builder.skipSwiftSoupFallbacks,
           containsEndTagForHtmlVoidTags(sanitizedInput) {
            let fallbackBuilder = XmlTreeBuilder()
            return try fallbackBuilder.parse(input, baseUri, errors, settings)
        }
        let options = Int32(
            XML_PARSE_RECOVER.rawValue
                | XML_PARSE_NOERROR.rawValue
                | XML_PARSE_NOWARNING.rawValue
                | XML_PARSE_NONET.rawValue
                | XML_PARSE_COMPACT.rawValue
        )
        let baseUriString = baseUri.isEmpty ? nil : String(decoding: baseUri, as: UTF8.self)
        let encoding = "UTF-8"
        let docPtr: xmlDocPtr? = sanitizedInput.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return nil }
            let cString = baseAddress.assumingMemoryBound(to: CChar.self)
            return encoding.withCString { encodingPtr in
                if let baseUriString {
                    return baseUriString.withCString { url in
                        xmlReadMemory(cString, Int32(rawBuffer.count), url, encodingPtr, options)
                    }
                }
                return xmlReadMemory(cString, Int32(rawBuffer.count), nil, encodingPtr, options)
            }
        }
        guard let docPtr else {
            throw Libxml2BackendError.parseFailed
        }
        var docPtrToFree: xmlDocPtr? = docPtr
        defer {
            if let docPtrToFree {
                xmlFreeDoc(docPtrToFree)
            }
        }
        builder.errors = errors
        builder.settings = settings
        builder.tracksSourceRanges = false
        builder.tracksErrors = errors.getMaxSize() > 0

        let doc = Document(baseUri)
        doc.parsedAsXml = true
        doc.outputSettings().syntax(syntax: OutputSettings.Syntax.xml)
#if canImport(CLibxml2) || canImport(libxml2)
        let context = Libxml2DocumentContext(docPtr: docPtr, settings: settings, baseUri: baseUri)
        context.document = doc
        doc.parserBackend = .libxml2(
            swiftSoupParityMode: builder.skipSwiftSoupFallbacks ? .libxml2Only : .swiftSoupParity
        )
        doc.libxml2DocPtr = docPtr
        doc.libxml2BackedDirty = false
        doc.libxml2ChildrenHydrated = false
        doc._childNodes.removeAll(keepingCapacity: true)
        doc.libxml2Preferred = true
        let preserveCase = settings.preservesTagCase() || settings.preservesAttributeCase()
        if builder.skipSwiftSoupFallbacks
            || shouldBuildAttributeOverrides(sanitizedInput, preserveCase: preserveCase)
            || shouldBuildTagNameOverridesForNamespaces(sanitizedInput) {
            let overrides = buildStartTagOverrides(
                input: sanitizedInput,
                baseUri: baseUri,
                settings: settings,
                docPtr: docPtr
            )
            context.attributeOverrides = overrides.attributes
            context.tagNameOverrides = overrides.tagNames
            doc.libxml2AttributeOverrides = overrides.attributes
            doc.libxml2TagNameOverrides = overrides.tagNames
        } else {
            context.attributeOverrides = nil
            doc.libxml2AttributeOverrides = nil
            context.tagNameOverrides = nil
            doc.libxml2TagNameOverrides = nil
        }
        doc.libxml2Context = context
        doc.libxml2OriginalInput = sanitizedInput
#endif
        builder.doc = doc
        doc.treeBuilder = builder
        docPtrToFree = nil
        return doc
    }

    static func attachLibxml2Document(_ doc: Document, isXml: Bool = false) {
#if canImport(CLibxml2) || canImport(libxml2)
        guard doc.libxml2DocPtr == nil else { return }
        let docPtr: xmlDocPtr?
        if isXml {
            docPtr = xmlNewDoc("1.0")
        } else {
            docPtr = htmlNewDoc(nil, nil)
        }
        guard let docPtr else { return }
        doc.libxml2DocPtr = docPtr
        doc.libxml2BackedDirty = false
        doc.libxml2AttributeOverrides = nil
        doc.libxml2TagNameOverrides = nil
        doc.libxml2OriginalInput = nil
        doc.libxml2Context = nil
        doc.libxml2Preferred = true

        if let html = try? doc.getElementsByTag(UTF8Arrays.html).first(),
           let rootPtr = html.libxml2EnsureNode(in: doc) {
            xmlDocSetRootElement(docPtr, rootPtr)
            return
        }
        if let root = doc.children().first(),
           let rootPtr = root.libxml2EnsureNode(in: doc) {
            xmlDocSetRootElement(docPtr, rootPtr)
        }
#endif
    }

    private static func buildDocument(
        doc: Document,
        docPtr: htmlDocPtr,
        baseUri: [UInt8],
        settings: ParseSettings,
        builder: Libxml2TreeBuilder,
        hints: inout HtmlScanHints,
        sawBase: inout Bool,
        sawTable: inout Bool,
        sawNoscript: inout Bool,
        sawFrameset: inout Bool,
        bindLibxml2Nodes: Bool = true,
        attributeOverrides: [UnsafeMutableRawPointer: Attributes]? = nil,
        tagNameOverrides: [UnsafeMutableRawPointer: [UInt8]]? = nil
    ) throws -> Document {
        doc._childNodes.removeAll(keepingCapacity: true)
        doc._attributes = nil
#if canImport(CLibxml2) || canImport(libxml2)
        // We're about to fully materialize the tree; avoid lazy hydration while building.
        doc.libxml2ChildrenHydrated = true
        doc.libxml2AttributesHydrated = true
#endif
        builder.beginBulkAppend()
        defer { builder.endBulkAppend() }

        if let dtd = xmlGetIntSubset(docPtr) {
            let rawName = bytesFromXmlChar(dtd.pointee.name)
            let name = containsUppercaseAscii(rawName) ? settings.normalizeTag(rawName) : rawName
            let publicId = bytesFromXmlChar(dtd.pointee.ExternalID)
            let systemId = bytesFromXmlChar(dtd.pointee.SystemID)
            let doctype = DocumentType(name, publicId, systemId, baseUri)
            doctype.treeBuilder = builder
            try doc.appendChild(doctype)
        }

        if let root = docPtr.pointee.children {
            try buildChildren(
                from: root,
                parent: doc,
                docPtr: docPtr,
                baseUri: baseUri,
                settings: settings,
                builder: builder,
                hints: &hints,
                sawBase: &sawBase,
                sawTable: &sawTable,
                sawNoscript: &sawNoscript,
                sawFrameset: &sawFrameset,
                bindLibxml2Nodes: bindLibxml2Nodes,
                attributeOverrides: attributeOverrides,
                tagNameOverrides: tagNameOverrides
            )
        }
        return doc
    }

    private static func markLibxml2Hydrated(_ root: Node, markAttributes: Bool) {
        var stack: [Node] = [root]
        while let node = stack.popLast() {
            node.libxml2ChildrenHydrated = true
            if markAttributes, node is Element {
                node.libxml2AttributesHydrated = true
            }
            let children = node._childNodes
            if !children.isEmpty {
                for child in children.reversed() {
                    stack.append(child)
                }
            }
        }
    }

    private static func buildChildren(
        from nodePtr: xmlNodePtr?,
        parent: Element,
        docPtr: xmlDocPtr,
        baseUri: [UInt8],
        settings: ParseSettings,
        builder: Libxml2TreeBuilder,
        hints: inout HtmlScanHints,
        sawBase: inout Bool,
        sawTable: inout Bool,
        sawNoscript: inout Bool,
        sawFrameset: inout Bool,
        bindLibxml2Nodes: Bool,
        attributeOverrides: [UnsafeMutableRawPointer: Attributes]? = nil,
        tagNameOverrides: [UnsafeMutableRawPointer: [UInt8]]? = nil
    ) throws {
        @inline(__always)
        func fastAppend(_ child: Node) {
            // Bulk build fast path: avoid Element.appendChild overhead.
            child.treeBuilder = builder
            child.parentNode = parent
            parent._childNodes.append(child)
            child.setSiblingIndex(parent._childNodes.count - 1)
        }

        let preferHints = !builder.skipSwiftSoupFallbacks && booleanHintsEnabled()
        var current = nodePtr
        while let node = current {
            let type = node.pointee.type
            switch type {
            case XML_ELEMENT_NODE:
                let rawName = qualifiedName(for: node)
                var normalizedName = containsUppercaseAscii(rawName) ? settings.normalizeTag(rawName) : rawName
                if let overrideName = tagNameOverrides?[UnsafeMutableRawPointer(node)] {
                    normalizedName = containsUppercaseAscii(overrideName) ? settings.normalizeTag(overrideName) : overrideName
                }
                if normalizedName == UTF8Arrays.base {
                    sawBase = true
                } else if normalizedName == UTF8Arrays.table {
                    sawTable = true
                } else if normalizedName == UTF8Arrays.noscript {
                    sawNoscript = true
                } else if normalizedName == UTF8Arrays.frameset {
                    sawFrameset = true
                }
                let occurrenceSelfClose = hints.consumeSelfClosing(for: normalizedName)
                let isUnknown = !Tag.isKnownTag(normalizedName)
                let hasChildren = node.pointee.children != nil
                let shouldSelfClose = isUnknown && occurrenceSelfClose && !hasChildren
                let tag = try Tag.valueOfNormalized(normalizedName, isSelfClosing: shouldSelfClose)
                let element: Element
                if !bindLibxml2Nodes, node.pointee.properties != nil {
                    let collected = Attributes()
                    if normalizedName == UTF8Arrays.form {
                        element = FormElement(tag, baseUri, collected, skipChildReserve: builder.isBulkBuilding)
                    } else {
                        element = Element(tag, baseUri, collected, skipChildReserve: builder.isBulkBuilding)
                    }
                    #if PROFILE
                    let pAttrs = Profiler.start("Libxml2.buildAttrs")
                    #endif
                    if var attr = node.pointee.properties {
                        while true {
                            let rawAttrName = qualifiedName(for: attr)
                            let attrName = containsUppercaseAscii(rawAttrName) ? settings.normalizeAttribute(rawAttrName) : rawAttrName
                            let booleanIndex = booleanAttributeIndex(for: attrName[...])
                            var isBoolean = false
                            var value: [UInt8]? = nil
                            if let booleanIndex {
                                if preferHints {
                                    isBoolean = hints.consumeBooleanAttribute(index: booleanIndex)
                                } else if attr.pointee.children == nil {
                                    isBoolean = true
                                } else {
                                    if let child = attr.pointee.children,
                                       child.pointee.next == nil,
                                       (child.pointee.type == XML_TEXT_NODE || child.pointee.type == XML_ENTITY_REF_NODE),
                                       let contentPtr = child.pointee.content {
                                        value = bytesFromXmlChar(contentPtr)
                                    } else {
                                        #if PROFILE
                                        let pValue = Profiler.start("Libxml2.attrValue")
                                        #endif
                                        let valuePtr = xmlNodeListGetString(docPtr, attr.pointee.children, 1)
                                        value = bytesFromXmlChar(valuePtr)
                                        if let valuePtr {
                                            xmlFree(valuePtr)
                                        }
                                        #if PROFILE
                                        Profiler.end("Libxml2.attrValue", pValue)
                                        #endif
                                    }
                                    if let value, equalsIgnoreCaseAscii(attrName, value) {
                                        isBoolean = true
                                    }
                                }
                            } else if attr.pointee.children == nil {
                                isBoolean = true
                            }
                            if isBoolean {
                                let booleanAttr = try BooleanAttribute(key: attrName)
                                collected.put(attribute: booleanAttr)
                            } else {
                                if value == nil {
                                    if let child = attr.pointee.children,
                                       child.pointee.next == nil,
                                       (child.pointee.type == XML_TEXT_NODE || child.pointee.type == XML_ENTITY_REF_NODE),
                                       let contentPtr = child.pointee.content {
                                        value = bytesFromXmlChar(contentPtr)
                                    } else {
                                        #if PROFILE
                                        let pValue = Profiler.start("Libxml2.attrValue")
                                        #endif
                                        let valuePtr = xmlNodeListGetString(docPtr, attr.pointee.children, 1)
                                        value = bytesFromXmlChar(valuePtr)
                                        if let valuePtr {
                                            xmlFree(valuePtr)
                                        }
                                        #if PROFILE
                                        Profiler.end("Libxml2.attrValue", pValue)
                                        #endif
                                    }
                                }
                                if let value {
                                    try collected.put(attrName, value)
                                }
                            }
                            guard let next = attr.pointee.next else { break }
                            attr = next
                        }
                    }
                    #if PROFILE
                    Profiler.end("Libxml2.buildAttrs", pAttrs)
                    #endif
                } else {
                    if normalizedName == UTF8Arrays.form {
                        element = FormElement(tag, baseUri, skipChildReserve: builder.isBulkBuilding)
                    } else {
                        element = Element(tag, baseUri, skipChildReserve: builder.isBulkBuilding)
                    }
                }
#if canImport(CLibxml2) || canImport(libxml2)
                // This element will be materialized by the builder; prevent lazy hydration mid-build.
                element.libxml2ChildrenHydrated = true
                if !bindLibxml2Nodes {
                    element.libxml2AttributesHydrated = true
                }
#endif
                if !bindLibxml2Nodes,
                   let overrideAttrs = attributeOverrides?[UnsafeMutableRawPointer(node)] {
                    element.attributes = overrideAttrs
                    overrideAttrs.ownerElement = element
                }
                if bindLibxml2Nodes {
                    #if canImport(CLibxml2) || canImport(libxml2)
                    element.libxml2NodePtr = node
                    node.pointee._private = Unmanaged.passUnretained(element).toOpaque()
                    #endif
                }
                element.libxml2Context = parent.libxml2Context
                if builder.isBulkBuilding {
                    fastAppend(element)
                } else {
                    element.treeBuilder = builder
                    try parent.appendChild(element)
                }
                if element.tag().isFormListed() {
                    var cursor: Node? = parent
                    while let node = cursor {
                        if let form = node as? FormElement {
                            form.addElement(element)
                            break
                        }
                        cursor = node.parentNode
                    }
                }
                if let child = node.pointee.children {
                    try buildChildren(
                        from: child,
                        parent: element,
                        docPtr: docPtr,
                        baseUri: baseUri,
                        settings: settings,
                        builder: builder,
                        hints: &hints,
                        sawBase: &sawBase,
                        sawTable: &sawTable,
                        sawNoscript: &sawNoscript,
                        sawFrameset: &sawFrameset,
                        bindLibxml2Nodes: bindLibxml2Nodes,
                        attributeOverrides: attributeOverrides,
                        tagNameOverrides: tagNameOverrides
                    )
                }
            case XML_TEXT_NODE, XML_CDATA_SECTION_NODE, XML_ENTITY_REF_NODE:
                let content: [UInt8]
                if let contentPtr = node.pointee.content {
                    content = bytesFromXmlChar(contentPtr)
                } else {
                    let contentPtr = xmlNodeGetContent(node)
                    content = bytesFromXmlChar(contentPtr)
                    if let contentPtr {
                        xmlFree(contentPtr)
                    }
                }
                if !content.isEmpty {
                    try appendTextNode(
                        content: content,
                        parent: parent,
                        baseUri: baseUri,
                        builder: builder,
                        nodePtr: bindLibxml2Nodes ? node : nil
                    )
                }
            case XML_COMMENT_NODE:
                let content: [UInt8]
                if let contentPtr = node.pointee.content {
                    content = bytesFromXmlChar(contentPtr)
                } else {
                    let contentPtr = xmlNodeGetContent(node)
                    content = bytesFromXmlChar(contentPtr)
                    if let contentPtr {
                        xmlFree(contentPtr)
                    }
                }
                let comment = Comment(content, baseUri)
                if bindLibxml2Nodes {
                    #if canImport(CLibxml2) || canImport(libxml2)
                    comment.libxml2NodePtr = node
                    node.pointee._private = Unmanaged.passUnretained(comment).toOpaque()
                    #endif
                }
                comment.libxml2Context = parent.libxml2Context
                if builder.isBulkBuilding {
                    fastAppend(comment)
                } else {
                    comment.treeBuilder = builder
                    try parent.appendChild(comment)
                }
            case XML_PI_NODE:
                let name = bytesFromXmlChar(node.pointee.name)
                let normalizedName = containsUppercaseAscii(name) ? settings.normalizeTag(name) : name
                let declaration = XmlDeclaration(normalizedName, baseUri, false)
                if let contentPtr = node.pointee.content {
                    let content = String(decoding: bytesFromXmlChar(contentPtr), as: UTF8.self)
                    let base = String(decoding: baseUri, as: UTF8.self)
                    let tempDoc = try Parser.xmlParser(.swiftSoup).parseInput("<" + declaration.name() + " " + content + ">", base)
                    if let el = tempDoc.childNodes.first as? Element {
                        declaration.getAttributes()?.addAll(incoming: el.getAttributes())
                    }
                }
                if bindLibxml2Nodes {
                    #if canImport(CLibxml2) || canImport(libxml2)
                    declaration.libxml2NodePtr = node
                    node.pointee._private = Unmanaged.passUnretained(declaration).toOpaque()
                    #endif
                }
                declaration.libxml2Context = parent.libxml2Context
                if builder.isBulkBuilding {
                    fastAppend(declaration)
                } else {
                    declaration.treeBuilder = builder
                    try parent.appendChild(declaration)
                }
            case XML_DTD_NODE, XML_DOCUMENT_TYPE_NODE:
                break
            default:
                break
            }
            current = node.pointee.next
        }
    }

    private static func appendTextNode(
        content: [UInt8],
        parent: Element,
        baseUri: [UInt8],
        builder: Libxml2TreeBuilder,
        nodePtr: xmlNodePtr? = nil
    ) throws {
        let isScriptOrStyle = isScriptOrStyleParent(parent)
        if isScriptOrStyle, let lastData = parent.childNodes.last as? DataNode {
            lastData.appendBytes(content)
            return
        }
        if !isScriptOrStyle, let lastText = parent.childNodes.last as? TextNode {
            lastText.appendBytes(content)
            return
        }
        let node: Node
        if isScriptOrStyle {
            node = DataNode(content, baseUri)
        } else {
            node = TextNode(content, baseUri)
        }
#if canImport(CLibxml2) || canImport(libxml2)
        node.libxml2NodePtr = nodePtr
        node.libxml2Context = parent.libxml2Context
        if let nodePtr {
            nodePtr.pointee._private = Unmanaged.passUnretained(node).toOpaque()
        }
#endif
        if builder.isBulkBuilding {
            node.treeBuilder = builder
            node.parentNode = parent
            parent._childNodes.append(node)
            node.setSiblingIndex(parent._childNodes.count - 1)
        } else {
            node.treeBuilder = builder
            try parent.appendChild(node)
        }
    }

    private static func isScriptOrStyleParent(_ parent: Node) -> Bool {
        guard let element = parent as? Element else { return false }
        let tag = element.tagNameNormalUTF8()
        return tag == UTF8Arrays.script || tag == UTF8Arrays.style
    }

    @inline(__always)
    private static func bytesFromXmlChar(_ ptr: UnsafePointer<xmlChar>?) -> [UInt8] {
        guard let ptr else { return [] }
        let length = Int(xmlStrlen(ptr))
        guard length > 0 else { return [] }
        return Array(UnsafeBufferPointer(start: ptr, count: length))
    }

    @inline(__always)
    static func attributeValueFromLibxml2Node(_ node: xmlNodePtr, key: [UInt8]) -> [UInt8]? {
        guard !key.isEmpty else { return nil }
        let attrName = key + [0]
        return attrName.withUnsafeBufferPointer { buf in
            guard let base = buf.baseAddress else { return nil }
            let attrPtr = base.withMemoryRebound(to: xmlChar.self, capacity: buf.count) { $0 }
            guard let valuePtr = xmlGetProp(node, attrPtr) else { return nil }
            let raw = bytesFromXmlChar(valuePtr)
            xmlFree(valuePtr)
            return raw
        }
    }

    @inline(__always)
    static func hasAttributeInLibxml2Node(_ node: xmlNodePtr, key: [UInt8]) -> Bool {
        guard !key.isEmpty else { return false }
        let attrName = key + [0]
        return attrName.withUnsafeBufferPointer { buf in
            guard let base = buf.baseAddress else { return false }
            let attrPtr = base.withMemoryRebound(to: xmlChar.self, capacity: buf.count) { $0 }
            return xmlHasProp(node, attrPtr) != nil
        }
    }

    @inline(__always)
    private static func containsUppercaseAscii(_ bytes: [UInt8]) -> Bool {
        for b in bytes {
            if b >= 0x41 && b <= 0x5A {
                return true
            }
        }
        return false
    }

    @inline(__always)
    private static func qualifiedName(for node: xmlNodePtr) -> [UInt8] {
        let localName = bytesFromXmlChar(node.pointee.name)
        guard let ns = node.pointee.ns,
              let prefixPtr = ns.pointee.prefix
        else {
            return localName
        }
        let prefix = bytesFromXmlChar(prefixPtr)
        guard !prefix.isEmpty else { return localName }
        var full = prefix
        full.append(0x3A)
        full.append(contentsOf: localName)
        return full
    }

    @inline(__always)
    private static func asciiLower(_ b: UInt8) -> UInt8 {
        return (b >= 65 && b <= 90) ? (b &+ 32) : b
    }

    @inline(__always)
    private static func cStringEqualsLowercase(
        _ ptr: UnsafePointer<xmlChar>,
        _ bytes: ArraySlice<UInt8>
    ) -> Bool {
        var i = 0
        while true {
            let c = ptr[i]
            if c == 0 {
                return i == bytes.count
            }
            if i >= bytes.count {
                return false
            }
            if asciiLower(UInt8(c)) != bytes[bytes.startIndex + i] {
                return false
            }
            i &+= 1
        }
    }

    @inline(__always)
    private static func cStringEqualsAnyLowercase(
        _ ptr: UnsafePointer<xmlChar>,
        _ tags: [[UInt8]]
    ) -> Bool {
        for tag in tags {
            var i = 0
            var matched = true
            while true {
                let c = ptr[i]
                if c == 0 {
                    matched = i == tag.count
                    break
                }
                if i >= tag.count {
                    matched = false
                    break
                }
                if asciiLower(UInt8(c)) != tag[i] {
                    matched = false
                    break
                }
                i &+= 1
            }
            if matched {
                return true
            }
        }
        return false
    }

    @inline(__always)
    private static func qualifiedName(for attr: xmlAttrPtr) -> [UInt8] {
        let localName = bytesFromXmlChar(attr.pointee.name)
        guard let ns = attr.pointee.ns,
              let prefixPtr = ns.pointee.prefix
        else {
            return localName
        }
        let prefix = bytesFromXmlChar(prefixPtr)
        guard !prefix.isEmpty else { return localName }
        var full = prefix
        full.append(0x3A)
        full.append(contentsOf: localName)
        return full
    }

    private static func normalizeTables(
        in doc: Document,
        baseUri: [UInt8],
        builder: Libxml2TreeBuilder
    ) throws {
        let tables = try doc.getElementsByTag("table")
        if tables.size() == 0 {
            return
        }
        for table in tables.array() {
            var tbody: Element? = nil
            var directTr: [Element] = []
            for child in table.children().array() {
                switch child.tagNameNormalUTF8() {
                case UTF8Arrays.tbody:
                    if tbody == nil {
                        tbody = child
                    }
                case UTF8Arrays.tr:
                    directTr.append(child)
                default:
                    break
                }
            }
            if directTr.isEmpty {
                continue
            }
            let targetTbody: Element
            if let existing = tbody {
                targetTbody = existing
            } else {
                let tag = try Tag.valueOf(UTF8Arrays.tbody, ParseSettings.htmlDefault)
                let created = Element(tag, baseUri)
                created.treeBuilder = builder
                try table.prependChild(created)
                targetTbody = created
            }
            for tr in directTr {
                try targetTbody.appendChild(tr)
            }
        }
    }

    private static func normalizeNoscriptInHead(
        in doc: Document,
        baseUri: [UInt8],
        builder: Libxml2TreeBuilder
    ) throws {
        let noscripts = try doc.getElementsByTag("noscript")
        if noscripts.size() == 0 {
            return
        }
        for noscript in noscripts.array() {
            guard let parent = noscript.parent() else { continue }
            if parent.tagNameNormalUTF8() != UTF8Arrays.head {
                continue
            }
            let originalChildren = noscript.childNodes
            var newChildren: [Node] = []
            newChildren.reserveCapacity(originalChildren.count)
            for child in originalChildren {
                try appendNoscriptContent(from: child, into: &newChildren, baseUri: baseUri, builder: builder)
            }
            _ = noscript.empty()
            for node in newChildren {
                try noscript.appendChild(node)
            }
        }
    }

    private static let noscriptHeadAllowedTags: [[UInt8]] = [
        [0x62, 0x61, 0x73, 0x65, 0x66, 0x6F, 0x6E, 0x74], // basefont
        [0x62, 0x67, 0x73, 0x6F, 0x75, 0x6E, 0x64], // bgsound
        [0x6C, 0x69, 0x6E, 0x6B], // link
        [0x6D, 0x65, 0x74, 0x61], // meta
        [0x6E, 0x6F, 0x66, 0x72, 0x61, 0x6D, 0x65, 0x73], // noframes
        UTF8Arrays.style
    ]

    private static func appendNoscriptContent(
        from node: Node,
        into nodes: inout [Node],
        baseUri: [UInt8],
        builder: Libxml2TreeBuilder
    ) throws {
        if let text = node as? TextNode {
            appendNoscriptText(text.getWholeTextUTF8(), into: &nodes, baseUri: baseUri, builder: builder)
            return
        }
        if let comment = node as? Comment {
            let clone = Comment(comment.getDataUTF8(), baseUri)
            clone.treeBuilder = builder
            nodes.append(clone)
            return
        }
        if let data = node as? DataNode {
            appendNoscriptText(data.getWholeDataUTF8(), into: &nodes, baseUri: baseUri, builder: builder)
            return
        }
        if let element = node as? Element {
            let tagName = element.tagNameNormalUTF8()
            if tagName == UTF8Arrays.head || tagName == UTF8Arrays.noscript {
                for child in element.childNodes {
                    try appendNoscriptContent(from: child, into: &nodes, baseUri: baseUri, builder: builder)
                }
                return
            }
            if noscriptHeadAllowedTags.contains(tagName) {
                let clone = element.copy(parent: nil)
                clone.treeBuilder = builder
                nodes.append(clone)
                return
            }
            appendNoscriptText(startTagBytes(for: element), into: &nodes, baseUri: baseUri, builder: builder)
            if !element.childNodes.isEmpty {
                for child in element.childNodes {
                    try appendNoscriptContent(from: child, into: &nodes, baseUri: baseUri, builder: builder)
                }
            }
            return
        }
    }

    private static func appendNoscriptText(
        _ bytes: [UInt8],
        into nodes: inout [Node],
        baseUri: [UInt8],
        builder: Libxml2TreeBuilder
    ) {
        guard !bytes.isEmpty else { return }
        if let last = nodes.last as? TextNode {
            last.appendBytes(bytes)
            return
        }
        let textNode = TextNode(bytes, baseUri)
        textNode.treeBuilder = builder
        nodes.append(textNode)
    }

    private static func startTagBytes(for element: Element) -> [UInt8] {
        var bytes: [UInt8] = [0x3C]
        bytes.append(contentsOf: element.tagNameNormalUTF8())
        if let attributes = element.attributes, attributes.size() > 0 {
            if let attrBytes = try? attributes.htmlUTF8() {
                bytes.append(contentsOf: attrBytes)
            }
        }
        bytes.append(0x3E)
        return bytes
    }

    private static func normalizeBodyPlacement(in doc: Document) throws {
        guard let body = doc.body() else { return }
        let html = try doc.getElementsByTag(UTF8Arrays.html).first()
        guard let html else { return }
        var beforeBodyHtml: [Node] = []
        var afterBodyHtml: [Node] = []
        var seenBody = false
        for child in html.childNodes {
            if child === body {
                seenBody = true
                continue
            }
            guard let element = child as? Element else { continue }
            if element.tagNameNormalUTF8() == UTF8Arrays.head {
                continue
            }
            if seenBody {
                afterBodyHtml.append(element)
            } else {
                beforeBodyHtml.append(element)
            }
        }

        let docChildren = doc.childNodes
        let htmlIndex = docChildren.firstIndex(where: { $0 === html }) ?? docChildren.count
        var beforeBodyDoc: [Node] = []
        var afterBodyDoc: [Node] = []
        if !docChildren.isEmpty {
            for (idx, child) in docChildren.enumerated() {
                guard let element = child as? Element else { continue }
                if element === html {
                    continue
                }
                if idx < htmlIndex {
                    beforeBodyDoc.append(element)
                } else {
                    afterBodyDoc.append(element)
                }
            }
        }

        let beforeBody = beforeBodyDoc + beforeBodyHtml
        let afterBody = afterBodyHtml + afterBodyDoc

        if !beforeBody.isEmpty {
            for node in beforeBody.reversed() {
                if moveNodePreservingLibxml2(node, to: body, prepend: true) {
                    continue
                }
                try node.remove()
                try body.prependChild(node)
            }
        }
        if !afterBody.isEmpty {
            for node in afterBody {
                if moveNodePreservingLibxml2(node, to: body, prepend: false) {
                    continue
                }
                try node.remove()
                try body.appendChild(node)
            }
        }
    }

    @inline(__always)
    private static func moveNodePreservingLibxml2(
        _ node: Node,
        to parent: Element,
        prepend: Bool
    ) -> Bool {
#if canImport(CLibxml2) || canImport(libxml2)
        guard let doc = parent.ownerDocument(), doc.libxml2DocPtr != nil else { return false }
        guard let nodePtr = node.libxml2NodePtr,
              let parentPtr = parent.libxml2NodePtr else { return false }

        if let oldParent = node.parentNode {
            if let idx = oldParent._childNodes.firstIndex(where: { $0 === node }) {
                oldParent._childNodes.remove(at: idx)
                oldParent.reindexChildren(idx)
            }
        }
        xmlUnlinkNode(nodePtr)
        if prepend, let firstPtr = parentPtr.pointee.children {
            xmlAddPrevSibling(firstPtr, nodePtr)
        } else {
            xmlAddChild(parentPtr, nodePtr)
        }

        node.parentNode = parent
        node.treeBuilder = parent.treeBuilder
        if prepend {
            parent._childNodes.insert(node, at: 0)
            parent.reindexChildren(0)
        } else {
            parent._childNodes.append(node)
            node.setSiblingIndex(parent._childNodes.count - 1)
        }
        return true
#else
        return false
#endif
    }

    private static func normalizeFrameset(in doc: Document) throws {
        guard let html = try doc.getElementsByTag(UTF8Arrays.html).first() else { return }
        let framesets = try doc.getElementsByTag(UTF8Arrays.frameset)
        if framesets.size() == 0 {
            return
        }
        var rootFrameset: Element? = nil
        for frameset in framesets.array() {
            if let parent = frameset.parent(),
               parent.tagNameNormalUTF8() == UTF8Arrays.html
                || parent.tagNameNormalUTF8() == UTF8Arrays.body {
                rootFrameset = frameset
                break
            }
        }
        guard let frameset = rootFrameset else { return }
        if frameset.parent() !== html {
            try frameset.remove()
            try html.appendChild(frameset)
        }
        if let body = doc.body() {
            try body.remove()
        }
    }

    private static func normalizeImplicitParagraphs(in doc: Document, allowUnwrap: Bool) throws {
        guard allowUnwrap else { return }
        guard let body = doc.body() else { return }
        let overrides = doc.libxml2AttributeOverrides
        var candidates: [Element] = []
        for child in body.children().array() {
            if child.tagNameNormalUTF8() != UTF8Arrays.p {
                continue
            }
            if child.attributes?.size() ?? 0 > 0 {
                continue
            }
            if let nodePtr = child.libxml2NodePtr,
               overrides?[UnsafeMutableRawPointer(nodePtr)] != nil {
                continue
            }
            var hasElementChild = false
            for node in child.childNodes {
                if node is Element {
                    hasElementChild = true
                    break
                }
            }
            if !hasElementChild {
                candidates.append(child)
            }
        }
        if candidates.isEmpty {
            return
        }
        for element in candidates {
            _ = try element.unwrap()
        }
    }

    private static func hasExplicitParagraphStartTag(_ bytes: [UInt8]) -> Bool {
        guard !bytes.isEmpty else { return false }
        var found = false
        let count = bytes.count
        bytes.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            var i = 0
            @inline(__always)
            func advanceToNextTag(from start: Int) -> Int? {
                let remaining = count - start
                if remaining <= 0 {
                    return nil
                }
                guard let foundPtr = memchr(base.advanced(by: start), 0x3C, remaining) else {
                    return nil
                }
                return Int(bitPattern: foundPtr) - Int(bitPattern: base)
            }
            while i < count {
                if base[i] != 0x3C { // <
                    if let next = advanceToNextTag(from: i + 1) {
                        i = next
                    } else {
                        break
                    }
                    continue
                }
                if i + 1 >= count {
                    break
                }
                let next = base[i + 1]
                if next == 0x21 { // !
                    if i + 3 < count && base[i + 2] == 0x2D && base[i + 3] == 0x2D { // <!--
                        var j = i + 4
                        while j + 2 < count {
                            if base[j] == 0x2D && base[j + 1] == 0x2D && base[j + 2] == 0x3E {
                                i = j + 3
                                break
                            }
                            j += 1
                        }
                        if j + 2 >= count {
                            break
                        }
                        continue
                    }
                    var j = i + 2
                    while j < count && base[j] != 0x3E {
                        j += 1
                    }
                    i = min(j + 1, count)
                    continue
                }
                if next == 0x2F { // /
                    var j = i + 2
                    while j < count && base[j] != 0x3E {
                        j += 1
                    }
                    i = min(j + 1, count)
                    continue
                }
                if next == 0x3F { // ?
                    var j = i + 2
                    while j + 1 < count {
                        if base[j] == 0x3F && base[j + 1] == 0x3E {
                            i = j + 2
                            break
                        }
                        j += 1
                    }
                    if j + 1 >= count {
                        break
                    }
                    continue
                }
                if !isNameCharTable[Int(next)] {
                    i += 1
                    continue
                }
                let nameStart = i + 1
                var nameEnd = nameStart
                while nameEnd < count && isNameCharTable[Int(base[nameEnd])] {
                    nameEnd += 1
                }
                if nameEnd == nameStart + 1 {
                    let b = base[nameStart]
                    if b == 0x70 || b == 0x50 { // p/P
                        found = true
                        break
                    }
                }
                i = nameEnd
            }
        }
        return found
    }

    private static func applyBaseUriFromFirstBaseTag(in doc: Document) throws {
        let bases = try doc.getElementsByTag("base")
        if bases.size() == 0 {
            return
        }
        let first = bases.get(0)
        let href = try first.absUrl("href")
        if href.isEmpty {
            return
        }
        try doc.setBaseUri(href)
    }

    private static func shouldFallbackToSwiftSoup(
        _ bytes: [UInt8],
        reason: inout Libxml2FallbackReason?,
        recordReason: Bool,
        hints: inout HtmlScanHints
    ) -> Bool {
        @inline(__always)
        func fail(_ r: Libxml2FallbackReason) -> Bool {
            if recordReason {
                reason = r
            }
            return true
        }

        if fallbackCEnabled() {
            var cReason: swiftsoup_fallback_reason = SWIFTSOUP_FALLBACK_NONE
            var ctx = HtmlScanHintsCContext(hints: hints)
            let shouldFallback = bytes.withUnsafeBufferPointer { buffer -> Bool in
                guard let base = buffer.baseAddress else {
                    return true
                }
                return withUnsafeMutablePointer(to: &ctx) { ctxPtr -> Bool in
                    if booleanHintsEnabled() {
                        if booleanCollectEnabled() {
                            var pairs: UnsafeMutablePointer<Int32>? = nil
                            var count: Int32 = 0
                            let result = swiftsoup_should_fallback_collect(
                                base,
                                Int32(buffer.count),
                                swiftsoupRecordSelfClosingLowercase,
                                ctxPtr,
                                &cReason,
                                &pairs,
                                &count
                            )
                            if let pairs {
                                recordBooleanPairs(UnsafePointer(pairs), count, &ctxPtr.pointee.hints)
                                swiftsoup_free_int32(pairs)
                            }
                            return result != 0
                        }
                        return swiftsoup_should_fallback(
                            base,
                            Int32(buffer.count),
                            swiftsoupRecordSelfClosingLowercase,
                            swiftsoupRecordBoolean,
                            ctxPtr,
                            &cReason
                        ) != 0
                    }
                    return swiftsoup_should_fallback(
                        base,
                        Int32(buffer.count),
                        swiftsoupRecordSelfClosingLowercase,
                        nil,
                        ctxPtr,
                        &cReason
                    ) != 0
                }
            }
            hints = ctx.hints
            let fallback = fallbackReason(from: cReason)
            if recordReason {
                reason = fallback
            }
            return shouldFallback
        }

        let count = bytes.count
        var i = 0
        var sawTagDelimiter = false
        var sawHtmlTag = false
        var sawBodyTag = false
        var inHead = false
        var sawContentBeforeHtml = false
        // track content before html to decide when to fallback
        var headingOpen = false
        var formattingStack: [UInt8] = []
        var openTagDepth = 0
        var selectDepth = 0
        var lowerNameBuffer: [UInt8] = []
        lowerNameBuffer.reserveCapacity(64)
        struct TableState {
            var captionDepth: Int = 0
            var sectionDepth: Int = 0
            var trDepth: Int = 0
            var cellDepth: Int = 0
        }
        var tableStack: [TableState] = []
        formattingStack.reserveCapacity(8)
        tableStack.reserveCapacity(4)

        let tagArea = Libxml2ScanTags.area
        let tagLink = Libxml2ScanTags.link
        let tagParam = Libxml2ScanTags.param
        let tagScript = Libxml2ScanTags.script
        let tagSource = Libxml2ScanTags.source
        let tagStyle = Libxml2ScanTags.style
        let tagTextarea = Libxml2ScanTags.textarea
        let tagTrack = Libxml2ScanTags.track
        let tagWbr = Libxml2ScanTags.wbr

        @inline(__always)
        func asciiLower(_ b: UInt8) -> UInt8 {
            return asciiLowerTable[Int(b)]
        }
        @inline(__always)
        func equalsAsciiLower(_ slice: ArraySlice<UInt8>, _ target: [UInt8]) -> Bool {
            if slice.count != target.count {
                return false
            }
            var idx = 0
            var i = slice.startIndex
            let end = slice.endIndex
            while i < end {
                let byte = slice[i]
                if byte >= 0x80 {
                    return false
                }
                if asciiLower(byte) != target[idx] {
                    return false
                }
                idx += 1
                i = slice.index(after: i)
            }
            return true
        }
        @inline(__always)
        func equalsAsciiLower(_ bytes: UnsafePointer<UInt8>, _ start: Int, _ end: Int, _ target: [UInt8]) -> Bool {
            let length = end - start
            if length != target.count || length <= 0 {
                return false
            }
            var i = 0
            while i < length {
                let byte = bytes[start + i]
                if byte >= 0x80 {
                    return false
                }
                if asciiLower(byte) != target[i] {
                    return false
                }
                i += 1
            }
            return true
        }
        @inline(__always)
        func isInList(_ slice: ArraySlice<UInt8>, _ list: [[UInt8]]) -> Bool {
            for entry in list {
                if equalsAsciiLower(slice, entry) {
                    return true
                }
            }
            return false
        }
        @inline(__always)
        func isWhitespace(_ b: UInt8) -> Bool {
            return isWhitespaceTable[Int(b)]
        }
        @inline(__always)
        func isNameStart(_ b: UInt8) -> Bool {
            return isNameStartTable[Int(b)]
        }
        @inline(__always)
        func isNameChar(_ b: UInt8) -> Bool {
            return isNameCharTable[Int(b)]
        }
        typealias TagId = Token.Tag.TagId

        func formattingTagId(_ tagId: TagId, _ bytes: UnsafePointer<UInt8>, _ start: Int, _ end: Int) -> UInt8? {
            switch tagId {
            case .a: return 0
            case .b: return 1
            case .i: return 2
            case .em: return 4
            case .strong: return 6
            default:
                break
            }
            let length = end - start
            if length == 1, bytes[start] == 0x75 { // u
                return 3
            }
            if length == 4, equalsAsciiLower(bytes, start, end, [0x66, 0x6F, 0x6E, 0x74]) { // font
                return 5
            }
            return nil
        }

        func isHeadingTag(_ tagId: TagId) -> Bool {
            switch tagId {
            case .h1, .h2, .h3, .h4, .h5, .h6:
                return true
            default:
                return false
            }
        }

        func isTableStructureTag(_ tagId: TagId) -> Bool {
            switch tagId {
            case .table, .tbody, .thead, .tfoot, .tr, .td, .th, .caption, .colgroup, .col:
                return true
            default:
                return false
            }
        }

        func isTableOutsideRowAllowed(_ tagId: TagId) -> Bool {
            switch tagId {
            case .table, .thead, .tbody, .tfoot, .tr, .col, .caption, .colgroup, .style, .script:
                return true
            default:
                return false
            }
        }

        func isHeadAllowedTag(_ tagId: TagId, _ bytes: UnsafePointer<UInt8>, _ start: Int, _ end: Int) -> Bool {
            switch tagId {
            case .base, .meta, .title, .style, .script:
                return true
            default:
                return equalsAsciiLower(bytes, start, end, tagLink)
            }
        }

        func isVoidTag(_ tagId: TagId, _ bytes: UnsafePointer<UInt8>, _ start: Int, _ end: Int) -> Bool {
            switch tagId {
            case .br, .hr, .col, .img, .embed, .input, .meta, .base:
                return true
            default:
                break
            }
            let length = end - start
            switch length {
            case 3:
                return equalsAsciiLower(bytes, start, end, tagWbr)
            case 4:
                return equalsAsciiLower(bytes, start, end, tagArea) || equalsAsciiLower(bytes, start, end, tagLink)
            case 5:
                return equalsAsciiLower(bytes, start, end, tagParam) || equalsAsciiLower(bytes, start, end, tagTrack)
            case 6:
                return equalsAsciiLower(bytes, start, end, tagSource)
            default:
                return false
            }
        }

        return bytes.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else {
                return fail(.malformedTag)
            }
            @inline(__always)
            func skipRawText(_ tag: [UInt8], _ start: Int) -> Int? {
                var j = start
                while j + tag.count + 2 < count {
                    if base[j] == 0x3C && base[j + 1] == 0x2F {
                        var k = 0
                        while k < tag.count {
                            let b = base[j + 2 + k]
                            if b >= 0x80 || asciiLower(b) != tag[k] {
                                break
                            }
                            k += 1
                        }
                        if k == tag.count {
                            var end = j + 2 + tag.count
                            while end < count && base[end] != 0x3E {
                                end += 1
                            }
                            return min(end + 1, count)
                        }
                    }
                    j += 1
                }
                return nil
            }
            while i < count {
                if base[i] == 0x00 {
                    return fail(.containsNull)
                }
                if base[i] != 0x3C { // <
                    if !sawHtmlTag && !isWhitespace(base[i]) {
                        sawContentBeforeHtml = true
                    }
                    if sawHtmlTag && !sawBodyTag && !inHead && !isWhitespace(base[i]) {
                        sawBodyTag = true // implicit body
                    }
                    i += 1
                    continue
                }
                sawTagDelimiter = true
                if i + 1 >= count {
                    return fail(.malformedTag)
                }
                let next = base[i + 1]
            if next == 0x21 { // !
                if i + 4 < count,
                   base[i + 2] == 0x2D,
                   base[i + 3] == 0x2D,
                   base[i + 4] == 0x2D {
                    return fail(.commentDashDashDash)
                }
                if i + 3 < count && base[i + 2] == 0x2D && base[i + 3] == 0x2D {
                    var j = i + 4
                    while j + 2 < count {
                        if base[j] == 0x2D && base[j + 1] == 0x2D && base[j + 2] == 0x3E {
                            i = j + 3
                            break
                        }
                        j += 1
                    }
                    if j + 2 >= count {
                        return fail(.malformedTag)
                    }
                    continue
                }
                var j = i + 2
                while j < count && base[j] != 0x3E {
                    j += 1
                }
                if j >= count {
                    return fail(.malformedTag)
                }
                i = j + 1
                continue
            }
            if next == 0x2F { // </
                let nameStart = i + 2
                var nameEnd = nameStart
                while nameEnd < count && isNameChar(base[nameEnd]) {
                    let b = base[nameEnd]
                    if b == 0x3A { // :
                        return fail(.namespacedTag)
                    }
                    nameEnd += 1
                }
                if nameEnd == i + 2 {
                    return fail(.malformedTag)
                }
                if nameEnd < count && base[nameEnd] >= 0x80 {
                    return fail(.nonAsciiTagName)
                }
                let tagId = Token.Tag.tagIdForAsciiLowercaseBytes(base, nameStart, nameEnd) ?? .none
                if tagId == .noscript {
                    // noscript is handled post-parse for head-specific behavior
                }
                if isVoidTag(tagId, base, nameStart, nameEnd) {
                    return fail(.voidEndTag)
                }
                if isTableStructureTag(tagId) {
                    if !tableStack.isEmpty {
                        if tagId == .table {
                            tableStack.removeLast()
                        } else {
                            var state = tableStack[tableStack.count - 1]
                            if tagId == .caption {
                                state.captionDepth = max(0, state.captionDepth - 1)
                            } else if tagId == .tbody
                                        || tagId == .thead
                                        || tagId == .tfoot {
                                state.sectionDepth = max(0, state.sectionDepth - 1)
                            } else if tagId == .tr {
                                state.trDepth = max(0, state.trDepth - 1)
                                state.cellDepth = 0
                            } else if tagId == .td
                                        || tagId == .th {
                                state.cellDepth = max(0, state.cellDepth - 1)
                            }
                            if !tableStack.isEmpty {
                                tableStack[tableStack.count - 1] = state
                            }
                        }
                    }
                }
                if tagId == .select {
                    if selectDepth > 0 {
                        selectDepth -= 1
                    }
                }
                if isHeadingTag(tagId) {
                    headingOpen = false
                }
                if let formatId = formattingTagId(tagId, base, nameStart, nameEnd) {
                    if let idx = formattingStack.lastIndex(of: formatId) {
                        if idx == formattingStack.count - 1 {
                            formattingStack.removeLast()
                        } else {
                            return fail(.formattingMismatch)
                        }
                    }
                }
                if tagId == .head { // head
                    inHead = false
                } else if tagId == .body { // body
                    sawBodyTag = true
                }
                if openTagDepth > 0 {
                    openTagDepth -= 1
                }
                var j = nameEnd
                while j < count && base[j] != 0x3E {
                    j += 1
                }
                if j >= count {
                    return fail(.malformedTag)
                }
                i = j + 1
                continue
            }
            if next == 0x3F { // <?
                var j = i + 2
                while j < count && base[j] != 0x3E {
                    j += 1
                }
                if j >= count {
                    return fail(.malformedTag)
                }
                i = j + 1
                continue
            }
            if !isNameChar(next) {
                return fail(.malformedTag)
            }
            let nameStart = i + 1
            var nameEnd = nameStart
            while nameEnd < count && isNameChar(base[nameEnd]) {
                let b = base[nameEnd]
                if b == 0x3A { // :
                    return fail(.namespacedTag)
                }
                nameEnd += 1
            }
            if nameEnd == i + 1 {
                return fail(.malformedTag)
            }
            if nameEnd < count && base[nameEnd] >= 0x80 {
                return fail(.nonAsciiTagName)
            }
            let tagId = Token.Tag.tagIdForAsciiLowercaseBytes(base, nameStart, nameEnd) ?? .none
            if tagId == .noscript {
                // noscript is handled post-parse for head-specific behavior
            }
            if tagId == .hgroup {
                return fail(.tableHeuristics)
            }
            if tagId == .table {
                if let state = tableStack.last, state.cellDepth == 0 {
                    return fail(.tableHeuristics)
                }
                tableStack.append(TableState())
            } else if tableStack.isEmpty && isTableStructureTag(tagId) {
                return fail(.tableHeuristics)
            } else if !tableStack.isEmpty {
                var state = tableStack[tableStack.count - 1]
                if state.captionDepth > 0 && isTableStructureTag(tagId) {
                    return fail(.tableHeuristics)
                }
                if tagId == .caption {
                    if state.captionDepth > 0 {
                        return fail(.tableHeuristics)
                    }
                    state.captionDepth += 1
                } else if tagId == .tbody
                            || tagId == .thead
                            || tagId == .tfoot {
                    if state.captionDepth > 0 {
                        return fail(.tableHeuristics)
                    }
                    state.sectionDepth += 1
                } else if tagId == .tr {
                    if state.captionDepth > 0 {
                        return fail(.tableHeuristics)
                    }
                    state.trDepth += 1
                    state.cellDepth = 0
                } else if tagId == .td
                            || tagId == .th {
                    if state.captionDepth > 0 || state.trDepth == 0 {
                        return fail(.tableHeuristics)
                    }
                    state.cellDepth += 1
                }
                if state.captionDepth == 0 && state.trDepth == 0 {
                    if !isTableOutsideRowAllowed(tagId) {
                        return fail(.tableHeuristics)
                    }
                }
                tableStack[tableStack.count - 1] = state
            }
            if isHeadingTag(tagId) {
                if headingOpen {
                    return fail(.formattingMismatch)
                }
                headingOpen = true
            }
            if tagId == .p, !formattingStack.isEmpty {
                return fail(.formattingMismatch)
            }
            if tagId == .html { // html
                if sawContentBeforeHtml {
                    return fail(.headBodyPlacement)
                }
                sawHtmlTag = true
            } else if !sawHtmlTag {
                // tags before html are handled by normalizeBodyPlacement
            }
            if sawHtmlTag && !sawBodyTag {
                if tagId == .head { // head
                    inHead = true
                } else if tagId == .body { // body
                    sawBodyTag = true
                    inHead = false
                } else if inHead {
                    if !isHeadAllowedTag(tagId, base, nameStart, nameEnd) {
                        inHead = false
                        sawBodyTag = true
                    }
                } else if !isHeadAllowedTag(tagId, base, nameStart, nameEnd) {
                    sawBodyTag = true
                }
            } else if tagId == .body { // body before html
                if !sawHtmlTag && (sawContentBeforeHtml || openTagDepth > 0) {
                    return fail(.headBodyPlacement)
                }
            }
            var j = nameEnd
            var sawTagEnd = false
            var sawSelfClosing = false
            while j < count {
                while j < count && isWhitespace(base[j]) {
                    j += 1
                }
                if j >= count {
                    return fail(.malformedTag)
                }
                if base[j] == 0x3E { // >
                    j += 1
                    sawTagEnd = true
                    break
                }
                if base[j] == 0x2F && j + 1 < count && base[j + 1] == 0x3E { // />
                    j += 2
                    sawTagEnd = true
                    sawSelfClosing = true
                    break
                }
                var attrStart = j
                if base[j] == 0x2F, j + 1 < count, isAsciiLetter(base[j + 1]) {
                    // Allow leading "/" in attribute names to match SwiftSoup tokenization quirks.
                    j += 1
                    attrStart = j
                }
                while j < count && !isWhitespace(base[j]) && base[j] != 0x3D && base[j] != 0x3E && base[j] != 0x2F {
                    let b = base[j]
                    if b >= 0x80 {
                        return fail(.nonAsciiAttributeName)
                    }
                    if b == 0x22 || b == 0x27 || b == 0x00 || b == 0x3C || b == 0x3E {
                        return fail(.malformedAttribute)
                    }
                    j += 1
                }
                if attrStart == j {
                    return fail(.malformedAttribute)
                }
                let booleanIndex = booleanAttributeIndex(bytes: base, start: attrStart, end: j)
                while j < count && isWhitespace(base[j]) {
                    j += 1
                }
                if j < count && base[j] == 0x3D { // =
                    j += 1
                    while j < count && isWhitespace(base[j]) {
                        j += 1
                    }
                    if j >= count {
                        return fail(.malformedAttribute)
                    }
                    if base[j] == 0x22 || base[j] == 0x27 { // quoted
                        let quote = base[j]
                        j += 1
                        while j < count && base[j] != quote {
                            if base[j] == 0x00 {
                                return fail(.malformedAttribute)
                            }
                            j += 1
                        }
                        if j >= count {
                            return fail(.malformedAttribute)
                        }
                        j += 1
                    } else { // unquoted
                        if base[j] == 0x3C || base[j] == 0x3D {
                            return fail(.malformedAttribute)
                        }
                        while j < count && !isWhitespace(base[j]) && base[j] != 0x3E {
                            let b = base[j]
                            if b == 0x3C || b == 0x22 || b == 0x27 {
                                return fail(.malformedAttribute)
                            }
                            j += 1
                        }
                    }
                    if let booleanIndex {
                        hints.recordBooleanAttribute(index: booleanIndex, isBoolean: false)
                    }
                } else {
                    if let booleanIndex {
                        hints.recordBooleanAttribute(index: booleanIndex, isBoolean: true)
                    }
                }
            }
            var isSelfClosing = false
            if !sawTagEnd {
                return fail(.malformedTag)
            }
            if sawSelfClosing {
                isSelfClosing = true
            } else if j > 0 {
                var scan = j - 1
                while scan > nameEnd && isWhitespace(base[scan]) {
                    scan -= 1
                }
                if base[scan] == 0x2F {
                    isSelfClosing = true
                }
            }
            if tagId == .none {
                lowerNameBuffer.removeAll(keepingCapacity: true)
                lowerNameBuffer.reserveCapacity(nameEnd - nameStart)
                var idx = nameStart
                while idx < nameEnd {
                    lowerNameBuffer.append(asciiLower(base[idx]))
                    idx += 1
                }
                hints.recordSelfClosing(tagName: lowerNameBuffer, isSelfClosing: isSelfClosing)
            }
            if !isSelfClosing && tagId == .script { // script
                if let newIndex = skipRawText(tagScript, j) {
                    i = newIndex
                    continue
                }
                return fail(.rawTextUnterminated)
            }
            if !isSelfClosing && tagId == .style { // style
                if let newIndex = skipRawText(tagStyle, j) {
                    i = newIndex
                    continue
                }
                return fail(.rawTextUnterminated)
            }
            if !isSelfClosing && tagId == .textarea { // textarea
                if let newIndex = skipRawText(tagTextarea, j) {
                    i = newIndex
                    continue
                }
                return fail(.rawTextUnterminated)
            }
            if let formatId = formattingTagId(tagId, base, nameStart, nameEnd),
               !isSelfClosing && !isVoidTag(tagId, base, nameStart, nameEnd) {
                formattingStack.append(formatId)
            }
            if tagId == .select, !isSelfClosing {
                selectDepth += 1
            }
            if !isSelfClosing {
                openTagDepth += 1
            }
            i = j
            }
            if !sawTagDelimiter {
                return fail(.noTagDelimiter)
            }
            if headingOpen || !formattingStack.isEmpty {
                return fail(.formattingMismatch)
            }
            if selectDepth > 0 {
                return fail(.tableHeuristics)
            }
            if recordReason {
                reason = nil
            }
            return false
        }
    }
}
#endif
