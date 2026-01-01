import Foundation

@usableFromInline
internal enum OptimizationFlags {
    @inline(__always)
    private static func envBool(_ key: String, default defaultValue: Bool) -> Bool {
        guard let value = ProcessInfo.processInfo.environment[key] else { return defaultValue }
        if let parsed = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return parsed != 0
        }
        switch value.lowercased() {
        case "true", "yes", "on":
            return true
        case "false", "no", "off":
            return false
        default:
            return defaultValue
        }
    }

    /// Enables word-scan path in CharacterReader.consumeData.
    @usableFromInline
    static let useWordScanConsumeData: Bool = envBool("SWIFTSOUP_OPT_WORDSCAN_CONSUMEDATA", default: true)

    /// Enables slice-backed Attribute storage to avoid copying during parse.
    @usableFromInline
    static let useAttributeSlices: Bool = envBool("SWIFTSOUP_OPT_ATTRIBUTE_SLICES", default: true)

    /// Enables pointer-based whitespace normalization for ArraySlice paths.
    @usableFromInline
    static let usePointerWhitespaceNormalize: Bool = envBool("SWIFTSOUP_OPT_POINTER_WHITESPACE", default: true)

    /// Enables fast trailing-trim decisions in Element.text() family.
    @usableFromInline
    static let useTextTrimFastPath: Bool = envBool("SWIFTSOUP_OPT_TEXT_TRIM_FAST", default: true)
}
