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
    var includeInnerHtml: Bool
    var selectQuery: String?
    var selectIterations: Int
    var backend: Parser.Backend
}

func parseOptions() -> Options {
    let args = ProcessInfo.processInfo.arguments
    var fixturesPath = ProcessInfo.processInfo.environment["READABILITY_FIXTURES"]
    var includeText = false
    var includeInnerHtml = false
    var selectQuery: String? = nil
    var selectIterations = 1
    var backend: Parser.Backend = .swiftSoup

    var i = 1
    while i < args.count {
        let arg = args[i]
        if arg == "--fixtures", i + 1 < args.count {
            fixturesPath = args[i + 1]
            i += 2
            continue
        } else if arg == "--text" {
            includeText = true
        } else if arg == "--html" {
            includeInnerHtml = true
        } else if arg == "--backend", i + 1 < args.count {
            let value = args[i + 1].lowercased()
            switch value {
            case "swiftsoup", "default":
                backend = .swiftSoup
#if canImport(CLibxml2) || canImport(libxml2)
            case "libxml2":
                backend = .libxml2
#endif
            default:
                writeStderr("Unknown backend: \(value)\n")
                exit(1)
            }
            i += 2
            continue
        } else if arg == "--select", i + 1 < args.count {
            selectQuery = args[i + 1]
            i += 2
            continue
        } else if arg == "--select-iterations", i + 1 < args.count {
            if let parsed = Int(args[i + 1]), parsed > 0 {
                selectIterations = parsed
            }
            i += 2
            continue
        }
        i += 1
    }

    if fixturesPath == nil || fixturesPath!.isEmpty {
        fixturesPath = "/Users/alex/Code/lake-of-fire/swift-readability/Tests/SwiftReadabilityTests/Fixtures"
    }

    return Options(
        fixturesPath: fixturesPath!,
        includeText: includeText,
        includeInnerHtml: includeInnerHtml,
        selectQuery: selectQuery,
        selectIterations: selectIterations,
        backend: backend
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

let options = parseOptions()
let files = findSourceHTMLFiles(fixturesPath: options.fixturesPath)

if files.isEmpty {
    writeStderr("No source.html files found under: \(options.fixturesPath)\n")
    exit(1)
}

Profiler.reset()

let start = Date()
var totalBytes = 0
var parsedCount = 0
var totalParseTime: TimeInterval = 0
var totalSelectTime: TimeInterval = 0
var totalTextTime: TimeInterval = 0
var totalHtmlTime: TimeInterval = 0

for url in files {
    withAutoreleasepool {
        do {
            let data = try Data(contentsOf: url)
            totalBytes += data.count
            let parseStart = Date()
            let doc = try SwiftSoup.parse(data, "", backend: options.backend)
            totalParseTime += Date().timeIntervalSince(parseStart)
            if options.includeText {
                let textStart = Date()
                _ = try doc.text()
                totalTextTime += Date().timeIntervalSince(textStart)
            }
            if options.includeInnerHtml {
                let htmlStart = Date()
                _ = try doc.body()?.html()
                totalHtmlTime += Date().timeIntervalSince(htmlStart)
            }
            if let query = options.selectQuery {
                let selectStart = Date()
                if options.selectIterations == 1 {
                    _ = try doc.select(query)
                } else {
                    var iter = 0
                    while iter < options.selectIterations {
                        _ = try doc.select(query)
                        iter += 1
                    }
                }
                totalSelectTime += Date().timeIntervalSince(selectStart)
            }
            parsedCount += 1
        } catch {
            writeStderr("Error parsing \(url.path): \(error)\n")
        }
    }
}

let total = Date().timeIntervalSince(start)
let mb = Double(totalBytes) / (1024.0 * 1024.0)

print("Parsed \(parsedCount) files, \(String(format: "%.2f", mb)) MB in \(String(format: "%.2f", total)) s")
print("Parse time: \(String(format: "%.2f", totalParseTime)) s")
if options.includeText {
    print("Text time: \(String(format: "%.2f", totalTextTime)) s")
}
if options.includeInnerHtml {
    print("HTML time: \(String(format: "%.2f", totalHtmlTime)) s")
}
if options.selectQuery != nil {
    print("Select time: \(String(format: "%.2f", totalSelectTime)) s")
}
print(Profiler.report(top: 40))
